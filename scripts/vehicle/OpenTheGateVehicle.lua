-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- Vehicle-train bounds and movement direction.

local validNode = OpenTheGateUtil.validNode

local function projectOnAxis(rootX, rootZ, px, pz, fwdX, fwdZ)
    return fwdX * (px - rootX) + fwdZ * (pz - rootZ)
end

local function getObjectBoundingPoints(object)
    if object == nil or not validNode(object.rootNode) then
        return nil
    end
    local x, _, z = getWorldTranslation(object.rootNode)
    local fx, _, fz = localDirectionToWorld(object.rootNode, 0, 0, 1)
    local len = math.sqrt(fx * fx + fz * fz)
    if len > 0.0001 then fx, fz = fx / len, fz / len end
    local size = object.size or {}
    local halfLength = (tonumber(size.length) or 8) * 0.5
    local offset = tonumber(size.lengthOffset) or 0
    return x + fx * (halfLength + offset), z + fz * (halfLength + offset),
           x - fx * (halfLength - offset), z - fz * (halfLength - offset), fx, fz
end

local function walkVehicleTrain(object, rootX, rootZ, rootFx, rootFz, bounds, seen)
    if object == nil or seen[object] then return end
    seen[object] = true
    local frontX, frontZ, rearX, rearZ, fx, fz = getObjectBoundingPoints(object)
    if frontX ~= nil then
        local frontProjection = projectOnAxis(rootX, rootZ, frontX, frontZ, rootFx, rootFz)
        local rearProjection = projectOnAxis(rootX, rootZ, rearX, rearZ, rootFx, rootFz)
        if frontProjection > bounds.maxFront then
            bounds.maxFront = frontProjection
            bounds.frontX, bounds.frontZ = frontX, frontZ
            bounds.frontFx, bounds.frontFz = fx, fz
        end
        if rearProjection < bounds.maxRear then
            bounds.maxRear = rearProjection
            bounds.rearX, bounds.rearZ = rearX, rearZ
            bounds.rearFx, bounds.rearFz = fx, fz
        end
    end
    if object.getAttachedImplements ~= nil then
        local ok, implements = pcall(object.getAttachedImplements, object)
        if ok and implements ~= nil then
            for _, implement in ipairs(implements) do
                walkVehicleTrain(implement.object, rootX, rootZ, rootFx, rootFz, bounds, seen)
            end
        end
    end
end

function OpenTheGate:getVehicleCompositionBounds(vehicle)
    local rootVehicle = vehicle
    if vehicle.getRootVehicle ~= nil then
        local ok, candidate = pcall(vehicle.getRootVehicle, vehicle)
        if ok and candidate ~= nil then rootVehicle = candidate end
    end
    if rootVehicle == nil or not validNode(rootVehicle.rootNode) then return nil end
    local rootX, rootY, rootZ = getWorldTranslation(rootVehicle.rootNode)
    local rootFx, _, rootFz = localDirectionToWorld(rootVehicle.rootNode, 0, 0, 1)
    local len = math.sqrt(rootFx * rootFx + rootFz * rootFz)
    if len > 0.0001 then rootFx, rootFz = rootFx / len, rootFz / len end
    local bounds = {
        maxFront = -math.huge, maxRear = math.huge,
        frontX = rootX, frontZ = rootZ, frontFx = rootFx, frontFz = rootFz,
        rearX = rootX, rearZ = rootZ, rearFx = rootFx, rearFz = rootFz
    }
    walkVehicleTrain(rootVehicle, rootX, rootZ, rootFx, rootFz, bounds, setmetatable({}, {__mode='k'}))
    return rootX, rootY, rootZ, rootFx, rootFz,
           bounds.frontX, bounds.frontZ, bounds.frontFx, bounds.frontFz,
           bounds.rearX, bounds.rearZ, bounds.rearFx, bounds.rearFz
end


function OpenTheGate:getVehicleMovingDirection(vehicle)
    -- GIANTS vehicles normally expose movingDirection as 1 (forward),
    -- -1 (reverse), or 0 (stationary). Fall back to signed last speed where
    -- custom vehicles expose that instead.
    local direction = tonumber(vehicle.movingDirection)
    if direction ~= nil and math.abs(direction) > 0.01 then
        return direction > 0 and 1 or -1, "movingDirection"
    end

    local signedSpeed = tonumber(vehicle.lastSpeedReal)
    if signedSpeed ~= nil and math.abs(signedSpeed) > 0.0001 then
        return signedSpeed > 0 and 1 or -1, "lastSpeedReal"
    end

    return 0, "stationary"
end
