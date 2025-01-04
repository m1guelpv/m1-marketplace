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
    for _, blacklistedItem in ipairs(Config.BlacklistedItems) do
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

local function getMarketData()
    return MySQL.query.await('SELECT * FROM marketplace_offers')
end

local function getPlayerData(player, citizenid)
    local inventory = getCompactedPlayerInventory(player)
    local offers = MySQL.query.await('SELECT * FROM marketplace_offers WHERE sellerId = ?', { citizenid })
    local history = MySQL.query.await('SELECT * FROM marketplace_logs WHERE sellerid = ? OR buyerid = ?', { citizenid, citizenid })
    local money = player.PlayerData.money[Config.Currency] or 0
    local playerData = {
        id = citizenid,
        name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
        money = money,
        inventory = inventory,
        offers = offers,
        history = history
    }
    return playerData
end

local function reloadPlayerData(player)
    local playerSource = player.PlayerData.source
    local updatedPlayerData = QBCore.Functions.GetPlayer(playerSource).PlayerData
    player.PlayerData.items = updatedPlayerData.items
    player.PlayerData.money[Config.Currency] = updatedPlayerData.money[Config.Currency]
end

local function round(value)
    return math.floor(value + 0.5)
end

-- Callbacks

QBCore.Functions.CreateCallback('m1-marketplace:server:openMarket', function(source, cb)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        cb(nil, nil)
        return
    end
    cb(getMarketData(), getPlayerData(Player, citizenid))
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:createOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].PlayerNotFound })
    end
    if not data or not data.item or not data.quantity or not data.unitPrice then
        return cb({ status = 'error', message = Locales[Config.Lang].InvalidData })
    end
    local itemName = data.item
    local quantity = tonumber(data.quantity)
    local unitPrice = tonumber(data.unitPrice)
    local weight = QBCore.Shared.Items[itemName].weight * quantity
    if isBlacklistedItem(itemName) then
        return cb({ status = 'error', message = Locales[Config.Lang].itemNotAllowed })
    end
    if quantity > Config.MaxQuantity or quantity < 1 then
        return cb({ status = 'error', message = Locales[Config.Lang].MaxQuantityExceeded })
    end
    if unitPrice > Config.MaxPrice or unitPrice < 1 then
        return cb({ status = 'error', message = Locales[Config.Lang].MaxPriceExceeded })
    end
    if weight > Config.MaxWeight then
        return cb({ status = 'error', message = Locales[Config.Lang].maxWeightExceeded })
    end
    local currentOffers = MySQL.query.await('SELECT COUNT(*) AS total FROM marketplace_offers WHERE sellerId = ?', { citizenid })[1].total
    if currentOffers >= Config.MaxOffers then
        return cb({ status = 'error', message = Locales[Config.Lang].MaxOffersReached })
    end
    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount < quantity then
        return cb({ status = 'error', message = Locales[Config.Lang].NotEnoughItems })
    end
    local tax = round(quantity * unitPrice * Config.CreateTax) 
    if Player.PlayerData.money.bank < tax then
        return cb({ status = 'error', message = Locales[Config.Lang].InsufficientTaxMoney })
    end
    if not Player.Functions.RemoveMoney(Config.Currency, tax) then
        return cb({ status = 'error', message = Locales[Config.Lang].RemoveMoneyFailed })
    end
    if not Player.Functions.RemoveItem(itemName, quantity) then
        Player.Functions.AddMoney(Config.Currency, tax)
        return cb({ status = 'error', message = Locales[Config.Lang].RemoveItemFailed })
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
        Player.Functions.AddMoney(Config.Currency, tax)
        return cb({ status = 'error', message = Locales[Config.Lang].OfferCreationFailed })
    end
    reloadPlayerData(Player)
    TriggerClientEvent('m1-marketplace:client:updateMarketData', -1, getMarketData())
    TriggerClientEvent('m1-marketplace:client:updatePlayerData', source, getPlayerData(Player, citizenid))
    cb({ status = 'success', message = Locales[Config.Lang].OfferCreated })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:buyOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Locales[Config.Lang].InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_offers WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Locales[Config.Lang].OfferNotFound })
    end
    if offer.sellerId == citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].BuyOwnOffer })
    end
    local totalPrice = round(offer.quantity * offer.unitPrice)
    if Player.PlayerData.money.bank < totalPrice then
        return cb({ status = 'error', message = Locales[Config.Lang].NotEnoughMoney })
    end
    if not Player.Functions.RemoveMoney(Config.Currency, totalPrice) then
        return cb({ status = 'error', message = Locales[Config.Lang].RemoveMoneyFailed })
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
        Player.Functions.AddMoney(Config.Currency, totalPrice)
        return cb({ status = 'error', message = Locales[Config.Lang].TransactionFailed })
    end
    reloadPlayerData(Player)
    TriggerClientEvent('m1-marketplace:client:updateMarketData', -1, getMarketData())
    TriggerClientEvent('m1-marketplace:client:updatePlayerData', source, getPlayerData(Player, citizenid))
    local Seller = QBCore.Functions.GetPlayerByCitizenId(offer.sellerId)
    if Seller then
        TriggerClientEvent('m1-marketplace:client:updatePlayerData', Seller.PlayerData.source, getPlayerData(Seller, offer.sellerId))
    end
    sendTargetNotification(offer.sellerId, Locales[Config.Lang].OfferPurschased, 'success')
    cb({ status = 'success', message = Locales[Config.Lang].PurchaseSuccess })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:removeOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Locales[Config.Lang].InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_offers WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Locales[Config.Lang].OfferNotFound })
    end
    if offer.sellerId ~= citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].RemoveOthersOffer })
    end
    if not Player.Functions.AddItem(offer.name, offer.quantity) then
        return cb({ status = 'error', message = Locales[Config.Lang].ItemReturnFailed })
    end
    local result = MySQL.rawExecute.await('DELETE FROM marketplace_offers WHERE id = ?', { offerId })
    if not result then
        Player.Functions.RemoveItem(offer.name, offer.quantity)
        return cb({ status = 'error', message = Locales[Config.Lang].RemoveOfferFailed })
    end
    reloadPlayerData(Player)
    TriggerClientEvent('m1-marketplace:client:updateMarketData', -1, getMarketData())
    TriggerClientEvent('m1-marketplace:client:updatePlayerData', source, getPlayerData(Player, citizenid))
    cb({ status = 'success', message = Locales[Config.Lang].OfferRemoved })
end)

QBCore.Functions.CreateCallback('m1-marketplace:server:claimOffer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].PlayerNotFound })
    end
    if not data or not data.id then
        return cb({ status = 'error', message = Locales[Config.Lang].InvalidData })
    end
    local offerId = tonumber(data.id)
    local offer = MySQL.query.await('SELECT * FROM marketplace_logs WHERE id = ?', { offerId })[1]
    if not offer then
        return cb({ status = 'error', message = Locales[Config.Lang].OfferNotFound })
    end
    if offer.sellerId ~= citizenid and offer.buyerId ~= citizenid then
        return cb({ status = 'error', message = Locales[Config.Lang].ClaimNotAuthorized })
    end
    if offer.sellerId == citizenid then
        local totalPrice = round(offer.quantity * offer.unitPrice)
        if offer.sellerClaimed then
            return cb({ status = 'error', message = Locales[Config.Lang].OfferAlreadyClaimed })
        end
        if not Player.Functions.AddMoney(Config.Currency, totalPrice) then
            return cb({ status = 'error', message = Locales[Config.Lang].MoneyClaimFailed })
        end
        local update = MySQL.update.await('UPDATE marketplace_logs SET sellerClaimed = 1 WHERE id = ?', { offerId })
        if not update then
            Player.Functions.RemoveMoney(Config.Currency, totalPrice)
            return cb({ status = 'error', message = Locales[Config.Lang].ClaimUpdateFailed })
        end
    elseif offer.buyerId == citizenid then
        if offer.buyerClaimed then
            return cb({ status = 'error', message = Locales[Config.Lang].OfferAlreadyClaimed })
        end
        if not Player.Functions.AddItem(offer.name, offer.quantity) then
            return cb({ status = 'error', message = Locales[Config.Lang].ItemClaimFailed })
        end
        local update = MySQL.update.await('UPDATE marketplace_logs SET buyerClaimed = 1 WHERE id = ?', { offerId })
        if not update then
            Player.Functions.RemoveItem(offer.name, offer.quantity)
            return cb({ status = 'error', message = Locales[Config.Lang].ClaimUpdateFailed })
        end
    end
    reloadPlayerData(Player)
    TriggerClientEvent('m1-marketplace:client:updatePlayerData', source, getPlayerData(Player, citizenid))
    cb({ status = 'success', message = Locales[Config.Lang].OfferClaimed })
end)