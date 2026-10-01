local core = ug_require(
    "apasz_sided_signals::/sided_signals/core.lua"
) as SidedSignals.Core
local modelOverrides = ug_require(
    "apasz_sided_signals::/sided_signals/model_overrides.lua"
) as {string: SidedSignals.ModelOverride}

local BOUNDS_MATCH_EPSILON = 0.001

local NO_LATERAL_CORRECTION: SidedSignals.LateralCorrection = {
    left = 0,
    right = 0,
    configured = false,
}

local NO_METADATA: SidedSignals.MetadataConfig = {
    ignore = false,
    lateralCorrection = nil,
}

local IGNORED_METADATA: SidedSignals.MetadataConfig = {
    ignore = true,
    lateralCorrection = nil,
}

local function metadataWithoutCorrection(
    ignore: boolean
): SidedSignals.MetadataConfig
    if ignore then
        return IGNORED_METADATA
    end
    return NO_METADATA
end

local function warn(resourceName: string, issue: string)
    debugPrint(
        "[Sided Signals] Invalid "
            .. core.METADATA_KEY
            .. " metadata for "
            .. resourceName
            .. "; "
            .. issue
    )
end

local function readCorrectionValue(
    rawValue: any,
    fieldName: string,
    resourceName: string
): number | nil
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
    return rawValue as number
end

local function read(rawMetadata: any, resourceName: string): SidedSignals.MetadataConfig
    if type(rawMetadata) ~= "table" then
        return NO_METADATA
    end

    local rawConfig = (rawMetadata as {string: any})[core.METADATA_KEY]
    if rawConfig == nil then
        return NO_METADATA
    end
    if type(rawConfig) ~= "table" then
        warn(resourceName, "expected a table")
        return NO_METADATA
    end

    local config = rawConfig as {string: any}
    if config.version ~= core.METADATA_VERSION then
        warn(
            resourceName,
            "unsupported version; expected " .. tostring(core.METADATA_VERSION)
        )
        return NO_METADATA
    end

    local ignore = false
    if config.ignore ~= nil then
        if type(config.ignore) == "boolean" then
            ignore = config.ignore as boolean
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

    local correction = rawCorrection as {string: any}
    local left = readCorrectionValue(correction.left, "left", resourceName)
    local right = readCorrectionValue(correction.right, "right", resourceName)
    if left == nil or right == nil then
        return metadataWithoutCorrection(ignore)
    end

    return {
        ignore = ignore,
        lateralCorrection = {
            left = left as number,
            right = right as number,
            configured = true,
        },
    }
end

local function builtInLateralCorrection(
    modelName: string,
    normalizedModelName: string,
    bounds: BoundingInfo
): SidedSignals.LateralCorrection
    local override = modelOverrides[normalizedModelName]
    if override == nil then
        return NO_LATERAL_CORRECTION
    end

    local knownOverride = override as SidedSignals.ModelOverride
    if math.abs(bounds.bbMin.y - knownOverride.expectedMinY) > BOUNDS_MATCH_EPSILON
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

local function resolveLateralCorrection(
    modelName: string,
    normalizedModelName: string,
    bounds: BoundingInfo,
    config: SidedSignals.MetadataConfig
): SidedSignals.LateralCorrection
    if config.lateralCorrection ~= nil then
        return config.lateralCorrection as SidedSignals.LateralCorrection
    end
    return builtInLateralCorrection(modelName, normalizedModelName, bounds)
end

local M: SidedSignals.Metadata = {
    read = read,
    resolveLateralCorrection = resolveLateralCorrection,
}

return M
