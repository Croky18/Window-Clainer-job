local QBCore = nil
local ESX = nil

if Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()
--elseif Config.Framework == 'ESX' then
  --  TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
end

-- Adding money to the player
RegisterServerEvent("ramenjob:addMoney", function(amount)
    local src = source
    if Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddMoney('cash', amount)
        end
    end
end)

--[[-- ESX Progress Bar Event
RegisterNetEvent('esx_progressbar:start')
AddEventHandler('esx_progressbar:start', function(label, duration)
    TriggerEvent('esx:showNotification', label)
    local startTime = GetGameTimer()
    local endTime = startTime + duration                            -----------------Nog in niet helemaal klaar-------------------

    CreateThread(function()
        while GetGameTimer() < endTime do
            Citizen.Wait(0)
        end
        TriggerEvent('esx:showNotification', "Task completed!")
    end)
end)
]]

-- Paying the player after the job
RegisterServerEvent("ramenjob:server:payPlayer", function()
    local src = source
    if Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local amount = math.random(50, 150)
            Player.Functions.AddMoney('cash', amount)
            -- Notify using QBCore notification
            QBCore.Functions.Notify(src, "You have earned $" .. amount .. " for completing the job!", "success")
        end
    end
end)
