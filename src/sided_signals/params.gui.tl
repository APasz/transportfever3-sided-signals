local core = ug_require(
    "apasz_sided_signals::/sided_signals/core.lua"
) as SidedSignals.Core

local record SideOffsetCapture
    sideKey: string
    originalSideIndex: integer
    hasNativeSide: boolean
end

local record SignalCapture
    modeKey: string
    originalModeIndex: integer
    signalIndex: integer
    waypointIndex: integer
    originalIsSignal: boolean
end

local type ConstructionParams = {string: number}
local type CheckEnabledResult = ConstructionMenuParam.CheckEnabledResult

local function formatMetres(_capturedParams: table, value: number): string
    return core.formatMetres(value)
end

local function formatDegrees(_capturedParams: table, value: number): string
    return core.formatDegrees(value)
end

local function advancedAdjustmentsVisible(
    _capturedParams: table,
    params: ConstructionParams
): CheckEnabledResult
    if params[core.ADVANCED_ADJUSTMENTS_PARAM_KEY]
        == core.TOGGLE_ON_INDEX
    then
        return "Enabled" as CheckEnabledResult
    end
    -- "Hidden" and "InputActionOnly" both omit the control from the menu, but
    -- the game drops only "Hidden" values and can consequently reset the toggle.
    return "InputActionOnly" as CheckEnabledResult
end

local function sideOffsetEnabled(
    capturedParams: SideOffsetCapture,
    params: ConstructionParams
): CheckEnabledResult
    if capturedParams.hasNativeSide then
        return "Enabled" as CheckEnabledResult
    end

    local selectedSide = params[capturedParams.sideKey] or capturedParams.originalSideIndex
    if selectedSide == capturedParams.originalSideIndex then
        return "Disabled" as CheckEnabledResult
    end
    return "Enabled" as CheckEnabledResult
end

local function signalOnly(
    capturedParams: SignalCapture,
    params: ConstructionParams
): CheckEnabledResult
    local selectedMode = params[capturedParams.modeKey] or capturedParams.originalModeIndex
    if selectedMode == capturedParams.signalIndex then
        return "Enabled" as CheckEnabledResult
    end
    if selectedMode == capturedParams.waypointIndex then
        return "Disabled" as CheckEnabledResult
    end
    if capturedParams.originalIsSignal then
        return "Enabled" as CheckEnabledResult
    end
    return "Disabled" as CheckEnabledResult
end

function data(): any
    return {
        formatMetres = formatMetres,
        formatDegrees = formatDegrees,
        advancedAdjustmentsVisible = advancedAdjustmentsVisible,
        sideOffsetEnabled = sideOffsetEnabled,
        signalOnly = signalOnly,
    }
end
