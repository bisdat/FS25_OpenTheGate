-- FS25_openTheGate central configuration.
-- Change only values in this file when tuning behaviour or diagnostics.

OpenTheGateConfig = {
    VERSION = "1.0.0.0",

    MODE_NEAREST = 1,
    MODE_RADIUS = 2,

    DOUBLE_TAP_WINDOW_MS = 650,
    LONG_PRESS_MS = 2000,
    NEAREST_BASE_DISTANCE = 20,
    CLOSE_GATE_DISTANCE = 6,
    NEAREST_MAX_DYNAMIC_DISTANCE = 45,
    ALL_GATES_RADIUS = 20,
    PAIRED_GATE_DISTANCE = 6,
    MOVING_DIRECTION_BONUS = 500,
    MIN_DIRECTION_DOT = 0.65,
    MAX_LATERAL_OFFSET = 12,
    REQUEST_COOLDOWN_MS = 300,

    -- No debug output is emitted unless a value below is explicitly true.
    DEBUG = false,
    DEBUG_CORE = false,
    DEBUG_HORN = false,
    DEBUG_NETWORK = false,
    DEBUG_TARGETING = false,
    DEBUG_VEHICLE = false,
    DEBUG_GATES = false,
    DEBUG_PERFORMANCE = false,
    DEBUG_VERBOSE_GATE_SCAN = false,
}
