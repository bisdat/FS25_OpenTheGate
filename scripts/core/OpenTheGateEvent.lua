-- FS25_openTheGate
-- Client -> server request. The server performs the search and toggles gates.

OpenTheGateEvent = {}
local OpenTheGateEvent_mt = Class(OpenTheGateEvent, Event)
InitEventClass(OpenTheGateEvent, "OpenTheGateEvent")

local function debugLog(fmt, ...) OpenTheGateUtil.debugLog("NETWORK", fmt, ...) end

function OpenTheGateEvent.emptyNew()
    return Event.new(OpenTheGateEvent_mt)
end

function OpenTheGateEvent.new(vehicle, mode)
    local self = OpenTheGateEvent.emptyNew()
    self.vehicle = vehicle
    self.mode = mode or 1
    return self
end

function OpenTheGateEvent:writeStream(streamId, connection)
    debugLog("Event writeStream vehicle=%s mode=%s connection=%s", tostring(self.vehicle), tostring(self.mode), tostring(connection))
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUIntN(streamId, self.mode, 2)
end

function OpenTheGateEvent:readStream(streamId, connection)
    debugLog("Event readStream BEGIN connection=%s", tostring(connection))
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.mode = streamReadUIntN(streamId, 2)
    debugLog("Event readStream decoded vehicle=%s mode=%s", tostring(self.vehicle), tostring(self.mode))
    self:run(connection)
end

function OpenTheGateEvent:run(connection)
    debugLog("Event run connection=%s connectionIsServer=%s", tostring(connection), tostring(connection ~= nil and connection:getIsServer()))
    -- Requests are deliberately handled only by the server. AnimatedObject's
    -- own direction/event logic then synchronises the result to clients.
    if not connection:getIsServer() and g_openTheGate ~= nil then
        g_openTheGate:handleRequest(self.vehicle, self.mode, connection)
    end
end

function OpenTheGateEvent.sendEvent(vehicle, mode)
    debugLog("sendEvent vehicle=%s mode=%s g_server=%s g_client=%s", tostring(vehicle), tostring(mode), tostring(g_server ~= nil), tostring(g_client ~= nil))
    if vehicle == nil then
        debugLog("sendEvent ABORT vehicle=nil")
        return
    end

    if g_server ~= nil then
        if g_openTheGate ~= nil then
            g_openTheGate:handleRequest(vehicle, mode, nil)
        end
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(OpenTheGateEvent.new(vehicle, mode))
    end
end
