local _tl_compat
if (tonumber((_VERSION or ""):match("[%d.]*$")) or 0) < 5.3 then
	local p, m = pcall(require, "compat53.module")
	if p then
		_tl_compat = m
	end
end
local math = _tl_compat and _tl_compat.math or math
local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local construction = ug_require("apasz_sided_signals::/sided_signals/construction.lua")

local placement = ug_require("apasz_sided_signals::/sided_signals/placement.lua")

local alignment = ug_require("apasz_sided_signals::/sided_signals/alignment.lua")

local function modSelectionIndex(allModParams, optionKey, defaultIndex, optionCount)
	if optionCount < 1 or defaultIndex < 1 or defaultIndex > optionCount then
		error("Invalid mod parameter definition: " .. optionKey)
	end
	if allModParams == nil then
		return defaultIndex
	end
	local paramsByMod = allModParams
	local modParams = paramsByMod[getCurrentModId()]
	if modParams == nil or modParams[optionKey] == nil then
		return defaultIndex
	end

	local rawIndex = modParams[optionKey]
	if not core.isFiniteNumber(rawIndex) then
		error("Invalid mod parameter selection index: " .. optionKey)
	end
	local numericIndex = rawIndex
	local selectionIndex = math.floor(numericIndex)
	if numericIndex ~= selectionIndex or selectionIndex < 1 or selectionIndex > optionCount then
		error("Invalid mod parameter selection index: " .. optionKey)
	end
	return selectionIndex
end

local function modOptionEnabled(allModParams, optionKey)
	return modSelectionIndex(allModParams, optionKey, core.TOGGLE_OFF_INDEX, core.TOGGLE_ON_INDEX)
		== core.TOGGLE_ON_INDEX
end

local function defaultTrackOffset(allModParams)
	local optionCount = math.floor(
		(core.LONGITUDINAL_OFFSET_MAXIMUM - core.LONGITUDINAL_OFFSET_MINIMUM) / core.LONGITUDINAL_OFFSET_STEP + 0.5
	) + 1
	local zeroOffsetIndex = math.floor((0 - core.LONGITUDINAL_OFFSET_MINIMUM) / core.LONGITUDINAL_OFFSET_STEP + 0.5) + 1
	local selectionIndex =
		modSelectionIndex(allModParams, core.DEFAULT_TRACK_OFFSET_PARAM_KEY, zeroOffsetIndex, optionCount)

	return core.LONGITUDINAL_OFFSET_MINIMUM + (selectionIndex - 1) * core.LONGITUDINAL_OFFSET_STEP
end

function data()
	return {
		runFn = function(_captureParams, _configDict, allModParams, _baseConfig)
			local advancedAdjustmentsEnabledByDefault =
				modOptionEnabled(allModParams, core.ADVANCED_ADJUSTMENTS_PARAM_KEY)

			local showControlsForAllTrackEdgeObjects = modOptionEnabled(allModParams, core.FORCE_CONTROLS_PARAM_KEY)

			local defaultTrackOffsetValue = defaultTrackOffset(allModParams)
			addModifier("loadConstruction", function(fileName, constructionData)
				return construction.modify(
					fileName,
					constructionData,
					advancedAdjustmentsEnabledByDefault,
					showControlsForAllTrackEdgeObjects,
					defaultTrackOffsetValue
				)
			end)
			addModifier("loadScript", function(fileName, script)
				return placement.modifyScript(fileName, script, advancedAdjustmentsEnabledByDefault)
			end)
		end,
		postRunFn = alignment.prepareSignalConstructions,
	}
end
