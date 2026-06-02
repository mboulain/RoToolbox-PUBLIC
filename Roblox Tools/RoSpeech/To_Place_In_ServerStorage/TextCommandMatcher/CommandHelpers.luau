local CommandHelpers = {}

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

function CommandHelpers.NormalizeText(text: string): string
	text = string.lower(text)
	text = text:gsub("[%c]", " ")
	text = text:gsub("[%p]", " ")
	text = text:gsub("%s+", " ")
	text = trim(text)

	return text
end

function CommandHelpers.ContainsWholePhrase(text: string, phrase: string): boolean
	text = CommandHelpers.NormalizeText(text)
	phrase = CommandHelpers.NormalizeText(phrase)

	if phrase == "" then
		return false
	end

	if text == phrase then
		return true
	end

	local paddedText = " " .. text .. " "
	local paddedPhrase = " " .. phrase .. " "

	return string.find(paddedText, paddedPhrase, 1, true) ~= nil
end

function CommandHelpers.SplitWords(text: string): {string}
	local words = {}

	for word in string.gmatch(CommandHelpers.NormalizeText(text), "%S+") do
		table.insert(words, word)
	end

	return words
end

function CommandHelpers.CountMatchingKeywords(text: string, keywords: {string}): number
	local normalizedText = CommandHelpers.NormalizeText(text)
	local count = 0

	for _, keyword in ipairs(keywords) do
		local normalizedKeyword = CommandHelpers.NormalizeText(keyword)
		if normalizedKeyword ~= "" and CommandHelpers.ContainsWholePhrase(normalizedText, normalizedKeyword) then
			count += 1
		end
	end

	return count
end

function CommandHelpers.IsCommandDefinitionValid(command: any): boolean
	if type(command) ~= "table" then
		return false
	end

	if type(command.Id) ~= "string" or command.Id == "" then
		return false
	end

	if type(command.Aliases) ~= "table" then
		return false
	end

	if command.Keywords ~= nil and type(command.Keywords) ~= "table" then
		return false
	end

	if command.Priority ~= nil and type(command.Priority) ~= "number" then
		return false
	end

	return true
end

return CommandHelpers