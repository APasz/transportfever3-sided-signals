local core = ug_require(
    "apasz_sided_signals::/sided_signals/core.lua"
) as SidedSignals.Core
local alignment = ug_require(
    "apasz_sided_signals::/sided_signals/alignment.lua"
) as SidedSignals.Alignment

local SIDE_KEY = core.SIDE_KEY
local SIDE_OFFSET_KEY = core.SIDE_OFFSET_KEY
local LONGITUDINAL_OFFSET_KEY = core.LONGITUDINAL_OFFSET_KEY
local HEIGHT_OFFSET_KEY = core.HEIGHT_OFFSET_KEY
local YAW_OFFSET_KEY = core.YAW_OFFSET_KEY
local PITCH_OFFSET_KEY = core.PITCH_OFFSET_KEY
local ROLL_OFFSET_KEY = core.ROLL_OFFSET_KEY
local MODE_KEY = core.MODE_KEY
local WHISTLE_KEY = core.WHISTLE_KEY
local SIDE_ORIGINAL_INDEX = core.SIDE_ORIGINAL_INDEX
local SIDE_LEFT_INDEX = core.SIDE_LEFT_INDEX
local SIDE_RIGHT_INDEX = core.SIDE_RIGHT_INDEX
local MODE_ORIGINAL_INDEX = core.MODE_ORIGINAL_INDEX
local MODE_SIGNAL_INDEX = core.MODE_SIGNAL_INDEX
local MODE_WAYPOINT_INDEX = core.MODE_WAYPOINT_INDEX
local WHISTLE_ORIGINAL_INDEX = core.WHISTLE_ORIGINAL_INDEX
local WHISTLE_OFF_INDEX = core.WHISTLE_OFF_INDEX
local WHISTLE_ON_INDEX = core.WHISTLE_ON_INDEX
local isFiniteNumber = core.isFiniteNumber
local finiteNumberOr = core.finiteNumberOr
local findCapturedAlignment = alignment.findCaptured
local warnMissingAlignment = alignment.warnMissing

local DEFAULT_SIDE_DISTANCE = 2.5
local POSITION_EPSILON = 0.001
local TRANSFORM_X_TO_X_INDEX = 1
local TRANSFORM_X_TO_Y_INDEX = 2
local TRANSFORM_X_TO_Z_INDEX = 3
local TRANSFORM_Y_TO_X_INDEX = 5
local TRANSFORM_Y_TO_Y_INDEX = 6
local TRANSFORM_Y_TO_Z_INDEX = 7
local TRANSFORM_Z_TO_X_INDEX = 9
local TRANSFORM_Z_TO_Y_INDEX = 10
local TRANSFORM_Z_TO_Z_INDEX = 11
local TRANSFORM_TRANSLATION_Y_INDEX = 14
local TRANSFORM_TRANSLATION_Z_INDEX = 15
local TRANSFORM_BASIS_INDICES: {integer} = {
    TRANSFORM_X_TO_X_INDEX,
    TRANSFORM_X_TO_Y_INDEX,
    TRANSFORM_X_TO_Z_INDEX,
    TRANSFORM_Y_TO_X_INDEX,
    TRANSFORM_Y_TO_Y_INDEX,
    TRANSFORM_Y_TO_Z_INDEX,
    TRANSFORM_Z_TO_X_INDEX,
    TRANSFORM_Z_TO_Y_INDEX,
    TRANSFORM_Z_TO_Z_INDEX,
}
local PATH_SIGNAL_TYPE = "PATH_SIGNAL"
local ONE_WAY_PATH_SIGNAL_TYPE = "ONE_WAY_PATH_SIGNAL"
local WAYPOINT_TYPE = "WAYPOINT"
local HORN_SOUND_EVENT = "horn"
local NO_SOUND_EVENT = ""

local enum SideChoice
    "Original"
    "Left"
    "Right"
end

local enum SignalMode
    "Original"
    "Signal"
    "Waypoint"
end

local enum WhistleChoice
    "Original"
    "Off"
    "On"
end

local record LoadedScript
    updateFn: function(...: any): any...
end

local SIDE_BY_INDEX: {integer: SideChoice} = {
    [SIDE_ORIGINAL_INDEX] = "Original",
    [SIDE_LEFT_INDEX] = "Left",
    [SIDE_RIGHT_INDEX] = "Right",
}

local MODE_BY_INDEX: {integer: SignalMode} = {
    [MODE_ORIGINAL_INDEX] = "Original",
    [MODE_SIGNAL_INDEX] = "Signal",
    [MODE_WAYPOINT_INDEX] = "Waypoint",
}

local WHISTLE_BY_INDEX: {integer: WhistleChoice} = {
    [WHISTLE_ORIGINAL_INDEX] = "Original",
    [WHISTLE_OFF_INDEX] = "Off",
    [WHISTLE_ON_INDEX] = "On",
}

local function selectedIndex(
    params: SidedSignals.ConstructionParams,
    key: string,
    defaultIndex: integer,
    maximumIndex: integer
): integer
    local value = params[key]
    if not isFiniteNumber(value) then
        return defaultIndex
    end

    local numericValue = value as number
    local index = math.floor(numericValue)
    if numericValue ~= index or index < 1 or index > maximumIndex then
        return defaultIndex
    end
    return index
end

local function selectedNumber(
    params: SidedSignals.ConstructionParams,
    key: string
): number
    return finiteNumberOr(params[key], 0)
end

local function hasInjectedSideParam(
    captureParams: any,
    params: SidedSignals.ConstructionParams
): boolean
    if type(captureParams) == "table" then
        local capturedValue = (captureParams as {string: any})[
            core.HAS_INJECTED_SIDE_CAPTURE_KEY
        ]
        if type(capturedValue) == "boolean" then
            return capturedValue as boolean
        end
    end
    return params[SIDE_KEY] ~= nil
end

local function transformedModelAlignment(
    edgeModel: SidedSignals.ResultEdgeModel,
    captureParams: any
): number | nil, SidedSignals.LateralCorrection | nil
    if edgeModel.model == nil then
        return nil, nil
    end
    local model = edgeModel.model as SidedSignals.ResultModel
    if model.transf == nil or model.id == nil then
        return nil, nil
    end

    local transform = model.transf as {number}
    local modelId = model.id as string
    local captured = findCapturedAlignment(captureParams, modelId)
    if captured == nil then
        warnMissingAlignment(modelId)
        return nil, nil
    end

    local knownAlignment = captured as SidedSignals.ModelAlignment
    local centre = knownAlignment.centre
    local centreY = centre.x * finiteNumberOr(
        transform[TRANSFORM_X_TO_Y_INDEX],
        0
    )
        + centre.y * finiteNumberOr(transform[TRANSFORM_Y_TO_Y_INDEX], 1)
        + centre.z * finiteNumberOr(transform[TRANSFORM_Z_TO_Y_INDEX], 0)
        + finiteNumberOr(transform[TRANSFORM_TRANSLATION_Y_INDEX], 0)
    return centreY, knownAlignment.lateralCorrection
end

local function firstModelAlignment(
    edgeModels: {SidedSignals.ResultEdgeModel} | nil,
    captureParams: any,
    preferConfiguredCorrection: boolean
): number | nil, SidedSignals.LateralCorrection | nil
    if edgeModels == nil then
        return nil, nil
    end

    local firstCentreY: number | nil = nil
    local firstCorrection: SidedSignals.LateralCorrection | nil = nil
    for _, edgeModel in ipairs(edgeModels as {SidedSignals.ResultEdgeModel}) do
        local centreY, correction = transformedModelAlignment(
            edgeModel,
            captureParams
        )
        if centreY ~= nil and correction ~= nil then
            local knownCorrection = correction as SidedSignals.LateralCorrection
            if not preferConfiguredCorrection or knownCorrection.configured then
                return centreY, knownCorrection
            end
            if firstCentreY == nil then
                firstCentreY = centreY
                firstCorrection = knownCorrection
            end
        end
    end
    return firstCentreY, firstCorrection
end

local function usesIgnoredModel(
    edgeModels: {SidedSignals.ResultEdgeModel} | nil,
    captureParams: any
): boolean
    if edgeModels == nil then
        return false
    end

    for _, edgeModel in ipairs(edgeModels as {SidedSignals.ResultEdgeModel}) do
        if edgeModel.model ~= nil then
            local model = edgeModel.model as SidedSignals.ResultModel
            if model.id ~= nil then
                local captured = findCapturedAlignment(
                    captureParams,
                    model.id as string
                )
                if captured ~= nil
                    and (captured as SidedSignals.ModelAlignment).ignore
                then
                    return true
                end
            end
        end
    end
    return false
end

local function forEachUniqueTransform(
    edgeModels: {SidedSignals.ResultEdgeModel} | nil,
    visit: function({number})
)
    if edgeModels == nil then
        return
    end

    -- Some construction scripts reuse one transform table for several model parts.
    local visited: {{number}: boolean} = {}
    for _, edgeModel in ipairs(edgeModels as {SidedSignals.ResultEdgeModel}) do
        if edgeModel.model ~= nil then
            local model = edgeModel.model as SidedSignals.ResultModel
            if model.transf ~= nil then
                local transform = model.transf as {number}
                if not visited[transform] then
                    visited[transform] = true
                    visit(transform)
                end
            end
        end
    end
end

local function shiftModels(
    edgeModels: {SidedSignals.ResultEdgeModel} | nil,
    transformIndex: integer,
    shift: number
)
    if edgeModels == nil
        or not isFiniteNumber(shift)
        or math.abs(shift) < POSITION_EPSILON
    then
        return
    end

    forEachUniqueTransform(edgeModels, function(transform: {number})
        local shiftedValue = finiteNumberOr(transform[transformIndex], 0)
            + shift
        if isFiniteNumber(shiftedValue) then
            transform[transformIndex] = shiftedValue
        end
    end)
end

local function applySideAndLateralOffset(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams,
    captureParams: any
)
    local sideIndex = selectedIndex(
        params,
        SIDE_KEY,
        SIDE_ORIGINAL_INDEX,
        SIDE_RIGHT_INDEX
    )
    local lateralOffset = selectedNumber(params, SIDE_OFFSET_KEY)
    if sideIndex == SIDE_ORIGINAL_INDEX and lateralOffset == 0 then
        return
    end

    local hasInjectedSide = hasInjectedSideParam(captureParams, params)
    local side = hasInjectedSide
        and SIDE_BY_INDEX[sideIndex]
        or nil
    if side == "Original" or (side == nil and lateralOffset == 0) then
        return
    end

    local centreY, lateralCorrection = firstModelAlignment(
        result.edgeModels,
        captureParams,
        side ~= nil
    )
    if centreY == nil or lateralCorrection == nil then
        return
    end
    local knownCentreY = centreY as number
    local knownCorrection = lateralCorrection as SidedSignals.LateralCorrection

    if side == nil then
        local nativeDirection = knownCentreY >= 0 and 1 or -1
        shiftModels(
            result.edgeModels,
            TRANSFORM_TRANSLATION_Y_INDEX,
            nativeDirection * lateralOffset
        )
        return
    end

    local requestedDirection = side == "Left" and 1 or -1
    local modelCorrection = side == "Left"
        and knownCorrection.left
        or knownCorrection.right
    local authoredDistance = math.abs(knownCentreY)
    if authoredDistance < POSITION_EPSILON then
        authoredDistance = DEFAULT_SIDE_DISTANCE
    end
    local targetCentreY = requestedDirection
        * (authoredDistance + modelCorrection + lateralOffset)
    shiftModels(
        result.edgeModels,
        TRANSFORM_TRANSLATION_Y_INDEX,
        targetCentreY - knownCentreY
    )
end

local function requestsAdjustment(
    captureParams: any,
    params: SidedSignals.ConstructionParams,
    includeAdvancedAdjustments: boolean
): boolean
    local sideIndex = selectedIndex(
        params,
        SIDE_KEY,
        SIDE_ORIGINAL_INDEX,
        SIDE_RIGHT_INDEX
    )
    local lateralOffset = selectedNumber(params, SIDE_OFFSET_KEY)
    if sideIndex ~= SIDE_ORIGINAL_INDEX or lateralOffset ~= 0 then
        if hasInjectedSideParam(captureParams, params) then
            if sideIndex ~= SIDE_ORIGINAL_INDEX then
                return true
            end
        elseif lateralOffset ~= 0 then
            return true
        end
    end

    if selectedNumber(params, LONGITUDINAL_OFFSET_KEY) ~= 0 then
        return true
    end
    if includeAdvancedAdjustments then
        if selectedNumber(params, HEIGHT_OFFSET_KEY) ~= 0 then
            return true
        end
        if selectedNumber(params, YAW_OFFSET_KEY) ~= 0 then
            return true
        end
        if selectedNumber(params, PITCH_OFFSET_KEY) ~= 0 then
            return true
        end
        if selectedNumber(params, ROLL_OFFSET_KEY) ~= 0 then
            return true
        end
    end
    if selectedIndex(
        params,
        MODE_KEY,
        MODE_ORIGINAL_INDEX,
        MODE_WAYPOINT_INDEX
    ) ~= MODE_ORIGINAL_INDEX then
        return true
    end
    return selectedIndex(
        params,
        WHISTLE_KEY,
        WHISTLE_ORIGINAL_INDEX,
        WHISTLE_ON_INDEX
    ) ~= WHISTLE_ORIGINAL_INDEX
end

local function advancedAdjustmentsEnabled(
    params: SidedSignals.ConstructionParams,
    enabledByDefault: boolean
): boolean
    local selectedAdvancedIndex = params[core.ADVANCED_ADJUSTMENTS_PARAM_KEY]
    if selectedAdvancedIndex == nil then
        -- Constructions saved before the in-menu toggle use the original
        -- global setting so existing adjustments keep their behaviour.
        return enabledByDefault
    end
    return selectedAdvancedIndex == core.TOGGLE_ON_INDEX
end

local function applyLongitudinalOffset(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams
)
    local offset = selectedNumber(params, LONGITUDINAL_OFFSET_KEY)
    if offset == 0 or result.edgeModels == nil then
        return
    end

    for _, edgeModel in ipairs(result.edgeModels as {SidedSignals.ResultEdgeModel}) do
        local adjustedOffset = finiteNumberOr(edgeModel.edgeOffset, 0) - offset
        if isFiniteNumber(adjustedOffset) then
            edgeModel.edgeOffset = adjustedOffset
        end
    end
end

local function applyHeightOffset(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams
)
    shiftModels(
        result.edgeModels,
        TRANSFORM_TRANSLATION_Z_INDEX,
        selectedNumber(params, HEIGHT_OFFSET_KEY)
    )
end

local function hasFiniteBasis(transform: {number}): boolean
    for _, index in ipairs(TRANSFORM_BASIS_INDICES) do
        if not isFiniteNumber(transform[index]) then
            return false
        end
    end
    return true
end

local function rotateComponentPair(
    transform: {number},
    firstIndex: integer,
    secondIndex: integer,
    cosine: number,
    sine: number
)
    local first = transform[firstIndex]
    local second = transform[secondIndex]
    transform[firstIndex] = cosine * first - sine * second
    transform[secondIndex] = sine * first + cosine * second
end

local function rotationComponents(degrees: number): number, number
    if degrees == 0 then
        return 1, 0
    end
    local radians = math.rad(degrees)
    return math.cos(radians), math.sin(radians)
end

local function rotateTransformOrientation(
    transform: {number},
    rollCosine: number,
    rollSine: number,
    pitchCosine: number,
    pitchSine: number,
    yawCosine: number,
    yawSine: number
)
    if not hasFiniteBasis(transform) then
        return
    end

    -- Applied Roll, Pitch, then Yaw, producing Rz * Ry * Rx without moving the anchor.
    if rollSine ~= 0 then
        rotateComponentPair(
            transform,
            TRANSFORM_X_TO_Y_INDEX,
            TRANSFORM_X_TO_Z_INDEX,
            rollCosine,
            rollSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Y_TO_Y_INDEX,
            TRANSFORM_Y_TO_Z_INDEX,
            rollCosine,
            rollSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Z_TO_Y_INDEX,
            TRANSFORM_Z_TO_Z_INDEX,
            rollCosine,
            rollSine
        )
    end
    if pitchSine ~= 0 then
        rotateComponentPair(
            transform,
            TRANSFORM_X_TO_Z_INDEX,
            TRANSFORM_X_TO_X_INDEX,
            pitchCosine,
            pitchSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Y_TO_Z_INDEX,
            TRANSFORM_Y_TO_X_INDEX,
            pitchCosine,
            pitchSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Z_TO_Z_INDEX,
            TRANSFORM_Z_TO_X_INDEX,
            pitchCosine,
            pitchSine
        )
    end
    if yawSine ~= 0 then
        rotateComponentPair(
            transform,
            TRANSFORM_X_TO_X_INDEX,
            TRANSFORM_X_TO_Y_INDEX,
            yawCosine,
            yawSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Y_TO_X_INDEX,
            TRANSFORM_Y_TO_Y_INDEX,
            yawCosine,
            yawSine
        )
        rotateComponentPair(
            transform,
            TRANSFORM_Z_TO_X_INDEX,
            TRANSFORM_Z_TO_Y_INDEX,
            yawCosine,
            yawSine
        )
    end
end

local function applyOrientationOffsets(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams
)
    local yawDegrees = selectedNumber(params, YAW_OFFSET_KEY)
    local pitchDegrees = selectedNumber(params, PITCH_OFFSET_KEY)
    local rollDegrees = selectedNumber(params, ROLL_OFFSET_KEY)
    if (yawDegrees == 0 and pitchDegrees == 0 and rollDegrees == 0)
        or result.edgeModels == nil
    then
        return
    end

    local yawCosine, yawSine = rotationComponents(yawDegrees)
    local pitchCosine, pitchSine = rotationComponents(pitchDegrees)
    local rollCosine, rollSine = rotationComponents(rollDegrees)
    if not isFiniteNumber(yawCosine)
        or not isFiniteNumber(yawSine)
        or not isFiniteNumber(pitchCosine)
        or not isFiniteNumber(pitchSine)
        or not isFiniteNumber(rollCosine)
        or not isFiniteNumber(rollSine)
    then
        return
    end

    forEachUniqueTransform(result.edgeModels, function(transform: {number})
        rotateTransformOrientation(
            transform,
            rollCosine,
            rollSine,
            pitchCosine,
            pitchSine,
            yawCosine,
            yawSine
        )
    end)
end

local function applySignalMode(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams
)
    if result.signal == nil or params[MODE_KEY] == nil then
        return
    end

    local signal = result.signal as SidedSignals.ResultSignal
    local mode = MODE_BY_INDEX[
        selectedIndex(
            params,
            MODE_KEY,
            MODE_ORIGINAL_INDEX,
            MODE_WAYPOINT_INDEX
        )
    ]
    if mode == "Waypoint" then
        signal.type = WAYPOINT_TYPE
    elseif mode == "Signal" and signal.type ~= ONE_WAY_PATH_SIGNAL_TYPE then
        signal.type = PATH_SIGNAL_TYPE
    end
end

local function applyWhistle(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams
)
    local rawSignal = result.signal
    if rawSignal == nil or params[WHISTLE_KEY] == nil then
        return
    end
    local signal = rawSignal as SidedSignals.ResultSignal

    local whistle = WHISTLE_BY_INDEX[
        selectedIndex(
            params,
            WHISTLE_KEY,
            WHISTLE_ORIGINAL_INDEX,
            WHISTLE_ON_INDEX
        )
    ]
    if whistle == "On" then
        signal.soundevent = HORN_SOUND_EVENT
    elseif whistle == "Off" then
        signal.soundevent = NO_SOUND_EVENT
    end
end

local function modifyUpdateResult(
    captureParams: any,
    params: SidedSignals.ConstructionParams,
    includeAdvancedAdjustments: boolean,
    rawResult: any,
    ...: any
): any...
    if type(rawResult) ~= "table" then
        return rawResult, ...
    end
    local result = rawResult as SidedSignals.SignalResult
    if result.signal == nil or usesIgnoredModel(result.edgeModels, captureParams) then
        return rawResult, ...
    end

    applySignalMode(result, params)
    applyWhistle(result, params)
    applyLongitudinalOffset(result, params)
    if includeAdvancedAdjustments then
        applyHeightOffset(result, params)
    end
    applySideAndLateralOffset(result, params, captureParams)
    if includeAdvancedAdjustments then
        applyOrientationOffsets(result, params)
    end
    return rawResult, ...
end

local function modifyScript(
    _fileName: string,
    script: any,
    advancedAdjustmentsEnabledByDefault: boolean
): any
    if type(script) ~= "table" then
        return script
    end

    local loadedScript = script as LoadedScript
    local originalUpdate = loadedScript.updateFn
    if type(originalUpdate) ~= "function" then
        return script
    end

    loadedScript.updateFn = function(...: any): any...
        local captureParams = select(1, ...)
        local rawParams = select(2, ...)
        if type(rawParams) ~= "table" then
            return originalUpdate(...)
        end

        local params = rawParams as SidedSignals.ConstructionParams
        local includeAdvancedAdjustments = advancedAdjustmentsEnabled(
            params,
            advancedAdjustmentsEnabledByDefault
        )
        if params[SIDE_OFFSET_KEY] == nil
            or not requestsAdjustment(
                captureParams,
                params,
                includeAdvancedAdjustments
            )
        then
            return originalUpdate(...)
        end

        return modifyUpdateResult(
            captureParams,
            params,
            includeAdvancedAdjustments,
            originalUpdate(...)
        )
    end
    return loadedScript
end

local M: SidedSignals.Placement = {
    modifyScript = modifyScript,
}

return M
