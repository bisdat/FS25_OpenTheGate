-- FS25_openTheGate core class and configuration.

OpenTheGate = {}
local OpenTheGate_mt = Class(OpenTheGate)

OpenTheGate.MODE_NEAREST = OpenTheGateConfig.MODE_NEAREST
OpenTheGate.MODE_RADIUS = OpenTheGateConfig.MODE_RADIUS

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
    self.activeGateAnimations = setmetatable({}, {__mode = "k"})
    return self
end

function OpenTheGate:loadMap()
    self.vehicleStates = setmetatable({}, {__mode = "k"})
    self.lastServerRequest = setmetatable({}, {__mode = "k"})
    self.activeGateAnimations = setmetatable({}, {__mode = "k"})
    self:installHornHook()
    Logging.info("[FS25_openTheGate] Loaded build v%s: double horn = nearest gate; 2 second horn = all gates within %dm", OpenTheGateConfig.VERSION, OpenTheGateConfig.ALL_GATES_RADIUS)
    debugLog("Runtime: g_client=%s g_server=%s mission=%s", boolText(g_client ~= nil), boolText(g_server ~= nil), tostring(g_currentMission))
end

function OpenTheGate:deleteMap()
    self.vehicleStates = setmetatable({}, {__mode = "k"})
    self.lastServerRequest = setmetatable({}, {__mode = "k"})
    self.activeGateAnimations = setmetatable({}, {__mode = "k"})
end
