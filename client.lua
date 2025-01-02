local QBCore = exports['qb-core']:GetCoreObject()

local pedsSpawned = false
local pedsCreated = {}

-- Functions

local function openMarket()
    QBCore.Functions.TriggerCallback('m1-marketplace:server:openMarket', function(marketData, playerData)
        if marketData and playerData then
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openMarket',
                settings = Config.Offer,
                marketData = marketData,
                playerData = playerData,
            })
        else
            QBCore.Functions.Notify('Unable to fetch market data from the server. Please contact staff if the issue persists.', 'error')
        end
    end)
end

local function createBlips()
    if pedsSpawned then
        return
    end
    for _, v in pairs(Config.Locations) do
        if v.blip then
            local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, v.blip.sprite)
            SetBlipScale(blip, v.blip.scale)
            SetBlipDisplay(blip, 4)
            SetBlipColour(blip, v.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(v.blip.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end

local function createPeds()
    if pedsSpawned then 
        return 
    end
    for k, v in pairs(Config.Locations) do
        local model = v.ped.model
        RequestModel(model)
        while not HasModelLoaded(model) do 
            Wait(0)
        end
        local ped = CreatePed(0, model, v.coords.x, v.coords.y, v.coords.z - 1, v.coords.h, false, false)
        TaskStartScenarioInPlace(ped, v.ped.scenario, 0, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    label = v.ped.label,
                    icon = v.ped.icon,
                    action = openMarket
                }
            },
            distance = 2.0
        })
        pedsCreated[k] = ped
    end
    pedsSpawned = true
end

local function deletePeds()
    if not pedsSpawned then 
        return
    end
    for _, v in pairs(pedsCreated) do
        DeletePed(v)
    end
    pedsCreated = {}
    pedsSpawned = false
end

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createBlips()
    createPeds()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    deletePeds()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then 
        return 
    end
    createBlips()
    createPeds()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then 
        return 
    end
    deletePeds()
end)

-- NUI Callback

RegisterNUICallback('closeMarket', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('createOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('m1-marketplace:server:createOffer', function(response)
        if response then
            QBCore.Functions.Notify(response.message, response.status)
        end
        cb(response)
    end, data)
end)

RegisterNUICallback('removeOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('m1-marketplace:server:removeOffer', function(response)
        if response then
            QBCore.Functions.Notify(response.message, response.status)
        end
        cb(response)
    end, data)
end)

RegisterNUICallback('buyOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('m1-marketplace:server:buyOffer', function(response)
        if response then
            QBCore.Functions.Notify(response.message, response.status)
        end
        cb(response)
    end, data)
end)

RegisterNUICallback('claimOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('m1-marketplace:server:claimOffer', function(response)
        if response then
            QBCore.Functions.Notify(response.message, response.status)
        end
        cb(response)
    end, data)
end)