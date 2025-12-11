-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
if not wsb then return print((Strings.no_wsb):format(GetCurrentResourceName())) end
cuffedPlayers, jailedPlayers, GSRData, Outfits, SpeedTraps, SpeedTrapID, CCTVCameras, CCTVCameraID = {}, {}, {}, {}, {},
    0, {}, 0
local minutes = 60000
local playersToTrack = {}

local addCommas = function(n)
    return tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,')
        :gsub(',(%-?)$', '%1'):reverse()
end

local function verifyTouchingDistance(coords, targetCoords)
    local distance = #(coords - targetCoords)
    if distance > 3.0 then return false end
    return true
end

getPoliceOnline = function()
    local players = GetPlayers()
    local count = 0
    for i = 1, #players do
        local playerID = tonumber(players[i])
        local player = wsb.getPlayer(playerID)
        if player then
            local job, _grade = wsb.hasGroup(playerID, Config.policeJobs)
            if wsb.framework == 'qb' then
                if not player.PlayerData.job.onduty then job = nil end
            end
            if job then
                count = count + 1
            end
        end
    end
    return count
end

exports('getPoliceOnline', getPoliceOnline)

local function checkColumnExist(tableName, columnName, columnDefinition)
    local query = "SHOW COLUMNS FROM " .. tableName .. " LIKE '" .. columnName .. "'"
    local result = MySQL.query.await(query, {})
    if #result == 0 then
        local addQuery = "ALTER TABLE `" .. tableName .. "` ADD COLUMN `" .. columnName .. "` " .. columnDefinition
        MySQL.update(addQuery, {})
    else
        local typeQuery = "SELECT DATA_TYPE, COLUMN_DEFAULT FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '" ..
        tableName .. "' AND COLUMN_NAME = '" .. columnName .. "'"
        local typeResult = MySQL.query.await(typeQuery, {})
        if typeResult[1].DATA_TYPE ~= "tinyint" or typeResult[1].COLUMN_DEFAULT ~= "0" then
            local updateQuery = "ALTER TABLE `" ..
            tableName .. "` MODIFY COLUMN `" .. columnName .. "` " .. columnDefinition
            MySQL.update(updateQuery, {})
        end
    end
end

--Check ishandcuffed column present in database
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    if wsb.framework == 'esx' then
        checkColumnExist('users', 'ishandcuffed', 'BOOLEAN NOT NULL DEFAULT 0 AFTER `status`')
        checkColumnExist('users', 'injail', 'INT NOT NULL DEFAULT 0 AFTER `ishandcuffed`')
    end
    Wait(2500)
    CopCount = getPoliceOnline()
    TriggerClientEvent('police:SetCopCount', -1, CopCount)
end)


AddEventHandler('playerDropped', function(reason)
    if cuffedPlayers[source] then
        cuffedPlayers[source] = nil
    end
    if Config.TrackingBracelet.enabled then
        for i = 1, #TrackingPlayers do
            if TrackingPlayers[i].target == source then
                for police, suspects in pairs(playersToTrack) do
                    for j = 1, #suspects do
                        if suspects[j] == source then
                            TriggerClientEvent('wasabi_police:removeTrackedPlayer', police, source)
                            table.remove(suspects, j)
                            if #suspects == 0 then
                                playersToTrack[police] = nil
                            end
                        end
                    end
                end
                table.remove(TrackingPlayers, i)
                break
            end
        end
        playersToTrack[source] = nil
    end
    local job, _grade = wsb.hasGroup(source, Config.policeJobs)
    if not job then return end
    CopCount -= 1
    TriggerEvent('wasabi_police:updateCopCount')
end)

RegisterNetEvent('wasabi_police:attemptTackle', function(targetId)
    local src = source
    if not targetId or targetId == src or targetId == -1 then return end
    if not Config.tackle.enabled then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    if Config.tackle.policeOnly and not wsb.hasGroup(src, Config.policeJobs) then return end
    TriggerClientEvent('wasabi_police:tackled', targetId, src)
    TriggerClientEvent('wasabi_police:tackle', src)
end)

RegisterNetEvent('wasabi_police:inVehiclePlayer', function(targetId)
    local src = source
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    TriggerClientEvent('wasabi_police:stopEscorting', src, targetId)
    TriggerClientEvent('wasabi_police:putInVehicle', targetId)
end)

RegisterNetEvent('wasabi_police:outVehiclePlayer', function(targetId)
    local src = source
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    TriggerClientEvent('wasabi_police:takeFromVehicle', targetId, src)
end)

RegisterNetEvent('wasabi_police:setCuff', function(isCuffed)
    cuffedPlayers[source] = isCuffed
    Player(source).state:set('cuffed', isCuffed, true)
    local player = wsb.getPlayer(source)
    if wsb.framework == 'qb' then
        player.Functions.SetMetaData('ishandcuffed', isCuffed and true or false)
        --PersistentCuff
    elseif wsb.framework == 'esx' and Config.handcuff.persistentCuff then
        SetSQLHandcuffStatus(player.identifier, isCuffed and true or false)
    end
end)

RegisterNetEvent('wasabi_police:setGSR', function(positive)
    GSRData[source] = positive
end)

RegisterNetEvent('wasabi_police:svToggleDuty', function(stationId)
    local hasJob, grade
    if stationId then
        for id, clockingData in pairs(Config.Locations) do
            if id == stationId and clockingData.clockInAndOut.enabled then
                local jobLock = clockingData.clockInAndOut.jobLock or Config.policeJobs
                if wsb.framework == 'esx' then
                    if type(jobLock) == 'table' then
                        local jobLength = #jobLock
                        for i = 1, jobLength do
                            jobLock[jobLength + i] = 'off' .. jobLock[i]
                        end
                    else
                        jobLock = { jobLock, 'off' .. jobLock }
                    end
                end
                hasJob, grade = wsb.hasGroup(source, jobLock)
            end
        end
    else
        hasJob, grade = wsb.hasGroup(source, Config.policeJobs)
    end
    if not hasJob or not grade then return end

    local onDuty = wsb.toggleDuty(source, hasJob, grade)
    if not onDuty then return end
    TriggerEvent('wasabi_police:updateCopCount')
    if onDuty == 'on' then
        TriggerClientEvent('wasabi_bridge:notify', source, Strings.on_duty, Strings.on_duty_desc, 'success')
        TriggerEvent('wasabi_police:addPoliceCount', true)
        TriggerEvent('wasabi_police:addOfficerToGPS', source)
    else
        TriggerClientEvent('wasabi_bridge:notify', source, Strings.off_duty, Strings.off_duty_desc, 'error')
        TriggerEvent('wasabi_police:addPoliceCount', false)
        TriggerEvent('wasabi_police:removeOfficerFromGPS', source)
    end
end)

RegisterNetEvent('wasabi_police:escortPlayer', function(targetId)
    local src = source
    if not targetId or targetId == src or targetId == -1 then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    TriggerClientEvent('wasabi_police:setEscort', src, targetId)
    TriggerClientEvent('wasabi_police:escortedPlayer', targetId, src)
end)

RegisterNetEvent('wasabi_police:escortPlayerStop', function(pdId, notify)
    local src = source
    TriggerClientEvent('wasabi_police:stopEscorting', pdId, src)
    if not notify then return end
    TriggerClientEvent('wasabi_bridge:notify', pdId, Strings.suspect_died_escort, Strings.suspect_died_escort_desc,
        'error')
end)

RegisterNetEvent('wasabi_police:releasePlayer', function(targetId)
    local src = source
    if not targetId or targetId == src or targetId == -1 then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    TriggerClientEvent('wasabi_police:releasePlayerFromEscort', targetId, src)
end)

RegisterNetEvent('wasabi_police:handcuffPlayer', function(target, type)
    local src = source
    if not wsb.hasGroup(src, Config.policeJobs) then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    if cuffedPlayers[target] then
        TriggerClientEvent('wasabi_police:uncuffAnim', src, target)
        Wait(4000)
        TriggerClientEvent('wasabi_police:uncuff', target)
        if Config.handcuff?.cuffItem?.enabled and Config.handcuff?.cuffItem?.required then
            wsb.addItem(src,
                Config.handcuff.cuffItem.item, 1)
        end
        return
    end
    if Config.handcuff?.cuffItem?.enabled and Config.handcuff?.cuffItem?.required then
        local itemCheck = wsb.hasItem(source, Config.handcuff.cuffItem.item)
        if not itemCheck or itemCheck == 0 then
            TriggerClientEvent('wasabi_bridge:notify', src, Strings.no_cuffs, Strings.no_cuffs_desc, 'error')
            return
        end
        wsb.removeItem(src, Config.handcuff.cuffItem.item, 1)
    end
    TriggerClientEvent('wasabi_police:arrested', target, src, type)
    TriggerClientEvent('wasabi_police:arrest', src)
end)


RegisterNetEvent('wasabi_police:lockpickHandcuffs', function(target)
    local src = source
    if not target or target == src or target == -1 then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    if Config.handcuff?.cuffItem?.enabled and Config.handcuff?.cuffItem?.required then
        wsb.addItem(src,
            Config.handcuff.cuffItem.item, 1)
    end
    TriggerClientEvent('wasabi_police:uncuff', target)
end)

RegisterNetEvent('wasabi_police:breakLockpick', function()
    if not Config.handcuff?.lockpicking?.enabled then return end
    wsb.removeItem(source, Config.handcuff.lockpicking.item, 1)
end)

if Config.seizeCash.enabled then
    RegisterNetEvent('wasabi_police:seizeCash', function(target)
        local job, _grade = wsb.hasGroup(source, Config.policeJobs)
        if not job then return end
        local ped = GetPlayerPed(source)
        local targetPed = GetPlayerPed(target)
        if not ped or not targetPed then return end
        local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
        if not distanceCheck then return end
        if not source or not target then return end
        local cashTotal = wsb.getPlayerAccountFunds(target, 'money')
        if cashTotal > 0 then
            wsb.removeMoney(target, 'cash', cashTotal)
            TriggerClientEvent('wasabi_bridge:notify', target, Strings.seize_cash,
                Strings.seize_cash_desc:format(wsb.getName(source)))
            wsb.addItem(source, Config.seizeCash.item, 1, false, { cash = cashTotal })
        else
            TriggerClientEvent('wasabi_bridge:notify', source, Strings.seize_cash_failed, Strings.seize_cash_failed_desc)
        end
    end)
end


wsb.registerCallback('wasabi_police:registerStash', function(source, cb, data)
    local station = data.station
    local location = Config.Locations[station][data.location]
    if not Config.Locations[station] or not location then return end
    local coords = location.target.enabled and location.target.coords or location.coords
    if #(GetEntityCoords(GetPlayerPed(source)) - coords) > 8 then return end
    if not wsb.hasGroup(source, Config.policeJobs) then return end
    TriggerEvent('wasabi_bridge:registerStash', data)
    return true
end)

RegisterNetEvent('wasabi_police:billPlayer', function(target, job, amount)
    local job, _grade = wsb.hasGroup(source, Config.policeJobs)
    if not job then return end
    local ped = GetPlayerPed(source)
    local targetPed = GetPlayerPed(target)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    local player = wsb.getPlayer(target)
    if not player then return end
    local identifier = wsb.getIdentifier(source)
    exports.pefcl:createInvoice(source,
        {
            to = player.getName(),
            toIdentifier = identifier,
            from = job.label,
            fromIdentifier = nil,
            amount = amount,
            message =
                Strings.gov_billing,
            receiverAccountIdentifier = job.name,
            expiresAt = nil
        })
end)

-- Speed Traps

RegisterNetEvent('wasabi_police:removeSpeedTrap', function(id)
    local newSpeedTraps = {}
    for _, trap in ipairs(SpeedTraps) do
        if trap.id == id then
            if Config.RadarPosts.saveToDatabase then
                MySQL.update.await('DELETE FROM `wsb_speedtraps` WHERE `id` = ?', { id })
            end
            TriggerClientEvent('wasabi_police:removeSpeedTrap', -1, id)
        else
            newSpeedTraps[#newSpeedTraps + 1] = trap
        end
    end
    SpeedTraps = newSpeedTraps
end)

wsb.registerCallback('wasabi_police:renameSpeedTrap', function(_source, cb, id, name)
    for _, trap in ipairs(SpeedTraps) do
        if trap.id == id then
            trap.name = name
            if Config.RadarPosts.saveToDatabase then
                local data = json.encode(trap)
                MySQL.update.await('UPDATE `wsb_speedtraps` SET `data` = ? WHERE `id` = ?', { data, id })
            end

            TriggerClientEvent('wasabi_police:updateSpeedTrapName', -1, id, name)

            cb(true)
            return
        end
    end
    cb(false)
end)

wsb.registerCallback('wasabi_police:addccctvCamera', function(source, cb, coords, heading, index, input)
    local src = source
    local job, _grade = wsb.hasGroup(src, Config.policeJobs)
    if not job then return cb(false) end

    local tableKey = #CCTVCameras + 1

    CCTVCameras[tableKey] = {
        name = input[1],
        job = job,
        coords = coords,
        heading = heading,
        prop = Config.CCTVCameras.options[index].prop,
        destory = false
    }

    local id
    if Config.CCTVCameras.saveToDatabase then
        local data = json.encode(CCTVCameras[tableKey])
        id = MySQL.insert.await('INSERT INTO `wsb_cctvcameras` (`data`) VALUES (?)', { data })
    else
        CCTVCameraID = CCTVCameraID + 1
        id = CCTVCameraID
    end

    CCTVCameras[tableKey].id = id
    TriggerClientEvent('wasabi_police:addNewCCTVCamera', -1, CCTVCameras[tableKey])
    cb(true)
end)
wsb.registerCallback('wasabi_police:repairCCTVCameraById', function(_source, cb, id)
    for _, camera in ipairs(CCTVCameras) do
        if camera.id == id then
            camera.destory = false
            TriggerClientEvent('wasabi_police:updateCCTVCameraRepair', -1, id, false)
            cb(true)
            return
        end
    end
    cb(false)
end)

wsb.registerCallback('wasabi_police:renameCCTVCamera', function(_source, cb, id, name)
    for _, camera in ipairs(CCTVCameras) do
        if camera.id == id then
            if id:find('predefined_') then
                cb(false)
                return
            end
            camera.name = name
            if Config.CCTVCameras.saveToDatabase then
                local data = json.encode(camera)
                MySQL.update.await('UPDATE `wsb_cctvcameras` SET `data` = ? WHERE `id` = ?', { data, id })
            end

            TriggerClientEvent('wasabi_police:updateCCTVCameraName', -1, id, name)

            cb(true)
            return
        end
    end
    cb(false)
end)

RegisterNetEvent('wasabi_police:destroyCCTVCamera', function(id)
    for _, camera in ipairs(CCTVCameras) do
        if camera.id == id then
            camera.destory = true
            TriggerClientEvent('wasabi_police:updateCCTVCameraRepair', -1, id, true)
            return
        end
    end
end)

RegisterNetEvent('wasabi_police:removeCCTVCamera', function(id)
    local newCCTVCameras = {}
    for _, camera in ipairs(CCTVCameras) do
        if camera.id == id then
            if type(id) == 'string' and id:find('predefined_') then
                TriggerClientEvent('wasabi_bridge:notify', source, Strings.cctv_remove_error,
                    Strings.cctv_remove_error_desc, 'error')
                newCCTVCameras[#newCCTVCameras + 1] = camera
                return
            end
            if Config.CCTVCameras.saveToDatabase then
                MySQL.update.await('DELETE FROM `wsb_cctvcameras` WHERE `id` = ?', { id })
            end
            TriggerClientEvent('wasabi_police:removeCCTVCamera', -1, id)
        else
            newCCTVCameras[#newCCTVCameras + 1] = camera
        end
    end
    CCTVCameras = newCCTVCameras
end)

wsb.registerCallback('wasabi_police:getCCTVCameras', function(source, cb)
    cb(CCTVCameras or {})
end)

wsb.registerCallback('wasabi_police:addSpeedTrap', function(source, cb, coords, heading, index, input)
    local src = source
    local job, _grade = wsb.hasGroup(src, Config.policeJobs)
    if not job then return cb(false) end

    local tableKey = #SpeedTraps + 1

    SpeedTraps[tableKey] = {
        name = input[1],
        job = job,
        coords = coords,
        heading = heading,
        speedLimit = input[2],
        detectionRadius = input[3],
        prop = Config.RadarPosts.options[index].prop,
    }


    local id
    if Config.RadarPosts.saveToDatabase then
        local data = json.encode(SpeedTraps[tableKey])
        id = MySQL.insert.await('INSERT INTO `wsb_speedtraps` (`data`) VALUES (?)', { data })
    else
        SpeedTrapID = SpeedTrapID + 1
        id = SpeedTrapID
    end

    SpeedTraps[tableKey].id = id

    TriggerClientEvent('wasabi_police:addNewSpeedTrap', -1, SpeedTraps[tableKey])
    cb(true)
end)

wsb.registerCallback('wasabi_police:getSpeedTraps', function(source, cb)
    cb(SpeedTraps or {})
end)

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
    return currentFine, speedOver
end

RegisterNetEvent('wasabi_police:triggerSpeedTrap', function(id, speed)
    local src = source
    for _, trap in ipairs(SpeedTraps) do
        if trap.id == id then
            if trap.speedLimit > speed then return end
            local fine, speedOver = findProperSpeedTrapFine(trap.speedLimit, speed)
            if not Config.RadarPosts.allowNegativeBalance then
                local funds = wsb.getPlayerAccountFunds(src, Config.RadarPosts.chargeAccount)
                if fine > funds then
                    if funds > 0 then
                        wsb.removeMoney(src, Config.RadarPosts.chargeAccount, funds)
                        if Config.RadarPosts.creditSociety then
                            local accountToPay = (type(Config.RadarPosts.creditSociety) == 'string' and Config.RadarPosts.creditSociety) or
                                (type(Config.RadarPosts.creditSociety) == 'boolean' and trap.job ~= nil and trap.job) or
                                Config.policeJobs[1]
                            PaySociety(accountToPay, funds)
                        end
                    end
                else
                    wsb.removeMoney(src, Config.RadarPosts.chargeAccount, fine)
                    if Config.RadarPosts.creditSociety then
                        local accountToPay = (type(Config.RadarPosts.creditSociety) == 'string' and Config.RadarPosts.creditSociety) or
                            (type(Config.RadarPosts.creditSociety) == 'boolean' and trap.job ~= nil and trap.job) or
                            Config.policeJobs[1]
                        PaySociety(accountToPay, fine)
                    end
                end
            else
                wsb.removeMoney(src, Config.RadarPosts.chargeAccount, fine)
                if Config.RadarPosts.creditSociety then
                    local accountToPay = (type(Config.RadarPosts.creditSociety) == 'string' and Config.RadarPosts.creditSociety) or
                        (type(Config.RadarPosts.creditSociety) == 'boolean' and trap.job ~= nil and trap.job) or
                        Config.policeJobs[1]
                    PaySociety(accountToPay, fine)
                end
            end
            TriggerClientEvent('wasabi_bridge:notify', src, Strings.speedtrap_fine,
                (Strings.speedtrap_fine_desc):format(Strings.currency, addCommas(fine), speedOver,
                    Config.RadarPosts.measurement),
                'error', 'file-invoice-dollar')
            break
        end
    end
end)

RegisterNetEvent('wasabi_police:fineSuspect', function(targetId, amount, desc)
    local src = source
    local chargeAccount
    if src > 0 then
        local job, _grade = wsb.hasGroup(src, Config.policeJobs)
        if not job then return end
        chargeAccount = job
    else
        chargeAccount = Config.billingData.societyName or Config.policeJobs[1]
    end

    local player = wsb.getPlayer(targetId)
    if not player then return end
    local funds = wsb.getPlayerAccountFunds(targetId, Config.billingData.chargeAccount)
    if amount > funds and src and src > 0 then
        TriggerClientEvent('wasabi_bridge:notify', src, Strings.fine_nomoney,
            (Strings.fine_nomoney_desc):format(addCommas(amount)), 'error')
        return
    end

    wsb.removeMoney(targetId, Config.billingData.chargeAccount, amount)

    TriggerClientEvent('wasabi_police:alertDialog', targetId, {
        header = (Strings.ticket_received):format(wsb.getName(source)),
        content = desc,
        centered = true,
        cancel = false
    })
    if src and src > 0 then
        TriggerClientEvent('wasabi_bridge:notify', source, Strings.fine_sent,
            (Strings.fine_sent_desc):format(addCommas(amount)), 'success')
    end
    TriggerClientEvent('wasabi_bridge:notify', targetId, Strings.fine_received,
        (Strings.fine_received_desc):format(addCommas(amount)), 'success')

    if Config.billingData.creditSociety then
        PaySociety(
            (type(Config.billingData.creditSociety) == 'boolean' and chargeAccount) or
            (type(Config.billingData.creditSociety) == 'string' and Config.billingData.creditSociety), amount)
        return
    end

    if Config.billingData.societyName then -- Backward compatibility
        PaySociety(Config.billingData.societyName, amount)
    end
end)


RegisterNetEvent('wasabi_police:qbBill', function(target, amount, job)
    local src = source
    if not wsb.hasGroup(src, Config.policeJobs) then return end
    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if not ped or not targetPed then return end
    local distanceCheck = verifyTouchingDistance(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not distanceCheck then return end
    wsb.removeMoney(target, 'bank', amount)
    if src and src > 0 then
        TriggerClientEvent('wasabi_bridge:notify', source, Strings.fine_sent,
            (Strings.fine_sent_desc):format(addCommas(amount)), 'success')
    end
    TriggerClientEvent('wasabi_bridge:notify', target, Strings.fine_received,
        (Strings.fine_received_desc):format(addCommas(amount)), 'error')
    local qbBill = Config.OldQBManagement and 'qb-management' or 'qb-banking'
    exports[qbBill]:AddMoney(job, amount)
end)

--Cloakroom Standalone
RegisterNetEvent('wasabi_police:saveOutfit', function(outfit)
    local src = source
    local identifier = wsb.getIdentifier(src)
    if not identifier then return end
    if Outfits[identifier] then return end
    Outfits[identifier] = outfit
end)

wsb.registerCallback('wasabi_police:requestCivilianOutfit', function(source, cb)
    local src = source
    local identifier = wsb.getIdentifier(src)
    if not identifier then return end
    if not Outfits[identifier] then return cb(false) end
    local outfit = Outfits[identifier]
    Outfits[identifier] = nil
    cb(outfit)
end)

--Update PoliceCount for default qbRobberies
RegisterNetEvent('wasabi_police:addPoliceCount', function(increment)
    if not CopCount then
        CopCount = getPoliceOnline()
    else
        if increment then
            CopCount += 1
        else
            CopCount -= 1
        end
    end
    TriggerEvent('wasabi_police:updateCopCount')
end)

RegisterNetEvent('wasabi_police:updateCopCount', function()
    TriggerClientEvent('police:SetCopCount', -1, CopCount)
end)

RegisterNetEvent('wasabi_police:getPoliceOnline', function()
    local src = source
    TriggerClientEvent('police:SetCopCount', src, CopCount)
end)

wsb.registerCallback('wasabi_police:isCuffed', function(source, cb, target)
    cb(cuffedPlayers[target] or false)
end)

wsb.registerCallback('wasabi_police:canPurchase', function(source, cb, data)
    local itemData
    if data.grade > #Config.Locations[data.id].armoury.weapons then
        itemData = Config.Locations[data.id].armoury.weapons[#Config.Locations[data.id].armoury.weapons][data.itemId]
    elseif not Config.Locations[data.id].armoury.weapons[data.grade] then
        print('[wasabi_police] : Armory not set up properly for job grade: ' .. data.grade)
        cb(false)
        return
    else
        itemData = Config.Locations[data.id].armoury.weapons[data.grade][data.itemId]
    end
    if not itemData.price then
        if not Config.weaponsAsItems then
            if data.itemId:sub(0, 7) == 'WEAPON_' then
                wsb.addWeapon(data.itemId, 200)
            else
                wsb.addItem(source, data.itemId, data.quantity)
            end
        else
            wsb.addItem(source, data.itemId, data.quantity)
        end
        cb(true)
        return
    else
        local xBank = wsb.getPlayerAccountFunds(source, 'bank')
        if xBank < itemData.price then
            cb(false)
            return
        else
            wsb.removeMoney(source, 'bank', itemData.price)
            if not Config.weaponsAsItems then
                if data.itemId:sub(0, 7) == 'WEAPON_' then
                    wsb.addWeapon(source, data.itemId, 200)
                else
                    wsb.addItem(source, data.itemId, data.quantity)
                end
            else
                wsb.addItem(source, data.itemId, data.quantity)
            end
            cb(true)
            return
        end
        cb(false)
    end
end)

wsb.registerCallback('wasabi_police:getPlayerData', function(source, cb, data)
    local newData
    for i = 1, #data do
        if not newData then newData = {} end
        newData[#newData + 1] = {
            id = data[i].id,
            name = wsb.getName(data[i].id),
        }
    end
    while not #newData == #data do Wait(0) end
    cb(newData)
end)

wsb.registerCallback('wasabi_police:getVehicleOwner', function(source, cb, plate)
    local owner = wsb.getVehicleOwner(plate)
    while owner == nil do Wait(100) end
    cb(owner)
end)

wsb.registerCallback('wasabi_police:grantLicense', function(source, cb, id)
    if wsb.hasLicense(id, Config.GrantWeaponLicenses.license_name) then
        cb(false)
        return
    end

    local granted = wsb.grantLicense(id, Config.GrantWeaponLicenses.license_name)

    cb(granted and wsb.getName(id) or false)
end)

wsb.registerCallback('wasabi_police:gsrTest', function(source, cb, target)
    cb(GSRData[target] and true or false)
end)

wsb.registerCallback('wasabi_police:itemCheck', function(source, cb, item)
    cb(wsb.hasItem(source, item))
end)

if Config.Jail.enabled and Config.Jail.jail == 'qb' then
    RegisterNetEvent('wasabi_police:qbPrisonJail', function(target, time)
        local src = source
        local coords = GetEntityCoords(GetPlayerPed(src))
        local targetCoords = GetEntityCoords(GetPlayerPed(target))
        if #(coords - targetCoords) > 3.0 then return end
        local isPolice = wsb.hasGroup(src, Config.policeJobs)
        if not isPolice then return end
        local targetPlayer = wsb.getPlayer(target)
        if not targetPlayer then return end
        local date = os.date('*t')
        if date.day == 31 then date.day = 30 end
        targetPlayer.Functions.SetMetaData('injail', time)
        targetPlayer.Functions.SetMetaData('criminalrecord', {
            hasRecord = true,
            date = date
        })
        TriggerClientEvent('wasabi_police:qbPrisonJail', target, time)
        TriggerClientEvent('wasabi_bridge:notify', src, Strings.jailed_player,
            (Strings.jailed_player_desc):format(wsb.getName(target), time), 'success')
    end)
end

---Check if player is in jail
---@param target number
---@return boolean
function InJail(target)
    if not target then return false end
    return jailedPlayers[target] or false
end

exports('IsPlayerInJail', InJail)

RegisterNetEvent('wasabi_police:server:sendToJail', function(target, time)
    local src = source
    local suspect = src
    if target then
        local coords = GetEntityCoords(GetPlayerPed(src))
        local targetCoords = GetEntityCoords(GetPlayerPed(target))
        if #(coords - targetCoords) > 3.0 then return end
        local isPolice = wsb.hasGroup(src, Config.policeJobs)
        if not isPolice then return end
        TriggerClientEvent('wasabi_bridge:notify', src, Strings.jailed_player,
            (Strings.jailed_player_desc):format(wsb.getName(target), time), 'success')
        suspect = target
    end
    local targetPlayer = wsb.getPlayer(suspect)
    if not targetPlayer then return end
    if wsb.framework == 'qb' then
        local date = os.date('*t')
        if date.day == 31 then date.day = 30 end
        targetPlayer.Functions.SetMetaData('injail', time)
        targetPlayer.Functions.SetMetaData('criminalrecord', {
            hasRecord = true,
            date = date
        })
    elseif wsb.framework == 'esx' then
        SetSQLJailTime(targetPlayer.identifier, time)
    end
    Player(suspect).state:set('injail', time, true)
    jailedPlayers[suspect] = time
    TriggerClientEvent('wasabi_police:jailPlayer', suspect, time)
end)

RegisterNetEvent('wasabi_police:setJailStatus', function(status)
    local src = source
    if status ~= 0 then return end
    jailedPlayers[src] = nil
    if wsb.framework == 'qb' then
        local player = wsb.getPlayer(src)
        player.Functions.SetMetaData('injail', false)
    elseif wsb.framework == 'esx' then
        SetSQLJailTime(wsb.getIdentifier(src), false)
    end
    Player(src).state:set('injail', false, true)
    TriggerClientEvent('wasabi_police:releaseFromJail', src)
end)


if Config.billingSystem == 'qb' then
    RegisterNetEvent('wasabi_police:sendQBEmail', function(target, data)
        if target == nil or target < 1 then return end
        TriggerClientEvent('wasabi_police:sendQBEmail', target, data)
    end)
end

if Config.handcuff?.cuffItem?.enabled then
    wsb.registerUsableItem(Config.handcuff.cuffItem.item, function(source)
        TriggerClientEvent('wasabi_police:handcuffPlayer', source)
    end)
end

if Config.handcuff?.lockpicking?.enabled then
    wsb.registerUsableItem(Config.handcuff.lockpicking.item, function(source)
        TriggerClientEvent('wasabi_police:lockpickHandcuffs', source)
    end)
end

if Config.TrackingBracelet?.enabled then
    wsb.registerUsableItem(Config.TrackingBracelet.item, function(source)
        TriggerClientEvent('wasabi_police:trackPlayer', source)
    end)
end

TrackingPlayers = {}
RegisterNetEvent('wasabi_police:addPlayerToTracking', function(target)
    local source = source
    local isPolice = wsb.hasGroup(source, Config.policeJobs)
    if not isPolice then return end
    local coords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(target))
    if #(coords - targetCoords) > 3.0 then return end
    local targetPlayer = Player(target).state
    if targetPlayer.tracking then
        if Config.TrackingBracelet.item then
            wsb.addItem(source, Config.TrackingBracelet.item, 1)
        end
        targetPlayer:set('tracking', false, true)
        TriggerClientEvent('wasabi_police:removeTrackingProp', target)
        for i = 1, #TrackingPlayers do
            if TrackingPlayers[i].target == target then
                for police, suspects in pairs(playersToTrack) do
                    for j = 1, #suspects do
                        if suspects[j] == target then
                            TriggerClientEvent('wasabi_police:removeTrackedPlayer', police, target)
                            table.remove(suspects, j)
                            if #suspects == 0 then
                                playersToTrack[police] = nil
                            end
                        end
                    end
                end
                table.remove(TrackingPlayers, i)
                break
            end
        end
        return
    end
    if Config.TrackingBracelet.item then
        local itemCheck = wsb.hasItem(source, Config.TrackingBracelet.item)
        if not itemCheck or itemCheck == 0 then
            TriggerClientEvent('wasabi_bridge:notify', source, Strings.no_tracking_bracelet,
                Strings.no_tracking_bracelet_desc, 'error')
            return
        end
        wsb.removeItem(source, Config.TrackingBracelet.item, 1)
    end
    TriggerClientEvent('wasabi_police:addTrackingProp', target)
    targetPlayer:set('tracking', true, true)
    TrackingPlayers[#TrackingPlayers + 1] = {
        target = target,
        name = wsb.getName(target),
        sourceName = wsb.getName(source)
    }
    if Config.TrackingBracelet.timer then
        SetTimeout(Config.TrackingBracelet.timer, function()
            if not targetPlayer.tracking then return end
            targetPlayer:set('tracking', false, true)
            TriggerClientEvent('wasabi_police:removeTrackedPlayer', source, target)
            TriggerClientEvent('wasabi_police:removeTrackingProp', target)
            for i = 1, #TrackingPlayers do
                if TrackingPlayers[i].target == target then
                    table.remove(TrackingPlayers, i)
                    break
                end
            end
            for police, suspects in pairs(playersToTrack) do
                for j = 1, #suspects do
                    if suspects[j] == target then
                        table.remove(suspects, j)
                        if #suspects == 0 then
                            playersToTrack[police] = nil
                        end
                    end
                end
            end
        end)
    end
end)


RegisterNetEvent('wasabi_police:toggleTrackingBracelet', function(target)
    if not wsb.getPlayer(target) then return end
    if not wsb.hasGroup(source, Config.policeJobs) then return end
    playersToTrack[source] = playersToTrack[source] or {}
    local trackingList = playersToTrack[source]
    for i, trackedTarget in ipairs(trackingList) do
        if trackedTarget == target then
            table.remove(trackingList, i)
            TriggerClientEvent('wasabi_police:removeTrackedPlayer', source, target)
            if #trackingList == 0 then
                playersToTrack[source] = nil
            end
            return
        end
    end
    table.insert(trackingList, target)
end)

local function trackPlayers()
    for source, targets in pairs(playersToTrack) do
        local trackingData = {}
        for _, target in ipairs(targets) do
            local playerPed = GetPlayerPed(target)
            local coords = GetEntityCoords(playerPed)
            if coords and playerPed ~= 0 then
                trackingData[#trackingData + 1] = {
                    target = target,
                    coords = coords,
                    heading = math.ceil(GetEntityHeading(playerPed)),
                    name = wsb.getName(target)
                }
            end
        end
        if #trackingData > 0 then
            TriggerClientEvent('wasabi_police:refreshTrackingData', source, trackingData)
        else
            playersToTrack[source] = nil
        end
    end
end

CreateThread(function()
    while true do
        Wait(1500)
        if next(playersToTrack) then
            trackPlayers()
        end
    end
end)

wsb.registerCallback('wasabi_police:getTrackingBracelets', function(source, cb)
    cb(TrackingPlayers)
end)

wsb.registerCallback('wasabi_police:loadCuffCheck', function(source, cb)
    local src = source
    local identifier = wsb.getIdentifier(src)
    if not identifier then
        cb(false)
        return
    end
    local handcuffCheck = MySQL.single.await('SELECT `ishandcuffed` FROM `users` WHERE `identifier` = ? LIMIT 1', {
        identifier
    })
    if handcuffCheck and handcuffCheck.ishandcuffed then
        cb(true)
        return
    end
    cb(false)
end)

wsb.registerCallback('wasabi_police:jailCheck', function(source, cb)
    local src = source
    local identifier = wsb.getIdentifier(src)
    if not identifier then
        cb(false)
        return
    end
    local injail = MySQL.single.await('SELECT `injail` FROM `users` WHERE `identifier` = ? LIMIT 1', {
        identifier
    })
    if injail and injail.injail then
        cb(injail.injail)
        return
    end
    cb(false)
end)

function SetSQLJailTime(id, time)
    local affectedRows = MySQL.update.await('UPDATE users SET injail = ? WHERE identifier = ?', {
        time, id
    })
end

function SetSQLHandcuffStatus(id, status)
    status = status and 1 or 0

    local affectedRows = MySQL.update.await('UPDATE users SET ishandcuffed = ? WHERE identifier = ?', {
        status, id
    })
end

if Config.RadarPosts.enabled and Config.RadarPosts.saveToDatabase then
    CreateThread(function()
        local queries = {
            [[
            CREATE TABLE IF NOT EXISTS `wsb_speedtraps` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `data` longtext DEFAULT NULL,
            PRIMARY KEY (`id`)
            ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
            ]]
        }

        MySQL.transaction(queries, nil, function(success)
            if not success then
                print(Strings.warning_speedtrap_table)
            else
                local speedTraps = MySQL.query.await('SELECT * FROM `wsb_speedtraps`', {})
                if speedTraps then
                    for i = 1, #speedTraps do
                        local speedTrap = speedTraps[i]
                        local data = json.decode(speedTrap.data)
                        data.id = speedTrap.id
                        data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
                        SpeedTraps[#SpeedTraps + 1] = data
                    end
                    if #GetPlayers() > 0 then
                        Wait(3000)
                        TriggerClientEvent('wasabi_police:initSpeedTraps', -1, SpeedTraps)
                    end
                end
            end
        end)
    end)
end

if Config.CCTVCameras.enabled and Config.CCTVCameras.saveToDatabase then
    CreateThread(function()
        local queries = {
            [[
            CREATE TABLE IF NOT EXISTS `wsb_cctvcameras` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `data` longtext DEFAULT NULL,
            PRIMARY KEY (`id`)
            ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
            ]]
        }

        MySQL.transaction(queries, nil, function(success)
            if not success then
                print(Strings.warning_cctv_table)
            else
                local cctvCameras = MySQL.query.await('SELECT * FROM `wsb_cctvcameras`', {})
                if cctvCameras then
                    for i = 1, #cctvCameras do
                        local cctvCamera = cctvCameras[i]
                        local data = json.decode(cctvCamera.data)
                        data.id = cctvCamera.id
                        data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
                        CCTVCameras[#CCTVCameras + 1] = data
                    end
                    if Config.CCTVCameras.enabled and Config.CCTVCameras.locations.enabled and next(Config.CCTVCameras.locations.data) then
                        for i = 1, #Config.CCTVCameras.locations.data do
                            local location = Config.CCTVCameras.locations.data[i]
                            CCTVCameras[#CCTVCameras + 1] = {
                                id = 'predefined_' .. i,
                                name = location.name,
                                job = 'police',
                                coords = vector3(location.coords.x, location.coords.y, location.coords.z),
                                heading = location.heading,
                                prop = location.prop,
                                destory = false
                            }
                        end
                    end
                    if #GetPlayers() > 0 then
                        Wait(3000)
                        TriggerClientEvent('wasabi_police:initCCTVCameras', -1, CCTVCameras)
                    end
                end
            end
        end)
    end)
end

for id, data in pairs(Config.Locations) do
    if data.armoury and data.armoury.enabled and data.armoury.weapons then
        data = data.armoury
        local itemsData = data.weapons
        local groups = data.jobLock and (wsb.inventorySystem == 'ox_inventory' and { [data.jobLock] = 0 } or data.jobLock) or nil
        if wsb.inventorySystem then 
            for grade, items in pairs(itemsData) do
                local gradeItems = {}

                for _, item in pairs(items) do
                    local convertedItem = {
                        name = item.name,
                        price = item.price or 0,
                        amount = item.amount or 99,
                        metadata = item.metadata or {}
                    }
                    gradeItems[#gradeItems + 1] = convertedItem
                end
                TriggerEvent('wasabi_bridge:registerShop', {
                    identifier = id .. '_armoryweapons' .. grade,
                    groups = groups,
                    jobShop = true,
                    name = Strings.armoury_menu,
                    inventory = gradeItems,
                    location = { data.target.enabled and data.target.coords or data.coords },
                })
            end
        end
    end
end