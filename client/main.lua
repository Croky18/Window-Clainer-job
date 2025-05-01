local QBCore = exports['qb-core']:GetCoreObject()
local isWorking = false
local currentStep = 0
local spawnedVehicle = nil
local currentBlip = nil
local hasNotified = false

-- NPC en qb-target setup
CreateThread(function()
    local model = GetHashKey(Config.NPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local ped = CreatePed(0, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z - 1, Config.NPC.heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    local blip = AddBlipForCoord(Config.NPC.coords)
    SetBlipSprite(blip, 280)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Ramen Job Locatie")
    EndTextCommandSetBlipName(blip)

    local npcCoords = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)

    CreateThread(function()
        while true do
            Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local distance = #(playerCoords - npcCoords)

            if distance < 2.0 then
                DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.0, "[E] Open Menu")
                if IsControlJustReleased(0, 38) then
                    lib.registerContext({
                        id = 'ramen_job_menu',
                        title = 'Ramen Job Menu',
                        options = {
                            {
                                title = 'Start Job',
                                description = 'Begin washing windows',
                                icon = 'broom',
                                onSelect = function()
                                    TriggerEvent('ramenjob:start')
                                end
                            },
                            {
                                title = 'Stop Job',
                                description = 'Stop your current job',
                                icon = 'xmark',
                                disabled = not isWorking,
                                onSelect = function()
                                    TriggerEvent('ramenjob:stop')
                                end
                            }
                        }
                    })
                    lib.showContext('ramen_job_menu')
                end
            end
        end
    end)
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

RegisterNetEvent("ramenjob:start", function()
    if isWorking then 
        return QBCore.Functions.Notify("You're already working!", "error") 
    end

    local player = QBCore.Functions.GetPlayerData()
    if player.job.name ~= Config.RequiredJob then
        return QBCore.Functions.Notify("No access to this job.", "error")
    end

    QBCore.Functions.Notify("Vehicle is spawning...", "success")

    -- Spawn het voertuig met behulp van Config.Vehicle
    local vehicleModel = GetHashKey(Config.Vehicle.model)
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(500)
    end

    spawnedVehicle = CreateVehicle(vehicleModel, Config.Vehicle.spawnPoint.x, Config.Vehicle.spawnPoint.y, Config.Vehicle.spawnPoint.z, Config.Vehicle.spawnPoint.w, true, false)
    SetVehicleOnGroundProperly(spawnedVehicle)
    SetEntityAsMissionEntity(spawnedVehicle, true, true)

    -- Controleer of het voertuig correct gespawn is
    if not DoesEntityExist(spawnedVehicle) then
        QBCore.Functions.Notify("There is a problem with the vehicle.", "error")
        return
    end

    isWorking = true
    currentStep = 1
    GoToNextLocation()
end)

function GoToNextLocation()
    if currentBlip then RemoveBlip(currentBlip) end
    if currentStep > #Config.Locations then
        -- Set a GPS route back to the vehicle return location after completing all tasks
        QBCore.Functions.Notify("Bring the vehicle back", "primary")
        SetGpsBlipForReturn()
        return
    end

    local coords = Config.Locations[currentStep]
    currentBlip = AddBlipForCoord(coords)
    SetBlipRoute(currentBlip, true)

    CreateThread(function()
        while isWorking do
            Wait(0)  -- Keep looping to check player proximity
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(playerCoords - coords) < 2.0 then
                -- Notify only once the player is near the location
                if not hasNotified then
                    QBCore.Functions.Notify("Press E to start washing windows!", "success")
                    hasNotified = true -- Set notification status to true
                end

                if IsControlJustPressed(0, 38) then -- E key to start cleaning
                    TaskStartScenarioInPlace(PlayerPedId(), "world_human_maid_clean", 0, true)
                    local success = StartProgress(9000, "Cleaning windows...")

                    ClearPedTasks(PlayerPedId())
                    if success then
                        -- Reward the player after each cleaning task
                        local randomReward = math.random(Config.RewardPerWindow.min, Config.RewardPerWindow.max)  -- Willekeurig bedrag tussen min en max
                        TriggerServerEvent("ramenjob:addMoney", randomReward) -- Add money after cleaning
                        QBCore.Functions.Notify("You have $" .. randomReward .. " earned for cleaning a window.", "success")
                    
                        -- Verhoog de stap
                        currentStep = currentStep + 1
                    
                        -- Roep de functie aan om naar de volgende locatie te gaan
                        GoToNextLocation()
                    end
                    break
                end
            else
                -- Reset notification status if player is far from the location
                if hasNotified then
                    hasNotified = false
                end
            end
        end
    end)
end

function SetGpsBlipForReturn()
    -- Check if Config.VehicleReturn is defined
    if not Config.VehicleReturn or not Config.VehicleReturn.x or not Config.VehicleReturn.y or not Config.VehicleReturn.z then
        print("Error: VehicleReturn coordinates are not set in the Config.")
        return
    end

    -- Add a GPS blip for the return vehicle location
    currentBlip = AddBlipForCoord(Config.VehicleReturn.x, Config.VehicleReturn.y, Config.VehicleReturn.z)
    SetBlipRoute(currentBlip, true)  -- Enable the GPS route to the return location

    -- Show notification
    QBCore.Functions.Notify("Follow the GPS.", "primary")

    -- Keep the GPS line visible until the player reaches the return point
    CreateThread(function()
        while true do  -- Loop to keep checking the player's distance
            Wait(500)  -- Add a small delay to prevent constant checking

            local playerCoords = GetEntityCoords(PlayerPedId())  -- Get the player's current coordinates
            local distanceToReturn = #(playerCoords - vector3(Config.VehicleReturn.x, Config.VehicleReturn.y, Config.VehicleReturn.z))

            -- If the player reaches the return location
            if distanceToReturn < 2.0 then
                QBCore.Functions.Notify("Return to the NPC to stop the job.", "success")
                -- Optionally, remove the blip if the player has reached the return location
                RemoveBlip(currentBlip)
                break  -- Break out of the loop when the player reaches the return point
            end
        end
    end)
end

function StartProgress(duration, label)
    if Config.Progressbar == 'qs' then
        local result = exports['qs-interface']:ProgressBar({
            duration = duration,
            label = label,
            position = 'bottom',
            canCancel = false
        })
        return result
    else
        local finished = exports['qb-progressbar']:Progress({
            name = "ramen_job",
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = false,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }
        })
        return finished
    end
end

RegisterNetEvent("ramenjob:stop", function()
    if not isWorking then return QBCore.Functions.Notify("You are not working.", "error") end

    if DoesEntityExist(spawnedVehicle) then
        DeleteVehicle(spawnedVehicle)
    end

    isWorking = false
    currentStep = 0
    if currentBlip then RemoveBlip(currentBlip) end
    QBCore.Functions.Notify("Job gestopt.", "primary")
end)
