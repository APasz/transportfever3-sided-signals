local function hasMarker(value: string, marker: string): boolean
    return string.find(value, marker, 1, true) ~= nil
end

local function isFiniteNumber(value: any): boolean
    if type(value) ~= "number" then
        return false
    end
    local numberValue = value as number
    return numberValue == numberValue
        and numberValue ~= math.huge
        and numberValue ~= -math.huge
end

local function finiteNumberOr(value: any, fallback: number): number
    if isFiniteNumber(value) then
        return value as number
    end
    return fallback
end

local function formatMetres(value: number): string
    return string.format("%g m", value)
end

local function formatDegrees(value: number): string
    return string.format("%g°", value)
end

local function normalizeResourceName(resourceName: string): string
    local normalized = resourceName:gsub("\\", "/")
    return string.lower(normalized)
end

local function hasParam(params: {api.type.ScriptParam}, key: string): boolean
    for _, parameter in ipairs(params) do
        if parameter.key == key then
            return true
        end
    end
    return false
end

local M: SidedSignals.Core = {
    ADVANCED_ADJUSTMENTS_PARAM_KEY = "apasz_sided_signals_advanced_adjustments",
    FORCE_CONTROLS_PARAM_KEY = "apasz_sided_signals_force_controls",
    TOGGLE_OFF_INDEX = 1,
    TOGGLE_ON_INDEX = 2,
    SIDE_KEY = "apasz_sided_signals_side",
    SIDE_OFFSET_KEY = "apasz_sided_signals_side_offset",
    LONGITUDINAL_OFFSET_KEY = "apasz_sided_signals_offset",
    HEIGHT_OFFSET_KEY = "apasz_sided_signals_height_offset",
    YAW_OFFSET_KEY = "apasz_sided_signals_yaw_offset",
    PITCH_OFFSET_KEY = "apasz_sided_signals_pitch_offset",
    ROLL_OFFSET_KEY = "apasz_sided_signals_roll_offset",
    MODE_KEY = "apasz_sided_signals_mode",
    WHISTLE_KEY = "apasz_sided_signals_whistle",
    PARAM_GROUP = "apasz_sided_signals",
    PARAM_SCRIPT = "apasz_sided_signals::/sided_signals/params.gui",
    HAS_INJECTED_SIDE_CAPTURE_KEY = "apasz_sided_signals_has_injected_side",
    MODEL_ALIGNMENTS_CAPTURE_KEY = "apasz_sided_signals_model_alignments",
    METADATA_KEY = "apasz_sided_signals",
    METADATA_VERSION = 1,

    SIDE_ORIGINAL_INDEX = 1,
    SIDE_LEFT_INDEX = 2,
    SIDE_RIGHT_INDEX = 3,
    MODE_ORIGINAL_INDEX = 1,
    MODE_SIGNAL_INDEX = 2,
    MODE_WAYPOINT_INDEX = 3,
    WHISTLE_ORIGINAL_INDEX = 1,
    WHISTLE_OFF_INDEX = 2,
    WHISTLE_ON_INDEX = 3,

    hasMarker = hasMarker,
    isFiniteNumber = isFiniteNumber,
    finiteNumberOr = finiteNumberOr,
    formatMetres = formatMetres,
    formatDegrees = formatDegrees,
    normalizeResourceName = normalizeResourceName,
    hasParam = hasParam,
}

return M
