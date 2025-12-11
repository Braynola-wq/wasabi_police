-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
if not wsb then return print((Strings.no_wsb):format(GetCurrentResourceName())) end

CreateBlip = function(output, sprite, color, text, scale, flash, type, short)
    type = type or 'coords'
    local blip
    if type == 'coords' then
        local x, y, z = table.unpack(output)
        blip = AddBlipForCoord(x, y, z)
    elseif type == 'entity' then
        blip = AddBlipForEntity(output)
    end

    SetBlipSprite(blip, sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipFlashes(blip, flash)
    SetBlipAsShortRange(blip, short)

    local blipStr = ('police_%s'):format(tostring(blip))
    AddTextEntry(blipStr, text)
    BeginTextCommandSetBlipName(blipStr)
    EndTextCommandSetBlipName(blip)

    return blip
end

local exportQBHandler = function(exportName, func)
    AddEventHandler(('__cfx_export_qb-policejob_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
end

local firstToUpper = function(str)
    return (str:gsub('^%l', string.upper))
end

local addCommas = function(n)
    return tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,')
        :gsub(',(%-?)$', '%1'):reverse()
end

function RequestNetworkControl(entity)
    NetworkRequestControlOfEntity(entity)
    local timeout = 2000
    while timeout > 0 and not NetworkHasControlOfEntity(entity) do
        NetworkRequestControlOfEntity(entity)
        Wait(100)
        timeout = timeout - 100
    end
    SetEntityAsMissionEntity(entity, true, true)
    timeout = 2000
    while timeout > 0 and not IsEntityAMissionEntity(entity) do
        SetEntityAsMissionEntity(entity, true, true)
        Wait(100)
        timeout = timeout - 100
    end
    return NetworkHasControlOfEntity(entity)
end

function GetCoordsInFrontOfPed(distance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    return coords + (forward * distance)
end

JobArrayToTarget = function(tb)
    local data = {}
    for i = 1, #tb do
        data[tb[i]] = 0
    end
    return data
end

function PersistentCuffCheck()
    if not Config.handcuff.persistentCuff then return end

    while not wsb?.playerLoaded or not wsb?.playerData do Wait(1000) end

    local isPlayerCuffed = false

    if wsb.framework == 'esx' then
        isPlayerCuffed = wsb.awaitServerCallback('wasabi_police:loadCuffCheck')
    elseif wsb.framework == 'qb' then
        isPlayerCuffed = wsb.playerData.metadata.ishandcuffed and true or false
        if isPlayerCuffed then
            isPlayerCuffed = isPlayerCuffed and not (wsb.playerData.metadata.isziptied and true or false) or false
        end
    end

    if isPlayerCuffed then
        while not DoesEntityExist(PlayerPedId()) do Wait(1000) end

        handcuffed(Config.handcuff.defaultCuff)

        TriggerEvent('wasabi_bridge:notify', Strings.cuffed_last_online, Strings.cuffed_last_online_desc, 'info')
    end
end

function InitializeSpeedTraps()
    local speedTraps = wsb.awaitServerCallback('wasabi_police:getSpeedTraps')
    if not speedTraps or not next(speedTraps) then return {} end

    for i = 1, #speedTraps do
        local trap = speedTraps[i]
        trap.point = AddSpeedTrapPoint(trap, i)
        if Config.RadarPosts.blip.enabled then
            trap.blip = CreateBlip(vec3(trap.coords.x, trap.coords.y, trap.coords.z), Config.RadarPosts.blip.sprite,
                Config.RadarPosts.blip.color, Config.RadarPosts.blip.label, Config.RadarPosts.blip.scale, false, 'coords',
                Config.RadarPosts.blip.short)
        end
    end

    return speedTraps
end

function ConvertToRealSpeed(speed)
    if Config.measurementSystem == 'kmh' then
        return speed / 0.27778
    else
        return speed / 0.44704
    end
end

RevokeWeaponLicense = function(id, license)
    if not wsb.hasGroup(Config.policeJobs) then return end
    return wsb.awaitServerCallback('wasabi_police:revokeLicense', id, license)
end

GiveWeaponLicense = function(id)
    if not wsb.hasGroup(Config.policeJobs) then return end
    local granted = wsb.awaitServerCallback('wasabi_police:grantLicense', id)
    if granted then
        TriggerEvent('wasabi_bridge:notify', Strings.license_granted, (Strings.license_granted_desc):format(granted, id))
    else
        TriggerEvent('wasabi_bridge:notify', Strings.failed, Strings.license_alr_granted)
    end
end

GetVehicleInDirection = function()
    local coords                                                 = GetEntityCoords(wsb.cache.ped)
    local inDirection                                            = GetOffsetFromEntityInWorldCoords(wsb.cache.ped, 0.0,
        5.0,
        0.0)
    local rayHandle                                              = StartExpensiveSynchronousShapeTestLosProbe(coords.x,
        coords.y, coords.z, inDirection.x, inDirection.y, inDirection.z, 10, wsb.cache.ped, 0)
    local numRayHandle, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    if hit == 1 and GetEntityType(entityHit) == 2 then
        local entityCoords = GetEntityCoords(entityHit)
        return entityHit, entityCoords
    end

    return nil
end

ShowHelpNotification = function(msg, thisFrame, beep, duration)
    AddTextEntry('HelpNotification', msg)

    if thisFrame then
        DisplayHelpTextThisFrame('HelpNotification', false)
    else
        if beep == nil then beep = true end
        BeginTextCommandDisplayHelp('HelpNotification')
        EndTextCommandDisplayHelp(0, false, beep, duration or -1)
    end
end

IsHandcuffed = function()
    return isCuffed
end

exports('IsHandcuffed', IsHandcuffed)

exportQBHandler('IsHandcuffed', IsHandcuffed)

openOutfits = function(station)
    if deathCheck() or isCuffed then return end
    if Config.skinScript == 'qb' then
        TriggerEvent('qb-clothing:client:openMenu')
    else
        local data = Config.Locations[station].cloakroom.uniforms
        local Options = {
            {
                title = Strings.civilian_wear,
                description = '',
                arrow = false,
                event = 'wasabi_police:changeClothes',
                args = 'civ_wear'
            }
        }
        for i = 1, #data do
            if data[i].minGrade then
                local _job, grade = wsb.hasGroup(Config.policeJobs)
                if grade and grade >= data[i].minGrade then
                    Options[#Options + 1] = {
                        title = data[i].label,
                        description = '',
                        arrow = false,
                        event = 'wasabi_police:changeClothes',
                        args = { male = data[i].male, female = data[i].female }
                    }
                end
            else
                Options[#Options + 1] = {
                    title = data[i].label,
                    description = '',
                    arrow = false,
                    event = 'wasabi_police:changeClothes',
                    args = { male = data[i].male, female = data[i].female }
                }
            end
        end
        if Config.MobileMenu.enabled then
            wsb.showMenu({
                id = 'pd_cloakroom',
                color = Config.UIColor,
                position = Config.MobileMenu.position,
                title = Strings.cloakroom,
                options = Options
            })
            return
        else
            wsb.showContextMenu({
                id = 'pd_cloakroom',
                color = Config.UIColor,
                title = Strings.cloakroom,
                options = Options
            })
        end
    end
end

exports('openOutfits', openOutfits)

-- Cloakroom Standalone
function RequestCivilianOutfit()
    wsb.serverCallback('wasabi_police:requestCivilianOutfit', function(outfit)
        if not outfit then return end
        if outfit.clothing and next(outfit.clothing) then
            for _, clothingData in pairs(outfit.clothing) do
                SetPedComponentVariation(wsb.cache.ped, clothingData.component, clothingData.drawable,
                    clothingData.texture,
                    0)
            end
        end
        if not outfit.props or not next(outfit.props) then return end
        for _, propData in pairs(outfit.props) do
            SetPedPropIndex(wsb.cache.ped, propData.component, propData.drawable, propData.texture, true)
        end
    end)
end

function SaveCivilianOutfit()
    local civilianOutfit = { clothing = {}, props = {} }
    for i = 0, 11 do
        local drawable = GetPedDrawableVariation(wsb.cache.ped, i)
        local texture = GetPedTextureVariation(wsb.cache.ped, i)
        civilianOutfit.clothing[#civilianOutfit.clothing + 1] = {
            component = i,
            drawable = drawable,
            texture = texture
        }
    end
    for i = 0, 7 do
        local drawable = GetPedPropIndex(wsb.cache.ped, i)
        local texture = GetPedPropTextureIndex(wsb.cache.ped, i)
        civilianOutfit.props[#civilianOutfit.props + 1] = {
            component = i,
            drawable = drawable,
            texture = texture
        }
    end
    TriggerServerEvent('wasabi_police:saveOutfit', civilianOutfit)
end

function FineSuspect(targetId)
    if not next(Config.billingData.fines) then return end

    local fineData = {}
    for id, fine in ipairs(Config.billingData.fines) do
        fineData[#fineData + 1] = { label = fine.label, value = id }
    end

    local inputData = {
        { type = 'input',        label = Strings.description_invoice, description = Strings.description_invoice_desc, required = false,                           min = 4,         max = 50 },
        { type = 'multi-select', label = Strings.tickets_invoice,     options = fineData,                             description = Strings.tickets_invoice_desc, required = true, searchable = true, clearable = true }
    }

    local input = wsb.inputDialog(Strings.fine_id_invoice .. ' ' .. targetId, inputData, Config.UIColor)
    if not input then return end
    if not input[1] or not input[2] then return end

    local fineAmount, label = 0, '**' .. Strings.description_invoice .. '**  \n' .. input[1]
    label = label .. '  \n\n**' .. Strings.offenses_invoice .. '**  \n  '
    for _, selectedFine in ipairs(input[2]) do
        selectedFine = tonumber(selectedFine)
        fineAmount = fineAmount + Config.billingData.fines[selectedFine].amount
        label = label .. '- ' .. Config.billingData.fines[selectedFine].label .. '  \n'
    end

    label = label .. '  \n\n**' .. Strings.invoice_amount .. '**  \n' .. Strings.currency .. addCommas(fineAmount)

    TriggerServerEvent('wasabi_police:fineSuspect', targetId, fineAmount, label)
end

function RemoveClothingProps()
    SetPedPropIndex(wsb.cache.ped, 0, -1, 0, true)
    for i = 0, 11 do
        ClearPedProp(wsb.cache.ped, i)
    end
    for i = 0, 7 do
        ClearPedProp(wsb.cache.ped, i)
    end
end

escortPlayer = function(targetId)
    if deathCheck() or isCuffed then return end
    local targetCuffed = wsb.awaitServerCallback('wasabi_police:isCuffed', targetId)
    local deathCheck = deathCheck(targetId)
    if IsPedInAnyVehicle(GetPlayerPed(GetPlayerFromServerId(targetId)), false) then
        TriggerEvent('wasabi_bridge:notify', Strings.player_in_vehicle, Strings.player_in_vehicle_desc, 'error')
        return
    end
    if targetCuffed or deathCheck then
        TriggerServerEvent('wasabi_police:escortPlayer', targetId)
        return
    end
    TriggerEvent('wasabi_bridge:notify', Strings.not_restrained, Strings.not_restrained_desc, 'error')
end

exports('escortPlayer', escortPlayer)

handcuffPlayer = function(targetId, type)
    if deathCheck() or isCuffed then return end
    local cId = GetPlayerFromServerId(targetId)
    if not Config.handcuff.cuffDeadPlayers and deathCheck(targetId) then
        TriggerEvent('wasabi_bridge:notify', Strings.unconcious, Strings.unconcious_desc, 'error')
    elseif GetVehiclePedIsIn(GetPlayerPed(targetId), false) ~= 0 then
        TriggerEvent('wasabi_bridge:notify', Strings.in_vehicle, Strings.in_vehicle_desc, 'error')
    else
        TriggerServerEvent('wasabi_police:handcuffPlayer', targetId, type)
    end
end

local startCuffTimer = function()
    if Config.handcuff.timer and cuffTimer.active then
        wsb.clearTimeout(cuffTimer.timer)
    end
    cuffTimer.active = true
    cuffTimer.timer = wsb.setTimeout(Config.handcuff.timer, function()
        TriggerEvent('wasabi_police:uncuff')
    end)
end

handcuffed = function(type)
    type = type or 'hard'
    isCuffed = type
    DisableInventory(true)
    if Config.UseRadialMenu then
        DisableRadial(true)
    end
    TriggerServerEvent('wasabi_police:setCuff', type)
    SetEnableHandcuffs(wsb.cache.ped, true)
    --   SetEnableBoundAnkles(wsb.cache.ped, true)
    SetCurrentPedWeapon(wsb.cache.ped, `WEAPON_UNARMED`, true)
    SetPedCanPlayGestureAnims(wsb.cache.ped, false)
    --    FreezeEntityPosition(wsb.cache.ped, true)
    wsb.stream.animDict('mp_arresting')
    TaskPlayAnim(wsb.cache.ped, 'mp_arresting', 'idle', 8.0, -8, 3000, 49, 0, false, false, false)
    Wait(3000)
    --[[    if type == 'soft' then
        FreezeEntityPosition(wsb.cache.ped, false)
    end]]
    if Config.handcuff.timer then
        if cuffTimer.active then
            wsb.clearTimeout(cuffTimer.timer)
            cuffTimer = {}
        end
        startCuffTimer()
    end
end

uncuffed = function()
    if not isCuffed then return end
    DisableInventory(false)
    isCuffed = false
    if escorted?.active then
        escorted.active = nil
    end
    TriggerServerEvent('wasabi_police:setCuff', false)
    SetEnableHandcuffs(wsb.cache.ped, false)
    DisablePlayerFiring(wsb.cache.ped, false)
    SetPedCanPlayGestureAnims(wsb.cache.ped, true)
    --    FreezeEntityPosition(wsb.cache.ped, false)
    if Config.UseRadialMenu then
        DisableRadial(false)
    end
    if Config.handcuff.timer and cuffTimer.active then
        wsb.clearTimeout(cuffTimer.timer)
        cuffTimer = {}
    end
    Wait(250) -- Only in fivem ;)
    ClearPedTasks(wsb.cache.ped)
    ClearPedSecondaryTask(wsb.cache.ped)
    if cuffProp and DoesEntityExist(cuffProp) then
        SetEntityAsMissionEntity(cuffProp, true, true)
        DetachEntity(cuffProp, false, false)
        DeleteObject(cuffProp)
        cuffProp = nil
    end
end

manageId = function(data)
    if deathCheck() or isCuffed then return end
    local targetId, license = data.targetId, data.license
    local Options = {
        {
            title = Strings.go_back,
            description = '',
            icon = '',
            arrow = false,
            event = 'wasabi_police:checkId',
            args = targetId
        },
        {
            title = Strings.revoke_license,
            description = '',
            icon = '',
            arrow = false,
            event = 'wasabi_police:revokeLicense',
            args = { targetId = targetId, license = license.type }
        },
    }
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_manage_id',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = (license.label or firstToUpper(tostring(license.type))),
            options = Options

        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_manage_id',
            color = Config.UIColor,
            title = (license.label or firstToUpper(tostring(license.type))),
            options = Options
        })
    end
end

openLicenseMenu = function(data)
    if deathCheck() or isCuffed then return end
    local targetId, licenses = data.targetId, data.licenses
    local Options = {
        {
            title = Strings.go_back,
            description = '',
            icon = '',
            arrow = false,
            event = 'wasabi_police:checkId',
            args = targetId
        }
    }
    for i = 1, #licenses do
        Options[#Options + 1] = {
            title = (licenses[i].label or firstToUpper(tostring(licenses[i].type))),
            description = '',
            icon = '',
            arrow = true,
            event = 'wasabi_police:manageId',
            args = { targetId = targetId, license = licenses[i] }
        }
    end
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_license_check',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.licenses,
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_license_check',
            color = Config.UIColor,
            title = Strings.licenses,
            options = Options
        })
    end
end

checkPlayerId = function(targetId)
    if deathCheck() or isCuffed then return end
    local data = wsb.awaitServerCallback('wasabi_police:checkPlayerId', targetId)
    local Options = {
        {
            title = Strings.go_back,
            description = '',
            icon = '',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.name,
            description = data.name,
            icon = 'id-badge',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.job,
            description = data.job,
            icon = 'briefcase',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.job_position,
            description = data.position,
            icon = 'briefcase',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.dob,
            description = data.dob,
            icon = 'cake-candles',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.sex,
            description = data.sex,
            icon = 'venus-mars',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        }
    }
    if data.drunk then
        Options[#Options + 1] = {
            title = Strings.bac,
            description = data.drunk,
            icon = 'champagne-glasses',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        }
    end
    if not data.licenses or #data.licenses < 1 then
        Options[#Options + 1] = {
            title = Strings.licenses,
            description = Strings.no_licenses,
            icon = 'id-card',
            arrow = true,
            event = 'wasabi_police:pdJobMenu',
        }
    else
        Options[#Options + 1] = {
            title = Strings.licenses,
            description = Strings.total_licenses .. ' ' .. #data.licenses,
            icon = 'id-card',
            arrow = true,
            event = 'wasabi_police:licenseMenu',
            args = { licenses = data.licenses, targetId = targetId }
        }
    end
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_id_check',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.id_result_menu,
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_id_check',
            color = Config.UIColor,
            title = Strings.id_result_menu,
            options = Options
        })
    end
end

vehicleInfoMenu = function(vehicle)
    if deathCheck() or isCuffed then return end
    if not DoesEntityExist(vehicle) then
        TriggerEvent('wasabi_bridge:notify', Strings.vehicle_not_found, Strings.vehicle_not_found_desc, 'error')
    else
        local plate = GetVehicleNumberPlateText(vehicle)
        plate = wsb.trim(plate)
        local ownerData = wsb.awaitServerCallback('wasabi_police:getVehicleOwner', plate)
        local Options = {
            {
                title = Strings.go_back,
                description = '',
                arrow = false,
                event = 'wasabi_police:vehicleInteractions',
            },
            {
                title = Strings.plate,
                description = plate,
                arrow = false,
                event = 'wasabi_police:pdJobMenu',
            }
        }
        if ownerData then
            Options[#Options + 1] = {
                title = Strings.owner,
                description = ownerData,
                arrow = false,
                event = 'wasabi_police:pdJobMenu',
            }
        else
            Options[#Options + 1] = {
                title = Strings.possibly_stolen,
                description = Strings.possibly_stolen_desc,
                arrow = false,
                event = 'wasabi_police:pdJobMenu',
            }
        end
        if Config.MobileMenu.enabled then
            wsb.showMenu({
                id = 'pd_veh_info_menu',
                color = Config.UIColor,
                position = Config.MobileMenu.position,
                title = Strings.vehicle_interactions,
                options = Options
            })
            return
        else
            wsb.showContextMenu({
                id = 'pd_veh_info_menu',
                color = Config.UIColor,
                title = Strings.vehicle_interactions,
                options = Options
            })
        end
    end
end

lockpickVehicle = function(vehicle)
    if deathCheck() or isCuffed then return end
    if not DoesEntityExist(vehicle) then
        TriggerEvent('wasabi_bridge:notify', Strings.vehicle_not_found, Strings.vehicle_not_found_desc, 'error')
    else
        local playerCoords = GetEntityCoords(wsb.cache.ped)
        local targetCoords = GetEntityCoords(vehicle)
        local dist = #(playerCoords - targetCoords)
        if dist < 2.5 then
            TaskTurnPedToFaceCoord(wsb.cache.ped, targetCoords.x, targetCoords.y, targetCoords.z, 2000)
            Wait(2000)
            if wsb.progressUI({
                    duration = 7500,
                    position = 'bottom',
                    label = Strings.lockpick_progress,
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        car = true,
                    },
                    anim = {
                        scenario = 'PROP_HUMAN_PARKING_METER',
                    },
                }, 'progressCircle') then
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                TriggerEvent('wasabi_bridge:notify', Strings.lockpicked, Strings.lockpicked_desc, 'success')
            else
                TriggerEvent('wasabi_bridge:notify', Strings.cancelled, Strings.cancelled_desc, 'error')
            end
        else
            TriggerEvent('wasabi_bridge:notify', Strings.too_far, Strings.too_far_desc, 'error')
        end
    end
end

impoundVehicle = function(vehicle)
    if deathCheck() or isCuffed then return end
    if not DoesEntityExist(vehicle) then
        TriggerEvent('wasabi_bridge:notify', Strings.vehicle_not_found, Strings.vehicle_not_found_desc, 'error')
    else
        local playerCoords = GetEntityCoords(wsb.cache.ped)
        local targetCoords = GetEntityCoords(vehicle)
        local dist = #(playerCoords - targetCoords)
        if dist < 2.5 then
            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver == 0 then
                SetVehicleDoorsLocked(vehicle, 2)
                SetVehicleDoorsLockedForAllPlayers(vehicle, true)
                TaskTurnPedToFaceCoord(wsb.cache.ped, targetCoords.x, targetCoords.y, targetCoords.z, 2000)
                Wait(2000)
                if wsb.progressUI({
                        duration = 7500,
                        position = 'bottom',
                        label = Strings.impounding_progress,
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            car = true,
                        },
                        anim = {
                            scenario = 'PROP_HUMAN_PARKING_METER',
                        },
                    }, 'progressCircle') then
                    impoundSuccessful(vehicle)
                else
                    TriggerEvent('wasabi_bridge:notify', Strings.cancelled, Strings.cancelled_desc, 'error')
                end
            else
                TriggerEvent('wasabi_bridge:notify', Strings.driver_in_car, Strings.driver_in_car_desc, 'error')
            end
        else
            TriggerEvent('wasabi_bridge:notify', Strings.too_far, Strings.too_far_desc, 'error')
        end
    end
end

vehicleInteractionMenu = function()
    if deathCheck() or isCuffed then return end
    local Options = {
        {
            title = Strings.go_back,
            description = '',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.vehicle_information,
            description = Strings.vehicle_information_desc,
            icon = 'magnifying-glass',
            arrow = false,
            event = 'wasabi_police:vehicleInfo',
        },
        {
            title = Strings.lockpick_vehicle,
            description = Strings.locakpick_vehicle_desc,
            icon = 'lock-open',
            arrow = false,
            event = 'wasabi_police:lockpickVehicle',
        },
        {
            title = Strings.impound_vehicle,
            description = Strings.impound_vehicle_desc,
            icon = 'reply',
            arrow = false,
            event = 'wasabi_police:impoundVehicle',
        },
    }
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_veh_menu',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.vehicle_interactions,
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_veh_menu',
            color = Config.UIColor,
            title = Strings.vehicle_interactions,
            options = Options
        })
    end
end

function GetSpeedTrapById(id)
    for i = 1, #SpeedTraps do
        if SpeedTraps[i].id == id then
            return SpeedTraps[i]
        end
    end
    return nil
end

function UpdateSpeedTrapName(id, name)
    for i = 1, #SpeedTraps do
        if SpeedTraps[i].id == id then
            SpeedTraps[i].name = name
            return
        end
    end
end

function RenameSpeedTrap(id)
    local job, grade = wsb.getGroup()
    if not Config.RadarPosts.jobs[job] or grade < Config.RadarPosts.jobs[job] then return end

    local radarPost = GetSpeedTrapById(id)
    if not radarPost then return end

    local newName = wsb.inputDialog((Strings.speed_trap_rename):format(radarPost.name or Strings.speed_trap),
        { Strings.new_name }, Config.UIColor)

    if not newName or not newName[1] or newName[1] == '' or #newName[1] < 1 then
        TriggerEvent('wasabi_bridge:notify', Strings.invalid_entry, Strings.invalid_entry_desc, 'error')
        return
    end

    local success = wsb.awaitServerCallback('wasabi_police:renameSpeedTrap', id, newName[1])

    if success then
        TriggerEvent('wasabi_bridge:notify', Strings.success,
            (Strings.speed_trap_renamed):format(radarPost.name, newName[1]), 'success')
    else
        TriggerEvent('wasabi_bridge:notify', Strings.failed, Strings.speed_trap_rename_failed, 'error')
    end
end

function ManageRadarPost(id)
    local job, grade = wsb.getGroup()
    if not Config.RadarPosts.jobs[job] or grade < Config.RadarPosts.jobs[job] then return end

    local radarPost = GetSpeedTrapById(id)
    if not radarPost then return end
    local radarName = radarPost.name or Strings.speed_trap

    local Options = {
        {
            title = Strings.go_back,
            description = '',
            icon = 'chevron-left',
            arrow = false,
            event = 'wasabi_police:radarPosts',
        },
        {
            title = Strings.manage_trap_rename,
            description = Strings.manage_trap_rename_desc,
            icon = 'pen-to-square',
            arrow = false,
            event = 'wasabi_police:renameSpeedTrap',
            args = { id = id }
        },
        {
            title = Strings.manage_trap_delete,
            description = Strings.manage_trap_delete_desc,
            icon = 'trash',
            arrow = false,
            event = 'wasabi_police:removeSpeedTrap',
            args = { id = id }
        },
    }

    local menu = 'showContextMenu'
    if Config.MobileMenu.enabled then menu = 'showMenu' end

    wsb[menu]({
        id = 'manage_radar_menu',
        color = Config.UIColor,
        position = Config.MobileMenu.position,
        title = radarName,
        options = Options
    })
end

function RadarPostsMenu()
    if deathCheck() or isCuffed then return end
    local job, grade = wsb.getGroup()
    if not Config.RadarPosts.jobs[job] or grade < Config.RadarPosts.jobs[job] then return end

    local Options = {
        {
            title = Strings.go_back,
            description = '',
            icon = 'chevron-left',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
        {
            title = Strings.menu_trap_create,
            description = Strings.menu_trap_create_desc,
            icon = 'plus',
            arrow = false,
            event = 'wasabi_police:createRadarPost',
        },
    }

    if ClosestSpeedTrap and SpeedTraps[ClosestSpeedTrap] and SpeedTraps[ClosestSpeedTrap].id then
        Options[#Options + 1] = {
            title = Strings.menu_trap_manage,
            description = Strings.menu_trap_manage_desc,
            icon = 'pen-to-square',
            arrow = false,
            event = 'wasabi_police:manageRadarPost',
            args = { id = SpeedTraps[ClosestSpeedTrap].id }
        }
    end

    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_radar_menu',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = 'Speed Trap Menu',
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_radar_menu',
            color = Config.UIColor,
            title = 'Speed Trap Menu',
            options = Options
        })
    end
end

function CreateRadarPost()
    if deathCheck() or isCuffed then return end
    local job, grade = wsb.getGroup()
    if not Config.RadarPosts.jobs[job] or grade < Config.RadarPosts.jobs[job] then return end
    local options = {}
    for i = 1, #Config.RadarPosts.options do
        options[#options + 1] = {
            title = Config.RadarPosts.options[i].label,
            description = '',
            icon = 'camera',
            arrow = false,
            event = 'wasabi_police:placeRadarPost',
            args = { prop = Config.RadarPosts.options[i].prop }
        }
    end
    local menu = Config.MobileMenu.enabled and 'showMenu' or 'showContextMenu'
    wsb[menu]({
        id = 'pd_radar_post_menu',
        color = Config.UIColor,
        position = Config.MobileMenu.position,
        title = Strings.menu_select_trap,
        options = options
    })
end

function PlaceRadarPost(prop)
    wsb.stream.model(prop)
    local coords = GetEntityCoords(wsb.cache.ped)
    local obj = CreateObject(joaat(prop), coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(obj, false, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    RadarPostProp = obj
end

function CCTVMenu()
    if deathCheck() or isCuffed then return end
    local job, grade = wsb.getGroup()
    if not Config.CCTVCameras.jobs[job] then return end
    local options = {}
    options[#options + 1] = {
        title = Strings.go_back,
        description = '',
        icon = 'chevron-left',
        arrow = false,
        event = 'wasabi_police:pdJobMenu',
    }
    if tonumber(grade or 0) >= Config.CCTVCameras.jobs[job] then
        options[#options + 1] = {
            title = Strings.menu_cctv_create,
            description = Strings.menu_cctv_create_desc,
            icon = 'plus',
            arrow = false,
            event = 'wasabi_police:createCCTVCamera',
        }
    end
    if #CCTVCameras > 0 then
        for i = 1, #CCTVCameras do
            if CCTVCameras[i].id then
                options[#options + 1] = {
                    title = CCTVCameras[i].name or Strings.cctv_camera,
                    description = '',
                    icon = 'camera',
                    arrow = true,
                    event = 'wasabi_police:manageCCTVCamera',
                    args = { id = CCTVCameras[i].id }
                }
            end
        end
    end

    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_cctv_menu',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = 'CCTV Camera Menu',
            options = options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_cctv_menu',
            color = Config.UIColor,
            title = 'CCTV Camera Menu',
            options = options
        })
    end
end

function TrackingBraceletMenu()
    if deathCheck() or isCuffed then return end
    if not wsb.hasGroup(Config.policeJobs) then return end
    TrackingPlayers = wsb.awaitServerCallback('wasabi_police:getTrackingBracelets')
    if not TrackingPlayers or not next(TrackingPlayers) then
        TriggerEvent('wasabi_bridge:notify', Strings.no_bracelets, Strings.no_bracelets_desc, 'error')
        return
    end
    local options = {
        {
            title = Strings.go_back,
            icon = 'chevron-left',
            description = '',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
    }
    for _, trackingData in pairs(TrackingPlayers) do
        options[#options + 1] = {
            title = Strings.optn_tracking_bracelet_title:format(trackingData.name),
            description = Strings.optn_tracking_bracelet_desc:format(trackingData.sourceName),
            icon = 'user',
            arrow = true,
            event = 'wasabi_police:toggleTrackingBracelet',
            args = trackingData
        }
    end
    local menu = Config.MobileMenu.enabled and 'showMenu' or 'showContextMenu'
    wsb[menu]({
        id = 'pd_tracking_bracelet_menu',
        color = Config.UIColor,
        position = Config.MobileMenu.position,
        title = Strings.menu_tracking_bracelet,
        options = options
    })
end

function AttachTrackingProp()
    wsb.stream.model(`tag`)
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(wsb.cache.ped, 0.0, 3.0, 0.5))
    TrackingBracelet = CreateObjectNoOffset(`tag`, x, y, z, true, false, false)
    AttachEntityToEntity(TrackingBracelet, wsb.cache.ped, 15, 0.33606937269201, 0.025398326730096, 0.0012138579926551, 13.588062284908, -77.631353092725, -20.009694671156, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(`tag`)
end

function HandleTrackingProp()
    CreateThread(function()
        while TrackingBracelet do
            if not IsEntityAttachedToEntity(TrackingBracelet, wsb.cache.ped) then
                DeleteEntity(TrackingBracelet)
                AttachTrackingProp()
            end
            Wait(10000)
        end
        if DoesEntityExist(TrackingBracelet) then
            DeleteEntity(TrackingBracelet)
        end
    end)
end

function CreateCCTVCamera()
    if deathCheck() or isCuffed then return end
    local job, grade = wsb.getGroup()
    if not Config.CCTVCameras.jobs[job] or grade < Config.CCTVCameras.jobs[job] then return end
    local options = {}
    for i = 1, #Config.CCTVCameras.options do
        options[#options + 1] = {
            title = Config.CCTVCameras.options[i].label,
            description = '',
            icon = 'camera',
            arrow = false,
            event = 'wasabi_police:placeCCTVCamera',
            args = { prop = Config.CCTVCameras.options[i].prop }
        }
    end
    local menu = Config.MobileMenu.enabled and 'showMenu' or 'showContextMenu'
    wsb[menu]({
        id = 'pd_cctv_post_menu',
        color = Config.UIColor,
        position = Config.MobileMenu.position,
        title = Strings.menu_select_cctv,
        options = options
    })
end

function PlaceCCTVCamera(prop)
    wsb.stream.model(prop)
    local coords = GetEntityCoords(wsb.cache.ped)
    local obj = CreateObject(joaat(prop), coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(obj, false, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    CCTVCameraProp = obj
end

local glm_sincos, glm_rad = require 'glm'.sincos, require 'glm'.rad
local function getForwardVector()
    local sin, cos = glm_sincos(glm_rad(GetFinalRenderedCamRot(2)))
    return vec3(-sin.z * math.abs(cos.x), cos.z * math.abs(cos.x), sin.x)
end

function RayCastFromCam(flags, ignore, distance)
    local coords = GetFinalRenderedCamCoord()
    local destination = coords + getForwardVector() * (distance or 10)
    local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y,
        destination.z, flags or 511, wsb.cache.ped, ignore or 4)

    while true do
        Wait(0)
        local retval, hit, endCoords, surfaceNormal, material, entityHit = GetShapeTestResultIncludingMaterial(handle)
        if retval ~= 1 then
            return hit, entityHit, endCoords, surfaceNormal, material
        end
    end
end

function ManageCCTVCamera(id)
    local job, grade = wsb.getGroup()
    if not Config.CCTVCameras.jobs[job] then return end

    local cctvCamera = GetCCTVCameraById(id)
    if not cctvCamera then return end
    local cctvName = cctvCamera.name or Strings.cctv_camera

    local Options = {}
    Options[#Options + 1] = {
        title = Strings.go_back,
        description = '',
        icon = 'chevron-left',
        arrow = false,
        event = 'wasabi_police:cctvCameras',
    }
    Options[#Options + 1] = {
        title = Strings.manage_cctv_view,
        description = Strings.manage_cctv_view_desc,
        icon = 'eye',
        disabled = cctvCamera.destory,
        arrow = false,
        event = 'wasabi_police:viewCCTVCamera',
        args = { id = id }
    }
    if tonumber(grade or 0) >= Config.CCTVCameras.jobs[job] then
        Options[#Options + 1] = {
            title = Strings.manage_cctv_rename,
            description = Strings.manage_cctv_rename_desc,
            icon = 'pen-to-square',
            arrow = false,
            event = 'wasabi_police:renameCCTVCamera',
            args = { id = id }
        }

        Options[#Options + 1] = {
            title = Strings.manage_cctv_delete,
            description = Strings.manage_cctv_delete_desc,
            icon = 'trash',
            arrow = false,
            event = 'wasabi_police:removeCCTVCamera',
            args = { id = id }
        }
    end
    if Config.CCTVCameras.destoryable then
        Options[#Options + 1] = {
            title = Strings.manage_cctv_repair,
            description = Strings.manage_cctv_repair_desc,
            icon = 'wrench',
            disabled = not cctvCamera.destory,
            arrow = false,
            event = 'wasabi_police:repairCCTVCamera',
            args = { id = id }
        }
    end

    local menu = Config.MobileMenu.enabled and 'showMenu' or 'showContextMenu'

    wsb[menu]({
        id = 'manage_cctv_menu',
        color = Config.UIColor,
        position = Config.MobileMenu.position,
        title = cctvName,
        options = Options
    })
end

function GetCCTVCameraById(id)
    for i = 1, #CCTVCameras do
        if CCTVCameras[i].id == id then
            return CCTVCameras[i]
        end
    end
    return nil
end

function RenameCCTVCamera(id)
    local job, grade = wsb.getGroup()
    if not Config.CCTVCameras.jobs[job] or grade < Config.CCTVCameras.jobs[job] then return end

    local cctvCamera = GetCCTVCameraById(id)
    if not cctvCamera then return end

    local newName = wsb.inputDialog((Strings.manage_cctv_rename):format(cctvCamera.name or Strings.cctv_camera),
        { Strings.new_name }, Config.UIColor)

    if not newName or not newName[1] or newName[1] == '' or #newName[1] < 1 then
        TriggerEvent('wasabi_bridge:notify', Strings.invalid_entry, Strings.invalid_entry_desc, 'error')
        return
    end

    local success = wsb.awaitServerCallback('wasabi_police:renameCCTVCamera', id, newName[1])

    if success then
        TriggerEvent('wasabi_bridge:notify', Strings.success,
            (Strings.cctv_renamed):format(cctvCamera.name, newName[1]), 'success')
    else
        TriggerEvent('wasabi_bridge:notify', Strings.failed, Strings.cctv_rename_failed, 'error')
    end
end

function UpdateCCTVCameraName(id, name)
    for i = 1, #CCTVCameras do
        if CCTVCameras[i].id == id then
            CCTVCameras[i].name = name
            return
        end
    end
end

function CameraRotation()
    local getCameraRot = GetCamRot(CreatedCamera, 2)

    if IsControlPressed(0, 32) then
        if getCameraRot.x <= 0.0 then
            SetCamRot(CreatedCamera, getCameraRot.x + 0.7, 0.0,
                getCameraRot.z, 2)
        end
    end

    if IsControlPressed(0, 8) then
        if getCameraRot.x >= -50.0 then
            SetCamRot(CreatedCamera, getCameraRot.x - 0.7, 0.0,
                getCameraRot.z, 2)
        end
    end

    if IsControlPressed(0, 34) then SetCamRot(CreatedCamera, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2) end

    if IsControlPressed(0, 9) then SetCamRot(CreatedCamera, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2) end
end

function CreateCamera(coords)
    if CreatedCamera then DestroyCam(CreatedCamera, 0) end
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)
    SetCamCoord(cam, coords.x, coords.y, coords.z)
    SetCamRot(cam, 0.0, 0.0, 0.0, 2)
    RenderScriptCams(1, 0, 0, 1, 1)
    CreatedCamera = cam
    if wsb.targetSystem and Config.useTarget then
        wsb.target.disable(cam and true)
    end
    CameraThread()
end

function IsPlayerInsideCamera()
    return CreatedCamera and true or false
end

exports('IsPlayerInsideCamera', IsPlayerInsideCamera)

function ViewCCTVCamera(id)
    local job, grade = wsb.getGroup()
    if not Config.CCTVCameras.jobs[job] then return end
    local cctvCamera = GetCCTVCameraById(id)
    if not cctvCamera then return end
    if cctvCamera.destroy then
        TriggerEvent('wasabi_bridge:notify', Strings.cctv_destroyed, Strings.cctv_destroyed_desc, 'error')
        return
    end
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    SendNUIMessage({
        action = "showCamera",
        time = string.format("%02d:%02d", GetClockHours(), GetClockMinutes()),
        name =
            cctvCamera.name or Strings.cctv_camera
    })
    SetFocusArea(cctvCamera.coords.x, cctvCamera.coords.y, cctvCamera.coords.z, cctvCamera.coords.x, cctvCamera.coords.y, cctvCamera.coords.z)
    CameraIndex = cctvCamera
    CreateCamera(cctvCamera.coords)
    DoScreenFadeIn(250)
    local PlayerPed = PlayerPedId()
    if CameraIndex then FreezeEntityPosition(PlayerPed, true) end
    TaskStartScenarioInPlace(wsb.cache.ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
end

function CloseCamera()
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end

    if CreatedCamera then
        DestroyCam(CreatedCamera, 0)
    end
    RenderScriptCams(false, false, 1, true, true)
    CreatedCamera = nil
    CameraIndex = nil
    ClearTimecycleModifier("scanline_cam_cheap")
    SetFocusEntity(PlayerPedId())
    SendNUIMessage({ action = "disableCameraOverlay" })
    DisplayRadar(true)
    if wsb.targetSystem and Config.useTarget then
        wsb.target.disable(false)
    end
    DoScreenFadeIn(250)
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasksImmediately(wsb.cache.ped)
end

function InitializeCCTVCameras()
    local cctvCameras = wsb.awaitServerCallback('wasabi_police:getCCTVCameras')
    if not cctvCameras or not next(cctvCameras) then return {} end
    for i = 1, #cctvCameras do
        local camera = cctvCameras[i]
        camera.point = AddCCTVCameraPoint(camera, i)
        if Config.CCTVCameras.blip.enabled then
            camera.blip = CreateBlip(vec3(camera.coords.x, camera.coords.y, camera.coords.z),
                Config.CCTVCameras.blip.sprite,
                Config.CCTVCameras.blip.color, Config.CCTVCameras.blip.label, Config.CCTVCameras.blip.scale, false,
                'coords',
                Config.CCTVCameras.blip.short)
        end
    end

    return cctvCameras
end

placeObjectsMenu = function()
    if deathCheck() or isCuffed then return end
    if not wsb.hasGroup(Config.policeJobs) then return end
    local job, grade = wsb.getGroup()
    local Options = {
        {
            title = Strings.go_back,
            icon = 'chevron-left',
            description = '',
            arrow = false,
            event = 'wasabi_police:pdJobMenu',
        },
    }
    for i = 1, #Config.Props do
        local data = Config.Props[i]
        local add = true
        if (data.groups) then
            local rank = data.groups[job]
            if not (rank and grade >= rank) then
                add = false
            end
        end
        if (add) then
            data.arrow = false
            data.icon = 'cart-flatbed'
            data.event = 'wasabi_police:spawnProp'
            data.args = i
            Options[#Options + 1] = data
        end
    end
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_object_menu',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.vehicle_interactions,
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_object_menu',
            color = Config.UIColor,
            title = Strings.vehicle_interactions,
            options = Options
        })
    end
end

armouryMenu = function(station)
    if deathCheck() or isCuffed then return end
    local data = Config.Locations[station].armoury
    local job, grade = wsb.getGroup()
    if not data.weapons or not data.weapons[grade] then
        TriggerEvent('wasabi_bridge:notify', Strings.no_permission, Strings.no_access_desc, 'error')
        return
    end
    local allow = false
    local aData
    if data.jobLock then
        if data.jobLock == job then
            allow = true
        end
    else
        allow = true
    end
    if not allow then
        TriggerEvent('wasabi_bridge:notify', Strings.no_permission, Strings.no_access_desc, 'error')
        return
    end
    if wsb.inventorySystem then
        local identifier = station .. '_armoryweapons' .. grade
        wsb.inventory.openShop({
            identifier = identifier,
            name = Strings.armoury_menu,
        })
        return
    end
    
    if grade > #data.weapons then
        aData = data.weapons[#data.weapons]
    elseif not data.weapons[grade] then
        print('[wasabi_police] : ARMORY NOT SET UP PROPERLY FOR GRADE: ' .. grade)
    else
        aData = data.weapons[grade]
    end
    local Options = {}
    if #aData == 0 then --Backward compatibility
        for k, v in pairs(aData) do
            if wsb.inventorySystem then
                Options[#Options + 1] = {
                    name = k,
                    price = v.price or 0,
                }
            else
                Options[#Options + 1] = {
                    title = v.label,
                    description = '',
                    arrow = false,
                    event = 'wasabi_police:purchaseArmoury',
                    args = { id = station, grade = grade, itemId = k, multiple = v.multiple or false }
                }
                if v.price then
                    Options[#Options].description = Strings.currency .. addCommas(v.price)
                end
            end
        end
    else
        for i = 1, #aData do
            local v = aData[i]
            if wsb.inventorySystem then
                Options[#Options + 1] = {
                    name = v.name,
                    price = v.price or 0,
                }
            else
                Options[#Options + 1] = {
                    title = v.label,
                    description = '',
                    arrow = false,
                    event = 'wasabi_police:purchaseArmoury',
                    args = { id = station, grade = grade, itemId = v.name, multiple = v.multiple or false }
                }
                if v.price then
                    Options[#Options].description = Strings.currency .. addCommas(v.price)
                end
            end
        end
    end

    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_armoury',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.armoury_menu,
            options = Options
        })
    else
        wsb.showContextMenu({
            id = 'pd_armoury',
            color = Config.UIColor,
            title = Strings.armoury_menu,
            options = Options
        })
    end
end

openVehicleMenu = function(station)
    if deathCheck() or isCuffed then return end
    if not wsb.hasGroup(Config.policeJobs) then return end
    local data, grade
    local job, level = wsb.getGroup()
    if level > #Config.Locations[station].vehicles.options then
        grade = #Config.Locations[station].vehicles.options
        data = Config.Locations[station].vehicles.options[#Config.Locations[station].vehicles.options]
    elseif not Config.Locations[station].vehicles.options[level] then
        print('[wasabi_police] : Police garage not set up properly for job grade: ' .. level)
        return
    else
        grade = level
        data = Config.Locations[station].vehicles.options[level]
    end
    local Options = {}
    for k, v in pairs(data) do
        if v.category == 'land' then
            Options[#Options + 1] = {
                title = v.label,
                description = '',
                icon = 'car',
                arrow = true,
                event = 'wasabi_police:spawnVehicle',
                args = { station = station, model = k, grade = grade }
            }
        elseif v.category == 'air' then
            Options[#Options + 1] = {
                title = v.label,
                description = '',
                icon = 'helicopter',
                arrow = true,
                event = 'wasabi_police:spawnVehicle',
                args = { station = station, model = k, grade = grade, category = v.category }
            }
        end
    end
    if Config.MobileMenu.enabled then
        wsb.showMenu({
            id = 'pd_garage_menu',
            color = Config.UIColor,
            position = Config.MobileMenu.position,
            title = Strings.police_garage,
            options = Options
        })
        return
    else
        wsb.showContextMenu({
            id = 'pd_garage_menu',
            color = Config.UIColor,
            title = Strings.police_garage,
            options = Options
        })
    end
end

local lastTackle = 0
attemptTackle = function()
    if deathCheck() or isCuffed then return end
    if not IsPedSprinting(wsb.cache.ped) then return end
    local coords = GetEntityCoords(wsb.cache.ped)
    local player = wsb.getClosestPlayer(vec3(coords.x, coords.y, coords.z), 2.0, false)
    if player and not isBusy and not IsPedInAnyVehicle(wsb.cache.ped, false) and not IsPedInAnyVehicle(GetPlayerPed(player), false) and GetGameTimer() - lastTackle > 7 * 1000 then
        if Config.tackle.policeOnly then
            if wsb.hasGroup(Config.policeJobs) then
                lastTackle = GetGameTimer()
                TriggerServerEvent('wasabi_police:attemptTackle', GetPlayerServerId(player))
            end
        else
            lastTackle = GetGameTimer()
            TriggerServerEvent('wasabi_police:attemptTackle', GetPlayerServerId(player))
        end
    end
end

getTackled = function(targetId)
    isBusy = true
    local target = GetPlayerPed(GetPlayerFromServerId(targetId))
    wsb.stream.animDict('missmic2ig_11')
    AttachEntityToEntity(wsb.cache.ped, target, 11816, 0.25, 0.5, 0.0, 0.5, 0.5, 180.0, false, false, false, false, 2,
        false)
    TaskPlayAnim(wsb.cache.ped, 'missmic2ig_11', 'mic_2_ig_11_intro_p_one', 8.0, -8.0, 3000, 0, 0, false, false, false)
    Wait(3000)
    DetachEntity(wsb.cache.ped, true, false)
    SetPedToRagdoll(wsb.cache.ped, 1000, 1000, 0, false, false, false)
    isRagdoll = true
    Wait(3000)
    isRagdoll = false
    isBusy = false
    RemoveAnimDict('missmic2ig_11')
end

tacklePlayer = function()
    isBusy = true
    wsb.stream.animDict('missmic2ig_11')
    TaskPlayAnim(wsb.cache.ped, 'missmic2ig_11', 'mic_2_ig_11_intro_goon', 8.0, -8.0, 3000, 0, 0, false, false, false)
    Wait(3000)
    isBusy = false
    RemoveAnimDict('missmic2ig_11')
end

GSRTestNearbyPlayer = function()
    if deathCheck() or isCuffed then return end
    if not wsb.hasGroup(Config.policeJobs) then return end
    local coords = GetEntityCoords(wsb.cache.ped)
    local player = wsb.getClosestPlayer(vec3(coords.x, coords.y, coords.z), 2.0, false)
    if player and not isBusy then
        local serverId = GetPlayerServerId(player)
        local result = wsb.awaitServerCallback('wasabi_police:gsrTest', serverId)
        if result then
            TriggerEvent('wasabi_bridge:notify', Strings.positive, Strings.positive_gsr_desc, 'success')
        else
            TriggerEvent('wasabi_bridge:notify', Strings.negative, Strings.negative_gsr_desc, 'error')
        end
    else
        TriggerEvent('wasabi_bridge:notify', Strings.no_nearby, Strings.no_nearby_desc, 'error')
    end
end

function GetClosestDeadPlayerServerID(coords, maxDistance)
    local players = GetActivePlayers()
    local closestDeadPlayer = nil
    if not players or not next(players) then return nil end
    for i = 1, #players do
        if players[i] ~= PlayerId() then
            local serverID = GetPlayerServerId(players[i])
            local playerCoords = GetEntityCoords(GetPlayerPed(players[i]))
            local distance = #(vec3(playerCoords.x, playerCoords.y, playerCoords.z) - vec3(coords.x, coords.y, coords.z))
            if distance <= maxDistance and not closestDeadPlayer and deathCheck(serverID) then
                closestDeadPlayer = serverID
            elseif distance <= maxDistance and closestDeadPlayer and deathCheck(serverID) then
                local closestPlayerCoords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(closestDeadPlayer)))
                local closestDistance = #(vec3(closestPlayerCoords.x, closestPlayerCoords.y, closestPlayerCoords.z) - vec3(coords.x, coords.y, coords.z))
                if distance < closestDistance then
                    closestDeadPlayer = serverID
                end
            end
        end
    end
    return closestDeadPlayer
end

function PlayAnimation(dict, anim, duration, heading, flags)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if not heading then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flags or 33, 0, false, false, false)
    else
        local coords = GetEntityCoords(ped)
        TaskPlayAnimAdvanced(ped, dict, anim, coords.x, coords.y, coords.z, 0.0, 0.0, heading, 2.0, 2.0, duration,
            flags or 33, 0.0, false, false)
    end
end

IsResourceAllowed = function(res)
    if not res then
        return false
    elseif res:lower() == GetCurrentResourceName():lower() then
        return true
    end

    res = res:lower()
    for k, data in pairs(Config.AllowedResources) do
        if res == data:lower() then
            return true
        end
    end

    return false
end

function IsTriggerApproved(resource)
    local approved = false
    if wsb.hasGroup(Config.policeJobs) then approved = true end
    if next(Config.AllowedJobs) then
        if wsb.hasGroup(Config.AllowedJobs) then approved = true end
    end
    if next(Config.AllowedResources) then
        if IsResourceAllowed(resource) then approved = true end
    end
    return approved
end

-- Speed Traps

function DeleteAllSpeedTraps()
    for i = 1, #SpeedTraps do
        if SpeedTraps[i].object then
            DeleteEntity(SpeedTraps[i].object)
            SpeedTraps[i].object = nil
        end

        if SpeedTraps[i].blip then
            RemoveBlip(SpeedTraps[i].blip)
            SpeedTraps[i].blip = nil
        end
        if SpeedTraps[i].point then
            SpeedTraps[i].point:remove()
            SpeedTraps[i].point = nil
        end
    end
end

local function cameraFlash()
    PlaySoundFrontend(-1, "Camera_Shoot", "Phone_SoundSet_Default", true)
    if Config.RadarPosts.disableCameraFlash then return end
    SendNUIMessage({ action = 'cameraFlash' })
end

local speedTrapCooldown = GetGameTimer()
local speedTrapCurrentIndex = 0

local function triggerSpeedTrap(index, speed)
    if speedTrapCurrentIndex == index and GetGameTimer() - speedTrapCooldown < 5000 then return end
    speedTrapCurrentIndex = index
    speedTrapCooldown = GetGameTimer()
    cameraFlash()
    TriggerServerEvent('wasabi_police:triggerSpeedTrap', SpeedTraps[index].id, speed)
end

local function findProperSpeedTrapFine(speedLimit, speed)
    local overSpeed = speed - speedLimit
    local fines = Config.RadarPosts.thresholds
    local speedOver = 0
    local currentFine = 0
    for speeding, fine in pairs(fines) do
        if speeding < overSpeed then
            if speeding > speedOver then
                speedOver = speeding
                currentFine = fine
            end
        end
    end

    if speedOver == 0 then return false end

    return currentFine, speedOver
end

function AddSpeedTrapPoint(speedTrap, index)
    return wsb.points.new({
        coords = vec3(speedTrap.coords.x, speedTrap.coords.y, speedTrap.coords.z),
        heading = speedTrap.heading,
        id = speedTrap.id,
        index = index,
        speedLimit = speedTrap.speedLimit,
        detectionRadius = speedTrap.detectionRadius or Config.RadarPosts.detectionRadius,
        distance = 50.0,
        onEnter = function(self)
            if not SpeedTraps[index].object or not DoesEntityExist(SpeedTraps[index].object) then
                wsb.stream.model(SpeedTraps[index].prop, 7500)
                SpeedTraps[index].object = CreateObject(SpeedTraps[index].prop, speedTrap.coords.x, speedTrap.coords.y,
                    speedTrap.coords.z, false, false, false)
                SetEntityHeading(SpeedTraps[index].object, speedTrap.heading)
                PlaceObjectOnGroundProperly(SpeedTraps[index].object)
                FreezeEntityPosition(SpeedTraps[index].object, true)
                SetModelAsNoLongerNeeded(SpeedTraps[index].prop)
            end
        end,
        nearby = function(self)
            local coords = GetEntityCoords(wsb.cache.ped)
            local dist = #(coords - self.coords)
            if dist > self.detectionRadius then return end
            if dist < 5.0 then
                if not ClosestSpeedTrap then
                    ClosestSpeedTrap = self.index
                elseif ClosestSpeedTrap ~= self.index and SpeedTraps[ClosestSpeedTrap] and #(self.coords - coords) < #(SpeedTraps[ClosestSpeedTrap].coords - coords) then
                    ClosestSpeedTrap = self.index
                end
            elseif dist > 5.0 and ClosestSpeedTrap == self.index then
                ClosestSpeedTrap = nil
            end
            if not wsb.cache.vehicle or wsb.cache.seat ~= -1 then return end
            local vehSpeed = ConvertToRealSpeed(GetEntitySpeed(wsb.cache.vehicle))
            if vehSpeed and vehSpeed > self.speedLimit and findProperSpeedTrapFine(self.speedLimit, vehSpeed) then
                if Config.RadarPosts.whitelistJobs and next(Config.RadarPosts.whitelistJobs) then
                    if wsb.hasGroup(Config.policeJobs) or wsb.hasGroup(Config.RadarPosts.whitelistJobs) then return end
                end
                triggerSpeedTrap(index, vehSpeed)
            end
        end,
        onExit = function(self)
            if SpeedTraps[index].object then
                DeleteEntity(SpeedTraps[index].object)
                SpeedTraps[index].object = nil
            end
        end
    })
end

local GetEntityHealth, SetEntityHealth, GetEntityCoords = GetEntityHealth, SetEntityHealth, GetEntityCoords
function AddCCTVCameraPoint(cctv, index)
    return wsb.points.new({
        coords = vec3(cctv.coords.x, cctv.coords.y, cctv.coords.z),
        heading = cctv.heading,
        id = cctv.id,
        index = index,
        distance = 50.0,
        onEnter = function(self)
            if not CCTVCameras[index].object or not DoesEntityExist(CCTVCameras[index].object) then
                wsb.stream.model(CCTVCameras[index].prop, 7500)
                CCTVCameras[index].object = CreateObject(CCTVCameras[index].prop, cctv.coords.x, cctv.coords.y,
                    cctv.coords.z, false, false, false)
                SetEntityHeading(CCTVCameras[index].object, cctv.heading)
                FreezeEntityPosition(CCTVCameras[index].object, true)
                SetModelAsNoLongerNeeded(CCTVCameras[index].prop)
            end
        end,
        nearby = function(self)
            if Config.CCTVCameras.destoryable then
                if CCTVCameras and CCTVCameras[self.index] and CCTVCameras[self.index].object and not CCTVCameras[self.index].destory then
                    local maxHealth, currentHealth = GetEntityMaxHealth(CCTVCameras[self.index].object),
                        GetEntityHealth(CCTVCameras[self.index].object)
                    if currentHealth < 750 then
                        if not CCTVCameras[self.index].destory then
                            TriggerServerEvent('wasabi_police:destroyCCTVCamera', CCTVCameras[self.index].id)
                            SetEntityHealth(CCTVCameras[self.index].object, maxHealth)
                        end
                    end
                end
            end
            local coords = GetEntityCoords(wsb.cache.ped)
            local dist = #(coords - self.coords)
            if dist > 25.0 then return end
            if dist < 10.0 then
                if not ClosestCCTVCamera then
                    ClosestCCTVCamera = self.index
                elseif ClosestCCTVCamera ~= self.index and CCTVCameras[ClosestCCTVCamera] and #(self.coords - coords) < #(CCTVCameras[ClosestCCTVCamera].coords - coords) then
                    ClosestCCTVCamera = self.index
                end
            elseif dist > 10.0 and ClosestCCTVCamera == self.index then
                ClosestCCTVCamera = nil
            end
        end,
        onExit = function(self)
            if CCTVCameras[index].object then
                DeleteEntity(CCTVCameras[index].object)
                CCTVCameras[index].object = nil
            end
        end
    })
end
