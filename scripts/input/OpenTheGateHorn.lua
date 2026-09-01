-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- Horn gesture detection and local controlled-vehicle polling.

local function debugLog(fmt, ...) OpenTheGateUtil.debugLog("HORN", fmt, ...) end
local boolText = OpenTheGateUtil.boolText
local vehicleText = OpenTheGateUtil.vehicleText
local getTimeMs = OpenTheGateUtil.getTimeMs

function OpenTheGate:installHornHook()
    if self.hornHookInstalled then
        debugLog("installHornHook skipped: already installed")
        return
    end
    if Honk == nil then
        debugLog("installHornHook FAILED: Honk table is nil")
        return
    end
    if Honk.playHonk == nil then
        debugLog("installHornHook FAILED: Honk.playHonk is nil")
        return
    end

    Honk.playHonk = Utils.appendedFunction(Honk.playHonk, function(vehicle, isPlaying, noEventSend)
        debugLog("HOOK Honk.playHonk: vehicle=%s isPlaying=%s noEventSend=%s specState=%s", vehicleText(vehicle), tostring(isPlaying), tostring(noEventSend), tostring(vehicle ~= nil and vehicle.spec_honk ~= nil and vehicle.spec_honk.isPlaying))
        if g_openTheGate ~= nil then
            g_openTheGate:onHonkStateChanged(vehicle, isPlaying, "hook")
        end
    end)

    self.hornHookInstalled = true
    debugLog("Horn hook installed successfully on Honk.playHonk")
end

function OpenTheGate:getState(vehicle)
    local state = self.vehicleStates[vehicle]
    if state == nil then
        state = {
            pressed = false,
            pressStarted = 0,
            previousTapReleased = nil,
            longTriggered = false
        }
        self.vehicleStates[vehicle] = state
    end
    return state
end

function OpenTheGate:getLocalVehicle()
    -- FS25 does not reliably maintain g_currentMission.controlledVehicle.
    -- The supported access path used by the base game is g_localPlayer:getCurrentVehicle().
    if g_localPlayer ~= nil and g_localPlayer.getCurrentVehicle ~= nil then
        local ok, vehicle = pcall(g_localPlayer.getCurrentVehicle, g_localPlayer)
        if ok and vehicle ~= nil then
            return vehicle, "g_localPlayer:getCurrentVehicle"
        end
    end

    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.getCurrentVehicle ~= nil then
        local ok, vehicle = pcall(g_currentMission.player.getCurrentVehicle, g_currentMission.player)
        if ok and vehicle ~= nil then
            return vehicle, "g_currentMission.player:getCurrentVehicle"
        end
    end

    if g_currentMission ~= nil and g_currentMission.controlledVehicle ~= nil then
        return g_currentMission.controlledVehicle, "g_currentMission.controlledVehicle"
    end

    return nil, "none"
end

function OpenTheGate:isLocallyControlledVehicle(vehicle)
    if vehicle == nil then
        debugLog("Local-control check failed: vehicle=nil")
        return false
    end
    if vehicle.spec_honk == nil then
        debugLog("Local-control check failed for %s: spec_honk=nil", vehicleText(vehicle))
        return false
    end
    if not vehicle.isClient then
        debugLog("Local-control check failed for %s: vehicle.isClient=%s", vehicleText(vehicle), tostring(vehicle.isClient))
        return false
    end

    -- Only the controlling player's client interprets the gesture. Remote
    -- HonkEvents must not cause every client to submit the same gate request.
    local activeIgnore = nil
    local active = nil
    if vehicle.getIsActiveForInputIgnoreSelection ~= nil then
        activeIgnore = vehicle:getIsActiveForInputIgnoreSelection()
    end
    if vehicle.getIsActiveForInput ~= nil then
        active = vehicle:getIsActiveForInput()
    end
    local localVehicle, source = self:getLocalVehicle()
    local isControlled = vehicle == localVehicle
    local result = activeIgnore == true or active == true or isControlled
    debugLog("Local-control check %s: ignoreSelection=%s active=%s localVehicle=%s source=%s => %s", vehicleText(vehicle), tostring(activeIgnore), tostring(active), boolText(isControlled), tostring(source), boolText(result))
    return result
end

function OpenTheGate:onHonkStateChanged(vehicle, isPlaying, source)
    debugLog("Horn state callback source=%s vehicle=%s requestedState=%s", tostring(source), vehicleText(vehicle), tostring(isPlaying))
    if type(isPlaying) ~= "boolean" then
        debugLog("Horn callback ignored: isPlaying is not boolean (%s)", type(isPlaying))
        return
    end
    if not self:isLocallyControlledVehicle(vehicle) then
        debugLog("Horn callback ignored: vehicle is not locally controlled")
        return
    end

    local state = self:getState(vehicle)
    local now = getTimeMs()

    if isPlaying and not state.pressed then
        state.pressed = true
        state.pressStarted = now
        state.longTriggered = false
        debugLog("PRESS started: vehicle=%s time=%d", vehicleText(vehicle), now)
    elseif not isPlaying and state.pressed then
        local duration = now - state.pressStarted
        state.pressed = false
        debugLog("PRESS released: vehicle=%s duration=%dms longTriggered=%s previousRelease=%s", vehicleText(vehicle), duration, boolText(state.longTriggered), tostring(state.previousTapReleased))

        if not state.longTriggered and duration < OpenTheGateConfig.LONG_PRESS_MS then
            if state.previousTapReleased ~= nil and now - state.previousTapReleased <= OpenTheGateConfig.DOUBLE_TAP_WINDOW_MS then
                local gap = now - state.previousTapReleased
                state.previousTapReleased = nil
                debugLog("DOUBLE TAP detected: gap=%dms; sending nearest request", gap)
                OpenTheGateEvent.sendEvent(vehicle, OpenTheGateConfig.MODE_NEAREST)
            else
                state.previousTapReleased = now
                debugLog("First short tap stored at %d; waiting %dms for second tap", now, OpenTheGateConfig.DOUBLE_TAP_WINDOW_MS)
            end
        else
            state.previousTapReleased = nil
        end
    end
end


function OpenTheGate:update(dt)
    local now = getTimeMs()

    -- Poll the controlled vehicle as a fallback. This also tells us whether the
    -- hook or local-control test is the point of failure.
    local controlled, vehicleSource = self:getLocalVehicle()
    if controlled ~= self.lastPolledVehicle or vehicleSource ~= self.lastVehicleSource then
        debugLog("Local vehicle changed: old=%s new=%s source=%s g_localPlayer=%s missionPlayer=%s legacyControlled=%s", vehicleText(self.lastPolledVehicle), vehicleText(controlled), tostring(vehicleSource), tostring(g_localPlayer), tostring(g_currentMission ~= nil and g_currentMission.player or nil), vehicleText(g_currentMission ~= nil and g_currentMission.controlledVehicle or nil))
        self.lastVehicleSource = vehicleSource
        self.lastPolledVehicle = controlled
        self.lastPolledHornState = nil
    end

    if controlled ~= nil then
        local spec = controlled.spec_honk
        if spec == nil then
            if now - self.lastHeartbeat > 5000 then
                debugLog("POLL: controlled vehicle %s has no spec_honk", vehicleText(controlled))
            end
        else
            local hornState = spec.isPlaying == true
            if self.lastPolledHornState == nil or hornState ~= self.lastPolledHornState then
                debugLog("POLL horn transition: vehicle=%s source=%s spec.isPlaying=%s inputPressed=%s isActive=%s sample=%s", vehicleText(controlled), tostring(vehicleSource), boolText(hornState), tostring(spec.inputPressed), tostring(spec.isActive), tostring(spec.sample))
                self.lastPolledHornState = hornState
                self:onHonkStateChanged(controlled, hornState, "poll")
            end
        end
    end

    for vehicle, state in pairs(self.vehicleStates) do
        if state.pressed and not state.longTriggered and now - state.pressStarted >= OpenTheGateConfig.LONG_PRESS_MS then
            state.longTriggered = true
            state.previousTapReleased = nil
            debugLog("LONG PRESS detected: vehicle=%s duration=%dms; sending radius request", vehicleText(vehicle), now - state.pressStarted)
            OpenTheGateEvent.sendEvent(vehicle, OpenTheGateConfig.MODE_RADIUS)
        end

        if state.previousTapReleased ~= nil and now - state.previousTapReleased > OpenTheGateConfig.DOUBLE_TAP_WINDOW_MS then
            debugLog("Double-tap window expired for %s after %dms", vehicleText(vehicle), now - state.previousTapReleased)
            state.previousTapReleased = nil
        end
    end

    if now - self.lastHeartbeat > 5000 then
        self.lastHeartbeat = now
        debugLog("Heartbeat: update running; localVehicle=%s source=%s hornHook=%s trackedVehicles=%s g_localPlayer=%s", vehicleText(controlled), tostring(vehicleSource), boolText(self.hornHookInstalled), tostring(next(self.vehicleStates) ~= nil), tostring(g_localPlayer))
    end
end


