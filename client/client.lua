---@diagnostic disable: missing-parameter
local cacheTimers = {}
local QBCore = exports['qb-core']:GetCoreObject()

for veh in EnumerateVehicles() do
    DeleteEntity(veh)
end


local player = {ped = nil, coords = nil, areaId = nil}

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        player.ped = PlayerPedId()
        player.coords = GetEntityCoords(player.ped)
        
        for id, area in pairs(config.AuctionAreas) do
            if #(player.coords - area.coords) <= area.radius then
                player.areaId = id
            end
        end
        Citizen.Wait(sleep)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)

    if onScreen then
        SetTextScale(0.50, 0.50)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

local mainmenu = MenuV:CreateMenu(false, 'Auction House', 'topright', 220, 20, 60, 'size-125', 'none', 'menuv', 'auctionmain')
local auctionmenu = MenuV:CreateMenu(false, 'Auction', 'topright', 220, 20, 60, 'size-125', 'none', 'menuv', 'auction')
local configmenu = MenuV:CreateMenu(false, 'Configure Vehicle Auction', 'topright', 220, 20, 60, 'size-125', 'none', 'menuv', 'auctionconfig')

function OpenMenu()
    mainmenu:ClearItems()
    MenuV:OpenMenu(mainmenu)
end

function OpenAuctionMenu(id)
    auctionmenu:ClearItems()
    MenuV:OpenMenu(auctionmenu)

    auctionmenu:AddButton({
        label = "Make Bid",
        description = "Make a bid on the vehicle",
        value = nil,
        select = function(_)
            local bidinput = LocalInput('Bid: ', 30)
            local bid = tonumber(bidinput)
            if bid ~= nil and type(bid) == "number" then
                TriggerServerEvent("auction:bid", id, bid)
                MenuV:CloseAll()
            else
                notification('error', 'ERROR', 'Invalid Number')
                MenuV:CloseAll()
            end
        end
    })
end

Citizen.CreateThread(function()
    while not player.ped or not player.coords do Citizen.Wait(1000) end

    while true do
        local sleep = 1000

        for id, area in pairs(config.AuctionAreas) do
            local dst = #(player.coords - area.coords)

            if dst <= area.radius then
                sleep = 2

                DrawMarker(27, area.coords.x, area.coords.y, area.coords.z, 0.0,
                            0.0, 0.0, 0, 0.0, 0.0, area.radius * 2.0,
                            area.radius * 2.0, area.radius * 2.0, player.areaId == id and 0 or 255, player.areaId == id and 255, player.areaId == id and 0,
                            100, false, true, 2, false, false, false, false)

                if area.beingUsed then
                    DrawText3D(area.coords.x, area.coords.y, area.coords.z + 2, string.format("~b~Title:~w~ %s <br>~b~Value:~w~ $%s <br> ~b~Time Left:~w~ %s", area.data.data.title, area.data.bid.value, cacheTimers[id] and cacheTimers[id] or "0"))

                    if IsControlJustReleased(0, 38) then
                        OpenAuctionMenu(id)
                    end
                else
                    DrawText3D(area.coords.x, area.coords.y, area.coords.z + 2, "Click ~b~[E]~w~ to start an auction")
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent("auction:isAreaFree", id)
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

local tempSpawnedCars = {}
Citizen.CreateThread(function()
    while true do
        local sleep = 1000

        for id, area in pairs(config.AuctionAreas) do
            if area.beingUsed then
                local dst = #(area.coords - player.coords)

                if dst < 100 and not tempSpawnedCars[id] then
                    local model = area.data.data.model
                    QBCore.Functions.SpawnVehicle(model, function(veh)
                        SetEntityInvincible(veh, true)
                        SetVehicleNumberPlateText(veh, area.data.data.plate)
                        SetEntityHeading(veh, area.heading)
                        SetVehicleOnGroundProperly(veh)
                        SetVehicleDirtLevel(veh, 0.0)
                        SetVehicleDoorsLocked(veh, 3)
                        FreezeEntityPosition(veh, true)
                        if area.data.data.plate ~= 'ADMIN' then
                            QBCore.Functions.SetVehicleProperties(veh, area.data.data.props)
                        end
                            tempSpawnedCars[id] = veh
                    end, area.coords, true)
                elseif dst > 100 and tempSpawnedCars[id] then
                    DeleteEntity(tempSpawnedCars[id])
                    tempSpawnedCars[id] = nil
                end
            elseif not area.beingUsed and tempSpawnedCars[id] then
                DeleteEntity(tempSpawnedCars[id])
                tempSpawnedCars[id] = nil
            end
        end

        Citizen.Wait(sleep)
    end
end)

function openVehicleList(areaId, list)
    MenuV:CloseAll()
    OpenMenu()

    local elements = {}
    for id, veh in pairs(list) do
        elements[#elements + 1] = {
            label = QBCore.Shared.Vehicles[veh.model].name .. "[ " .. veh.plate .. " ]",
            value = id
        }
    end

    for k, v in pairs(elements) do
        mainmenu:AddButton({
            label = v.label,
            description = "Put the " .. v.label .. " on auction",
            select = function(_)
                local title = LocalInput('Title of the auction: ', 30)
                local valueInput = LocalInput('Initial value of the auction: ', 30)
                local initialValue = tonumber(valueInput)
                local chosenVehicle = v.value
                if string.len(title) >=2 and initialValue ~= nil and type(initialValue) == "number" then
                    TriggerServerEvent("auction:claimArea", areaId, title, initialValue, list[chosenVehicle])
                    MenuV:CloseAll()
                else
                    notification('error', 'ERROR', 'Invalid Input')
                    MenuV:CloseAll()
                end
            end
        })
    end
end

RegisterNetEvent("auction:openVehicleList")
AddEventHandler("auction:openVehicleList", openVehicleList)

RegisterNetEvent("auction:syncAreas")
AddEventHandler("auction:syncAreas", function(AuctionAreas)
    config.AuctionAreas = AuctionAreas
end)

-- Citizen.CreateThread(function()
--     while true do
--         local sleep = 200
        
--         if player.areaId and tempSpawnedCars[player.areaId] then
--             local veh = tempSpawnedCars[player.areaId]
            
--             SetEntityHeading(veh, GetEntityHeading(veh) + 0.5)
--         end

--         Citizen.Wait(sleep)
--     end
-- end)



function startTimer(id, seconds)
    cacheTimers[id] = seconds
end

RegisterNetEvent("auction:timer")
AddEventHandler("auction:timer", startTimer)


Citizen.CreateThread(function()
    while true do
        local sleep = 1000

        for id, value in pairs(cacheTimers) do
            if not config.AuctionAreas[id] then
                table.remove(cacheTimers, id)
            else
                if (value-1) > 0 then
                    cacheTimers[id] = cacheTimers[id] - 1
                else
                    cacheTimers[id] = 0
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

-- Create Map Blips
Citizen.CreateThread(function()
    for id, data in pairs(config.MapBlips) do
		local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        
        SetBlipSprite (blip, data.sprite)
        SetBlipDisplay(blip, 2)
        SetBlipScale  (blip, 1.0)
        SetBlipColour (blip, data.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(data.name)
        EndTextCommandSetBlipName(blip)
    end
end)

function LocalInput(text, number, windows)
    AddTextEntry("FMMC_MPM_NA", text)
    DisplayOnscreenKeyboard(1, "FMMC_MPM_NA", "", windows or "", "", "", "", number or 30)
    while (UpdateOnscreenKeyboard() == 0) do
    DisableAllControlActions(0)
    Wait(0)
    end

    if (GetOnscreenKeyboardResult()) then
    local result = GetOnscreenKeyboardResult()
        return result
    end
end