-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
if not wsb then return print((Strings.no_wsb):format(GetCurrentResourceName())) end

if not Config.GPSBlips.enabled then return end

local activeBlips = {}

local function getBlipSprite(driving)
    return Config.GPSBlips.sprites[driving] or Config.GPSBlips.sprites.none
end

if not Config.GPSBlips.item then
    AddEventHandler('wasabi_bridge:playerLoaded', function()
        while not wsb.playerLoaded and not wsb?.playerData?.job do Wait(1000) end
        Wait(4000)
        if not wsb.hasGroup(Config.policeJobs) then return end
        if wsb.framework == 'qb' then
            if not wsb.playerData.job.onduty then return end
        else
            if not wsb.isOnDuty() then return end
        end
        TriggerServerEvent('wasabi_police:addOfficerToGPS')
    end)

    local oldJob = nil
    RegisterNetEvent('wasabi_bridge:setJob', function(job)
        local function isInList(str, tbl)
            for _, value in ipairs(tbl) do
                if value == str then
                    return true
                end
            end
            return false
        end

        if isInList(job.name, Config.policeJobs) then
            local isOnDuty = false
            if wsb.framework == 'qb' then
                isOnDuty = job.onduty
            else
                Wait(100) -- Wait for the job to be set (it will use the old job otherwise)
                isOnDuty = wsb.isOnDuty()
            end
            if isOnDuty then
                TriggerServerEvent('wasabi_police:addOfficerToGPS')
            else
                TriggerServerEvent('wasabi_police:removeOfficerFromGPS')
            end
        else
            TriggerServerEvent('wasabi_police:removeOfficerFromGPS')
        end
        oldJob = job.name
    end)
end

local toggled = false

RegisterNetEvent('wasabi_police:useGPSItem', function()
    if not Config.GPSBlips.enabled or not Config.GPSBlips.item then return end
    if not wsb.hasGroup(Config.policeJobs) then
        TriggerEvent('wasabi_bridge:notify', Strings.not_authorized, Strings.not_authorized_desc, 'error')
        return
    end

    if wsb.framework == 'qb' and not wsb.isOnDuty() then
        TriggerEvent('wasabi_bridge:notify', Strings.not_on_duty, Strings.not_on_duty_desc, 'error')
        return
    end

    if not toggled then
        TriggerEvent('wasabi_bridge:notify', Strings.gps_enabled, Strings.gps_enabled_desc, 'success')
        TriggerServerEvent('wasabi_police:addOfficerToGPS')
        toggled = true
        return
    end

    TriggerEvent('wasabi_bridge:notify', Strings.gps_disabled, Strings.gps_disabled_desc, 'info')
    TriggerServerEvent('wasabi_police:removeOfficerFromGPS')
    toggled = false
end)

RegisterNetEvent('wasabi_police:refreshGPSBlips', function(blipData)
    if next(activeBlips) then
        for _, blip in ipairs(activeBlips) do
            RemoveBlip(blip)
        end
        activeBlips = {}
    end

    if not blipData or not next(blipData) then return end

    for _, blip in ipairs(blipData) do
        local id = #activeBlips + 1

        activeBlips[id] = CreateBlip(blip.coords, getBlipSprite(blip.driving) or 1, blip.color,
            blip.name,
            Config.GPSBlips.settings.scale,
            false, nil, Config.GPSBlips.settings.short)
        SetBlipCategory(activeBlips[id], Config.GPSBlips.settings.category)
        SetBlipRotation(activeBlips[id], blip.heading)
    end
end)
