local Players = game:GetService("Players")

local SpeedHackAction = {}
SpeedHackAction.__index = SpeedHackAction

function SpeedHackAction.new()
	local self = setmetatable({}, SpeedHackAction)

	self.Name = "Speed Hack"
	self.Description = "Overrides the humanoid walk speed locally."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "Speed",
			Label = "Walk speed",
			Type = "number",
			Default = 32,
			Placeholder = "Example: 32",
		},
	}

	self.Enabled = false
	self.Speed = 32
	self._originalWalkSpeed = nil
	self._characterAddedConnection = nil

	return self
end

function SpeedHackAction:_disconnectConnections()
	if self._characterAddedConnection then
		self._characterAddedConnection:Disconnect()
		self._characterAddedConnection = nil
	end
end

function SpeedHackAction:_getHumanoid(): Humanoid?
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function SpeedHackAction:_applySpeed()
	local humanoid = self:_getHumanoid()
	if not humanoid then
		return false
	end

	if self._originalWalkSpeed == nil then
		self._originalWalkSpeed = humanoid.WalkSpeed
	end

	humanoid.WalkSpeed = self.Speed
	return true
end

function SpeedHackAction:_restoreSpeed()
	local humanoid = self:_getHumanoid()
	if humanoid and self._originalWalkSpeed ~= nil then
		humanoid.WalkSpeed = self._originalWalkSpeed
	end

	self._originalWalkSpeed = nil
end

function SpeedHackAction:Enable(values)
	values = values or {}

	local speed = values.Speed
	if typeof(speed) ~= "number" then
		speed = 32
	end

	speed = math.max(speed, 0)

	if self.Enabled then
		self:Disable()
	end

	self.Enabled = true
	self.Speed = speed
	self:_disconnectConnections()

	local applied = self:_applySpeed()
	if not applied then
		self.Enabled = false
		return false, "Character not ready"
	end

	self._characterAddedConnection = Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid and self.Enabled then
			if self._originalWalkSpeed == nil then
				self._originalWalkSpeed = humanoid.WalkSpeed
			end

			humanoid.WalkSpeed = self.Speed
		end
	end)

	return true, string.format("Enabled at walk speed %s", tostring(self.Speed))
end

function SpeedHackAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnectConnections()
	self:_restoreSpeed()

	return true, "Disabled"
end

function SpeedHackAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function SpeedHackAction:Destroy()
	self:Disable()
end

return SpeedHackAction
