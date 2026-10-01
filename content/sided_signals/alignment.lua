local _tl_compat
if (tonumber((_VERSION or ""):match("[%d.]*$")) or 0) < 5.3 then
	local p, m = pcall(require, "compat53.module")
	if p then
		_tl_compat = m
	end
end
local pairs = _tl_compat and _tl_compat.pairs or pairs
local pcall = _tl_compat and _tl_compat.pcall or pcall
local string = _tl_compat and _tl_compat.string or string
local table = _tl_compat and _tl_compat.table or table
local core = ug_require("apasz_sided_signals::/sided_signals/core.lua")

local metadata = ug_require("apasz_sided_signals::/sided_signals/metadata.lua")

local normalizeResourceName = core.normalizeResourceName

local missingModelWarnings = {}

local function readModelAlignment(modelAlignmentCache, repositoryId, modelName, normalizedName)
	local cached = modelAlignmentCache[normalizedName]
	if cached ~= nil then
		return cached
	end

	local model = api.res.modelRep.get(repositoryId)
	local bounds = model.boundingInfo
	local config = metadata.read(model.metadata, modelName)
	local centre = {
		x = (bounds.bbMin.x + bounds.bbMax.x) * 0.5,
		y = (bounds.bbMin.y + bounds.bbMax.y) * 0.5,
		z = (bounds.bbMin.z + bounds.bbMax.z) * 0.5,
	}
	if not core.isFiniteNumber(centre.x) or not core.isFiniteNumber(centre.y) or not core.isFiniteNumber(centre.z) then
		error("model bounds must have finite coordinates: " .. modelName)
	end

	local alignment = {
		centre = centre,
		lateralCorrection = metadata.resolveLateralCorrection(modelName, normalizedName, bounds, config),

		ignore = config.ignore,
	}
	modelAlignmentCache[normalizedName] = alignment
	return alignment
end

local function findCaptured(captureParams, modelId)
	if type(captureParams) ~= "table" then
		return nil
	end
	local rawAlignments = (captureParams)[core.MODEL_ALIGNMENTS_CAPTURE_KEY]

	if type(rawAlignments) ~= "table" then
		return nil
	end
	local alignments = rawAlignments
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

local function warnMissing(modelId)
	local cacheKey = normalizeResourceName(modelId)
	if missingModelWarnings[cacheKey] then
		return
	end
	missingModelWarnings[cacheKey] = true
	debugPrint("[Sided Signals] No captured alignment data for " .. modelId .. "; preserving its authored side")
end

local function resourceDirectory(resourceReference)
	local resourceName = resourceReference:match("^(.-)@") or resourceReference
	return normalizeResourceName(resourceName):match("^(.*[/])[^/]*$") or ""
end

local function modelDirectoryPrefixes(constructionName, updateScriptFileName)
	local constructionDirectory = resourceDirectory(constructionName)
	local prefixes = {}
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

local function matchesDirectory(normalizedModelName, prefixes)
	for prefix in pairs(prefixes) do
		if string.find(normalizedModelName, prefix, 1, true) == 1 then
			return true
		end
	end
	return false
end

local function directoryCacheKey(prefixes)
	local sortedPrefixes = {}
	for prefix in pairs(prefixes) do
		sortedPrefixes[#sortedPrefixes + 1] = prefix
	end
	table.sort(sortedPrefixes)
	return table.concat(sortedPrefixes, "\n")
end

local function addModelAlignment(alignments, modelAlignmentCache, repositoryId, modelName, normalizedName)
	if alignments[normalizedName] ~= nil then
		return false
	end

	local success
	local value
	success, value = pcall(function()
		return readModelAlignment(modelAlignmentCache, repositoryId, modelName, normalizedName)
	end)
	if success then
		alignments[normalizedName] = value
		return true
	end

	debugPrint("[Sided Signals] Cannot prepare alignment data for " .. modelName .. ": " .. tostring(value))

	return false
end

local function collectMetadataModelAlignments(modelAlignmentCache, normalizedModelNames)
	local alignments = {}
	api.res.modelRep.forEachModelWithMetadata(core.METADATA_KEY, function(modelName)
		local repositoryId = api.res.modelRep.find(modelName)
		if repositoryId ~= -1 then
			local normalizedName = normalizedModelNames[repositoryId] or normalizeResourceName(modelName)
			addModelAlignment(alignments, modelAlignmentCache, repositoryId, modelName, normalizedName)
		end
	end)
	return alignments
end

local function collectModelAlignments(
	constructionName,
	construction,
	allModels,
	normalizedModelNames,
	modelAlignmentCache,
	metadataAlignments,
	directoryCache
)
	local prefixes = modelDirectoryPrefixes(constructionName, construction.updateScript.fileName)

	local cacheKey = directoryCacheKey(prefixes)
	local cached = directoryCache[cacheKey]
	if cached ~= nil then
		local collection = cached
		return collection.alignments, collection.count
	end

	local alignments = {}
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
			if addModelAlignment(alignments, modelAlignmentCache, repositoryId, modelName, normalizedName) then
				count = count + 1
			end
		end
	end

	if not hasDirectoryMatch then
		debugPrint("[Sided Signals] No nearby model resources found for " .. constructionName)
	end
	directoryCache[cacheKey] = {
		alignments = alignments,
		count = count,
	}
	return alignments, count
end

local function buildNormalizedModelNames(allModels)
	local normalizedNames = {}
	for repositoryId, modelName in pairs(allModels) do
		normalizedNames[repositoryId] = normalizeResourceName(modelName)
	end
	return normalizedNames
end

local function attachModelAlignments(construction, alignments)
	local updateScript = construction.updateScript
	local captureParams = {}
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

	local modelAlignmentCache = {}
	local metadataAlignments = collectMetadataModelAlignments(modelAlignmentCache, normalizedModelNames)

	local directoryCache = {}

	for constructionId, constructionName in pairs(api.res.constructionRep.getAll()) do
		local construction = api.res.constructionRep.get(constructionId)
		local params = construction.params
		if params ~= nil and core.hasParam(params, core.SIDE_OFFSET_KEY) then
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

local M = {
	findCaptured = findCaptured,
	warnMissing = warnMissing,
	prepareSignalConstructions = prepareSignalConstructions,
}

return M
