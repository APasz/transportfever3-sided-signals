local core = ug_require(
    "apasz_sided_signals::/sided_signals/core.lua"
) as SidedSignals.Core
local construction = ug_require(
    "apasz_sided_signals::/sided_signals/construction.lua"
) as SidedSignals.Construction
local placement = ug_require(
    "apasz_sided_signals::/sided_signals/placement.lua"
) as SidedSignals.Placement
local alignment = ug_require(
    "apasz_sided_signals::/sided_signals/alignment.lua"
) as SidedSignals.Alignment

local type ModParams = {string: number}
local type AllModParams = {string: ModParams}
local type ConfigDict = {string: string}

local function modSelectionIndex(
    allModParams: AllModParams | nil,
    optionKey: string,
    defaultIndex: integer,
    optionCount: integer
): integer
    if optionCount < 1 or defaultIndex < 1 or defaultIndex > optionCount then
        error("Invalid mod parameter definition: " .. optionKey)
    end
    if allModParams == nil then
        return defaultIndex
    end
    local paramsByMod = allModParams as AllModParams
    local modParams = paramsByMod[getCurrentModId()]
    if modParams == nil or modParams[optionKey] == nil then
        return defaultIndex
    end

    local rawIndex = modParams[optionKey]
    if not core.isFiniteNumber(rawIndex) then
        error("Invalid mod parameter selection index: " .. optionKey)
    end
    local numericIndex = rawIndex as number
    local selectionIndex = math.floor(numericIndex)
    if numericIndex ~= selectionIndex
        or selectionIndex < 1
        or selectionIndex > optionCount
    then
        error("Invalid mod parameter selection index: " .. optionKey)
    end
    return selectionIndex
end

local function modOptionEnabled(
    allModParams: AllModParams | nil,
    optionKey: string
): boolean
    return modSelectionIndex(
        allModParams,
        optionKey,
        core.TOGGLE_OFF_INDEX,
        core.TOGGLE_ON_INDEX
    ) == core.TOGGLE_ON_INDEX
end

local function defaultTrackOffset(allModParams: AllModParams | nil): number
    local optionCount = math.floor(
        (core.LONGITUDINAL_OFFSET_MAXIMUM
            - core.LONGITUDINAL_OFFSET_MINIMUM)
            / core.LONGITUDINAL_OFFSET_STEP
        + 0.5
    ) + 1
    local zeroOffsetIndex = math.floor(
        (0 - core.LONGITUDINAL_OFFSET_MINIMUM)
            / core.LONGITUDINAL_OFFSET_STEP
        + 0.5
    ) + 1
    local selectionIndex = modSelectionIndex(
        allModParams,
        core.DEFAULT_TRACK_OFFSET_PARAM_KEY,
        zeroOffsetIndex,
        optionCount
    )
    return core.LONGITUDINAL_OFFSET_MINIMUM
        + (selectionIndex - 1) * core.LONGITUDINAL_OFFSET_STEP
end

function data(): any
    return {
        runFn = function(
            _captureParams: table,
            _configDict: ConfigDict,
            allModParams: AllModParams | nil,
            _baseConfig: BaseConfig | nil
        )
            local advancedAdjustmentsEnabledByDefault = modOptionEnabled(
                allModParams,
                core.ADVANCED_ADJUSTMENTS_PARAM_KEY
            )
            local showControlsForAllTrackEdgeObjects = modOptionEnabled(
                allModParams,
                core.FORCE_CONTROLS_PARAM_KEY
            )
            local defaultTrackOffsetValue = defaultTrackOffset(allModParams)
            addModifier("loadConstruction", function(
                fileName: string,
                constructionData: api.type.ConstructionDesc
            ): api.type.ConstructionDesc
                return construction.modify(
                    fileName,
                    constructionData,
                    advancedAdjustmentsEnabledByDefault,
                    showControlsForAllTrackEdgeObjects,
                    defaultTrackOffsetValue
                )
            end)
            addModifier("loadScript", function(
                fileName: string,
                script: any
            ): any
                return placement.modifyScript(
                    fileName,
                    script,
                    advancedAdjustmentsEnabledByDefault
                )
            end)
        end,
        postRunFn = alignment.prepareSignalConstructions,
    }
end
