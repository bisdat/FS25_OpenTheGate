-- Server-side gate selection and request coordination.

local function debugLog(fmt, ...) OpenTheGateUtil.debugLog("TARGETING", fmt, ...) end
local boolText = OpenTheGateUtil.boolText
local vehicleText = OpenTheGateUtil.vehicleText
local getTimeMs = OpenTheGateUtil.getTimeMs
local getNodeNameSafe = OpenTheGateUtil.getNodeNameSafe

local function planarDistance(x1, z1, x2, z2)
    local dx, dz = x2 - x1, z2 - z1
    return math.sqrt(dx * dx + dz * dz)
end

local function pointMetrics(gx, gz, px, pz, fx, fz)
    local dx, dz = gx - px, gz - pz
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.0001 then return distance, 1, 0, 0 end
    local longitudinal = dx * fx + dz * fz
    local lateral = math.abs(dx * fz - dz * fx)
    return distance, longitudinal / distance, lateral, longitudinal
end


local function getGatePosition(gate)
    if gate.positionX ~= nil and gate.positionZ ~= nil then
        return gate.positionX, gate.positionY or 0, gate.positionZ
    end
    return getWorldTranslation(gate.node)
end

function OpenTheGate:handleRequest(vehicle, mode, connection)
    debugLog("handleRequest BEGIN vehicle=%s mode=%s connection=%s server=%s", vehicleText(vehicle), tostring(mode), tostring(connection), boolText(g_server ~= nil))
    if g_server == nil then debugLog("handleRequest ABORT: g_server=nil") return end
    if vehicle == nil then debugLog("handleRequest ABORT: vehicle=nil") return end
    if vehicle.getIsSynchronized ~= nil and not vehicle:getIsSynchronized() then debugLog("handleRequest ABORT: vehicle not synchronized") return end

    local now = getTimeMs()
    local last = self.lastServerRequest[vehicle] or 0
    if now - last < OpenTheGateConfig.REQUEST_COOLDOWN_MS then
        debugLog("handleRequest ABORT: cooldown delta=%dms", now-last)
        return
    end
    self.lastServerRequest[vehicle] = now

    local vx, vy, vz, fx, fz, frontX, frontZ, frontFx, frontFz, rearX, rearZ, rearFx, rearFz = self:getVehicleCompositionBounds(vehicle)
    if vx == nil then
        debugLog("handleRequest ABORT: could not get vehicle composition bounds")
        return
    end
    debugLog("Vehicle composition: root=%.2f,%.2f,%.2f forward=%.3f,%.3f front=%.2f,%.2f frontDir=%.3f,%.3f rear=%.2f,%.2f rearDir=%.3f,%.3f",
        vx, vy, vz, fx, fz, frontX, frontZ, frontFx, frontFz, rearX, rearZ, rearFx, rearFz)

    local gates = self:collectGates()
    local selected = {}

    local compositionLength = planarDistance(frontX, frontZ, rearX, rearZ)
    local nearestRange = math.min(OpenTheGateConfig.NEAREST_MAX_DYNAMIC_DISTANCE,
        math.max(OpenTheGateConfig.NEAREST_BASE_DISTANCE, OpenTheGateConfig.NEAREST_BASE_DISTANCE + compositionLength))
    local movingDirection, movingDirectionSource = self:getVehicleMovingDirection(vehicle)
    debugLog("Targeting parameters: compositionLength=%.2fm nearestRange=%.2fm movingDirection=%d source=%s pairedDistance=%.2fm",
        compositionLength, nearestRange, movingDirection, movingDirectionSource, OpenTheGateConfig.PAIRED_GATE_DISTANCE)

    if mode == OpenTheGateConfig.MODE_RADIUS then
        for _, gate in ipairs(gates) do
            local gx, _, gz = getGatePosition(gate)
            local rootDist = planarDistance(vx, vz, gx, gz)
            local frontDist = planarDistance(frontX, frontZ, gx, gz)
            local rearDist = planarDistance(rearX, rearZ, gx, gz)
            local distance = math.min(rootDist, frontDist, rearDist)
            debugLog("Radius candidate node='%s' root=%.2fm front=%.2fm rear=%.2fm nearest=%.2fm inside=%s",
                getNodeNameSafe(gate.node), rootDist, frontDist, rearDist, distance,
                boolText(distance <= OpenTheGateConfig.ALL_GATES_RADIUS))
            if distance <= OpenTheGateConfig.ALL_GATES_RADIUS then
                table.insert(selected, gate)
            end
        end
    else
        local eligible = {}
        local bestEntry, bestScore = nil, math.huge
        for _, gate in ipairs(gates) do
            local gx, _, gz = getGatePosition(gate)
            local fd, fdot, flat, flong = pointMetrics(gx, gz, frontX, frontZ, frontFx, frontFz)
            local rd, rdot, rlat, rlong = pointMetrics(gx, gz, rearX, rearZ, rearFx, rearFz)

            local rootDistance = planarDistance(vx, vz, gx, gz)
            local closeDistance = math.min(rootDistance, fd, rd)
            local isClose = closeDistance <= OpenTheGateConfig.CLOSE_GATE_DISTANCE

            local useFront = flong >= 0
            local useRear = rlong <= 0
            local distance, alignment, lateral, side
            if useFront and (not useRear or fd <= rd) then
                distance, alignment, lateral, side = fd, fdot, flat, "front"
            elseif useRear then
                distance, alignment, lateral, side = rd, -rdot, rlat, "rear"
            elseif isClose then
                -- A wide door beside a long vehicle can lie between the calculated
                -- front and rear endpoints. For close candidates, use the nearest
                -- endpoint rather than rejecting it for being outside both cones.
                if fd <= rd then
                    distance, alignment, lateral, side = fd, fdot, flat, "front"
                else
                    distance, alignment, lateral, side = rd, -rdot, rlat, "rear"
                end
            end

            local directionOK = alignment ~= nil and alignment >= OpenTheGateConfig.MIN_DIRECTION_DOT
            local lateralOK = lateral ~= nil and lateral <= OpenTheGateConfig.MAX_LATERAL_OFFSET
            local distanceOK = distance ~= nil and distance <= nearestRange

            local targetableNow = isClose or (directionOK and lateralOK and distanceOK)
            debugLog("Nearest candidate node='%s' side=%s front[d=%.2f dot=%.3f lateral=%.2f long=%.2f] rear[d=%.2f dot=%.3f lateral=%.2f long=%.2f] root=%.2f close=%.2f closeOverride=%s targetable=%s",
                getNodeNameSafe(gate.node), tostring(side), fd, fdot, flat, flong, rd, rdot, rlat, rlong,
                rootDistance, closeDistance, boolText(isClose), boolText(targetableNow))

            if targetableNow then
                local motionPenalty = 0
                if not isClose then
                    if movingDirection > 0 and side ~= "front" then
                        motionPenalty = OpenTheGateConfig.MOVING_DIRECTION_BONUS
                    elseif movingDirection < 0 and side ~= "rear" then
                        motionPenalty = OpenTheGateConfig.MOVING_DIRECTION_BONUS
                    end
                end

                -- Every close-proximity candidate outranks every directional
                -- candidate. Among close candidates, choose the physically nearest.
                local score
                if isClose then
                    score = closeDistance
                else
                    score = 10000 + lateral * 100 + distance + motionPenalty
                end
                local entry = {
                    gate = gate, x = gx, z = gz, side = side,
                    distance = isClose and closeDistance or distance,
                    lateral = lateral or 0, alignment = alignment or 0,
                    isClose = isClose, score = score
                }
                table.insert(eligible, entry)
                if score < bestScore then
                    bestScore = score
                    bestEntry = entry
                    debugLog("Nearest BEST updated: node='%s' side=%s score=%.2f close=%s lateral=%.2f distance=%.2f motionPenalty=%.2f",
                        getNodeNameSafe(gate.node), tostring(side), score, boolText(isClose), lateral or 0,
                        isClose and closeDistance or distance, motionPenalty)
                end
            end
        end

        if bestEntry ~= nil then
            table.insert(selected, bestEntry.gate)

            -- Paired entrances commonly use two adjacent AnimatedObjects. Open
            -- the companion when it is close to the selected gate, lies on the
            -- same front/rear side, and is similarly aligned with the vehicle.
            local pairEntry, pairDistance = nil, math.huge
            for _, entry in ipairs(eligible) do
                if entry ~= bestEntry and entry.side == bestEntry.side then
                    local separation = planarDistance(bestEntry.x, bestEntry.z, entry.x, entry.z)
                    local alignmentDelta = math.abs(entry.alignment - bestEntry.alignment)
                    if separation <= OpenTheGateConfig.PAIRED_GATE_DISTANCE
                        and alignmentDelta <= 0.20
                        and separation < pairDistance then
                        pairEntry = entry
                        pairDistance = separation
                    end
                end
            end

            if pairEntry ~= nil then
                table.insert(selected, pairEntry.gate)
                debugLog("Paired gate selected: primary='%s' companion='%s' separation=%.2fm side=%s",
                    getNodeNameSafe(bestEntry.gate.node), getNodeNameSafe(pairEntry.gate.node), pairDistance, bestEntry.side)
            else
                debugLog("No paired gate found within %.2fm of primary='%s'", OpenTheGateConfig.PAIRED_GATE_DISTANCE,
                    getNodeNameSafe(bestEntry.gate.node))
            end
        end
    end

    local toggled = 0
    for _, gate in ipairs(selected) do
        if self:toggle(gate.animatedObject) then toggled = toggled + 1 end
    end
    debugLog("Request mode=%d found=%d selected=%d toggled=%d", mode, #gates, #selected, toggled)
end


g_openTheGate = OpenTheGate.new()
addModEventListener(g_openTheGate)
