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
local SIDE_ORIGINAL_INDEX = core.SIDE_ORIGINAL_INDEX
local SIDE_LEFT_INDEX = core.SIDE_LEFT_INDEX
local SIDE_RIGHT_INDEX = core.SIDE_RIGHT_INDEX
local MODE_ORIGINAL_INDEX = core.MODE_ORIGINAL_INDEX
local MODE_SIGNAL_INDEX = core.MODE_SIGNAL_INDEX
local MODE_WAYPOINT_INDEX = core.MODE_WAYPOINT_INDEX
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

    for _, edgeModel in ipairs(edgeModels as {SidedSignals.ResultEdgeModel}) do
        if edgeModel.model ~= nil then
            local model = edgeModel.model as SidedSignals.ResultModel
            if model.transf ~= nil then
                local transform = model.transf as {number}
                local shiftedValue = finiteNumberOr(transform[transformIndex], 0)
                    + shift
                if isFiniteNumber(shiftedValue) then
                    transform[transformIndex] = shiftedValue
                end
            end
        end
    end
end

local function applySideAndLateralOffset(
    result: SidedSignals.SignalResult,
    params: SidedSignals.ConstructionParams,
    captureParams: any
)
    local hasInjectedSide = params[SIDE_KEY] ~= nil
    local side = hasInjectedSide
        and SIDE_BY_INDEX[
            selectedIndex(
                params,
                SIDE_KEY,
                SIDE_ORIGINAL_INDEX,
                SIDE_RIGHT_INDEX
            )
        ]
        or nil
    local lateralOffset = selectedNumber(params, SIDE_OFFSET_KEY)
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
    params: SidedSignals.ConstructionParams,
    includeAdvancedAdjustments: boolean
): boolean
    local side = params[SIDE_KEY]
    if side ~= nil then
        if side ~= SIDE_ORIGINAL_INDEX then
            return true
        end
    else
        local lateralOffset = params[SIDE_OFFSET_KEY]
        if lateralOffset ~= nil and lateralOffset ~= 0 then
            return true
        end
    end

    local longitudinalOffset = params[LONGITUDINAL_OFFSET_KEY]
    if longitudinalOffset ~= nil and longitudinalOffset ~= 0 then
        return true
    end
    if includeAdvancedAdjustments then
        local heightOffset = params[HEIGHT_OFFSET_KEY]
        if heightOffset ~= nil and heightOffset ~= 0 then
            return true
        end
        local yawOffset = params[YAW_OFFSET_KEY]
        if yawOffset ~= nil and yawOffset ~= 0 then
            return true
        end
        local pitchOffset = params[PITCH_OFFSET_KEY]
        if pitchOffset ~= nil and pitchOffset ~= 0 then
            return true
        end
        local rollOffset = params[ROLL_OFFSET_KEY]
        if rollOffset ~= nil and rollOffset ~= 0 then
            return true
        end
    end
    local mode = params[MODE_KEY]
    return mode ~= nil and mode ~= MODE_ORIGINAL_INDEX
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

    for _, edgeModel in ipairs(result.edgeModels as {SidedSignals.ResultEdgeModel}) do
        if edgeModel.model ~= nil then
            local model = edgeModel.model as SidedSignals.ResultModel
            if model.transf ~= nil then
                rotateTransformOrientation(
                    model.transf as {number},
                    rollCosine,
                    rollSine,
                    pitchCosine,
                    pitchSine,
                    yawCosine,
                    yawSine
                )
            end
        end
    end
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
    includeAdvancedAdjustments: boolean
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
        if params[SIDE_OFFSET_KEY] == nil
            or not requestsAdjustment(params, includeAdvancedAdjustments)
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
