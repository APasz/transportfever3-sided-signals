local _tl_compat
if (tonumber((_VERSION or ""):match("[%d.]*$")) or 0) < 5.3 then
	local p, m = pcall(require, "compat53.module")
	if p then
		_tl_compat = m
	end
end
local ipairs = _tl_compat and _tl_compat.ipairs or ipairs
local math = _tl_compat and _tl_compat.math or math
local string = _tl_compat and _tl_compat.string or string
local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local metadata = ug_require("apasz_sided_signals::/sided_signals/metadata.lua")

local ONE_WAY_DISABLED_INDEX = 2
local STANDARD_ONE_WAY_KEY = "oneWay"
local ROTATION_SUFFIX = "rotation"

local function emptyExistingParams()
	return {
		hasNativeSide = false,
		hasNativeLongitudinalOffset = false,
		hasNativeHeightOffset = false,
		hasNativeYawOffset = false,
		hasNativePitchOffset = false,
		hasNativeRollOffset = false,
		hasNativeMode = false,
		hasSemanticOneWay = false,
		standardOneWay = nil,
	}
end

local NO_EXISTING_PARAMS = emptyExistingParams()

local numericValueTemplates = {}

local METRES_FORMATTER = {
	format = core.formatMetres,
	scriptFunction = "formatMetres",
}

local DEGREES_FORMATTER = {
	format = core.formatDegrees,
	scriptFunction = "formatDegrees",
}

local SIDE_OFFSET_SPEC = {
	key = core.SIDE_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_SIDE_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_SIDE_OFFSET_TOOLTIP",
	minimum = -5,
	maximum = 20,
	step = 0.5,
	formatter = METRES_FORMATTER,
}

local LONGITUDINAL_OFFSET_SPEC = {
	key = core.LONGITUDINAL_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_OFFSET_TOOLTIP",
	minimum = -20,
	maximum = 20,
	step = 1,
	formatter = METRES_FORMATTER,
}

local HEIGHT_OFFSET_SPEC = {
	key = core.HEIGHT_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_HEIGHT_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_HEIGHT_OFFSET_TOOLTIP",
	minimum = -7.5,
	maximum = 7.5,
	step = 0.25,
	formatter = METRES_FORMATTER,
}

local YAW_OFFSET_SPEC = {
	key = core.YAW_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_YAW_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_YAW_OFFSET_TOOLTIP",
	minimum = -30,
	maximum = 30,
	step = 1,
	formatter = DEGREES_FORMATTER,
}

local PITCH_OFFSET_SPEC = {
	key = core.PITCH_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_PITCH_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_PITCH_OFFSET_TOOLTIP",
	minimum = -15,
	maximum = 15,
	step = 1,
	formatter = DEGREES_FORMATTER,
}

local ROLL_OFFSET_SPEC = {
	key = core.ROLL_OFFSET_KEY,
	nameKey = "APASZ_SIDED_SIGNALS_ROLL_OFFSET",
	tooltipKey = "APASZ_SIDED_SIGNALS_ROLL_OFFSET_TOOLTIP",
	minimum = -15,
	maximum = 15,
	step = 1,
	formatter = DEGREES_FORMATTER,
}

local function normalizeKey(key)
	local normalized = string.lower(key):gsub("[^%w]", "")
	return normalized
end

local function isHeightOffsetKey(normalizedKey)
	if core.hasMarker(normalizedKey, "offsetz") or core.hasMarker(normalizedKey, "zoffset") then
		return true
	end
	if not core.hasMarker(normalizedKey, "offset") then
		return false
	end
	return core.hasMarker(normalizedKey, "height")
		or core.hasMarker(normalizedKey, "vertical")
		or core.hasMarker(normalizedKey, "elevation")
end

local function isPitchOffsetKey(normalizedKey)
	return core.hasMarker(normalizedKey, "pitch")
		or core.hasMarker(normalizedKey, "rotationy")
		or core.hasMarker(normalizedKey, "yrotation")
		or core.hasMarker(normalizedKey, "rotatey")
		or core.hasMarker(normalizedKey, "yrotate")
		or core.hasMarker(normalizedKey, "roty")
		or core.hasMarker(normalizedKey, "yrot")
end

local function isRollOffsetKey(normalizedKey)
	return core.hasMarker(normalizedKey, "roll")
		or core.hasMarker(normalizedKey, "rotationx")
		or core.hasMarker(normalizedKey, "xrotation")
		or core.hasMarker(normalizedKey, "rotatex")
		or core.hasMarker(normalizedKey, "xrotate")
		or core.hasMarker(normalizedKey, "rotx")
		or core.hasMarker(normalizedKey, "xrot")
end

local function isYawOffsetKey(normalizedKey, isPitchOffset, isRollOffset)
	if
		core.hasMarker(normalizedKey, "yaw")
		or core.hasMarker(normalizedKey, "heading")
		or core.hasMarker(normalizedKey, "rotationz")
		or core.hasMarker(normalizedKey, "zrotation")
		or core.hasMarker(normalizedKey, "rotatez")
		or core.hasMarker(normalizedKey, "zrotate")
		or core.hasMarker(normalizedKey, "rotz")
		or core.hasMarker(normalizedKey, "zrot")
	then
		return true
	end

	if isPitchOffset or isRollOffset then
		return false
	end

	return string.sub(normalizedKey, -#ROTATION_SUFFIX) == ROTATION_SUFFIX
end

local function hasSideMarker(normalizedKey)
	return core.hasMarker(normalizedKey, "side") or core.hasMarker(normalizedKey, "lado")
end

local function isLateralAdjustmentKey(normalizedKey)
	if
		core.hasMarker(normalizedKey, "lateral")
		or core.hasMarker(normalizedKey, "setback")
		or core.hasMarker(normalizedKey, "offsety")
		or core.hasMarker(normalizedKey, "yoffset")
	then
		return true
	end
	return hasSideMarker(normalizedKey)
		and (
			core.hasMarker(normalizedKey, "offset")
			or core.hasMarker(normalizedKey, "distance")
			or core.hasMarker(normalizedKey, "distancia")
		)
end

local function isSideKey(normalizedKey, isLateralAdjustment)
	if core.hasMarker(normalizedKey, "trackpos") then
		return true
	end
	return hasSideMarker(normalizedKey) and not isLateralAdjustment
end

local function inspectParams(params)
	local result = emptyExistingParams()

	for _, parameter in ipairs(params) do
		if type(parameter.key) == "string" then
			local key = parameter.key
			local normalized = normalizeKey(key)
			if key == STANDARD_ONE_WAY_KEY then
				result.standardOneWay = parameter
			end
			local isLateralAdjustment = isLateralAdjustmentKey(normalized)
			if key ~= core.SIDE_KEY and key ~= core.SIDE_OFFSET_KEY and isSideKey(normalized, isLateralAdjustment) then
				result.hasNativeSide = true
			end

			local isHeightOffset = isHeightOffsetKey(normalized)
			if key ~= core.HEIGHT_OFFSET_KEY and isHeightOffset then
				result.hasNativeHeightOffset = true
			end
			local isPitchOffset = isPitchOffsetKey(normalized)
			if key ~= core.PITCH_OFFSET_KEY and isPitchOffset then
				result.hasNativePitchOffset = true
			end
			local isRollOffset = isRollOffsetKey(normalized)
			if key ~= core.ROLL_OFFSET_KEY and isRollOffset then
				result.hasNativeRollOffset = true
			end
			local isYawOffset = isYawOffsetKey(normalized, isPitchOffset, isRollOffset)

			if key ~= core.YAW_OFFSET_KEY and isYawOffset then
				result.hasNativeYawOffset = true
			end
			local isAngularAdjustment = isYawOffset
				or isPitchOffset
				or isRollOffset
				or core.hasMarker(normalized, "rotat")
				or core.hasMarker(normalized, "angle")
			if
				key ~= core.LONGITUDINAL_OFFSET_KEY
				and key ~= core.SIDE_OFFSET_KEY
				and key ~= core.HEIGHT_OFFSET_KEY
				and key ~= core.YAW_OFFSET_KEY
				and key ~= core.PITCH_OFFSET_KEY
				and key ~= core.ROLL_OFFSET_KEY
				and core.hasMarker(normalized, "offset")
				and not isHeightOffset
				and not isLateralAdjustment
				and not isAngularAdjustment
			then
				result.hasNativeLongitudinalOffset = true
			end
			if key ~= core.MODE_KEY and core.hasMarker(normalized, "waypoint") then
				result.hasNativeMode = true
			end
			if core.hasMarker(normalized, "oneway") then
				result.hasSemanticOneWay = true
			end
		end
	end

	return result
end

local function hasMenuCategory(constructionData, category)
	local menuCategory = constructionData.menuCategory
	if menuCategory == nil or menuCategory.categories == nil then
		return false
	end
	for _, categoryWithOrder in ipairs(menuCategory.categories) do
		if categoryWithOrder.category == category then
			return true
		end
	end
	return false
end

local function isRailSignal(fileName, constructionData, existing)
	if hasMenuCategory(constructionData, "rail_signals") then
		return true
	end
	if existing.standardOneWay ~= nil or existing.hasNativeMode then
		return true
	end

	return hasMenuCategory(constructionData, "rail_tools") and core.hasMarker(string.lower(fileName), "signal")
end

local function numericValues(spec)
	local template = numericValueTemplates[spec.key]
	if template == nil then
		local generated = {
			labels = {},
			numbers = {},
		}
		local stepCount = math.floor((spec.maximum - spec.minimum) / spec.step + 0.5)

		for index = 0, stepCount do
			local value = spec.minimum + index * spec.step
			generated.labels[#generated.labels + 1] = spec.formatter.format(value)
			generated.numbers[#generated.numbers + 1] = value
		end
		numericValueTemplates[spec.key] = generated
		template = generated
	end

	local labels = {}
	local numbers = {}
	local knownTemplate = template
	for index, label in ipairs(knownTemplate.labels) do
		labels[index] = label
		numbers[index] = knownTemplate.numbers[index]
	end
	return labels, numbers
end

local function numericValueIndex(spec, value)
	return math.floor((value - spec.minimum) / spec.step + 0.5) + 1
end

local function appendSideParam(params)
	params[#params + 1] = {
		key = core.SIDE_KEY,
		name = _("APASZ_SIDED_SIGNALS_SIDE"),
		tooltip = _("APASZ_SIDED_SIGNALS_SIDE_TOOLTIP"),
		values = {
			_("APASZ_SIDED_SIGNALS_ORIGINAL"),
			_("APASZ_SIDED_SIGNALS_LEFT"),
			_("APASZ_SIDED_SIGNALS_RIGHT"),
		},
		uiType = "Button",
		displayMode = "Horizontal",
		group = core.PARAM_GROUP,
		defaultIndex = core.SIDE_ORIGINAL_INDEX,
		postConstructionModifiable = true,
		yearFrom = 0,
		yearTo = 0,
	}
end

local function appendNumericParam(params, spec)
	local labels, numbers = numericValues(spec)
	local parameter = {
		key = spec.key,
		name = _(spec.nameKey),
		tooltip = _(spec.tooltipKey),
		values = labels,
		numbers = numbers,
		uiType = "Slider",
		displayMode = "Vertical",
		group = core.PARAM_GROUP,
		defaultIndex = numericValueIndex(spec, 0),
		postConstructionModifiable = true,
		yearFrom = 0,
		yearTo = 0,
		formatValueScript = {
			fileName = core.PARAM_SCRIPT .. "@" .. spec.formatter.scriptFunction,
			params = {},
		},
	}
	params[#params + 1] = parameter
	return parameter
end

local function appendSideOffsetParam(params, hasNativeSide)
	local parameter = appendNumericParam(params, SIDE_OFFSET_SPEC)
	parameter.checkEnabledScript = {
		fileName = core.PARAM_SCRIPT .. "@sideOffsetEnabled",
		params = {
			sideKey = core.SIDE_KEY,
			originalSideIndex = core.SIDE_ORIGINAL_INDEX,
			hasNativeSide = hasNativeSide,
		},
	}
end

local function appendModeParam(params)
	params[#params + 1] = {
		key = core.MODE_KEY,
		name = _("APASZ_SIDED_SIGNALS_MODE"),
		tooltip = _("APASZ_SIDED_SIGNALS_MODE_TOOLTIP"),
		values = {
			_("APASZ_SIDED_SIGNALS_ORIGINAL"),
			_("APASZ_SIDED_SIGNALS_SIGNAL"),
			_("APASZ_SIDED_SIGNALS_WAYPOINT"),
		},
		uiType = "Button",
		displayMode = "Horizontal",
		group = core.PARAM_GROUP,
		defaultIndex = core.MODE_ORIGINAL_INDEX,
		postConstructionModifiable = true,
		yearFrom = 0,
		yearTo = 0,
	}
end

local function signalOnlyCheck(originalIsSignal)
	return {
		fileName = core.PARAM_SCRIPT .. "@signalOnly",
		params = {
			modeKey = core.MODE_KEY,
			originalModeIndex = core.MODE_ORIGINAL_INDEX,
			signalIndex = core.MODE_SIGNAL_INDEX,
			waypointIndex = core.MODE_WAYPOINT_INDEX,
			originalIsSignal = originalIsSignal,
		},
	}
end

local function appendOneWayParam(params, originalIsSignal)
	params[#params + 1] = {
		key = STANDARD_ONE_WAY_KEY,
		name = _("APASZ_SIDED_SIGNALS_ONE_WAY"),
		tooltip = _("APASZ_SIDED_SIGNALS_ONE_WAY_TOOLTIP"),
		values = { _("APASZ_SIDED_SIGNALS_YES"), _("APASZ_SIDED_SIGNALS_NO") },
		uiType = "Button",
		displayMode = "Horizontal",
		group = core.PARAM_GROUP,
		defaultIndex = ONE_WAY_DISABLED_INDEX,
		postConstructionModifiable = true,
		yearFrom = 0,
		yearTo = 0,
		checkEnabledScript = signalOnlyCheck(originalIsSignal),
	}
end

local function configureOneWayParam(params, existing)
	local oneWayParam = existing.standardOneWay
	local originalIsSignal = oneWayParam ~= nil
	if oneWayParam ~= nil then
		local knownOneWayParam = oneWayParam
		knownOneWayParam.postConstructionModifiable = true
		if knownOneWayParam.checkEnabledScript == nil or knownOneWayParam.checkEnabledScript.fileName == "" then
			knownOneWayParam.checkEnabledScript = signalOnlyCheck(originalIsSignal)
		end
	elseif not existing.hasSemanticOneWay then
		appendOneWayParam(params, originalIsSignal)
	end
end

local function modify(fileName, constructionData, includeAdvancedAdjustments)
	if constructionData.edgeObject == nil or constructionData.edgeObject.snapToTrack ~= true then
		return constructionData
	end

	local params = constructionData.params
	local existing = NO_EXISTING_PARAMS
	if params ~= nil then
		existing = inspectParams(params)
	end
	if not isRailSignal(fileName, constructionData, existing) then
		return constructionData
	end
	if metadata.read(constructionData.metadata, fileName).ignore then
		return constructionData
	end

	if params == nil then
		params = {}
	end
	local signalParams = params
	constructionData.params = signalParams

	if not core.hasParam(signalParams, core.SIDE_KEY) and not existing.hasNativeSide then
		appendSideParam(signalParams)
	end
	if not core.hasParam(signalParams, core.SIDE_OFFSET_KEY) then
		appendSideOffsetParam(signalParams, existing.hasNativeSide)
	end
	if not core.hasParam(signalParams, core.LONGITUDINAL_OFFSET_KEY) and not existing.hasNativeLongitudinalOffset then
		appendNumericParam(signalParams, LONGITUDINAL_OFFSET_SPEC)
	end

	if includeAdvancedAdjustments then
		if not core.hasParam(signalParams, core.HEIGHT_OFFSET_KEY) and not existing.hasNativeHeightOffset then
			appendNumericParam(signalParams, HEIGHT_OFFSET_SPEC)
		end
		if not core.hasParam(signalParams, core.YAW_OFFSET_KEY) and not existing.hasNativeYawOffset then
			appendNumericParam(signalParams, YAW_OFFSET_SPEC)
		end
		if not core.hasParam(signalParams, core.PITCH_OFFSET_KEY) and not existing.hasNativePitchOffset then
			appendNumericParam(signalParams, PITCH_OFFSET_SPEC)
		end
		if not core.hasParam(signalParams, core.ROLL_OFFSET_KEY) and not existing.hasNativeRollOffset then
			appendNumericParam(signalParams, ROLL_OFFSET_SPEC)
		end
	end

	local hasModMode = core.hasParam(signalParams, core.MODE_KEY)
	if not hasModMode and not existing.hasNativeMode then
		appendModeParam(signalParams)
		hasModMode = true
	end
	if hasModMode and not existing.hasNativeMode then
		configureOneWayParam(signalParams, existing)
	end

	return constructionData
end

local M = {
	modify = modify,
}

return M
