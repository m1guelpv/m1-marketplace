local QBCore = exports['qb-core']:GetCoreObject()

-- Functions

local function getPlayerAndCitizenId(playerId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then 
        return nil, nil
    end
    return Player, Player.PlayerData.citizenid
end

local function isBlacklistedItem(item)
    for _, blacklistedItem in ipairs(Config.Offer.blacklistedItems) do
        if blacklistedItem == item then
            return true
        end
    end
    return false
end

local function sendTargetNotification(citizenid, message, type)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then 
        TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, message, type)
    end
end

local function getCompactedPlayerInventory(player)
    local inventory = {}
    for _, item in pairs(player.PlayerData.items) do
        if item and not isBlacklistedItem(item.name) then
            if inventory[item.name] then
                inventory[item.name].amount = inventory[item.name].amount + item.amount
                inventory[item.name].weight = inventory[item.name].weight + item.weight
            else
                inventory[item.name] = {
                    name = item.name,
                    label = item.label,
                    amount = item.amount,
                    weight = item.weight
                }
            end
        end
    end
    return inventory
end

-- Callbacks

QBCore.Functions.CreateCallback('m1-marketplace:server:openMarket', function(source, cb)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        cb(nil, nil)
        return
    end
    local marketData = MySQL.query.await('SELECT * FROM marketplace_offers')
    local playerData = {
        id = citizenid,
        name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        bank = Player.PlayerData.money.bank,
        inventory = getCompactedPlayerInventory(Player),
        offers = MySQL.query.await('SELECT * FROM marketplace_offers WHERE sellerId = ?', { citizenid }),
        history = MySQL.query.await('SELECT * FROM marketplace_logs WHERE sellerid = ? OR buyerid = ?', { citizenid, citizenid })
    }
    cb(marketData, playerData)
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:createOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.PlayerNotFound })
    end
    if not data or not data.item or not data.quantity or not data.unitPrice then
        return cb({ status = 'error', message = Config.Messages.Errors.InvalidData })
    end
    local itemName = data.item
    local quantity = tonumber(data.quantity)
    local unitPrice = tonumber(data.unitPrice)
    local weight = QBCore.Shared.Items[itemName].weight * quantity
    if isBlacklistedItem(itemName) then
        return cb({ status = 'error', message = Config.Messages.Errors.itemNotAllowed })
    end
    if quantity > Config.Offer.maxQuantity or quantity < 1 then
        return cb({ status = 'error', message = Config.Messages.Errors.MaxQuantityExceeded })
    end
    if unitPrice > Config.Offer.maxPrice or unitPrice < 1 then
        return cb({ status = 'error', message = Config.Messages.Errors.MaxPriceExceeded })
    end
    if weight > Config.Offer.maxWeight then
        return cb({ status = 'error', message = Config.Messages.Errors.maxWeightExceeded })
    end
    local currentOffers = MySQL.query.await('SELECT COUNT(*) AS total FROM marketplace_offers WHERE sellerId = ?', { citizenid })[1].total
    if currentOffers >= Config.Offer.maxOffers then
        return cb({ status = 'error', message = Config.Messages.Errors.MaxOffersReached })
    end
    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount < quantity then
        return cb({ status = 'error', message = Config.Messages.Errors.NotEnoughItems })
    end
    local tax = quantity * unitPrice * Config.Offer.createTax
    if Player.PlayerData.money.bank < tax then
        return cb({ status = 'error', message = Config.Messages.Errors.InsufficientTaxMoney })
    end
    if not Player.Functions.RemoveMoney('bank', tax) then
        return cb({ status = 'error', message = Config.Messages.Errors.RemoveMoneyFailed })
    end
    if not Player.Functions.RemoveItem(itemName, quantity) then
        Player.Functions.AddMoney('bank', tax)
        return cb({ status = 'error', message = Config.Messages.Errors.RemoveItemFailed })
    end
    local result = MySQL.insert.await('INSERT INTO marketplace_offers (name, label, quantity, weight, unitPrice, sellerId, sellerName) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        itemName,
        QBCore.Shared.Items[itemName].label,
        quantity,
        weight,
        unitPrice,
        citizenid,
        Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
    })
    if not result then
        Player.Functions.AddItem(itemName, quantity)
        Player.Functions.AddMoney('bank', tax)
        return cb({ status = 'error', message = Config.Messages.Errors.OfferCreationFailed })
    end
    cb({ status = 'success', message = Config.Messages.Success.OfferCreated })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:buyOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Config.Messages.Errors.InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_offers WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Config.Messages.Errors.OfferNotFound })
    end
    if offer.sellerId == citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.BuyOwnOffer })
    end
    local totalPrice = offer.quantity * offer.unitPrice
    if Player.PlayerData.money.bank < totalPrice then
        return cb({ status = 'error', message = Config.Messages.Errors.NotEnoughMoney })
    end
    if not Player.Functions.RemoveMoney('bank', totalPrice) then
        return cb({ status = 'error', message = Config.Messages.Errors.RemoveMoneyFailed })
    end
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local transactionSuccess = MySQL.transaction.await({
        {
            query = 'DELETE FROM marketplace_offers WHERE id = ?',
            values = { offerId }
        },
        {
            query = 'INSERT INTO marketplace_logs (name, label, quantity, weight, unitPrice, sellerId, sellerName, buyerId, buyerName) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            values = { offer.name, offer.label, offer.quantity, offer.weight, offer.unitPrice, offer.sellerId, offer.sellerName, citizenid, playerName }
        }
    })

    if not transactionSuccess then
        Player.Functions.AddMoney('bank', totalPrice)
        return cb({ status = 'error', message = Config.Messages.Errors.TransactionFailed })
    end
    sendTargetNotification(offer.sellerId, Config.Messages.Success.OfferPurschased, 'success')
    cb({ status = 'success', message = Config.Messages.Success.PurchaseSuccess })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:removeOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Config.Messages.Errors.InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_offers WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Config.Messages.Errors.OfferNotFound })
    end
    if offer.sellerId ~= citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.RemoveOthersOffer })
    end
    if not Player.Functions.AddItem(offer.name, offer.quantity) then
        return cb({ status = 'error', message = Config.Messages.Errors.ItemReturnFailed })
    end
    local result = MySQL.rawExecute.await('DELETE FROM marketplace_offers WHERE id = ?', { offerId })
    if not result then
        Player.Functions.RemoveItem(offer.name, offer.quantity)
        return cb({ status = 'error', message = Config.Messages.Errors.RemoveOfferFailed })
    end
    cb({ status = 'success', message = Config.Messages.Success.OfferRemoved })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:claimOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Config.Messages.Errors.InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_logs WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Config.Messages.Errors.OfferNotFound })
    end
    if offer.sellerId ~= citizenid and offer.buyerId ~= citizenid then
        return cb({ status = 'error', message = Config.Messages.Errors.ClaimNotAuthorized })
    end
    if offer.sellerId == citizenid then
        if offer.sellerClaimed then
            return cb({ status = 'error', message = Config.Messages.Errors.OfferAlreadyClaimed })
        end
        if not Player.Functions.AddMoney('bank', offer.unitPrice * offer.quantity) then
            return cb({ status = 'error', message = Config.Messages.Errors.MoneyClaimFailed })
        end
        local update = MySQL.update.await('UPDATE marketplace_logs SET sellerClaimed = 1 WHERE id = ?', { offerId })
        if not update then
            Player.Functions.RemoveMoney('bank', offer.unitPrice * offer.quantity)
            return cb({ status = 'error', message = Config.Messages.Errors.ClaimUpdateFailed })
        end
    elseif offer.buyerId == citizenid then
        if offer.buyerClaimed then
            return cb({ status = 'error', message = Config.Messages.Errors.OfferAlreadyClaimed })
        end
        if not Player.Functions.AddItem(offer.name, offer.quantity) then
            return cb({ status = 'error', message = Config.Messages.Errors.ItemClaimFailed })
        end
        local update = MySQL.update.await('UPDATE marketplace_logs SET buyerClaimed = 1 WHERE id = ?', { offerId })
        if not update then
            Player.Functions.RemoveItem(offer.name, offer.quantity)
            return cb({ status = 'error', message = Config.Messages.Errors.ClaimUpdateFailed })
        end
    end
    cb({ status = 'success', message = Config.Messages.Success.OfferClaimed })
end)
