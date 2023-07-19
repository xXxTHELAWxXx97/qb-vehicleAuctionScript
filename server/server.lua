QBCore = exports['qb-core']:GetCoreObject()

local function GeneratePlate()
    local plate = QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(2)
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

RegisterServerEvent("auction:isAreaFree")
AddEventHandler("auction:isAreaFree", function(id)
    local src = source

    if not config.AuctionAreas[id] then
        logs.cheater(src)
        return
    end

    local area = config.AuctionAreas[id]

    if area.beingUsed then
        notification(src, "error", "Info", "Area is being used")
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local pdata = Player.PlayerData

    if QBCore.Functions.HasPermission(src, config.BypassOnwership.permission) then
        local list = {}
        for k, veh in pairs(QBCore.Shared.Vehicles) do
            local hash = GetHashKey(veh.model)
            list[#list + 1] = {
                hash = hash,
                model = veh.model,
                plate = "ADMIN",
                distance = 0
            }
        end
        TriggerClientEvent("auction:openVehicleList", src, id, list)
    elseif pdata.job.name == config.BypassOnwership.job and pdata.job.grade == config.BypassOwnership.grade then
        local list = {}
        for k, veh in pairs(QBCore.Shared.Vehicles) do
            local hash = GetHashKey(veh.model)
            list[#list + 1] = {
                hash = hash,
                model = veh.model,
                plate = "ADMIN",
                distance = 0
            }
        end
        TriggerClientEvent("auction:openVehicleList", src, id, list)
    else
        local result = MySQL.query.await("SELECT * FROM player_vehicles WHERE citizenid = ?", {pdata.citizenid})
        if #result > 0 then
            local list = {}

            for vehId, veh in pairs(result) do
                if veh.balance == 0 and veh.state == 1 then
                    list[#list + 1] = {
                        hash = veh.hash,
                        model = veh.vehicle,
                        plate = veh.plate,
                        props = json.decode(veh.mods),
                        distance = veh.drivingdistance
                    }
                end
            end
            TriggerClientEvent("auction:openVehicleList", src, id, list)
        else
            notification(src, "error", "ERROR", "You dont have any cars")
        end
    end

end)

RegisterServerEvent("auction:claimArea")
AddEventHandler("auction:claimArea", function(id, title, initialValue, data)
    local src = source

    if not config.AuctionAreas[id] then
        logs.cheater(src)
        return
    end

    local area = config.AuctionAreas[id]

    if area.beingUsed then
        notification(src, "error", "Error", "Area is already being used")
        return
    end

    area.beingUsed = true
    area.data = {}
    area.data.player = src

    area.data.bid = {}
    area.data.bid.player = src
    area.data.bid.value = initialValue
    area.data.bid.oldPlayers = {}
    area.data.bid.uniquePlayers = {
        [src] = true,
    }

    area.data.data = {title = title, plate = data.plate, hash = data.hash, model = data.model, distance = data.distance, props = data.props}

    TriggerClientEvent("auction:timer", -1, id, config.AuctionDuration)
    TriggerClientEvent("auction:syncAreas", -1, config.AuctionAreas)

    SetTimeout(config.AuctionDuration * 1000, function()
        local area = config.AuctionAreas[id]

        if area.data.player == area.data.bid.player then
            notification(area.data.player, "error", "ERROR", "No one bid")
            logs.noBid(src, area.data.data.plate)

            area.beingUsed = false

            area.data.player = nil

            area.data.bid.player = nil
            area.data.bid.value = nil
            area.data.bid.oldPlayers = {}
            area.data.bid.uniquePlayers = {}

            area.data.data = nil

            TriggerClientEvent("auction:syncAreas", -1, config.AuctionAreas)
            return
        end
        local oldOwner = QBCore.Functions.GetPlayer(area.data.player)
        local newOwner = QBCore.Functions.GetPlayer(area.data.bid.player)
        if newOwner.PlayerData.money['bank'] < area.data.bid.value then
            for tid, data in pairs(area.data.bid.uniquePlayers) do
                notification(tid, "error", "ERROR", "The highest bidder didn't have the money in the bank")
            end

            return
        end
        local license = QBCore.Functions.GetIdentifier(src, 'license')
        newOwner.Functions.RemoveMoney("bank", area.data.bid.value, "auction")
        if area.data.data.plate ~= "ADMIN" then
            oldOwner.Functions.AddMoney("bank", area.data.bid.value)
            MySQL.update("UPDATE player_vehicles SET citizenid = ?, license = ? WHERE plate = ?", {newOwner.PlayerData.citizenid, license, area.data.data.plate})
        else
            local plate = GeneratePlate()
            MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                license,
                newOwner.PlayerData.citizenid,
                area.data.data.model,
                area.data.data.hash,
                '{}',
                plate,
                'pillboxgarage',
                1
            })
        end




        local text = string.format("Someone bought %s for $%s", area.data.data.title, area.data.bid.value)
        for tid, data in pairs(area.data.bid.uniquePlayers) do
            notification(tid, "success", "Purchase Successful", text)
        end

        logs.wonBid(src, area.data.data.plate, area.data.bid.value)

        area.beingUsed = false
        area.data.player = nil
        area.data.bid.player = nil
        area.data.bid.value = nil
        area.data.bid.oldPlayers = {}
        area.data.bid.uniquePlayers = {}

        area.data.data = nil
        

        TriggerClientEvent("auction:syncAreas", -1, config.AuctionAreas)
    end)
end)

RegisterServerEvent("auction:bid")
AddEventHandler("auction:bid", function(id, money)
    local src = source

    if not config.AuctionAreas[id] then
        logs.cheater(src)
        return
    end

    local area = config.AuctionAreas[id]

    local Player = QBCore.Functions.GetPlayer(src)
    local pdata = Player.PlayerData

    if pdata.money['bank'] < money then
        notification(src, "error", "No money", "You dont have funds to bid that amount")
        return
    end

    if area.data.bid.value < money then
        area.data.bid.oldPlayers[#area.data.bid.oldPlayers + 1] = {
            id = area.data.bid.player,
            value = area.data.bid.value
        }

        area.data.bid.value = money
        area.data.bid.player = src

        TriggerClientEvent("auction:syncAreas", -1, config.AuctionAreas)

        for tid, data in pairs(area.data.bid.uniquePlayers) do
            notification(tid, "success", "Info", "Someone just bid $" .. money)
        end

        area.data.bid.uniquePlayers[src] = true
        logs.bid(src, area.data.data.plate, money)
    else
        notification(src, "error", "Invalid Value", "That value is to low")
    end
end)


