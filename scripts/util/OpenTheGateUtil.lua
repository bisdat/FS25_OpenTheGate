-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- FS25_OpenTheGate shared utility helpers.

OpenTheGateUtil = OpenTheGateUtil or {}

function OpenTheGateUtil.isDebugEnabled(category)
    if OpenTheGateConfig == nil then
        return false
    end

    -- The master flag must itself be explicitly true. Truthy non-boolean
    -- values are deliberately ignored to prevent accidental debug output.
    if OpenTheGateConfig.DEBUG == true then
        return true
    end

    if category == nil then
        return false
    end

    local flagName = "DEBUG_" .. string.upper(tostring(category))
    return OpenTheGateConfig[flagName] == true
end

function OpenTheGateUtil.debugLog(category, fmt, ...)
    if not OpenTheGateUtil.isDebugEnabled(category) then
        return
    end

    Logging.info("[FS25_OpenTheGate][DEBUG][%s] " .. tostring(fmt), tostring(category), ...)
end

function OpenTheGateUtil.boolText(value)
    if value == nil then return "nil" end
    return value and "true" or "false"
end

function OpenTheGateUtil.vehicleText(vehicle)
    if vehicle == nil then return "nil" end

    local name = vehicle.configFileName or "unnamed"
    if vehicle.getName ~= nil then
        local ok, value = pcall(vehicle.getName, vehicle)
        if ok and value ~= nil then
            name = value
        end
    end

    return string.format("%s (%s)", tostring(name), tostring(vehicle))
end

function OpenTheGateUtil.getTimeMs()
    if g_time ~= nil then return g_time end
    return math.floor(os.clock() * 1000)
end

function OpenTheGateUtil.validNode(node)
    return node ~= nil and node ~= 0 and entityExists(node)
end

function OpenTheGateUtil.getNodeNameSafe(node)
    if not OpenTheGateUtil.validNode(node) then return "" end
    local ok, value = pcall(getName, node)
    return ok and value or ""
end
