local _tl_compat
if (tonumber((_VERSION or ""):match("[%d.]*$")) or 0) < 5.3 then
	local p, m = pcall(require, "compat53.module")
	if p then
		_tl_compat = m
	end
end
local math = _tl_compat and _tl_compat.math or math
local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local modelOverrides = ug_require("apasz_sided_signals::/sided_signals/model_overrides.lua")

local BOUNDS_MATCH_EPSILON = 0.001

local NO_LATERAL_CORRECTION = {
	left = 0,
	right = 0,
	configured = false,
}

local NO_METADATA = {
	ignore = false,
	lateralCorrection = nil,
}

local IGNORED_METADATA = {
	ignore = true,
	lateralCorrection = nil,
}

local function metadataWithoutCorrection(ignore)
	if ignore then
		return IGNORED_METADATA
	end
	return NO_METADATA
end

local function warn(resourceName, issue)
	debugPrint("[Sided Signals] Invalid " .. core.METADATA_KEY .. " metadata for " .. resourceName .. "; " .. issue)
end

local function readCorrectionValue(rawValue, fieldName, resourceName)
	if rawValue == nil then
		return 0
	end
	if type(rawValue) ~= "number" then
		warn(resourceName, "lateralCorrection." .. fieldName .. " must be a number")
		return nil
	end
	if not core.isFiniteNumber(rawValue) then
		warn(resourceName, "lateralCorrection." .. fieldName .. " must be finite")
		return nil
	end
	return rawValue
end

local function read(rawMetadata, resourceName)
	if type(rawMetadata) ~= "table" then
		return NO_METADATA
	end

	local rawConfig = (rawMetadata)[core.METADATA_KEY]
	if rawConfig == nil then
		return NO_METADATA
	end
	if type(rawConfig) ~= "table" then
		warn(resourceName, "expected a table")
		return NO_METADATA
	end

	local config = rawConfig
	if config.version ~= core.METADATA_VERSION then
		warn(resourceName, "unsupported version; expected " .. tostring(core.METADATA_VERSION))

		return NO_METADATA
	end

	local ignore = false
	if config.ignore ~= nil then
		if type(config.ignore) == "boolean" then
			ignore = config.ignore
		else
			warn(resourceName, "ignore must be a boolean")
		end
	end

	local rawCorrection = config.lateralCorrection
	if rawCorrection == nil then
		return metadataWithoutCorrection(ignore)
	end
	if type(rawCorrection) ~= "table" then
		warn(resourceName, "lateralCorrection must be a table")
		return metadataWithoutCorrection(ignore)
	end

	local correction = rawCorrection
	local left = readCorrectionValue(correction.left, "left", resourceName)
	local right = readCorrectionValue(correction.right, "right", resourceName)
	if left == nil or right == nil then
		return metadataWithoutCorrection(ignore)
	end

	return {
		ignore = ignore,
		lateralCorrection = {
			left = left,
			right = right,
			configured = true,
		},
	}
end

local function builtInLateralCorrection(modelName, normalizedModelName, bounds)
	local override = modelOverrides[normalizedModelName]
	if override == nil then
		return NO_LATERAL_CORRECTION
	end

	local knownOverride = override
	if
		math.abs(bounds.bbMin.y - knownOverride.expectedMinY) > BOUNDS_MATCH_EPSILON
		or math.abs(bounds.bbMax.y - knownOverride.expectedMaxY) > BOUNDS_MATCH_EPSILON
	then
		debugPrint(
			"[Sided Signals] Ignoring stale built-in lateral correction for "
				.. modelName
				.. "; model bounds have changed"
		)

		return NO_LATERAL_CORRECTION
	end
	return knownOverride.lateralCorrection
end

local function resolveLateralCorrection(modelName, normalizedModelName, bounds, config)
	if config.lateralCorrection ~= nil then
		return config.lateralCorrection
	end
	return builtInLateralCorrection(modelName, normalizedModelName, bounds)
end

local M = {
	read = read,
	resolveLateralCorrection = resolveLateralCorrection,
}

return M
