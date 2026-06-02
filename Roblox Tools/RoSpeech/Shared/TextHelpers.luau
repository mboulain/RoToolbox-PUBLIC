local TextHelpers = {}

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

function TextHelpers.PrepareRawForTransport(text: string): string
	text = text:gsub("[%c]", " ")
	text = text:gsub("%s+", " ")
	text = trim(text)

	return text
end

function TextHelpers.NormalizeForServer(text: string, maxLength: number?): string
	text = string.lower(text)
	text = text:gsub("[%c]", " ")
	text = text:gsub("[%p]", " ")
	text = text:gsub("%s+", " ")
	text = trim(text)

	if maxLength and #text > maxLength then
		text = string.sub(text, 1, maxLength)
		text = trim(text)
	end

	return text
end

function TextHelpers.IsMeaningful(text: string): boolean
	return type(text) == "string" and trim(text) ~= ""
end

return TextHelpers