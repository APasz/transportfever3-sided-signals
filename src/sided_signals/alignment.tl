local core = ug_require(
    "apasz_sided_signals::/sided_signals/core.lua"
) as SidedSignals.Core
local metadata = ug_require(
    "apasz_sided_signals::/sided_signals/metadata.lua"
) as SidedSignals.Metadata

local normalizeResourceName = core.normalizeResourceName

local record ModelAlignmentCollection
    alignments: {string: SidedSignals.ModelAlignment}
    count: integer
end

local missingModelWarnings: {string: boolean} = {}

local function readModelAlignment(
    modelAlignmentCache: {string: SidedSignals.ModelAlignment},
    repositoryId: integer,
    modelName: string,
    normalizedName: string
): SidedSignals.ModelAlignment
    local cached = modelAlignmentCache[normalizedName]
    if cached ~= nil then
        return cached
    end

    local model = api.res.modelRep.get(repositoryId)
    local bounds = model.boundingInfo
    local config = metadata.read(model.metadata, modelName)
    local centre: SidedSignals.ModelCentre = {
        x = (bounds.bbMin.x + bounds.bbMax.x) * 0.5,
        y = (bounds.bbMin.y + bounds.bbMax.y) * 0.5,
        z = (bounds.bbMin.z + bounds.bbMax.z) * 0.5,
    }
    if not core.isFiniteNumber(centre.x)
        or not core.isFiniteNumber(centre.y)
        or not core.isFiniteNumber(centre.z)
    then
        error("model bounds must have finite coordinates: " .. modelName)
    end

    local alignment: SidedSignals.ModelAlignment = {
        centre = centre,
        lateralCorrection = metadata.resolveLateralCorrection(
            modelName,
            normalizedName,
            bounds,
            config
        ),
        ignore = config.ignore,
    }
    modelAlignmentCache[normalizedName] = alignment
    return alignment
end

local function findCaptured(
    captureParams: any,
    modelId: string
): SidedSignals.ModelAlignment | nil
    if type(captureParams) ~= "table" then
        return nil
    end
    local rawAlignments = (captureParams as {string: any})[
        core.MODEL_ALIGNMENTS_CAPTURE_KEY
    ]
    if type(rawAlignments) ~= "table" then
        return nil
    end
    local alignments = rawAlignments as {string: SidedSignals.ModelAlignment}
    local directMatch = alignments[modelId]
    if directMatch ~= nil then
        return directMatch
    end

    local normalizedId = normalizeResourceName(modelId)
    if normalizedId == modelId then
        return nil
    end
    return alignments[normalizedId]
end

local function warnMissing(modelId: string)
    local cacheKey = normalizeResourceName(modelId)
    if missingModelWarnings[cacheKey] then
        return
    end
    missingModelWarnings[cacheKey] = true
    debugPrint(
        "[Sided Signals] No captured alignment data for "
            .. modelId
            .. "; preserving its authored side"
    )
end

local function resourceDirectory(resourceReference: string): string
    local resourceName = resourceReference:match("^(.-)@") or resourceReference
    return normalizeResourceName(resourceName):match("^(.*[/])[^/]*$") or ""
end

local function modelDirectoryPrefixes(
    constructionName: string,
    updateScriptFileName: string
): {string: boolean}
    local constructionDirectory = resourceDirectory(constructionName)
    local prefixes: {string: boolean} = {}
    if constructionDirectory ~= "" then
        prefixes[constructionDirectory] = true
    end

    local scriptDirectory = resourceDirectory(updateScriptFileName)
    if scriptDirectory ~= "" then
        if core.hasMarker(scriptDirectory, "::/") then
            prefixes[scriptDirectory] = true
        elseif constructionDirectory ~= "" then
            prefixes[constructionDirectory .. scriptDirectory] = true
        end
    end
    return prefixes
end

local function matchesDirectory(
    normalizedModelName: string,
    prefixes: {string: boolean}
): boolean
    for prefix in pairs(prefixes) do
        if string.find(normalizedModelName, prefix, 1, true) == 1 then
            return true
        end
    end
    return false
end

local function directoryCacheKey(prefixes: {string: boolean}): string
    local sortedPrefixes: {string} = {}
    for prefix in pairs(prefixes) do
        sortedPrefixes[#sortedPrefixes + 1] = prefix
    end
    table.sort(sortedPrefixes)
    return table.concat(sortedPrefixes, "\n")
end

local function addModelAlignment(
    alignments: {string: SidedSignals.ModelAlignment},
    modelAlignmentCache: {string: SidedSignals.ModelAlignment},
    repositoryId: integer,
    modelName: string,
    normalizedName: string
): boolean
    if alignments[normalizedName] ~= nil then
        return false
    end

    local success: boolean
    local value: any
    success, value = pcall(function(): SidedSignals.ModelAlignment
        return readModelAlignment(
            modelAlignmentCache,
            repositoryId,
            modelName,
            normalizedName
        )
    end)
    if success then
        alignments[normalizedName] = value as SidedSignals.ModelAlignment
        return true
    end

    debugPrint(
        "[Sided Signals] Cannot prepare alignment data for "
            .. modelName
            .. ": "
            .. tostring(value)
    )
    return false
end

local function collectMetadataModelAlignments(
    modelAlignmentCache: {string: SidedSignals.ModelAlignment},
    normalizedModelNames: {integer: string}
): {string: SidedSignals.ModelAlignment}
    local alignments: {string: SidedSignals.ModelAlignment} = {}
    api.res.modelRep.forEachModelWithMetadata(core.METADATA_KEY, function(modelName: string)
        local repositoryId = api.res.modelRep.find(modelName)
        if repositoryId ~= -1 then
            local normalizedName = normalizedModelNames[repositoryId]
                or normalizeResourceName(modelName)
            addModelAlignment(
                alignments,
                modelAlignmentCache,
                repositoryId,
                modelName,
                normalizedName
            )
        end
    end)
    return alignments
end

local function collectModelAlignments(
    constructionName: string,
    construction: api.type.ConstructionDesc,
    allModels: {integer: string},
    normalizedModelNames: {integer: string},
    modelAlignmentCache: {string: SidedSignals.ModelAlignment},
    metadataAlignments: {string: SidedSignals.ModelAlignment},
    directoryCache: {string: ModelAlignmentCollection}
): {string: SidedSignals.ModelAlignment}, integer
    local prefixes = modelDirectoryPrefixes(
        constructionName,
        construction.updateScript.fileName
    )
    local cacheKey = directoryCacheKey(prefixes)
    local cached = directoryCache[cacheKey]
    if cached ~= nil then
        local collection = cached as ModelAlignmentCollection
        return collection.alignments, collection.count
    end

    local alignments: {string: SidedSignals.ModelAlignment} = {}
    local count = 0
    local hasDirectoryMatch = false

    for modelName, alignment in pairs(metadataAlignments) do
        alignments[modelName] = alignment
        count = count + 1
    end
    for repositoryId, modelName in pairs(allModels) do
        local normalizedName = normalizedModelNames[repositoryId]
        if matchesDirectory(normalizedName, prefixes) then
            hasDirectoryMatch = true
            if addModelAlignment(
                alignments,
                modelAlignmentCache,
                repositoryId,
                modelName,
                normalizedName
            ) then
                count = count + 1
            end
        end
    end

    if not hasDirectoryMatch then
        debugPrint(
            "[Sided Signals] No nearby model resources found for " .. constructionName
        )
    end
    directoryCache[cacheKey] = {
        alignments = alignments,
        count = count,
    }
    return alignments, count
end

local function buildNormalizedModelNames(
    allModels: {integer: string}
): {integer: string}
    local normalizedNames: {integer: string} = {}
    for repositoryId, modelName in pairs(allModels) do
        normalizedNames[repositoryId] = normalizeResourceName(modelName)
    end
    return normalizedNames
end

local function attachModelAlignments(
    construction: api.type.ConstructionDesc,
    alignments: {string: SidedSignals.ModelAlignment}
)
    local updateScript = construction.updateScript
    local captureParams: table = {}
    if type(updateScript.params) == "table" then
        for key, value in pairs(updateScript.params) do
            captureParams[key] = value
        end
    end
    captureParams[core.MODEL_ALIGNMENTS_CAPTURE_KEY] = alignments

    local replacement = api.type.ScriptRef.new()
    replacement.fileName = updateScript.fileName
    replacement.params = captureParams
    construction.updateScript = replacement
end

local function prepareSignalConstructions()
    local preparedCount = 0
    local modelReferenceCount = 0
    local allModels = api.res.modelRep.getAll(true)
    local normalizedModelNames = buildNormalizedModelNames(allModels)
    -- Resource data is available during postRun, but not inside construction updates.
    local modelAlignmentCache: {string: SidedSignals.ModelAlignment} = {}
    local metadataAlignments = collectMetadataModelAlignments(
        modelAlignmentCache,
        normalizedModelNames
    )
    local directoryCache: {string: ModelAlignmentCollection} = {}

    for constructionId, constructionName in pairs(api.res.constructionRep.getAll()) do
        local construction = api.res.constructionRep.get(constructionId)
        local params = construction.params
        if params ~= nil
            and core.hasParam(
                params as {api.type.ScriptParam},
                core.SIDE_OFFSET_KEY
            )
        then
            local alignments, count = collectModelAlignments(
                constructionName,
                construction,
                allModels,
                normalizedModelNames,
                modelAlignmentCache,
                metadataAlignments,
                directoryCache
            )
            attachModelAlignments(construction, alignments)
            preparedCount = preparedCount + 1
            modelReferenceCount = modelReferenceCount + count
        end
    end

    debugPrint(
        "[Sided Signals] Prepared lateral alignment for "
            .. tostring(preparedCount)
            .. " signal constructions ("
            .. tostring(modelReferenceCount)
            .. " model references)"
    )
end

local M: SidedSignals.Alignment = {
    findCaptured = findCaptured,
    warnMissing = warnMissing,
    prepareSignalConstructions = prepareSignalConstructions,
}

return M
