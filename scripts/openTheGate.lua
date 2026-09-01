-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 bisdat

-- FS25_OpenTheGate entry point.
-- This loader owns module ordering; modules extend the shared OpenTheGate class.

local modDirectory = g_currentModDirectory or ""

local modules = {
    "scripts/config/OpenTheGateConfig.lua",
    "scripts/util/OpenTheGateUtil.lua",
    "scripts/core/OpenTheGate.lua",
    "scripts/input/OpenTheGateHorn.lua",
    "scripts/vehicle/OpenTheGateVehicle.lua",
    "scripts/gates/OpenTheGateGates.lua",
    "scripts/core/OpenTheGateEvent.lua",
    "scripts/core/OpenTheGateController.lua",
}

for _, relativePath in ipairs(modules) do
    source(modDirectory .. relativePath)
end

OpenTheGate.modDirectory = modDirectory
