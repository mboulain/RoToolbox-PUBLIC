local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ItemMagnetAction = {}
ItemMagnetAction.__index = ItemMagnetAction

function ItemMagnetAction.new()
	local self = setmetatable({}, ItemMagnetAction)

	self.Name = "Item Magnet"
	self.Description = "Attracts tagged items locally toward the player."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "Tag",
			Label = "Tag to attract",
			Type = "string",
			Default = "",
			Placeholder = "Example: Collectible",
		},
		{
			Key = "Speed",
			Label = "Magnet speed",
			Type = "number",
			Default = 60,
			Placeholder = "Example: 60",
		},
	}

	self.Enabled = false
	self.Tag = nil
	self.Speed = 60
	self._heartbeatConnection = nil

	return self
end

function ItemMagnetAction:_getTargetPart(item: Instance): BasePart?
	if item:IsA("BasePart") then
		return item
	elseif item:IsA("Model") and item.PrimaryPart then
		return item.PrimaryPart
	end

	return nil
end

function ItemMagnetAction:_disconnectHeartbeat()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
end

function ItemMagnetAction:Enable(values)
	values = values or {}

	local tag = values.Tag
	local speed = values.Speed

	if typeof(tag) ~= "string" or tag == "" then
		warn("ItemMagnetAction: Missing or invalid tag.")
		return false, "Missing tag"
	end

	if typeof(speed) ~= "number" then
		speed = 60
	end

	speed = math.max(speed, 0)

	if self.Enabled then
		self:Disable()
	end

	self.Enabled = true
	self.Tag = tag
	self.Speed = speed

	self:_disconnectHeartbeat()

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not self.Enabled then
			return
		end

		local player = Players.LocalPlayer
		local character = player and player.Character
		if not character then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		for _, item in ipairs(CollectionService:GetTagged(self.Tag)) do
			local targetPart = self:_getTargetPart(item)
			if not targetPart then
				continue
			end

			if (targetPart.Position - hrp.Position).Magnitude < 50 then
				if targetPart.Anchored then
					targetPart.Anchored = false
				end

				local direction = hrp.Position - targetPart.Position
				if direction.Magnitude > 0.01 then
					targetPart.AssemblyLinearVelocity = direction.Unit * self.Speed
				end
			end
		end
	end)

	return true, string.format("Enabled for tag '%s' at speed %s", self.Tag, tostring(self.Speed))
end

function ItemMagnetAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnectHeartbeat()

	self.Tag = nil
	self.Speed = 60

	return true, "Disabled"
end

function ItemMagnetAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function ItemMagnetAction:Destroy()
	self:Disable()
end

return ItemMagnetAction
