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

local function modOptionEnabled(
    allModParams: AllModParams | nil,
    optionKey: string
): boolean
    if allModParams == nil then
        return false
    end
    local paramsByMod = allModParams as AllModParams
    local modParams = paramsByMod[getCurrentModId()]
    return modParams ~= nil
        and modParams[optionKey] == core.TOGGLE_ON_INDEX
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
            addModifier("loadConstruction", function(
                fileName: string,
                constructionData: api.type.ConstructionDesc
            ): api.type.ConstructionDesc
                return construction.modify(
                    fileName,
                    constructionData,
                    advancedAdjustmentsEnabledByDefault,
                    showControlsForAllTrackEdgeObjects
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
