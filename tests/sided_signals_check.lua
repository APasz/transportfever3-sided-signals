local MOD_ID = "apasz_sided_signals"
local ADVANCED_ADJUSTMENTS_PARAM_KEY = "apasz_sided_signals_advanced_adjustments"
local ADVANCED_ADJUSTMENTS_OFF_INDEX = 1
local ADVANCED_ADJUSTMENTS_ON_INDEX = 2
local SIDE_KEY = "apasz_sided_signals_side"
local SIDE_OFFSET_KEY = "apasz_sided_signals_side_offset"
local OFFSET_KEY = "apasz_sided_signals_offset"
local HEIGHT_OFFSET_KEY = "apasz_sided_signals_height_offset"
local YAW_OFFSET_KEY = "apasz_sided_signals_yaw_offset"
local PITCH_OFFSET_KEY = "apasz_sided_signals_pitch_offset"
local ROLL_OFFSET_KEY = "apasz_sided_signals_roll_offset"
local MODE_KEY = "apasz_sided_signals_mode"
local WHISTLE_KEY = "apasz_sided_signals_whistle"
local WHISTLE_ORIGINAL_INDEX = 1
local WHISTLE_OFF_INDEX = 2
local WHISTLE_ON_INDEX = 3
local HAS_INJECTED_SIDE_CAPTURE_KEY = "apasz_sided_signals_has_injected_side"
local MODEL_ALIGNMENTS_CAPTURE_KEY = "apasz_sided_signals_model_alignments"
local METADATA_KEY = "apasz_sided_signals"

local function fail(message)
	error(message, 2)
end

local function assertEqual(actual, expected, message)
	if actual ~= expected then
		fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

local function assertNear(actual, expected, message)
	if type(actual) ~= "number" or math.abs(actual - expected) > 0.000001 then
		fail((message or "numbers differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

local function assertNil(actual, message)
	if actual ~= nil then
		fail((message or "value is not nil") .. ": got " .. tostring(actual))
	end
end

local function parameter(params, key)
	for _, value in ipairs(params) do
		if value.key == key then
			return value
		end
	end
	return nil
end

local function assertAdvancedVisibility(parameterValue, message)
	assertEqual(
		parameterValue.checkEnabledScript.fileName,
		"apasz_sided_signals::/sided_signals/params.gui@advancedAdjustmentsVisible",
		message .. " visibility callback"
	)
	assertNil(next(parameterValue.checkEnabledScript.params), message .. " visibility has no competing default")
end

local function identityTransform(y, scaleY)
	return {
		1,
		0,
		0,
		0,
		0,
		scaleY or 1,
		0,
		0,
		0,
		0,
		1,
		0,
		0,
		y or 0,
		0,
		1,
	}
end

local function basisDeterminant(transform)
	return transform[1] * (transform[6] * transform[11] - transform[10] * transform[7])
		- transform[5] * (transform[2] * transform[11] - transform[10] * transform[3])
		+ transform[9] * (transform[2] * transform[7] - transform[6] * transform[3])
end

local modelBounds = {
	["::/infrastructure/signal/vanilla.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = -4, z = 0 },
			bbMax = { x = 1, y = -2, z = 2 },
		},
	},
	["yomiti1225_railway_signal::/infrastructure/signal/positive.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = 2, z = 0 },
			bbMax = { x = 1, y = 4, z = 2 },
		},
	},
	["yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.mdl"] = {
		boundingInfo = {
			bbMin = { x = -0.574051, y = 2.46455, z = -1.26703 },
			bbMax = { x = 0.633676, y = 3.4304, z = 5.09396 },
		},
		metadata = {
			[METADATA_KEY] = {
				version = 1,
				ignore = false,
			},
		},
	},
	["::/infrastructure/signal/centred.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = -1, z = 0 },
			bbMax = { x = 1, y = 1, z = 2 },
		},
	},
	["::/infrastructure/signal/author_override.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = 2, z = 0 },
			bbMax = { x = 1, y = 4, z = 2 },
		},
		metadata = {
			[METADATA_KEY] = {
				version = 1,
				lateralCorrection = {
					right = -0.25,
				},
			},
		},
	},
	["external_signal_pack::/models/ignored.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = -4, z = 0 },
			bbMax = { x = 1, y = -2, z = 2 },
		},
		metadata = {
			[METADATA_KEY] = {
				version = 1,
				ignore = true,
			},
		},
	},
	["::/infrastructure/signal/invalid_override.mdl"] = {
		boundingInfo = {
			bbMin = { x = -1, y = 2, z = 0 },
			bbMax = { x = 1, y = 4, z = 2 },
		},
		metadata = {
			[METADATA_KEY] = {
				version = 2,
				lateralCorrection = {
					right = -1,
				},
			},
		},
	},
}

_G._ = function(value)
	return value
end

local warnings = {}
_G.debugPrint = function(message)
	warnings[#warnings + 1] = message
end

local function hasWarning(fragment)
	for _, warning in ipairs(warnings) do
		if string.find(warning, fragment, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local modelsById = {}
local modelNamesById = {}
local modelGetCount = 0
local constructionsById = {}
local constructionNamesById = {}
for resourceName, model in pairs(modelBounds) do
	local modelId = #modelsById + 1
	modelsById[modelId] = model
	modelNamesById[modelId] = resourceName
end

_G.api = {
	res = {
		modelRep = {
			get = function(modelId)
				modelGetCount = modelGetCount + 1
				return modelsById[modelId]
			end,
			getAll = function()
				return modelNamesById
			end,
			find = function(modelName)
				for modelId, candidateName in pairs(modelNamesById) do
					if candidateName == modelName then
						return modelId
					end
				end
				return -1
			end,
			forEachModelWithMetadata = function(metadataKey, callback)
				for modelId, modelName in pairs(modelNamesById) do
					local metadata = modelsById[modelId].metadata
					if type(metadata) == "table" and metadata[metadataKey] ~= nil then
						callback(modelName)
					end
				end
			end,
		},
		constructionRep = {
			getAll = function()
				return constructionNamesById
			end,
			get = function(constructionId)
				return constructionsById[constructionId]
			end,
		},
	},
	type = {
		ScriptRef = {
			new = function()
				return {}
			end,
		},
	},
}

local modifiers = {}
_G.addModifier = function(kind, modifier)
	modifiers[kind] = modifier
end

_G.getCurrentModId = function()
	return MOD_ID
end

_G.ug_require = function(resourceName)
	local modulePath = resourceName:match("^apasz_sided_signals::/(.+)%.lua$")
	if modulePath == nil then
		error("unexpected module resource: " .. tostring(resourceName))
	end
	local moduleName = "content." .. modulePath:gsub("/", ".")
	return require(moduleName)
end

dofile("content/mod.script.lua")
local mod = data()
mod.runFn({}, {}, {
	[MOD_ID] = {
		[ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_ON_INDEX,
	},
}, {})

local modifyConstruction = modifiers.loadConstruction
local modifyScript = modifiers.loadScript
local postRun = mod.postRunFn
assertEqual(type(modifyConstruction), "function", "construction modifier registered")
assertEqual(type(modifyScript), "function", "script modifier registered")
assertEqual(type(postRun), "function", "post-run preparation registered")

local vanillaOneWay = {
	key = "oneWay",
	name = "One-way",
	values = { "Yes", "No" },
	defaultIndex = 2,
}
local vanilla = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_tools" } } },
	params = { vanillaOneWay },
}
modifyConstruction("infrastructure/signal/signal_path_a.con", vanilla)

assertEqual(#vanilla.params, 11, "vanilla parameters added once")
assertEqual(parameter(vanilla.params, SIDE_KEY).defaultIndex, 1, "original side is the default")
local sideOffset = parameter(vanilla.params, SIDE_OFFSET_KEY)
assertEqual(sideOffset.defaultIndex, 11, "zero lateral offset is the default")
assertEqual(#sideOffset.numbers, 51, "lateral offset has every half-metre step")
assertEqual(sideOffset.numbers[1], -5, "lateral offset minimum")
assertEqual(sideOffset.numbers[2], -4.5, "lateral offset half-metre step")
assertEqual(sideOffset.numbers[11], 0, "lateral offset zero")
assertEqual(sideOffset.numbers[51], 20, "lateral offset maximum")
assertEqual(sideOffset.values[1], "-5 m", "lateral offset includes units")
assertEqual(sideOffset.values[2], "-4.5 m", "lateral offset displays half metres")
assertEqual(sideOffset.displayMode, "Vertical", "lateral measurement has room to display")
assertEqual(
	sideOffset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatMetres",
	"lateral offset value formatter"
)
assertEqual(sideOffset.checkEnabledScript.params.hasNativeSide, false, "injected side controls lateral offset")

local offset = parameter(vanilla.params, OFFSET_KEY)
assertEqual(offset.defaultIndex, 21, "zero track offset is the default")
assertEqual(offset.numbers[1], -20, "signed offset minimum")
assertEqual(offset.numbers[21], 0, "signed offset zero")
assertEqual(offset.numbers[41], 20, "signed offset maximum")
assertEqual(offset.values[21], "0 m", "track offset includes units")
assertEqual(offset.displayMode, "Vertical", "track offset measurement has room to display")
assertEqual(
	offset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatMetres",
	"track offset value formatter"
)
local advancedAdjustments = parameter(vanilla.params, ADVANCED_ADJUSTMENTS_PARAM_KEY)
assertEqual(
	advancedAdjustments.defaultIndex,
	ADVANCED_ADJUSTMENTS_ON_INDEX,
	"global setting enables advanced controls by default"
)
assertEqual(advancedAdjustments.uiType, "CheckBox", "advanced visibility uses a checkbox")
assertEqual(advancedAdjustments.postConstructionModifiable, true, "advanced visibility can be edited later")
local heightOffset = parameter(vanilla.params, HEIGHT_OFFSET_KEY)
assertEqual(heightOffset.defaultIndex, 31, "zero height offset is the default")
assertEqual(#heightOffset.numbers, 61, "height offset has every quarter-metre step")
assertNear(heightOffset.numbers[1], -7.5, "height offset minimum")
assertNear(heightOffset.numbers[31], 0, "height offset zero")
assertNear(heightOffset.numbers[61], 7.5, "height offset maximum")
assertEqual(heightOffset.values[1], "-7.5 m", "height offset minimum includes units")
assertEqual(heightOffset.values[32], "0.25 m", "height offset includes fractional metres")
assertEqual(heightOffset.values[61], "7.5 m", "height offset maximum includes units")
assertEqual(heightOffset.displayMode, "Vertical", "height measurement has room to display")
assertEqual(
	heightOffset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatMetres",
	"height value formatter"
)
assertAdvancedVisibility(heightOffset, "height")
local yawOffset = parameter(vanilla.params, YAW_OFFSET_KEY)
assertEqual(yawOffset.defaultIndex, 31, "zero yaw is the default")
assertEqual(#yawOffset.numbers, 61, "yaw has every one-degree step")
assertEqual(yawOffset.numbers[1], -30, "yaw minimum")
assertEqual(yawOffset.numbers[31], 0, "yaw zero")
assertEqual(yawOffset.numbers[61], 30, "yaw maximum")
assertEqual(yawOffset.values[1], "-30°", "yaw minimum includes units")
assertEqual(yawOffset.values[31], "0°", "yaw zero includes units")
assertEqual(yawOffset.values[61], "30°", "yaw maximum includes units")
assertEqual(yawOffset.displayMode, "Vertical", "yaw measurement has room to display")
assertEqual(
	yawOffset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatDegrees",
	"yaw value formatter"
)
assertAdvancedVisibility(yawOffset, "yaw")
local pitchOffset = parameter(vanilla.params, PITCH_OFFSET_KEY)
assertEqual(pitchOffset.defaultIndex, 16, "zero pitch is the default")
assertEqual(#pitchOffset.numbers, 31, "pitch has every one-degree step")
assertEqual(pitchOffset.numbers[1], -15, "pitch minimum")
assertEqual(pitchOffset.numbers[16], 0, "pitch zero")
assertEqual(pitchOffset.numbers[31], 15, "pitch maximum")
assertEqual(pitchOffset.values[1], "-15°", "pitch minimum includes units")
assertEqual(pitchOffset.values[16], "0°", "pitch zero includes units")
assertEqual(pitchOffset.values[31], "15°", "pitch maximum includes units")
assertEqual(
	pitchOffset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatDegrees",
	"pitch value formatter"
)
assertAdvancedVisibility(pitchOffset, "pitch")
local rollOffset = parameter(vanilla.params, ROLL_OFFSET_KEY)
assertEqual(rollOffset.defaultIndex, 16, "zero roll is the default")
assertEqual(#rollOffset.numbers, 31, "roll has every one-degree step")
assertEqual(rollOffset.numbers[1], -15, "roll minimum")
assertEqual(rollOffset.numbers[16], 0, "roll zero")
assertEqual(rollOffset.numbers[31], 15, "roll maximum")
assertEqual(rollOffset.values[1], "-15°", "roll minimum includes units")
assertEqual(rollOffset.values[16], "0°", "roll zero includes units")
assertEqual(rollOffset.values[31], "15°", "roll maximum includes units")
assertEqual(
	rollOffset.formatValueScript.fileName,
	"apasz_sided_signals::/sided_signals/params.gui@formatDegrees",
	"roll value formatter"
)
assertAdvancedVisibility(rollOffset, "roll")
assertEqual(parameter(vanilla.params, MODE_KEY).defaultIndex, 1, "original function is the default")
local whistle = parameter(vanilla.params, WHISTLE_KEY)
assertEqual(whistle.defaultIndex, WHISTLE_ORIGINAL_INDEX, "original whistle behaviour is the default")
assertEqual(#whistle.values, 3, "whistle supports default, off, and on")
assertEqual(whistle.postConstructionModifiable, true, "whistle can be edited later")
assertEqual(vanillaOneWay.postConstructionModifiable, true, "vanilla one-way can be edited later")
assertEqual(vanillaOneWay.checkEnabledScript.params.originalIsSignal, true, "vanilla defaults to a signal")

modifyConstruction("infrastructure/signal/signal_path_a.con", vanilla)
assertEqual(#vanilla.params, 11, "construction modifier is idempotent")

mod.runFn({}, {}, {
	[MOD_ID] = {
		[ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_OFF_INDEX,
	},
}, {})
local modifyConstructionWithAdvancedHidden = modifiers.loadConstruction
local modifyScriptWithAdvancedHidden = modifiers.loadScript
local basicSignal = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {},
}
modifyConstructionWithAdvancedHidden("infrastructure/signal/basic.con", basicSignal)
assertEqual(#basicSignal.params, 11, "hidden advanced adjustments remain available to the menu")
assertEqual(parameter(basicSignal.params, SIDE_KEY) ~= nil, true, "hidden advanced settings retain side")
assertEqual(parameter(basicSignal.params, OFFSET_KEY) ~= nil, true, "hidden advanced settings retain track offset")
assertEqual(parameter(basicSignal.params, MODE_KEY) ~= nil, true, "hidden advanced settings retain function")
assertEqual(parameter(basicSignal.params, WHISTLE_KEY) ~= nil, true, "hidden advanced settings retain whistle")
assertEqual(
	parameter(basicSignal.params, ADVANCED_ADJUSTMENTS_PARAM_KEY).defaultIndex,
	ADVANCED_ADJUSTMENTS_OFF_INDEX,
	"global setting hides advanced controls by default"
)
local basicSideOffset = parameter(basicSignal.params, SIDE_OFFSET_KEY)
assertEqual(basicSideOffset.values == sideOffset.values, false, "cached labels remain construction-local")
assertEqual(basicSideOffset.numbers == sideOffset.numbers, false, "cached numbers remain construction-local")
assertAdvancedVisibility(parameter(basicSignal.params, HEIGHT_OFFSET_KEY), "hidden height")
assertAdvancedVisibility(parameter(basicSignal.params, YAW_OFFSET_KEY), "hidden yaw")
assertAdvancedVisibility(parameter(basicSignal.params, PITCH_OFFSET_KEY), "hidden pitch")
assertAdvancedVisibility(parameter(basicSignal.params, ROLL_OFFSET_KEY), "hidden roll")

local ignoredConstruction = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	metadata = {
		[METADATA_KEY] = {
			version = 1,
			ignore = true,
		},
	},
	params = {},
}
modifyConstruction("infrastructure/signal/ignored.con", ignoredConstruction)
assertEqual(#ignoredConstruction.params, 0, "construction metadata suppresses all injected controls")

local invalidIgnoreConstruction = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	metadata = {
		[METADATA_KEY] = {
			version = 1,
			ignore = "true",
		},
	},
	params = {},
}
modifyConstruction("infrastructure/signal/invalid_ignore.con", invalidIgnoreConstruction)
assertEqual(
	parameter(invalidIgnoreConstruction.params, SIDE_KEY) ~= nil,
	true,
	"non-boolean ignore metadata does not opt out"
)
assertEqual(hasWarning("ignore must be a boolean"), true, "invalid ignore metadata emits a diagnostic")

local nativeControls = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "mw_side" },
		{ key = "mw_offset" },
	},
}
modifyConstruction("railroad/bue_signale/bue_signale.con", nativeControls)
assertNil(parameter(nativeControls.params, SIDE_KEY), "native side is not duplicated")
assertNil(parameter(nativeControls.params, OFFSET_KEY), "native track offset is not duplicated")
assertEqual(
	parameter(nativeControls.params, SIDE_OFFSET_KEY).checkEnabledScript.params.hasNativeSide,
	true,
	"native side enables lateral offset"
)
assertEqual(parameter(nativeControls.params, MODE_KEY).defaultIndex, 1, "missing mode is added")
local injectedOneWay = parameter(nativeControls.params, "oneWay")
assertEqual(injectedOneWay.defaultIndex, 2, "new one-way defaults off")
assertEqual(
	injectedOneWay.checkEnabledScript.params.originalIsSignal,
	false,
	"native waypoint stays a waypoint by default"
)

local nativeSideConstructions = {}
for _, nativeSideKey in ipairs({ "joao_sa_lado", "n_seite", "pozycja" }) do
	local nativeSideConstruction = {
		edgeObject = { snapToTrack = true },
		menuCategory = { categories = { { category = "rail_signals" } } },
		params = {
			{ key = nativeSideKey },
		},
	}
	modifyConstruction("infrastructure/signal/native_side.con", nativeSideConstruction)
	assertNil(parameter(nativeSideConstruction.params, SIDE_KEY), "native side is not duplicated: " .. nativeSideKey)
	assertEqual(
		parameter(nativeSideConstruction.params, SIDE_OFFSET_KEY).checkEnabledScript.params.hasNativeSide,
		true,
		"native side enables lateral offset: " .. nativeSideKey
	)
	nativeSideConstructions[nativeSideKey] = nativeSideConstruction
end
local portugueseNativeSide = nativeSideConstructions.joao_sa_lado

local fullyParameterized = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "mw_trackpos" },
		{ key = "mw_offset_x" },
		{ key = "mw_offset_z" },
		{ key = "mw_rotation_z" },
		{ key = "mw_rotation_y" },
		{ key = "mw_rotation_x" },
		{ key = "mw_waypoint" },
		{ key = "mw_whistle" },
		{ key = "mw_oneway" },
	},
}
modifyConstruction("infrastructure/signal/custom.con", fullyParameterized)
assertEqual(#fullyParameterized.params, 10, "only lateral offset is added to a fully parameterized signal")
assertEqual(
	parameter(fullyParameterized.params, SIDE_OFFSET_KEY).numbers[51],
	20,
	"lateral offset added to native controls"
)
assertNil(parameter(fullyParameterized.params, HEIGHT_OFFSET_KEY), "native height offset is not duplicated")
assertNil(parameter(fullyParameterized.params, YAW_OFFSET_KEY), "native yaw is not duplicated")
assertNil(parameter(fullyParameterized.params, PITCH_OFFSET_KEY), "native pitch is not duplicated")
assertNil(parameter(fullyParameterized.params, ROLL_OFFSET_KEY), "native roll is not duplicated")
assertNil(parameter(fullyParameterized.params, WHISTLE_KEY), "native whistle is not duplicated")
assertNil(
	parameter(fullyParameterized.params, ADVANCED_ADJUSTMENTS_PARAM_KEY),
	"advanced visibility is omitted when every advanced control is native"
)

for _, nativeWhistleKey in ipairs({ "signal_whistle", "signal_horn", "signal_sound_event" }) do
	local nativeWhistleControl = {
		edgeObject = { snapToTrack = true },
		menuCategory = { categories = { { category = "rail_signals" } } },
		params = {
			{ key = nativeWhistleKey },
		},
	}
	modifyConstruction("infrastructure/signal/native_whistle.con", nativeWhistleControl)
	assertNil(
		parameter(nativeWhistleControl.params, WHISTLE_KEY),
		"native whistle marker is not duplicated: " .. nativeWhistleKey
	)
end

local modelHeightControl = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "mast_height" },
	},
}
modifyConstruction("infrastructure/signal/model_height.con", modelHeightControl)
assertEqual(
	parameter(modelHeightControl.params, HEIGHT_OFFSET_KEY).numbers[61],
	7.5,
	"a model-height choice does not suppress the height offset"
)

local unrelatedRotationControls = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "signal_side_offset" },
		{ key = "signal_pitch_offset" },
	},
}
modifyConstruction("infrastructure/signal/axis_controls.con", unrelatedRotationControls)
assertEqual(
	parameter(unrelatedRotationControls.params, SIDE_KEY).defaultIndex,
	1,
	"a lateral-offset key is not mistaken for a side selector"
)
assertEqual(
	parameter(unrelatedRotationControls.params, OFFSET_KEY).numbers[21],
	0,
	"a lateral-offset key is not mistaken for a track offset"
)
assertEqual(
	parameter(unrelatedRotationControls.params, YAW_OFFSET_KEY).numbers[31],
	0,
	"a pitch control is not mistaken for yaw"
)
assertNil(parameter(unrelatedRotationControls.params, PITCH_OFFSET_KEY), "native pitch is not duplicated")
assertEqual(
	parameter(unrelatedRotationControls.params, ROLL_OFFSET_KEY).numbers[16],
	0,
	"a native pitch control does not suppress roll"
)

local portugueseLateralControl = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "joao_lado_distancia" },
	},
}
modifyConstruction("infrastructure/signal/portuguese_lateral.con", portugueseLateralControl)
assertEqual(
	parameter(portugueseLateralControl.params, SIDE_KEY).defaultIndex,
	1,
	"a Portuguese lateral-distance key is not mistaken for a side selector"
)

local genericRotationControl = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
	params = {
		{ key = "signal_rotation" },
	},
}
modifyConstruction("infrastructure/signal/rotation.con", genericRotationControl)
assertNil(parameter(genericRotationControl.params, YAW_OFFSET_KEY), "generic native rotation is treated as yaw")

local airportSignal = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "air_tools" } } },
	params = {},
}
modifyConstruction("airport/signal.con", airportSignal)
assertEqual(#airportSignal.params, 0, "airport edge objects are excluded")

local unrelatedRailTool = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_tools" } } },
	params = {},
}
modifyConstruction("infrastructure/track_marker.con", unrelatedRailTool)
assertEqual(#unrelatedRailTool.params, 0, "unrelated rail edge objects are excluded")

local parameterlessSignal = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_signals" } } },
}
modifyConstruction("infrastructure/signal/parameterless.con", parameterlessSignal)
assertEqual(
	parameter(parameterlessSignal.params, SIDE_KEY) ~= nil,
	true,
	"signals without a parameter table are supported"
)

local constructionWithoutParams = {
	edgeObject = { snapToTrack = false },
}
modifyConstruction("infrastructure/depot.con", constructionWithoutParams)
assertNil(constructionWithoutParams.params, "inspecting an unrelated construction does not create a params table")

local unrelatedWarningCount = #warnings
local unrelatedInvalidMetadata = {
	edgeObject = { snapToTrack = false },
	metadata = {
		[METADATA_KEY] = "invalid",
	},
}
modifyConstruction("infrastructure/depot_with_metadata.con", unrelatedInvalidMetadata)
assertEqual(#warnings, unrelatedWarningCount, "metadata is validated only for railway signals")

local function makeSignalScript(modelId, modelY, signalType, scaleY, soundevent)
	return {
		updateFn = function()
			return {
				signal = {
					type = signalType or "PATH_SIGNAL",
					soundevent = soundevent,
				},
				edgeModels = {
					{
						edgeOffset = 2,
						model = { id = modelId, transf = identityTransform(modelY or 0, scaleY) },
					},
					{
						model = { id = modelId, transf = identityTransform((modelY or 0) - 1, scaleY) },
					},
				},
			}
		end,
	}
end

local vanillaScript = modifyScript("signal_path_a.script", makeSignalScript("::/infrastructure/signal/vanilla.mdl", 0))
local positiveScript = modifyScript(
	"japanese_signal.script",
	makeSignalScript("yomiti1225_railway_signal::/infrastructure/signal/positive.mdl", 0)
)
local japaneseScript = modifyScript(
	"japanese_signal_override.script",
	makeSignalScript("yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.mdl", 0)
)
local authorOverrideScript =
	modifyScript("author_override.script", makeSignalScript("::/infrastructure/signal/author_override.mdl", 0))
local ignoredScript = modifyScript("ignored.script", makeSignalScript("external_signal_pack::/models/ignored.mdl", 0))
local reversedTransformScript =
	modifyScript("reversed_transform.script", makeSignalScript("::/infrastructure/signal/vanilla.mdl", 0, nil, -1))
local advancedHiddenByDefaultScript = modifyScriptWithAdvancedHidden(
	"advanced_hidden_by_default.script",
	makeSignalScript("::/infrastructure/signal/vanilla.mdl", 0)
)
local normalizedIdScript =
	modifyScript("normalized_id.script", makeSignalScript("::\\INFRASTRUCTURE\\SIGNAL\\VANILLA.MDL", 0))
local authoredWhistleScript = modifyScript(
	"authored_whistle.script",
	makeSignalScript("::/infrastructure/signal/vanilla.mdl", 0, nil, nil, "custom_horn")
)

local vanillaScriptRef = "::/infrastructure/signal/signal_path_a.script@updateFn"
local positiveScriptRef = "yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.script@updateFn"
vanilla.updateScript = {
	fileName = vanillaScriptRef,
	params = {
		existingCaptureValue = 17,
	},
}

local positiveConstruction = {
	edgeObject = { snapToTrack = true },
	menuCategory = { categories = { { category = "rail_tools" } } },
	params = {
		{
			key = "oneWay",
			name = "One-way",
			values = { "Yes", "No" },
			defaultIndex = 2,
		},
	},
	updateScript = {
		fileName = positiveScriptRef,
		params = {},
	},
}
modifyConstruction("infrastructure/signal/japanese_signal.con", positiveConstruction)

local siblingConstruction = {
	params = {
		{ key = SIDE_OFFSET_KEY },
	},
	updateScript = {
		fileName = vanillaScriptRef,
		params = {},
	},
}

constructionsById[1] = vanilla
constructionNamesById[1] = "::/infrastructure/signal/signal_path_a.con"
constructionsById[2] = positiveConstruction
constructionNamesById[2] = "yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.con"
constructionsById[3] = siblingConstruction
constructionNamesById[3] = "::/infrastructure/signal/signal_path_b.con"
portugueseNativeSide.updateScript = {
	fileName = vanillaScriptRef,
	params = {},
}
constructionsById[4] = portugueseNativeSide
constructionNamesById[4] = "::/infrastructure/signal/portuguese_native.con"
postRun()

local vanillaCapture = vanilla.updateScript.params
local positiveCapture = positiveConstruction.updateScript.params
local siblingCapture = siblingConstruction.updateScript.params
local portugueseNativeCapture = portugueseNativeSide.updateScript.params
assertEqual(vanillaCapture.existingCaptureValue, 17, "existing capture params are preserved")
assertEqual(vanillaCapture[HAS_INJECTED_SIDE_CAPTURE_KEY], true, "injected side ownership is captured")
assertEqual(portugueseNativeCapture[HAS_INJECTED_SIDE_CAPTURE_KEY], false, "native side ownership is captured")
assertEqual(
	siblingCapture[MODEL_ALIGNMENTS_CAPTURE_KEY],
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY],
	"constructions with identical model directories reuse prepared alignment data"
)
assertNear(
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["::/infrastructure/signal/vanilla.mdl"].centre.y,
	-3,
	"negative-Y bounds are injected"
)
assertNear(
	positiveCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["yomiti1225_railway_signal::/infrastructure/signal/positive.mdl"].centre.y,
	3,
	"positive-Y bounds are injected"
)
assertNear(
	positiveCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.mdl"].lateralCorrection.right,
	-0.895,
	"ignore-only metadata retains the built-in correction"
)
assertNear(
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["::/infrastructure/signal/author_override.mdl"].lateralCorrection.right,
	-0.25,
	"author-provided correction is captured"
)
assertEqual(
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["external_signal_pack::/models/ignored.mdl"].ignore,
	true,
	"model opt-out is captured outside the construction directory"
)
assertEqual(
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["::/infrastructure/signal/vanilla.mdl"].ignore,
	false,
	"models opt in by default"
)
assertEqual(
	vanillaCapture[MODEL_ALIGNMENTS_CAPTURE_KEY]["::/infrastructure/signal/invalid_override.mdl"].lateralCorrection.configured,
	false,
	"invalid metadata falls back safely"
)
assertEqual(hasWarning("unsupported version; expected 1"), true, "invalid metadata emits a diagnostic")
assertEqual(modelGetCount, 7, "post-run reads each relevant model once")

-- Match the restricted construction runtime proven by the game log.
_G.api.res = nil

local legacyAdvancedDisabled = advancedHiddenByDefaultScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 2,
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
	[YAW_OFFSET_KEY] = 30,
})
assertNear(legacyAdvancedDisabled.edgeModels[1].model.transf[14], 6, "core adjustments remain active")
assertNear(legacyAdvancedDisabled.edgeModels[1].model.transf[15], 0, "legacy global Off disables height")
assertNear(legacyAdvancedDisabled.edgeModels[1].model.transf[1], 1, "legacy global Off disables orientation")

local locallyEnabledAdvanced = advancedHiddenByDefaultScript.updateFn(vanillaCapture, {
	[ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_ON_INDEX,
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
	[YAW_OFFSET_KEY] = 30,
})
assertNear(locallyEnabledAdvanced.edgeModels[1].model.transf[15], 1, "local toggle enables height")
assertNear(
	locallyEnabledAdvanced.edgeModels[1].model.transf[1],
	math.cos(math.rad(30)),
	"local toggle enables orientation"
)

local locallyDisabledAdvanced = vanillaScript.updateFn(vanillaCapture, {
	[ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_OFF_INDEX,
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
	[YAW_OFFSET_KEY] = 30,
})
assertNear(locallyDisabledAdvanced.edgeModels[1].model.transf[15], 0, "local toggle disables height")
assertNear(locallyDisabledAdvanced.edgeModels[1].model.transf[1], 1, "local toggle disables orientation")

local defaultCaptureReads = 0
local defaultCapture = setmetatable({}, {
	__index = function()
		defaultCaptureReads = defaultCaptureReads + 1
		return nil
	end,
})
local unchanged = vanillaScript.updateFn(defaultCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = 0,
	[PITCH_OFFSET_KEY] = 0,
	[ROLL_OFFSET_KEY] = 0,
	[MODE_KEY] = 1,
})
assertEqual(unchanged.signal.type, "PATH_SIGNAL", "original mode preserved")
assertNear(unchanged.edgeModels[1].model.transf[14], 0, "original side preserved")
assertNear(unchanged.edgeModels[1].edgeOffset, 2, "zero offset preserved")
assertEqual(defaultCaptureReads, 0, "default settings bypass alignment processing")

local preservedWhistle = authoredWhistleScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[WHISTLE_KEY] = WHISTLE_ORIGINAL_INDEX,
})
assertEqual(preservedWhistle.signal.soundevent, "custom_horn", "default preserves the authored sound event")

local enabledWhistle = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[MODE_KEY] = 2,
	[WHISTLE_KEY] = WHISTLE_ON_INDEX,
})
assertEqual(enabledWhistle.signal.type, "PATH_SIGNAL", "whistle is independent of signal mode")
assertEqual(enabledWhistle.signal.soundevent, "horn", "whistle enables the vehicle horn event")

local disabledWhistle = authoredWhistleScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[WHISTLE_KEY] = WHISTLE_OFF_INDEX,
})
assertEqual(disabledWhistle.signal.soundevent, "", "whistle can disable an authored sound event")

local waypointWhistle = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[MODE_KEY] = 3,
	[WHISTLE_KEY] = WHISTLE_ON_INDEX,
})
assertEqual(waypointWhistle.signal.type, "WAYPOINT", "whistle is independent of waypoint mode")
assertEqual(waypointWhistle.signal.soundevent, "horn", "waypoints can trigger the vehicle horn event")

local invalidWhistle = authoredWhistleScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[WHISTLE_KEY] = 99,
})
assertEqual(invalidWhistle.signal.soundevent, "custom_horn", "invalid whistle falls back to Default")

local invalidValues = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 99,
	[SIDE_OFFSET_KEY] = math.huge,
	[OFFSET_KEY] = 0 / 0,
	[HEIGHT_OFFSET_KEY] = -math.huge,
	[YAW_OFFSET_KEY] = math.huge,
	[PITCH_OFFSET_KEY] = -math.huge,
	[ROLL_OFFSET_KEY] = 0 / 0,
	[MODE_KEY] = 99,
})
assertEqual(invalidValues.signal.type, "PATH_SIGNAL", "invalid mode falls back to Default")
assertNear(invalidValues.edgeModels[1].model.transf[14], 0, "invalid side and lateral values are ignored")
assertNear(invalidValues.edgeModels[1].model.transf[15], 0, "non-finite height is ignored")
assertNear(invalidValues.edgeModels[1].model.transf[1], 1, "non-finite yaw is ignored")
assertNear(invalidValues.edgeModels[1].model.transf[2], 0, "non-finite yaw preserves orientation")
assertNear(invalidValues.edgeModels[1].edgeOffset, 2, "non-finite track offset is ignored")

local adjusted = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 2,
	[SIDE_OFFSET_KEY] = 4,
	[OFFSET_KEY] = -7,
	[HEIGHT_OFFSET_KEY] = 1.25,
	[YAW_OFFSET_KEY] = 0,
	[PITCH_OFFSET_KEY] = 0,
	[ROLL_OFFSET_KEY] = 0,
	[MODE_KEY] = 3,
})
assertEqual(adjusted.signal.type, "WAYPOINT", "waypoint override applied")
assertNear(adjusted.edgeModels[1].model.transf[6], 1, "side change preserves model handedness")
assertNear(adjusted.edgeModels[1].model.transf[14], 10, "model centre moves to the left lateral offset")
assertNear(adjusted.edgeModels[2].model.transf[6], 1, "all models preserve their orientation")
assertNear(adjusted.edgeModels[2].model.transf[14], 9, "multi-model spacing is preserved")
assertNear(adjusted.edgeModels[1].edgeOffset, 9, "negative track offset moves in the flipped direction")
assertNear(adjusted.edgeModels[2].edgeOffset, 7, "track offset initializes a missing edge offset")
assertNear(adjusted.edgeModels[1].model.transf[15], 1.25, "height offset moves the primary model")
assertNear(adjusted.edgeModels[2].model.transf[15], 1.25, "height offset moves every model")

local yawed = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = 30,
})
local cosine30 = math.cos(math.rad(30))
assertNear(yawed.edgeModels[1].model.transf[1], cosine30, "yaw rotates the model X axis")
assertNear(yawed.edgeModels[1].model.transf[2], 0.5, "positive yaw rotates anticlockwise")
assertNear(yawed.edgeModels[1].model.transf[5], -0.5, "yaw rotates the model Y axis")
assertNear(yawed.edgeModels[1].model.transf[6], cosine30, "yaw preserves unit scale")
assertNear(
	yawed.edgeModels[1].model.transf[1] * yawed.edgeModels[1].model.transf[6]
		- yawed.edgeModels[1].model.transf[2] * yawed.edgeModels[1].model.transf[5],
	1,
	"yaw preserves model handedness"
)
assertNear(yawed.edgeModels[1].model.transf[14], 0, "yaw preserves the primary model anchor")
assertNear(yawed.edgeModels[2].model.transf[14], -1, "yaw preserves each auxiliary model anchor")
assertNear(yawed.edgeModels[2].model.transf[2], 0.5, "yaw rotates every model")

local yawedClockwise = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = -30,
})
assertNear(yawedClockwise.edgeModels[1].model.transf[2], -0.5, "negative yaw rotates clockwise")
assertNear(yawedClockwise.edgeModels[1].model.transf[5], 0.5, "negative yaw rotates the model Y axis")

local pitchDegrees = 15
local pitchCosine = math.cos(math.rad(pitchDegrees))
local pitchSine = math.sin(math.rad(pitchDegrees))
local pitched = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[PITCH_OFFSET_KEY] = pitchDegrees,
})
assertNear(pitched.edgeModels[1].model.transf[1], pitchCosine, "pitch rotates the model X axis")
assertNear(pitched.edgeModels[1].model.transf[3], -pitchSine, "positive pitch rotates in the XZ plane")
assertNear(pitched.edgeModels[1].model.transf[9], pitchSine, "pitch rotates the model Z axis")
assertNear(pitched.edgeModels[1].model.transf[11], pitchCosine, "pitch preserves unit scale")
assertNear(pitched.edgeModels[1].model.transf[14], 0, "pitch preserves the model anchor")
assertNear(pitched.edgeModels[2].model.transf[3], -pitchSine, "pitch rotates every model")
assertNear(basisDeterminant(pitched.edgeModels[1].model.transf), 1, "pitch preserves model handedness")

local rollDegrees = 15
local rollCosine = math.cos(math.rad(rollDegrees))
local rollSine = math.sin(math.rad(rollDegrees))
local rolled = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[ROLL_OFFSET_KEY] = rollDegrees,
})
assertNear(rolled.edgeModels[1].model.transf[6], rollCosine, "roll rotates the model Y axis")
assertNear(rolled.edgeModels[1].model.transf[7], rollSine, "positive roll rotates in the YZ plane")
assertNear(rolled.edgeModels[1].model.transf[10], -rollSine, "roll rotates the model Z axis")
assertNear(rolled.edgeModels[1].model.transf[11], rollCosine, "roll preserves unit scale")
assertNear(rolled.edgeModels[1].model.transf[14], 0, "roll preserves the model anchor")
assertNear(rolled.edgeModels[2].model.transf[7], rollSine, "roll rotates every model")
assertNear(basisDeterminant(rolled.edgeModels[1].model.transf), 1, "roll preserves model handedness")

local oriented = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = 20,
	[PITCH_OFFSET_KEY] = -10,
	[ROLL_OFFSET_KEY] = 5,
})
assertNear(basisDeterminant(oriented.edgeModels[1].model.transf), 1, "combined orientation preserves handedness")
assertNear(oriented.edgeModels[1].model.transf[14], 0, "combined orientation preserves the primary anchor")
assertNear(oriented.edgeModels[2].model.transf[14], -1, "combined orientation preserves auxiliary anchors")

local ignored = ignoredScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 2,
	[SIDE_OFFSET_KEY] = 4,
	[OFFSET_KEY] = -7,
	[HEIGHT_OFFSET_KEY] = 1.25,
	[YAW_OFFSET_KEY] = 30,
	[PITCH_OFFSET_KEY] = 15,
	[ROLL_OFFSET_KEY] = 15,
	[MODE_KEY] = 3,
})
assertEqual(ignored.signal.type, "PATH_SIGNAL", "ignored model preserves its signal function")
assertNear(ignored.edgeModels[1].model.transf[14], 0, "ignored model preserves its lateral position")
assertNear(ignored.edgeModels[1].model.transf[15], 0, "ignored model preserves its height")
assertNear(ignored.edgeModels[1].model.transf[1], 1, "ignored model preserves its yaw")
assertNear(ignored.edgeModels[1].model.transf[2], 0, "ignored model preserves its orientation")
assertNear(ignored.edgeModels[1].edgeOffset, 2, "ignored model preserves its track position")

local movedRight = positiveScript.updateFn(positiveCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 2,
	[OFFSET_KEY] = 5,
	[MODE_KEY] = 2,
})
assertNear(movedRight.edgeModels[1].model.transf[6], 1, "positive-Y model retains its orientation")
assertNear(movedRight.edgeModels[1].model.transf[14], -8, "model centre moves to the right lateral offset")
assertNear(movedRight.edgeModels[1].edgeOffset, -3, "positive track offset uses the flipped direction")
assertEqual(movedRight.signal.type, "PATH_SIGNAL", "signal override applied")

local reversedRight = reversedTransformScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(reversedRight.edgeModels[1].model.transf[6], -1, "existing model reflection is preserved")
assertNear(reversedRight.edgeModels[1].model.transf[14], -6, "alignment includes the model transform")
assertNear(reversedRight.edgeModels[2].model.transf[14], -7, "transformed multi-model spacing is preserved")

local yawedReflection = reversedTransformScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = 30,
})
assertNear(yawedReflection.edgeModels[1].model.transf[1], cosine30, "yaw rotates a reflected model")
assertNear(yawedReflection.edgeModels[1].model.transf[2], 0.5, "reflected model uses consistent yaw direction")
assertNear(yawedReflection.edgeModels[1].model.transf[5], 0.5, "yaw preserves the reflected Y axis")
assertNear(yawedReflection.edgeModels[1].model.transf[6], -cosine30, "yaw preserves reflection")
assertNear(
	yawedReflection.edgeModels[1].model.transf[1] * yawedReflection.edgeModels[1].model.transf[6]
		- yawedReflection.edgeModels[1].model.transf[2] * yawedReflection.edgeModels[1].model.transf[5],
	-1,
	"yaw preserves reflected model handedness"
)

local orientedReflection = reversedTransformScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[YAW_OFFSET_KEY] = 20,
	[PITCH_OFFSET_KEY] = -10,
	[ROLL_OFFSET_KEY] = 5,
})
assertNear(
	basisDeterminant(orientedReflection.edgeModels[1].model.transf),
	-1,
	"combined orientation preserves reflected model handedness"
)
assertNear(orientedReflection.edgeModels[1].model.transf[14], 0, "reflected orientation preserves the anchor")

local unchangedJapanese = japaneseScript.updateFn(positiveCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(unchangedJapanese.edgeModels[1].model.transf[14], 0, "model correction leaves Default untouched")

local correctedJapaneseRight = japaneseScript.updateFn(positiveCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(
	correctedJapaneseRight.edgeModels[1].model.transf[14],
	-4.99995,
	"built-in correction aligns the Japanese signal on the right"
)

local correctedJapaneseWithOffset = japaneseScript.updateFn(positiveCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 2,
})
assertNear(
	correctedJapaneseWithOffset.edgeModels[1].model.transf[14],
	-6.99995,
	"user lateral offset is added after the model correction"
)

local authorCorrectedRight = authorOverrideScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(authorCorrectedRight.edgeModels[1].model.transf[14], -5.75, "author metadata controls right-side alignment")

local modelGetCountBeforeReuse = modelGetCount
local sameSide = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 2,
	[OFFSET_KEY] = 0,
	[MODE_KEY] = 1,
})
assertNear(sameSide.edgeModels[1].model.transf[6], 1, "authored side is not unnecessarily reflected")
assertNear(sameSide.edgeModels[1].model.transf[14], -2, "lateral offset moves outward on the authored side")
assertEqual(modelGetCount, modelGetCountBeforeReuse, "restricted runtime uses captured model alignment data")

local movedInward = vanillaScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = -2,
	[OFFSET_KEY] = 0,
	[MODE_KEY] = 1,
})
assertNear(movedInward.edgeModels[1].model.transf[14], 2, "negative lateral offset moves inward")

local nativeSideScript = modifyScript("native_side.script", makeSignalScript("::/infrastructure/signal/vanilla.mdl", 4))
local nativeLateralOffset = nativeSideScript.updateFn(portugueseNativeCapture, {
	[SIDE_OFFSET_KEY] = 5,
})
assertNear(nativeLateralOffset.edgeModels[1].model.transf[14], 9, "lateral offset follows a native side result")

local staleInjectedSide = nativeSideScript.updateFn(portugueseNativeCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 5,
})
assertNear(staleInjectedSide.edgeModels[1].model.transf[14], 9, "native side ignores a stale injected side value")

local nativeMultiModelScript = modifyScript("native_multi_model.script", {
	updateFn = function()
		return {
			signal = { type = "PATH_SIGNAL" },
			edgeModels = {
				{
					model = {
						id = "::/infrastructure/signal/vanilla.mdl",
						transf = identityTransform(4),
					},
				},
				{
					model = {
						id = "yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.mdl",
						transf = identityTransform(-5),
					},
				},
			},
		}
	end,
})
local nativeMultiModelOffset = nativeMultiModelScript.updateFn(portugueseNativeCapture, {
	[SIDE_OFFSET_KEY] = 2,
})
assertNear(
	nativeMultiModelOffset.edgeModels[1].model.transf[14],
	6,
	"native lateral direction follows the primary model"
)
assertNear(
	nativeMultiModelOffset.edgeModels[2].model.transf[14],
	-3,
	"native lateral offset shifts auxiliary models consistently"
)

local sharedTransformScript = modifyScript("shared_transform.script", {
	updateFn = function()
		local sharedTransform = identityTransform()
		local independentTransform = identityTransform()
		return {
			signal = { type = "PATH_SIGNAL" },
			edgeModels = {
				{
					model = {
						id = "::/infrastructure/signal/vanilla.mdl",
						transf = sharedTransform,
					},
				},
				{
					model = {
						id = "::/infrastructure/signal/vanilla.mdl",
						transf = sharedTransform,
					},
				},
				{
					model = {
						id = "::/infrastructure/signal/vanilla.mdl",
						transf = independentTransform,
					},
				},
			},
		}
	end,
})
local sharedTransformResult = sharedTransformScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 2,
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
	[YAW_OFFSET_KEY] = 30,
})
local sharedTransform = sharedTransformResult.edgeModels[1].model.transf
assertEqual(
	sharedTransformResult.edgeModels[2].model.transf,
	sharedTransform,
	"signal components retain their shared transform"
)
assertNear(sharedTransform[14], 6, "shared transform receives the lateral shift once")
assertNear(sharedTransform[15], 1, "shared transform receives the height shift once")
assertNear(sharedTransform[1], cosine30, "shared transform receives the yaw rotation once")
assertNear(sharedTransform[2], 0.5, "shared transform preserves the requested yaw")
assertNear(
	sharedTransformResult.edgeModels[3].model.transf[14],
	6,
	"independent components receive the same lateral shift"
)

local oneWayScript =
	modifyScript("one_way.script", makeSignalScript("::/infrastructure/signal/vanilla.mdl", 0, "ONE_WAY_PATH_SIGNAL"))
local remainsOneWay = oneWayScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 1,
	[SIDE_OFFSET_KEY] = 0,
	[MODE_KEY] = 2,
	[WHISTLE_KEY] = WHISTLE_ON_INDEX,
})
assertEqual(remainsOneWay.signal.type, "ONE_WAY_PATH_SIGNAL", "full override preserves native one-way type")
assertEqual(remainsOneWay.signal.soundevent, "horn", "one-way signals support the whistle event")

local missingModelScript = modifyScript("missing_model.script", makeSignalScript("missing.mdl", 0))
warnings = {}
local fallback = missingModelScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 3,
	[YAW_OFFSET_KEY] = 10,
})
assertNear(fallback.edgeModels[1].model.transf[14], 0, "missing alignment data preserves authored placement")
assertNear(
	fallback.edgeModels[1].model.transf[2],
	math.sin(math.rad(10)),
	"yaw does not depend on captured alignment data"
)
assertEqual(#warnings, 1, "missing alignment data emits one diagnostic")

local normalizedId = normalizedIdScript.updateFn(vanillaCapture, {
	[SIDE_KEY] = 2,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(normalizedId.edgeModels[1].model.transf[14], 6, "resource IDs are matched case-insensitively")

local centredScript = modifyScript("centred_signal.script", makeSignalScript("::/infrastructure/signal/centred.mdl", 0))
local centredBounds = modelBounds["::/infrastructure/signal/centred.mdl"].boundingInfo
local centredCapture = {
	[MODEL_ALIGNMENTS_CAPTURE_KEY] = {
		["::/infrastructure/signal/centred.mdl"] = {
			centre = {
				x = (centredBounds.bbMin.x + centredBounds.bbMax.x) * 0.5,
				y = (centredBounds.bbMin.y + centredBounds.bbMax.y) * 0.5,
				z = (centredBounds.bbMin.z + centredBounds.bbMax.z) * 0.5,
			},
			lateralCorrection = {
				left = 0,
				right = 0,
				configured = false,
			},
		},
	},
}
local centredRight = centredScript.updateFn(centredCapture, {
	[SIDE_KEY] = 3,
	[SIDE_OFFSET_KEY] = 0,
})
assertNear(centredRight.edgeModels[1].model.transf[14], -2.5, "known centred models use default track clearance")

local noSignalResult = { edgeModels = {} }
local noSignalScript = modifyScript("asset.script", {
	updateFn = function()
		return noSignalResult
	end,
})
assertEqual(
	noSignalScript.updateFn({}, { [SIDE_OFFSET_KEY] = 0, [HEIGHT_OFFSET_KEY] = 1 }),
	noSignalResult,
	"results without signals are untouched"
)

local multiReturnScript = modifyScript("multi_return.script", {
	updateFn = function()
		return {
			signal = { type = "PATH_SIGNAL" },
			edgeModels = {
				{
					edgeOffset = 2,
					model = {
						id = "::/infrastructure/signal/vanilla.mdl",
						transf = identityTransform(),
					},
				},
			},
		},
			nil,
			"tail"
	end,
})
local multiFirst, multiSecond, multiThird = multiReturnScript.updateFn(vanillaCapture, {
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
})
assertNear(multiFirst.edgeModels[1].model.transf[15], 1, "targeted first return is transformed")
assertNil(multiSecond, "targeted nil return is preserved")
assertEqual(multiThird, "tail", "targeted final return is preserved")

local passThrough = modifyScript("unrelated.script", {
	updateFn = function()
		return 1, nil, 3
	end,
})
local first, second, third = passThrough.updateFn({}, {})
assertEqual(first, 1, "untargeted first return preserved")
assertNil(second, "untargeted nil return preserved")
assertEqual(third, 3, "untargeted final return preserved")
local activeFirst, activeSecond, activeThird = passThrough.updateFn({}, {
	[SIDE_OFFSET_KEY] = 0,
	[HEIGHT_OFFSET_KEY] = 1,
})
assertEqual(activeFirst, 1, "targeted scalar first return preserved")
assertNil(activeSecond, "targeted scalar nil return preserved")
assertEqual(activeThird, 3, "targeted scalar final return preserved")

dofile("content/sided_signals/params.gui.lua")
local checks = data()
assertEqual(checks.formatMetres({}, 0), "0 m", "zero distance formatting")
assertEqual(checks.formatMetres({}, -7), "-7 m", "signed distance formatting")
assertEqual(checks.formatMetres({}, 0.25), "0.25 m", "fractional distance formatting")
assertEqual(checks.formatDegrees({}, 0), "0°", "zero-angle formatting")
assertEqual(checks.formatDegrees({}, -12), "-12°", "signed-angle formatting")
assertEqual(
	checks.advancedAdjustmentsVisible({}, {}),
	"InputActionOnly",
	"missing session toggle keeps advanced controls hidden"
)
assertEqual(
	checks.advancedAdjustmentsVisible({}, { [ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_ON_INDEX }),
	"Enabled",
	"session toggle shows advanced controls"
)
assertEqual(
	checks.advancedAdjustmentsVisible({}, { [ADVANCED_ADJUSTMENTS_PARAM_KEY] = ADVANCED_ADJUSTMENTS_OFF_INDEX }),
	"InputActionOnly",
	"session toggle omits advanced controls without dropping their values"
)
local sideCapture = {
	sideKey = SIDE_KEY,
	originalSideIndex = 1,
	hasNativeSide = false,
}
assertEqual(
	checks.sideOffsetEnabled(sideCapture, { [SIDE_KEY] = 1 }),
	"Disabled",
	"lateral offset disabled for default side"
)
assertEqual(
	checks.sideOffsetEnabled(sideCapture, { [SIDE_KEY] = 2 }),
	"Enabled",
	"lateral offset enabled for selected side"
)
sideCapture.hasNativeSide = true
assertEqual(checks.sideOffsetEnabled(sideCapture, {}), "Enabled", "lateral offset enabled for native side")

local signalCapture = {
	modeKey = MODE_KEY,
	originalModeIndex = 1,
	signalIndex = 2,
	waypointIndex = 3,
	originalIsSignal = true,
}
assertEqual(checks.signalOnly(signalCapture, { [MODE_KEY] = 1 }), "Enabled", "one-way enabled for original signal")
assertEqual(checks.signalOnly(signalCapture, { [MODE_KEY] = 2 }), "Enabled", "one-way enabled for signal override")
assertEqual(checks.signalOnly(signalCapture, { [MODE_KEY] = 3 }), "Disabled", "one-way disabled for waypoint")
signalCapture.originalIsSignal = false
assertEqual(checks.signalOnly(signalCapture, { [MODE_KEY] = 1 }), "Disabled", "one-way disabled for original waypoint")

print("sided_signals_check: ok")
