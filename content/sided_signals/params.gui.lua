local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local function formatMetres(_capturedParams, value)
	return core.formatMetres(value)
end

local function formatDegrees(_capturedParams, value)
	return core.formatDegrees(value)
end

local function sideOffsetEnabled(capturedParams, params)
	if capturedParams.hasNativeSide then
		return "Enabled"
	end

	local selectedSide = params[capturedParams.sideKey] or capturedParams.originalSideIndex
	if selectedSide == capturedParams.originalSideIndex then
		return "Disabled"
	end
	return "Enabled"
end

local function signalOnly(capturedParams, params)
	local selectedMode = params[capturedParams.modeKey] or capturedParams.originalModeIndex
	if selectedMode == capturedParams.signalIndex then
		return "Enabled"
	end
	if selectedMode == capturedParams.waypointIndex then
		return "Disabled"
	end
	if capturedParams.originalIsSignal then
		return "Enabled"
	end
	return "Disabled"
end

function data()
	return {
		formatMetres = formatMetres,
		formatDegrees = formatDegrees,
		sideOffsetEnabled = sideOffsetEnabled,
		signalOnly = signalOnly,
	}
end
