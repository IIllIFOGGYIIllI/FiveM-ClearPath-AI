local protectedPursuitPeds = {}

local function extractNetId(payload)
    if type(payload) == 'number' then
        return payload > 0 and payload or nil
    end

    if type(payload) ~= 'table' then return nil end

    local keys = {
        'pedNetId', 'PedNetId', 'ped_net_id',
        'netId', 'NetId', 'networkId', 'NetworkId',
        'pedNetworkId', 'PedNetworkId', 'entityNetId',
    }

    for _, key in ipairs(keys) do
        local value = tonumber(payload[key])
        if value and value > 0 then return value end
    end

    return nil
end

local function setPursuitPedProtected(pedNetId, protected)
    pedNetId = tonumber(pedNetId)
    if not pedNetId or pedNetId <= 0 then return false end

    if protected then
        protectedPursuitPeds[pedNetId] = true
    else
        protectedPursuitPeds[pedNetId] = nil
    end

    TriggerClientEvent('clearpath_ai:ersPursuitPed', -1, pedNetId, protected == true)
    return true
end

-- Nights Software documents these ERS integration events for pursuit lifecycle.
-- Their documentation has used both a numeric ped net ID and a pedData payload over
-- time, so the extractor deliberately supports both forms.
RegisterNetEvent('ErsIntegration::OnPursuitStarted')
AddEventHandler('ErsIntegration::OnPursuitStarted', function(payload)
    local pedNetId = extractNetId(payload)
    if pedNetId then
        setPursuitPedProtected(pedNetId, true)
    end
end)

RegisterNetEvent('ErsIntegration::OnPursuitEnded')
AddEventHandler('ErsIntegration::OnPursuitEnded', function(payload)
    local pedNetId = extractNetId(payload)
    if pedNetId then
        setPursuitPedProtected(pedNetId, false)
    end
end)

RegisterNetEvent('clearpath_ai:requestProtectedSnapshot')
AddEventHandler('clearpath_ai:requestProtectedSnapshot', function()
    local src = source
    local snapshot = {}
    for netId in pairs(protectedPursuitPeds) do
        snapshot[#snapshot + 1] = netId
    end
    TriggerClientEvent('clearpath_ai:protectedSnapshot', src, snapshot)
end)

-- Generic server-side compatibility hook for other resources.
exports('SetProtectedNetId', function(netId, protected)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return false end
    TriggerClientEvent('clearpath_ai:setProtectedNetId', -1, netId, protected == true, 0)
    return true
end)
