local CommandsFolder = script.Commands
local CommandHelpers = require(script.CommandHelpers)

export type CommandDefinition = {
	Id: string,
	Aliases: {string},
	Keywords: {string}?,
	Priority: number?,
}

export type MatchResult = {
	Command: CommandDefinition,
	CommandId: string,
	MatchedAlias: string?,
	MatchType: "ExactAlias" | "ContainsAlias" | "Keywords",
	Score: number,
	InputText: string,
	NormalizedInputText: string,
}

local TextCommandMatcher = {}
TextCommandMatcher.__index = TextCommandMatcher

local _cachedCommands: {CommandDefinition}? = nil

local function getCommandPriority(command: CommandDefinition): number
	return command.Priority or 0
end

local function loadCommands(): {CommandDefinition}
	if _cachedCommands then
		return _cachedCommands
	end

	local commands = {}

	for _, moduleScript in ipairs(CommandsFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local ok, command = pcall(require, moduleScript)

			if not ok then
				warn(("[TextCommandMatcher] Failed to require command module '%s': %s")
					:format(moduleScript.Name, tostring(command)))
				continue
			end

			if not CommandHelpers.IsCommandDefinitionValid(command) then
				warn(("[TextCommandMatcher] Invalid command definition in '%s'."):format(moduleScript.Name))
				continue
			end

			table.insert(commands, command)
		end
	end

	_cachedCommands = commands
	return commands
end

local function buildMatchResult(
	command: CommandDefinition,
	inputText: string,
	normalizedInputText: string,
	matchType: "ExactAlias" | "ContainsAlias" | "Keywords",
	score: number,
	matchedAlias: string?
): MatchResult
	return {
		Command = command,
		CommandId = command.Id,
		MatchedAlias = matchedAlias,
		MatchType = matchType,
		Score = score,
		InputText = inputText,
		NormalizedInputText = normalizedInputText,
	}
end

local function tryExactAliasMatch(command: CommandDefinition, normalizedInputText: string): MatchResult?
	for _, alias in ipairs(command.Aliases) do
		local normalizedAlias = CommandHelpers.NormalizeText(alias)
		if normalizedAlias ~= "" and normalizedInputText == normalizedAlias then
			return buildMatchResult(command, normalizedInputText, normalizedInputText, "ExactAlias", 1000 + getCommandPriority(command), alias)
		end
	end

	return nil
end

local function tryContainsAliasMatch(command: CommandDefinition, normalizedInputText: string): MatchResult?
	local bestAlias: string? = nil
	local bestAliasLength = -1

	for _, alias in ipairs(command.Aliases) do
		local normalizedAlias = CommandHelpers.NormalizeText(alias)
		if normalizedAlias ~= "" and CommandHelpers.ContainsWholePhrase(normalizedInputText, normalizedAlias) then
			if #normalizedAlias > bestAliasLength then
				bestAlias = alias
				bestAliasLength = #normalizedAlias
			end
		end
	end

	if bestAlias then
		return buildMatchResult(command, normalizedInputText, normalizedInputText, "ContainsAlias", 700 + bestAliasLength + getCommandPriority(command), bestAlias)
	end

	return nil
end

local function tryKeywordMatch(command: CommandDefinition, normalizedInputText: string): MatchResult?
	local keywords = command.Keywords
	if not keywords or #keywords == 0 then
		return nil
	end

	local matchedCount = CommandHelpers.CountMatchingKeywords(normalizedInputText, keywords)
	if matchedCount <= 0 then
		return nil
	end

	return buildMatchResult(command, normalizedInputText, normalizedInputText, "Keywords", 400 + matchedCount * 10 + getCommandPriority(command), nil)
end

function TextCommandMatcher.GetCommands(): {CommandDefinition}
	return loadCommands()
end

function TextCommandMatcher.FindMatchingCommand(cleanedText: string): MatchResult?
	if type(cleanedText) ~= "string" then
		return nil
	end

	local normalizedInputText = CommandHelpers.NormalizeText(cleanedText)
	if normalizedInputText == "" then
		return nil
	end

	local commands = loadCommands()
	local bestMatch: MatchResult? = nil

	for _, command in ipairs(commands) do
		local exactMatch = tryExactAliasMatch(command, normalizedInputText)
		if exactMatch then
			if not bestMatch or exactMatch.Score > bestMatch.Score then
				bestMatch = exactMatch
			end
		end
	end

	if bestMatch then
		return bestMatch
	end

	for _, command in ipairs(commands) do
		local containsMatch = tryContainsAliasMatch(command, normalizedInputText)
		if containsMatch then
			if not bestMatch or containsMatch.Score > bestMatch.Score then
				bestMatch = containsMatch
			end
		end
	end

	if bestMatch then
		return bestMatch
	end

	for _, command in ipairs(commands) do
		local keywordMatch = tryKeywordMatch(command, normalizedInputText)
		if keywordMatch then
			if not bestMatch or keywordMatch.Score > bestMatch.Score then
				bestMatch = keywordMatch
			end
		end
	end

	return bestMatch
end

function TextCommandMatcher.ResetCache()
	_cachedCommands = nil
end

return TextCommandMatcher