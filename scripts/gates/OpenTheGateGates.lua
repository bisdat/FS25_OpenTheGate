-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- Animated entrance discovery, validation, and operation.

local function debugLog(fmt, ...) OpenTheGateUtil.debugLog("GATES", fmt, ...) end
local boolText = OpenTheGateUtil.boolText
local validNode = OpenTheGateUtil.validNode
local getNodeNameSafe = OpenTheGateUtil.getNodeNameSafe

local function firstValidNode(...)
    for index = 1, select("#", ...) do
        local node = select(index, ...)
        if validNode(node) then
            return node
        end
    end
    return nil
end

function OpenTheGate:getAnimatedObjectNode(animatedObject, owner)
    local controls = animatedObject.controls
    local node = firstValidNode(
        animatedObject.triggerNode,
        controls ~= nil and controls.triggerNode or nil,
        animatedObject.node,
        animatedObject.rootNode,
        animatedObject.saveIdNode,
        owner ~= nil and owner.rootNode or nil
    )
    if node ~= nil then
        return node
    end

    if animatedObject.animation ~= nil and animatedObject.animation.parts ~= nil then
        for _, part in pairs(animatedObject.animation.parts) do
            if part ~= nil and validNode(part.node) then
                return part.node
            end
        end
    end

    return nil
end

function OpenTheGate:isOperableAnimatedEntry(animatedObject, owner, extraName)
    if animatedObject == nil then
        return false, "nil object"
    end

    -- Fence segments are already semantically known to be gates. They still
    -- need the native AnimatedObject interface before we accept them.
    local isFenceGate = extraName == "fenceGate"

    local animation = animatedObject.animation
    if animation == nil then
        return false, "no animation table"
    end

    if type(animatedObject.setDirection) ~= "function" then
        return false, "no setDirection method"
    end

    local triggerNode = animatedObject.triggerNode
    if not validNode(triggerNode) and animatedObject.controls ~= nil then
        triggerNode = animatedObject.controls.triggerNode
    end
    if not validNode(triggerNode) then
        return false, "no valid interaction trigger"
    end

    -- Reject zero-length or malformed animation definitions. A duration is
    -- the most reliable field, but some map objects expose only animation
    -- parts plus time/direction, so allow that equivalent structure too.
    local duration = tonumber(animation.duration)
    local hasDuration = duration ~= nil and duration > 0
    local hasAnimState = animation.time ~= nil and animation.direction ~= nil
    local hasParts = animation.parts ~= nil and next(animation.parts) ~= nil
    if not hasDuration and not (hasAnimState and hasParts) then
        return false, "animation has no usable duration/parts"
    end

    if isFenceGate then
        return true, "fence segment AnimatedObject"
    end

    -- Require evidence that this animation is intended for player interaction,
    -- rather than a decorative looping animation such as a fan, flag or animal.
    local activatable = animatedObject.activatable
    local hasActivatable = activatable ~= nil and
        (type(activatable.onAnimationInputToggle) == "function"
         or type(activatable.run) == "function"
         or type(activatable.getIsActivatable) == "function")

    local controls = animatedObject.controls
    local hasControls = controls ~= nil and
        (controls.posAction ~= nil
         or controls.negAction ~= nil
         or controls.posActionEventId ~= nil
         or controls.negActionEventId ~= nil)

    local hasTriggerContract = type(animatedObject.getCanBeTriggered) == "function"
        or type(animatedObject.onActivateObject) == "function"
        or type(animatedObject.registerInteraction) == "function"

    if not hasActivatable and not hasControls and not hasTriggerContract then
        return false, "animated but no player-interaction contract"
    end

    local reasons = {}
    if hasActivatable then table.insert(reasons, "activatable") end
    if hasControls then table.insert(reasons, "controls") end
    if hasTriggerContract then table.insert(reasons, "triggerContract") end
    return true, table.concat(reasons, "+")
end

function OpenTheGate:addCandidate(result, seen, animatedObject, owner, extraName, segment)
    if animatedObject == nil then return end
    if seen[animatedObject] then return end
    local gateMatch, matchReason = self:isOperableAnimatedEntry(animatedObject, owner, extraName)
    if OpenTheGateConfig.DEBUG_VERBOSE_GATE_SCAN == true then
        OpenTheGateUtil.debugLog("VERBOSE_GATE_SCAN", "Gate scan object=%s owner=%s extra=%s match=%s reason=%s", tostring(animatedObject), tostring(owner), tostring(extraName), boolText(gateMatch), tostring(matchReason))
    end
    if not gateMatch then return end

    local node = self:getAnimatedObjectNode(animatedObject, owner)
    if not validNode(node) then
        debugLog("Gate candidate rejected: behavioural match but no usable position node object=%s", tostring(animatedObject))
        return
    end

    local x, y, z = getWorldTranslation(node)

    -- Runtime fence segments expose their exact world-space endpoints. The
    -- interaction trigger may be offset or attached to one gate leaf, so use
    -- the segment midpoint for targeting while retaining the trigger node for
    -- diagnostics and normal AnimatedObject operation.
    local positionX, positionY, positionZ = x, y, z
    if segment ~= nil
        and tonumber(segment.startPosX) ~= nil and tonumber(segment.endPosX) ~= nil
        and tonumber(segment.startPosY) ~= nil and tonumber(segment.endPosY) ~= nil
        and tonumber(segment.startPosZ) ~= nil and tonumber(segment.endPosZ) ~= nil then
        positionX = (segment.startPosX + segment.endPosX) * 0.5
        positionY = (segment.startPosY + segment.endPosY) * 0.5
        positionZ = (segment.startPosZ + segment.endPosZ) * 0.5
    end

    debugLog("Gate candidate accepted: object=%s node=%s name='%s' reason=%s pos=%.2f,%.2f,%.2f segment=%s", tostring(animatedObject), tostring(node), getNodeNameSafe(node), tostring(matchReason), positionX, positionY, positionZ, boolText(segment ~= nil))
    seen[animatedObject] = true
    table.insert(result, {
        animatedObject = animatedObject,
        owner = owner,
        node = node,
        segment = segment,
        positionX = positionX,
        positionY = positionY,
        positionZ = positionZ
    })
end

function OpenTheGate:collectGates()
    debugLog("collectGates BEGIN")
    local result = {}
    local seen = setmetatable({}, {__mode = "k"})
    local mission = g_currentMission
    if mission == nil then
        return result
    end

    -- Purchased and pre-placed placeables.
    local placeables = nil
    if mission.placeableSystem ~= nil then
        placeables = mission.placeableSystem.placeables or mission.placeableSystem.placeablesById
    end
    if placeables == nil then
        placeables = mission.placeables
    end

    if placeables ~= nil then
        for _, placeable in pairs(placeables) do
            if placeable ~= nil and placeable.spec_animatedObjects ~= nil then
                for _, animatedObject in pairs(placeable.spec_animatedObjects.animatedObjects or {}) do
                    self:addCandidate(result, seen, animatedObject, placeable, nil)
                end
            end

            -- Dynamically built fence gates. FS25 stores new-fence runtime
            -- segments below spec_newFence.fence.segments. Gate segments expose
            -- an animatedObjects array even though the savegame XML contains a
            -- singular <animatedObject> element. Keep legacy fallbacks for maps
            -- or placeables using earlier/custom layouts.
            local fenceSpecs = {
                placeable ~= nil and placeable.spec_newFence or nil,
                placeable ~= nil and placeable.spec_fence or nil
            }
            for _, fenceSpec in pairs(fenceSpecs) do
                if fenceSpec ~= nil then
                    local segments = fenceSpec.fence ~= nil and fenceSpec.fence.segments or fenceSpec.segments
                    for _, segment in pairs(segments or {}) do
                        -- Base-game gates usually expose animatedObjects on the
                        -- segment. Some modded FenceGate classes retain the XML
                        -- hierarchy and expose them below segment.gate or a
                        -- similar wrapper.
                        local gateContainers = {
                            segment,
                            segment.gate,
                            segment.fenceGate,
                            segment.gateData,
                            segment.object
                        }

                        local foundFenceAnimation = false
                        for _, gateContainer in pairs(gateContainers) do
                            if gateContainer ~= nil then
                                if gateContainer.animatedObjects ~= nil then
                                    for _, animatedObject in pairs(gateContainer.animatedObjects) do
                                        self:addCandidate(result, seen, animatedObject, placeable, "fenceGate", segment)
                                        foundFenceAnimation = true
                                    end
                                end

                                if gateContainer.animatedObject ~= nil then
                                    self:addCandidate(result, seen, gateContainer.animatedObject, placeable, "fenceGate", segment)
                                    foundFenceAnimation = true
                                end
                            end
                        end

                        if OpenTheGateConfig.DEBUG_VERBOSE_GATE_SCAN == true and not foundFenceAnimation then
                            OpenTheGateUtil.debugLog("VERBOSE_GATE_SCAN",
                                "Fence segment has no exposed AnimatedObject: segment=%s gate=%s class=%s id=%s",
                                tostring(segment), tostring(segment.gate), tostring(segment.class), tostring(segment.id))
                        end
                    end
                end
            end

            -- Some custom placeables expose AnimatedObjects directly rather
            -- than through PlaceableAnimatedObjects specialization.
            if placeable ~= nil and placeable.animatedObjects ~= nil then
                for _, animatedObject in pairs(placeable.animatedObjects) do
                    self:addCandidate(result, seen, animatedObject, placeable, nil)
                end
            end
        end
    end

    -- Map-embedded AnimatedMapObjects. Different maps/game versions expose
    -- these through slightly different containers, so check all known ones.
    local containers = {}
    if mission.animatedMapObjects ~= nil then table.insert(containers, mission.animatedMapObjects) end
    if mission.animatedObjects ~= nil then table.insert(containers, mission.animatedObjects) end
    if mission.onCreateObjectSystem ~= nil then
        if mission.onCreateObjectSystem.animatedObjects ~= nil then
            table.insert(containers, mission.onCreateObjectSystem.animatedObjects)
        end
        if mission.onCreateObjectSystem.objects ~= nil then
            table.insert(containers, mission.onCreateObjectSystem.objects)
        end
    end

    for _, container in ipairs(containers) do
        if container ~= nil then
            for _, object in pairs(container) do
                local animatedObject = object.animatedObject or object
                self:addCandidate(result, seen, animatedObject, object, nil)
            end
        end
    end

    debugLog("collectGates END: %d operable animated entrance(s)", #result)
    return result
end

function OpenTheGate:canOperate(animatedObject)
    if animatedObject.getCanBeTriggered ~= nil then
        local ok, value = pcall(animatedObject.getCanBeTriggered, animatedObject)
        if ok and value == false then
            return false
        end
    end
    return true
end

function OpenTheGate:dumpGateInterface(animatedObject)
    if animatedObject == nil or not OpenTheGateUtil.isDebugEnabled("GATES") then return end

    local keys = {}
    for key, value in pairs(animatedObject) do
        if type(value) == "function" or key == "animation" or key == "controls" or key == "activatable" or key == "isServer" or key == "isClient" then
            table.insert(keys, string.format("%s=%s", tostring(key), type(value)))
        end
    end
    table.sort(keys)
    debugLog("Gate interface: %s", table.concat(keys, ", "))

    local animation = animatedObject.animation
    if animation ~= nil then
        debugLog("Gate state: time=%s direction=%s duration=%s timeSend=%s isMoving=%s isServer=%s isClient=%s dirtyFlag=%s",
            tostring(animation.time), tostring(animation.direction), tostring(animation.duration), tostring(animation.timeSend),
            tostring(animatedObject.isMoving), tostring(animatedObject.isServer), tostring(animatedObject.isClient), tostring(animatedObject.animatedObjectDirtyFlag))
    end

    local controls = animatedObject.controls
    if controls ~= nil then
        debugLog("Gate controls: posAction=%s negAction=%s posEvent=%s negEvent=%s triggerNode=%s",
            tostring(controls.posAction), tostring(controls.negAction), tostring(controls.posActionEventId),
            tostring(controls.negActionEventId), tostring(animatedObject.triggerNode or controls.triggerNode))
    end

    local activatable = animatedObject.activatable
    if activatable ~= nil then
        debugLog("Gate activatable: object=%s classMethods toggle=%s continuous=%s getIsActivatable=%s run=%s",
            tostring(activatable), tostring(activatable.onAnimationInputToggle),
            tostring(activatable.onAnimationInputContinuous), tostring(activatable.getIsActivatable), tostring(activatable.run))
    end
end

function OpenTheGate:toggle(animatedObject)
    debugLog("toggle BEGIN object=%s", tostring(animatedObject))
    if animatedObject == nil then
        debugLog("toggle FAILED: object=nil")
        return false
    end

    self:dumpGateInterface(animatedObject)

    if not self:canOperate(animatedObject) then
        debugLog("toggle FAILED: getCanBeTriggered returned false")
        return false
    end

    -- FS25 AnimatedObject:setDirection(0) is the engine's toggle command.
    -- It chooses the correct opening/closing direction itself, raises the
    -- object active, and sends the normal AnimatedObject network event.
    if animatedObject.setDirection ~= nil then
        local animation = animatedObject.animation
        local beforeTime = animation ~= nil and animation.time or nil
        local beforeDirection = animation ~= nil and animation.direction or nil
        debugLog("toggle calling setDirection(0): before time=%s direction=%s isServer=%s isClient=%s",
            tostring(beforeTime), tostring(beforeDirection), tostring(animatedObject.isServer), tostring(animatedObject.isClient))

        local ok, result = pcall(animatedObject.setDirection, animatedObject, 0)
        local afterTime = animation ~= nil and animation.time or nil
        local afterDirection = animation ~= nil and animation.direction or nil
        debugLog("toggle setDirection(0) returned: ok=%s result=%s after time=%s direction=%s isMoving=%s",
            boolText(ok), tostring(result), tostring(afterTime), tostring(afterDirection), tostring(animatedObject.isMoving))

        if ok then
            debugLog("toggle SUCCESS via native AnimatedObject:setDirection(0)")
            return true
        end

        debugLog("toggle native setDirection(0) ERROR: %s", tostring(result))
    else
        debugLog("toggle: animatedObject.setDirection is nil")
    end

    -- Fallback for unusual custom animated objects which only expose the
    -- normal player activatable callback.
    local activatable = animatedObject.activatable
    if activatable ~= nil and activatable.onAnimationInputToggle ~= nil then
        local animation = animatedObject.animation
        local beforeTime = animation ~= nil and animation.time or nil
        local beforeDirection = animation ~= nil and animation.direction or nil
        local ok, result = pcall(activatable.onAnimationInputToggle, activatable)
        debugLog("toggle activatable fallback: ok=%s result=%s before time=%s dir=%s after time=%s dir=%s",
            boolText(ok), tostring(result), tostring(beforeTime), tostring(beforeDirection),
            tostring(animation ~= nil and animation.time or nil), tostring(animation ~= nil and animation.direction or nil))
        if ok then
            debugLog("toggle SUCCESS via activatable.onAnimationInputToggle fallback")
            return true
        end
    end

    debugLog("toggle FAILED: no usable native gate toggle method")
    return false
end

