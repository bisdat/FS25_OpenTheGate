-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- FS25_OpenTheGate core class and lifecycle.

OpenTheGate = {}
local OpenTheGate_mt = Class(OpenTheGate)

local function debugLog(fmt, ...) OpenTheGateUtil.debugLog("CORE", fmt, ...) end
local boolText = OpenTheGateUtil.boolText

function OpenTheGate.new()
    local self = setmetatable({}, OpenTheGate_mt)
    self.vehicleStates = setmetatable({}, {__mode = "k"})
    self.lastServerRequest = setmetatable({}, {__mode = "k"})
    self.hornHookInstalled = false
    self.lastPolledVehicle = nil
    self.lastPolledHornState = nil
    self.lastHeartbeat = 0
    self.lastVehicleSource = nil
    return self
end

function OpenTheGate:loadMap()
    self.vehicleStates = setmetatable({}, {__mode = "k"})
    self.lastServerRequest = setmetatable({}, {__mode = "k"})
    self:installHornHook()
    self.lastPolledVehicle = nil
    self.lastPolledHornState = nil
    self.lastVehicleSource = nil
    self.lastHeartbeat = 0
    Logging.info("[FS25_OpenTheGate] Loaded build v%s: double horn = nearest gate; 2 second horn = all gates within %dm", OpenTheGateConfig.VERSION, OpenTheGateConfig.ALL_GATES_RADIUS)
    debugLog("Runtime: g_client=%s g_server=%s mission=%s", boolText(g_client ~= nil), boolText(g_server ~= nil), tostring(g_currentMission))
end

function OpenTheGate:deleteMap()
    self.vehicleStates = setmetatable({}, {__mode = "k"})
    self.lastServerRequest = setmetatable({}, {__mode = "k"})
    self.lastPolledVehicle = nil
    self.lastPolledHornState = nil
    self.lastVehicleSource = nil
    self.lastHeartbeat = 0
end
