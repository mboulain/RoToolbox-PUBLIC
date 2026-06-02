local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local ActionsFolder = script.Parent.Actions

export type HackTracker = {
	Start: (self: HackTracker) -> (),
	Destroy: (self: HackTracker) -> (),
}

local function formatKeyCode(keyCode: Enum.KeyCode): string
	local name = keyCode.Name

	local replacements = {
		LeftControl = "Ctrl",
		RightControl = "Ctrl",
		LeftShift = "Shift",
		RightShift = "Shift",
		One = "1",
		Two = "2",
		Three = "3",
	}

	return replacements[name] or name
end

local function getCleanRemoteName(fullName: string): string
	local rfIndex = string.find(fullName, ".RF.")
	if rfIndex then
		return string.sub(fullName, rfIndex + 4)
	end

	return fullName:match("[^%.]+$") or fullName
end

local function stringifyArgs(...): string
	local args = { ... }
	local result = {}

	for i, value in ipairs(args) do
		result[i] = tostring(value)
	end

	return table.concat(result, ", ")
end

local HackTracker = {}
HackTracker.__index = HackTracker

function HackTracker.new(toggleKey: Enum.KeyCode?, defaultVisibility: boolean?, printForDebug: boolean?): HackTracker?
	if not RunService:IsStudio() then
		local parentFolder = script.Parent
		script.Parent = nil
		ActionsFolder.Parent = nil
		parentFolder:Destroy()
		return nil
	end

	local self = setmetatable({}, HackTracker)

	self._uiVisible = defaultVisibility == true
	self._printForDebug = printForDebug == true
	self.ToggleKey = toggleKey or Enum.KeyCode.F6

	self.Actions = {}
	self._actionUi = {}

	self.RemoteEvents = {}
	self.RemoteFunctions = {}

	self._remoteEventConnections = {}
	self._toggleConnection = nil
	self._dragInputConnection = nil
	self._screenGui = nil

	self:_loadActions()
	self:_discoverRemotes()
	self:_connectRemoteEventListeners()
	self:BuildUpUI()

	return self
end

function HackTracker:_loadActions()
	self.Actions = {}

	for _, actionModule in ipairs(ActionsFolder:GetChildren()) do
		if not actionModule:IsA("ModuleScript") then
			warn("HackTracker: Ignoring non-ModuleScript child in Actions folder:", actionModule.Name)
			continue
		end

		local ok, actionClass = pcall(require, actionModule)
		if not ok then
			warn("HackTracker: Failed to require action module:", actionModule.Name, actionClass)
			continue
		end

		if typeof(actionClass) ~= "table" or typeof(actionClass.new) ~= "function" then
			warn("HackTracker: Action module does not expose .new():", actionModule.Name)
			continue
		end

		local instanceOk, actionInstance = pcall(function()
			return actionClass.new()
		end)

		if not instanceOk or not actionInstance then
			warn("HackTracker: Failed to instantiate action:", actionModule.Name, actionInstance)
			continue
		end

		table.insert(self.Actions, actionInstance)
	end

	table.sort(self.Actions, function(a, b)
		return (a.Name or "") < (b.Name or "")
	end)
end

function HackTracker:_discoverRemotes()
	self.RemoteEvents = {}
	self.RemoteFunctions = {}

	local function scan(instance: Instance)
		for _, child in ipairs(instance:GetChildren()) do
			if child:IsA("RemoteEvent") then
				self.RemoteEvents[child:GetFullName()] = child
			elseif child:IsA("RemoteFunction") then
				self.RemoteFunctions[child:GetFullName()] = child
			end

			scan(child)
		end
	end

	scan(ReplicatedStorage)

	if self._printForDebug then
		print("HackTracker: Listing all RemoteEvents:")
		for name, _ in pairs(self.RemoteEvents) do
			print(" - " .. name)
		end

		print("HackTracker: Listing all RemoteFunctions:")
		for name, _ in pairs(self.RemoteFunctions) do
			print(" - " .. name)
		end
	end
end

function HackTracker:_disconnectRemoteEventListeners()
	for _, connection in ipairs(self._remoteEventConnections) do
		connection:Disconnect()
	end

	table.clear(self._remoteEventConnections)
end

function HackTracker:_connectRemoteEventListeners()
	self:_disconnectRemoteEventListeners()

	for name, remote in pairs(self.RemoteEvents) do
		local connection = remote.OnClientEvent:Connect(function(...)
			if self._printForDebug then
				print(
					string.format(
						"HackTracker: RemoteEvent '%s' received by client with arguments: %s",
						name,
						stringifyArgs(...)
					)
				)
			end
		end)

		table.insert(self._remoteEventConnections, connection)
	end
end

function HackTracker:_parseInputValue(rawText: string, inputType: string)
	local trimmed = rawText:gsub("^%s+", ""):gsub("%s+$", "")

	if inputType == "number" then
		return tonumber(trimmed)
	elseif inputType == "boolean" then
		if trimmed == "true" then
			return true
		elseif trimmed == "false" then
			return false
		end
		return nil
	elseif inputType == "string" then
		return trimmed
	end

	return trimmed
end

function HackTracker:_getActionInputValues(action)
	local actionUi = self._actionUi[action.Name]
	if not actionUi then
		return {}
	end

	local values = {}

	for _, inputDef in ipairs(action.Inputs or {}) do
		local inputEntry = actionUi.Inputs[inputDef.Key]

		if not inputEntry then
			values[inputDef.Key] = inputDef.Default
			continue
		end

		if inputEntry.Type == "boolean" then
			values[inputDef.Key] = inputEntry.Widget.GetValue()
		else
			local inputBox = inputEntry.Widget
			local parsedValue = self:_parseInputValue(inputBox.Text, inputDef.Type or "string")

			if parsedValue == nil then
				parsedValue = inputDef.Default
			end

			values[inputDef.Key] = parsedValue
		end
	end

	return values
end

function HackTracker:_setActionStatus(actionName: string, enabled: boolean, message: string?)
	local actionUi = self._actionUi[actionName]
	if not actionUi or not actionUi.StatusLabel then
		return
	end

	local statusLabel = actionUi.StatusLabel
	statusLabel.Text = message or (enabled and "Enabled" or "Disabled")
	statusLabel.TextColor3 = enabled and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 120, 120)
end

function HackTracker:_toggleAction(action)
	local values = self:_getActionInputValues(action)

	local ok, success, message = pcall(function()
		if typeof(action.Toggle) == "function" then
			return action:Toggle(values)
		end

		if action.Enabled then
			return action:Disable()
		else
			return action:Enable(values)
		end
	end)

	if not ok then
		warn(string.format("HackTracker: Failed to toggle action '%s': %s", action.Name, tostring(success)))
		self:_setActionStatus(action.Name, false, "Error | " .. tostring(success))
		return
	end

	if success == nil then
		success = action.Enabled == true
	end

	local enabled = action.Enabled == true
	self:_setActionStatus(action.Name, enabled, message or (enabled and "Enabled" or "Disabled"))
end

function HackTracker:BuildUpUI()
	if self._toggleConnection then
		self._toggleConnection:Disconnect()
		self._toggleConnection = nil
	end

	if self._dragInputConnection then
		self._dragInputConnection:Disconnect()
		self._dragInputConnection = nil
	end

	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end

	self._actionUi = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HackTrackerUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	screenGui.Enabled = self._uiVisible
	screenGui.DisplayOrder = 999
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self._screenGui = screenGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(360, 440)
	mainFrame.Position = UDim2.fromOffset(20, 100)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	local titleBar = Instance.new("TextButton")
	titleBar.Name = "TitleBar"
	titleBar.Size = UDim2.new(1, 0, 0, 32)
	titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
	titleBar.BorderSizePixel = 0
	titleBar.Text = string.format("HackTracker (%s to toggle)", formatKeyCode(self.ToggleKey))
	titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleBar.TextXAlignment = Enum.TextXAlignment.Center
	titleBar.Font = Enum.Font.SourceSansBold
	titleBar.TextSize = 22
	titleBar.AutoButtonColor = false
	titleBar.Parent = mainFrame

	local scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "ScrollingFrame"
	scrollingFrame.Size = UDim2.new(1, -10, 1, -42)
	scrollingFrame.Position = UDim2.fromOffset(5, 37)
	scrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
	scrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollingFrame.ScrollBarThickness = 8
	scrollingFrame.Parent = mainFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollingFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = scrollingFrame

	local function parseSingleValue(raw: string)
		local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", "")

		if trimmed == "" then
			return ""
		end

		if trimmed == "true" then
			return true
		elseif trimmed == "false" then
			return false
		end

		local asNumber = tonumber(trimmed)
		if asNumber ~= nil then
			return asNumber
		end

		return trimmed
	end

	local function parseArguments(raw: string)
		if raw == "" then
			return {}
		end

		local args = {}
		for token in string.gmatch(raw, "([^;]+)") do
			table.insert(args, parseSingleValue(token))
		end

		return args
	end

	local function createDescription(parent: Instance, text: string)
		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(180, 180, 180)
		label.Font = Enum.Font.SourceSans
		label.TextSize = 14
		label.Text = text
		label.Parent = parent
		return label
	end

	local function createInputLabel(parent: Instance, text: string)
		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.Font = Enum.Font.SourceSansSemibold
		label.TextSize = 16
		label.Text = text
		label.Parent = parent
		return label
	end

	local function createTextBox(parent: Instance, placeholder: string, defaultText: string?)
		local input = Instance.new("TextBox")
		input.Size = UDim2.new(1, 0, 0, 34)
		input.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		input.BorderSizePixel = 0
		input.ClearTextOnFocus = false
		input.PlaceholderText = placeholder
		input.Text = defaultText or ""
		input.TextColor3 = Color3.fromRGB(255, 255, 255)
		input.Font = Enum.Font.SourceSans
		input.TextSize = 18
		input.Parent = parent
		return input
	end

	local function createButton(parent: Instance, text: string)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 32)
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 120)
		button.BorderSizePixel = 0
		button.Text = text
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Font = Enum.Font.SourceSansBold
		button.TextSize = 18
		button.Parent = parent
		return button
	end

	local function createStatusLabel(parent: Instance, defaultText: string?)
		local label = Instance.new("TextLabel")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(150, 220, 150)
		label.Font = Enum.Font.SourceSans
		label.TextSize = 15
		label.Text = defaultText or ""
		label.Parent = parent
		return label
	end

	local function createCheckbox(parent: Instance, labelText: string, defaultValue: boolean?)
		local value = defaultValue == true

		local container = Instance.new("Frame")
		container.Name = "Checkbox"
		container.Size = UDim2.new(1, 0, 0, 34)
		container.BackgroundTransparency = 1
		container.Parent = parent

		local button = Instance.new("TextButton")
		button.Name = "Box"
		button.Size = UDim2.fromOffset(24, 24)
		button.Position = UDim2.fromOffset(0, 5)
		button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = container

		local indicator = Instance.new("TextLabel")
		indicator.Name = "Indicator"
		indicator.Size = UDim2.new(1, 0, 1, 0)
		indicator.BackgroundTransparency = 1
		indicator.TextColor3 = Color3.fromRGB(255, 255, 255)
		indicator.Font = Enum.Font.SourceSansBold
		indicator.TextSize = 22
		indicator.Text = ""
		indicator.Parent = button

		local label = Instance.new("TextButton")
		label.Name = "Label"
		label.Size = UDim2.new(1, -34, 1, 0)
		label.Position = UDim2.fromOffset(34, 0)
		label.BackgroundTransparency = 1
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.SourceSans
		label.TextSize = 18
		label.Text = labelText
		label.AutoButtonColor = false
		label.Parent = container

		local function refresh()
			if value then
				indicator.Text = "✓"
				button.BackgroundColor3 = Color3.fromRGB(70, 120, 70)
			else
				indicator.Text = ""
				button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			end
		end

		local function setValue(newValue: boolean)
			value = newValue == true
			refresh()
		end

		local function getValue(): boolean
			return value
		end

		button.MouseButton1Click:Connect(function()
			setValue(not value)
		end)

		label.MouseButton1Click:Connect(function()
			setValue(not value)
		end)

		refresh()

		return {
			Root = container,
			GetValue = getValue,
			SetValue = setValue,
		}
	end

	local function createSection(parent: Instance, titleText: string, startsExpanded: boolean?, style)
		local expanded = if startsExpanded == nil then true else startsExpanded
		style = style or {}

		local section = Instance.new("Frame")
		section.Name = titleText
		section.AutomaticSize = Enum.AutomaticSize.Y
		section.Size = UDim2.new(1, 0, 0, 0)
		section.BackgroundColor3 = style.SectionBackgroundColor3 or Color3.fromRGB(40, 40, 40)
		section.BorderSizePixel = 0
		section.Parent = parent

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, style.PaddingTop or 8)
		padding.PaddingBottom = UDim.new(0, style.PaddingBottom or 8)
		padding.PaddingLeft = UDim.new(0, style.PaddingLeft or 8)
		padding.PaddingRight = UDim.new(0, style.PaddingRight or 8)
		padding.Parent = section

		local sectionLayout = Instance.new("UIListLayout")
		sectionLayout.Padding = UDim.new(0, style.SectionSpacing or 6)
		sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
		sectionLayout.Parent = section

		local header = Instance.new("TextButton")
		header.Name = "Header"
		header.Size = UDim2.new(1, 0, 0, style.HeaderHeight or 28)
		header.BackgroundColor3 = style.HeaderBackgroundColor3 or Color3.fromRGB(55, 55, 55)
		header.BorderSizePixel = 0
		header.TextColor3 = style.HeaderTextColor3 or Color3.fromRGB(255, 255, 255)
		header.Font = style.HeaderFont or Enum.Font.SourceSansBold
		header.TextSize = style.HeaderTextSize or 20
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.AutoButtonColor = false
		header.LayoutOrder = 0
		header.Parent = section

		local contentContainer = Instance.new("Frame")
		contentContainer.Name = "ContentContainer"
		contentContainer.AutomaticSize = Enum.AutomaticSize.Y
		contentContainer.Size = UDim2.new(1, 0, 0, 0)
		contentContainer.BackgroundTransparency = 1
		contentContainer.LayoutOrder = 1
		contentContainer.Parent = section

		local contentLayout = Instance.new("UIListLayout")
		contentLayout.Padding = UDim.new(0, style.ContentContainerSpacing or 6)
		contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
		contentLayout.Parent = contentContainer

		local content = Instance.new("Frame")
		content.Name = "Content"
		content.AutomaticSize = Enum.AutomaticSize.Y
		content.Size = UDim2.new(1, 0, 0, 0)
		content.BackgroundTransparency = 1
		content.Visible = expanded
		content.Parent = contentContainer

		local innerLayout = Instance.new("UIListLayout")
		innerLayout.Padding = UDim.new(0, style.InnerSpacing or 6)
		innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		innerLayout.Parent = content

		local function refreshHeader()
			header.Text = string.format("%s %s", expanded and "▼" or "►", titleText)
		end

		refreshHeader()

		header.MouseButton1Click:Connect(function()
			expanded = not expanded
			content.Visible = expanded
			refreshHeader()
		end)

		return section, content
	end

	local function createActionSection(action)
		local _, content = createSection(scrollingFrame, action.Name or "Unnamed Action", false)

		local layoutOrder = 0
		local inputMap = {}

		local function nextOrder()
			layoutOrder += 1
			return layoutOrder
		end

		local description = createDescription(content, action.Description or "")
		description.LayoutOrder = nextOrder()

		for _, inputDef in ipairs(action.Inputs or {}) do
			local labelText = inputDef.Label or inputDef.Key

			if inputDef.Type == "boolean" then
				local checkbox = createCheckbox(content, labelText, inputDef.Default)
				checkbox.Root.LayoutOrder = nextOrder()

				inputMap[inputDef.Key] = {
					Type = "boolean",
					Widget = checkbox,
				}
			else
				local inputLabel = createInputLabel(content, labelText)
				inputLabel.LayoutOrder = nextOrder()

				local placeholder = inputDef.Placeholder or labelText or inputDef.Key
				local defaultText = inputDef.Default ~= nil and tostring(inputDef.Default) or ""

				local input = createTextBox(content, placeholder, defaultText)
				input.LayoutOrder = nextOrder()

				inputMap[inputDef.Key] = {
					Type = inputDef.Type or "string",
					Widget = input,
				}
			end
		end

		local buttonText = action.Kind == "Toggle" and ("Toggle " .. (action.Name or "Action"))
			or (action.Name or "Run Action")

		local button = createButton(content, buttonText)
		button.LayoutOrder = nextOrder()

		local statusLabel = createStatusLabel(content, action.Enabled and "Enabled" or "Disabled")
		statusLabel.LayoutOrder = nextOrder()
		statusLabel.TextColor3 = action.Enabled and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(255, 120, 120)

		self._actionUi[action.Name] = {
			Inputs = inputMap,
			StatusLabel = statusLabel,
			Button = button,
		}

		button.MouseButton1Click:Connect(function()
			self:_toggleAction(action)
		end)
	end

	local function createRemoteRow(parent: Instance, fullName: string, remote: RemoteFunction, layoutOrder: number)
		local row = Instance.new("Frame")
		row.Name = fullName
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
		row.BorderSizePixel = 0
		row.LayoutOrder = layoutOrder
		row.Parent = parent

		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingTop = UDim.new(0, 8)
		rowPadding.PaddingBottom = UDim.new(0, 8)
		rowPadding.PaddingLeft = UDim.new(0, 16)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = row

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AutomaticSize = Enum.AutomaticSize.Y
		nameLabel.Size = UDim2.new(1, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextWrapped = true
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 18
		nameLabel.Text = getCleanRemoteName(fullName)
		nameLabel.LayoutOrder = 1
		nameLabel.Parent = row

		local input = createTextBox(row, "Example: hello; 42; true")
		input.LayoutOrder = 2

		local sendButton = createButton(row, "Send")
		sendButton.LayoutOrder = 3

		local resultLabel = createStatusLabel(row)
		resultLabel.LayoutOrder = 4

		sendButton.MouseButton1Click:Connect(function()
			local args = parseArguments(input.Text)

			local ok, result = pcall(function()
				return remote:InvokeServer(unpack(args))
			end)

			if ok then
				resultLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
				resultLabel.Text = "Success | Return: " .. tostring(result)

				print(
					string.format(
						"HackTracker: RemoteFunction '%s' manually invoked with args: %s | Return: %s",
						fullName,
						stringifyArgs(unpack(args)),
						tostring(result)
					)
				)
			else
				resultLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
				resultLabel.Text = "Error | " .. tostring(result)

				warn(
					string.format("HackTracker: RemoteFunction '%s' invocation failed: %s", fullName, tostring(result))
				)
			end
		end)
	end

	local function getRemoteCategoryInfo(remote: Instance)
		local parts = {}
		local current = remote.Parent

		while current and current ~= ReplicatedStorage do
			table.insert(parts, 1, current.Name)
			current = current.Parent
		end

		if #parts == 0 then
			return {
				GroupKey = "Uncategorized",
				DisplayName = "Uncategorized",
			}
		end

		local displayName = parts[#parts]

		if displayName == "RF" and #parts >= 2 then
			displayName = parts[#parts - 1]
		end

		return {
			GroupKey = table.concat(parts, "/"),
			DisplayName = displayName,
		}
	end

	local function groupRemoteFunctionsByCategory()
		local grouped = {}

		for fullName, remote in pairs(self.RemoteFunctions) do
			local categoryInfo = getRemoteCategoryInfo(remote)
			local groupKey = categoryInfo.GroupKey

			if not grouped[groupKey] then
				grouped[groupKey] = {
					DisplayName = categoryInfo.DisplayName,
					Entries = {},
				}
			end

			table.insert(grouped[groupKey].Entries, {
				FullName = fullName,
				Remote = remote,
			})
		end

		local sortedGroupKeys = {}
		for groupKey, _ in pairs(grouped) do
			table.insert(sortedGroupKeys, groupKey)
		end

		table.sort(sortedGroupKeys, function(a, b)
			local nameA = grouped[a].DisplayName
			local nameB = grouped[b].DisplayName

			if nameA == nameB then
				return a < b
			end

			return nameA < nameB
		end)

		for _, groupKey in ipairs(sortedGroupKeys) do
			table.sort(grouped[groupKey].Entries, function(a, b)
				return getCleanRemoteName(a.FullName) < getCleanRemoteName(b.FullName)
			end)
		end

		return grouped, sortedGroupKeys
	end

	do
		local dragging = false
		local dragStart = nil
		local startPos = nil

		titleBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = mainFrame.Position

				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)

		self._dragInputConnection = UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = input.Position - dragStart
				mainFrame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	for _, action in ipairs(self.Actions) do
		createActionSection(action)
	end

	local _, rfContent = createSection(scrollingFrame, "RemoteFunctions", false)
	local rfDescription =
		createDescription(rfContent, "Arguments: separate values with ';' | auto parse: number / true / false / string")
	rfDescription.LayoutOrder = 0

	local groupedRemotes, sortedGroupKeys = groupRemoteFunctionsByCategory()

	for index, groupKey in ipairs(sortedGroupKeys) do
		local groupData = groupedRemotes[groupKey]

		local _, categoryContent = createSection(rfContent, groupData.DisplayName, false, {
			SectionBackgroundColor3 = Color3.fromRGB(46, 46, 46),
			HeaderBackgroundColor3 = Color3.fromRGB(65, 65, 65),
			HeaderTextSize = 18,
			PaddingLeft = 12,
			PaddingRight = 8,
			PaddingTop = 6,
			PaddingBottom = 6,
			InnerSpacing = 6,
		})

		for remoteIndex, entry in ipairs(groupData.Entries) do
			createRemoteRow(categoryContent, entry.FullName, entry.Remote, remoteIndex)
		end
	end

	self._toggleConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == self.ToggleKey then
			self._uiVisible = not self._uiVisible
			screenGui.Enabled = self._uiVisible
		end
	end)
end

function HackTracker:Destroy()
	if self._toggleConnection then
		self._toggleConnection:Disconnect()
		self._toggleConnection = nil
	end

	if self._dragInputConnection then
		self._dragInputConnection:Disconnect()
		self._dragInputConnection = nil
	end

	self:_disconnectRemoteEventListeners()

	for _, action in ipairs(self.Actions) do
		if typeof(action.Destroy) == "function" then
			local ok, err = pcall(function()
				action:Destroy()
			end)

			if not ok then
				warn(
					string.format(
						"HackTracker: Failed to destroy action '%s': %s",
						tostring(action.Name),
						tostring(err)
					)
				)
			end
		elseif typeof(action.Disable) == "function" then
			pcall(function()
				action:Disable()
			end)
		end
	end

	if self._screenGui then
		self._screenGui:Destroy()
		self._screenGui = nil
	end
end

return HackTracker
