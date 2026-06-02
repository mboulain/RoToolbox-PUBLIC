local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local NoClipAction = {}
NoClipAction.__index = NoClipAction

function NoClipAction.new()
	local self = setmetatable({}, NoClipAction)

	self.Name = "NoClip"
	self.Description = "Allows the player to move through walls and objects."
	self.Kind = "Toggle"
	self.DefaultEnabled = false
	self.Inputs = {}

	self.Enabled = false
	self._heartbeatConnection = nil

	return self
end

function NoClipAction:Enable()
	if self.Enabled then
		return true, "Already enabled"
	end

	self.Enabled = true

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not self.Enabled then
			return
		end

		local player = Players.LocalPlayer
		local character = player and player.Character
		if not character then
			return
		end

		for _, obj in ipairs(character:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.CanCollide = false
			end
		end
	end)

	return true, "Enabled"
end

function NoClipAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	local player = Players.LocalPlayer
	local character = player and player.Character
	if character then
		for _, obj in ipairs(character:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.CanCollide = true
			end
		end
	end

	return true, "Disabled"
end

function NoClipAction:Toggle()
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable()
	end
end

function NoClipAction:Destroy()
	self:Disable()
end

return NoClipAction
