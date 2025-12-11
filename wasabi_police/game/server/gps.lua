-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
if not wsb then return print((Strings.no_wsb):format(GetCurrentResourceName())) end

if not Config.GPSBlips.enabled then return end

local activeBlips = {}

local function doesIdExist(table, id)
    for _, val in ipairs(table) do
        if val.id == id then
            return true
        end
    end
    return false
end

local function whatIsPedDriving(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return false end
    if not DoesEntityExist(vehicle) then return false end
    local vehicleType = GetVehicleType(vehicle)
    if not vehicleType then return false end
    if vehicleType == 'automobile' then
        vehicleType = 'car'
    elseif vehicleType == 'heli' then
        vehicleType = 'helicopter'
    end
    return vehicleType or false
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Config.GPSBlips.item then return end

    local players = GetPlayers()
    for _, playerString in ipairs(players) do
        local id = tonumber(playerString)
        if not wsb.hasGroup(id, Config.policeJobs) then return end
        if wsb.framework == 'qb' then
            local player = wsb.getPlayer(id)
            if not player then return end
            if not player.PlayerData.job.onduty then return end
        end
        TriggerEvent('wasabi_police:addOfficerToGPS', id)
    end
end)

if Config.GPSBlips.item then
    wsb.registerUsableItem(Config.GPSBlips.item, function(source)
        local src = source
        TriggerClientEvent('wasabi_police:useGPSItem', src)
    end)
end

RegisterNetEvent('wasabi_police:addOfficerToGPS', function(target)
    local src = target or source
    local name = wsb.getName(src) or Strings.officer .. '(' .. src .. ')'
    local job = wsb.getJobData(src).name
    if not next(activeBlips) or not doesIdExist(activeBlips, src) then
        activeBlips[#activeBlips + 1] = {
            id = src,
            name = name,
            color = Config.GPSBlips.settings.color[job] or Config.GPSBlips.settings.color.default or Config.GPSBlips.settings.color,
        }
    end
end)

RegisterNetEvent('wasabi_police:removeOfficerFromGPS', function(target)
    local src = target or source
    if not next(activeBlips) then return end

    for index, value in ipairs(activeBlips) do
        if value and value.id == src then
            table.remove(activeBlips, index)
            break
        end
    end
end)

RegisterNetEvent('playerDropped', function()
    local src = source

    for index, value in ipairs(activeBlips) do
        if value and value.id == src then
            table.remove(activeBlips, index)
            break
        end
    end
end)

CreateThread(function()
    local cachedActiveBlips = {}

    while true do
        Wait(1500)

        for _, data in ipairs(cachedActiveBlips) do
            if not doesIdExist(activeBlips, data.id) then
                TriggerClientEvent('wasabi_police:refreshGPSBlips', data.id, {})
            end
        end

        cachedActiveBlips = table.pack(table.unpack(activeBlips))

        if next(activeBlips) then
            for _, data in ipairs(activeBlips) do
                local id = data.id
                local playerPed = GetPlayerPed(id)
                local coords = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)

                if coords then
                    data.coords = coords
                    data.driving = whatIsPedDriving(playerPed) or false
                    data.heading = math.ceil(heading)
                end
            end

            for _, data in ipairs(activeBlips) do
                TriggerClientEvent('wasabi_police:refreshGPSBlips', data.id, activeBlips)
            end
        end
    end
end)
