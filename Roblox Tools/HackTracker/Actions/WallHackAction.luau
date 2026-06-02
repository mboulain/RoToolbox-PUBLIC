local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WallHackAction = {}
WallHackAction.__index = WallHackAction

function WallHackAction.new()
	local self = setmetatable({}, WallHackAction)

	self.Name = "Wall Hack"
	self.Description = "Highlights players and/or tagged objects."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "HighlightPlayers",
			Label = "Highlight players",
			Type = "boolean",
			Default = true,
		},
		{
			Key = "Tag",
			Label = "Tag to highlight",
			Type = "string",
			Default = "",
			Placeholder = "Example: Collectible",
		},
	}

	self.Enabled = false
	self.HighlightPlayers = true
	self.Tag = ""

	self._heartbeatConnection = nil
	self._playerAddedConnection = nil
	self._playerRemovingConnection = nil
	self._characterAddedConnections = {}

	self._playerHighlights = {}
	self._tagHighlights = {}

	return self
end

function WallHackAction:_disconnectConnections()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
		self._playerAddedConnection = nil
	end

	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
		self._playerRemovingConnection = nil
	end

	for _, connection in pairs(self._characterAddedConnections) do
		connection:Disconnect()
	end
	table.clear(self._characterAddedConnections)
end

function WallHackAction:_destroyHighlights(highlightTable)
	for instance, highlight in pairs(highlightTable) do
		if highlight then
			highlight:Destroy()
		end
		highlightTable[instance] = nil
	end
end

function WallHackAction:_cleanupAllHighlights()
	self:_destroyHighlights(self._playerHighlights)
	self:_destroyHighlights(self._tagHighlights)
end

function WallHackAction:_createHighlight(adornee: Instance, fillColor: Color3, outlineColor: Color3): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "HackTrackerESP"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Adornee = adornee
	highlight.Parent = adornee

	return highlight
end

function WallHackAction:_isValidPlayerTarget(player: Player): boolean
	return player ~= Players.LocalPlayer
end

function WallHackAction:_addPlayerHighlight(player: Player)
	if not self.HighlightPlayers then
		return
	end

	if not self:_isValidPlayerTarget(player) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	if self._playerHighlights[character] then
		return
	end

	local highlight = self:_createHighlight(character, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255))

	self._playerHighlights[character] = highlight
end

function WallHackAction:_removePlayerHighlightForCharacter(character: Model)
	local highlight = self._playerHighlights[character]
	if highlight then
		highlight:Destroy()
		self._playerHighlights[character] = nil
	end
end

function WallHackAction:_refreshPlayerHighlights()
	for character, highlight in pairs(self._playerHighlights) do
		if not character or not character.Parent then
			if highlight then
				highlight:Destroy()
			end
			self._playerHighlights[character] = nil
		end
	end

	if not self.HighlightPlayers then
		self:_destroyHighlights(self._playerHighlights)
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		self:_addPlayerHighlight(player)
	end
end

function WallHackAction:_isValidTaggedTarget(instance: Instance): boolean
	return instance ~= nil and instance.Parent ~= nil
end

function WallHackAction:_addTaggedHighlight(instance: Instance)
	if self.Tag == "" then
		return
	end

	if not self:_isValidTaggedTarget(instance) then
		return
	end

	if self._tagHighlights[instance] then
		return
	end

	local highlight = self:_createHighlight(instance, Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 80, 80))

	self._tagHighlights[instance] = highlight
end

function WallHackAction:_refreshTaggedHighlights()
	for instance, highlight in pairs(self._tagHighlights) do
		if not instance or not instance.Parent then
			if highlight then
				highlight:Destroy()
			end
			self._tagHighlights[instance] = nil
		end
	end

	if self.Tag == "" then
		self:_destroyHighlights(self._tagHighlights)
		return
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.Tag)) do
		self:_addTaggedHighlight(instance)
	end
end

function WallHackAction:_bindPlayerEvents()
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		if self.HighlightPlayers then
			local connection = player.CharacterAdded:Connect(function(character)
				task.defer(function()
					if self.Enabled and self.HighlightPlayers and character and character.Parent then
						self:_addPlayerHighlight(player)
					end
				end)
			end)

			self._characterAddedConnections[player] = connection
		end
	end)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		local connection = self._characterAddedConnections[player]
		if connection then
			connection:Disconnect()
			self._characterAddedConnections[player] = nil
		end

		if player.Character then
			self:_removePlayerHighlightForCharacter(player.Character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer then
			local connection = player.CharacterAdded:Connect(function(character)
				task.defer(function()
					if self.Enabled and self.HighlightPlayers and character and character.Parent then
						self:_addPlayerHighlight(player)
					end
				end)
			end)

			self._characterAddedConnections[player] = connection
		end
	end
end

function WallHackAction:Enable(values)
	values = values or {}

	local highlightPlayers = values.HighlightPlayers
	local tag = values.Tag

	if typeof(highlightPlayers) ~= "boolean" then
		highlightPlayers = true
	end

	if typeof(tag) ~= "string" then
		tag = ""
	end

	if self.Enabled then
		self:Disable()
	end

	self.Enabled = true
	self.HighlightPlayers = highlightPlayers
	self.Tag = tag

	self:_disconnectConnections()
	self:_cleanupAllHighlights()
	self:_bindPlayerEvents()

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not self.Enabled then
			return
		end

		self:_refreshPlayerHighlights()
		self:_refreshTaggedHighlights()
	end)

	self:_refreshPlayerHighlights()
	self:_refreshTaggedHighlights()

	local targetSummary = {}
	if self.HighlightPlayers then
		table.insert(targetSummary, "players")
	end
	if self.Tag ~= "" then
		table.insert(targetSummary, string.format("tag '%s'", self.Tag))
	end

	if #targetSummary == 0 then
		return true, "Enabled, but no targets configured"
	end

	return true, "Enabled for " .. table.concat(targetSummary, " and ")
end

function WallHackAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnectConnections()
	self:_cleanupAllHighlights()

	self.HighlightPlayers = true
	self.Tag = ""

	return true, "Disabled"
end

function WallHackAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function WallHackAction:Destroy()
	self:Disable()
end

return WallHackAction
