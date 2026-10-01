local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local construction = ug_require("apasz_sided_signals::/sided_signals/construction.lua")

local placement = ug_require("apasz_sided_signals::/sided_signals/placement.lua")

local alignment = ug_require("apasz_sided_signals::/sided_signals/alignment.lua")

local function advancedAdjustmentsEnabled(allModParams)
	if allModParams == nil then
		return false
	end
	local paramsByMod = allModParams
	local modParams = paramsByMod[getCurrentModId()]
	return modParams ~= nil and modParams[core.ADVANCED_ADJUSTMENTS_PARAM_KEY] == core.ADVANCED_ADJUSTMENTS_ON_INDEX
end

function data()
	return {
		runFn = function(_captureParams, _configDict, allModParams, _baseConfig)
			local includeAdvancedAdjustments = advancedAdjustmentsEnabled(allModParams)
			addModifier("loadConstruction", function(fileName, constructionData)
				return construction.modify(fileName, constructionData, includeAdvancedAdjustments)
			end)
			addModifier("loadScript", function(fileName, script)
				return placement.modifyScript(fileName, script, includeAdvancedAdjustments)
			end)
		end,
		postRunFn = alignment.prepareSignalConstructions,
	}
end
