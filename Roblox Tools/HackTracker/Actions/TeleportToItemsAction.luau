local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local TeleportToItemsAction = {}
TeleportToItemsAction.__index = TeleportToItemsAction

function TeleportToItemsAction.new()
	local self = setmetatable({}, TeleportToItemsAction)

	self.Name = "Teleport To Tagged Items"
	self.Description = "Moves the character toward tagged objects at a chosen speed."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "Tag",
			Label = "Tag to move toward",
			Type = "string",
			Default = "",
			Placeholder = "Example: Collectible",
		},
		{
			Key = "Speed",
			Label = "Teleport speed",
			Type = "number",
			Default = 80,
			Placeholder = "Example: 80",
		},
		{
			Key = "TriggerDistance",
			Label = "Trigger distance",
			Type = "number",
			Default = 50,
			Placeholder = "Example: 50",
		},
		{
			Key = "GoNextAuto",
			Label = "Auto-teleport to next item after target reached",
			Type = "boolean",
			Default = false,
		},
	}

	self.Enabled = false

	self.Tag = nil
	self.Speed = 80
	self.TriggerDistance = 50
	self.GoNextAuto = false

	self._heartbeatConnection = nil
	self._orderedTargets = {}
	self._currentTargetIndex = 1

	return self
end

function TeleportToItemsAction:_getTargetPart(item: Instance): BasePart?
	if item:IsA("BasePart") then
		return item
	elseif item:IsA("Model") then
		return item.PrimaryPart
	end

	return nil
end

function TeleportToItemsAction:_disconnectHeartbeat()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
end

function TeleportToItemsAction:_rebuildTargets()
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		self._orderedTargets = {}
		self._currentTargetIndex = 1
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		self._orderedTargets = {}
		self._currentTargetIndex = 1
		return
	end

	local entries = {}

	for _, item in ipairs(CollectionService:GetTagged(self.Tag)) do
		local part = self:_getTargetPart(item)

		if part and part.Parent then
			table.insert(entries, {
				Instance = item,
				Part = part,
				Distance = (part.Position - hrp.Position).Magnitude,
			})
		end
	end

	table.sort(entries, function(a, b)
		return a.Distance < b.Distance
	end)

	self._orderedTargets = entries
	self._currentTargetIndex = 1
end

function TeleportToItemsAction:_getCurrentTarget()
	return self._orderedTargets[self._currentTargetIndex]
end

function TeleportToItemsAction:_moveToNextTarget()
	self._currentTargetIndex += 1
end

function TeleportToItemsAction:Enable(values)
	values = values or {}

	local tag = values.Tag
	local speed = values.Speed
	local triggerDistance = values.TriggerDistance
	local goNextAuto = values.GoNextAuto

	if typeof(tag) ~= "string" or tag == "" then
		warn("TeleportToItemsAction: Missing or invalid tag.")
		return false, "Missing tag"
	end

	if typeof(speed) ~= "number" then
		speed = 80
	end

	if typeof(triggerDistance) ~= "number" then
		triggerDistance = 50
	end

	if typeof(goNextAuto) ~= "boolean" then
		goNextAuto = false
	end

	speed = math.max(speed, 1)
	triggerDistance = math.max(triggerDistance, 0)

	if self.Enabled then
		self:Disable()
	end

	self.Enabled = true
	self.Tag = tag
	self.Speed = speed
	self.TriggerDistance = triggerDistance
	self.GoNextAuto = goNextAuto

	self:_disconnectHeartbeat()
	self:_rebuildTargets()

	if #self._orderedTargets == 0 then
		self.Enabled = false
		return false, string.format("No tagged items found for '%s'", tag)
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not self.Enabled then
			return
		end

		local player = Players.LocalPlayer
		local character = player and player.Character
		if not character then
			self:Disable()
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			self:Disable()
			return
		end

		local targetEntry = self:_getCurrentTarget()
		if not targetEntry then
			self:Disable()
			return
		end

		local targetPart = targetEntry.Part
		if not targetPart or not targetPart.Parent then
			self:_moveToNextTarget()

			if self:_getCurrentTarget() == nil then
				self:Disable()
			end

			return
		end

		local targetPosition = targetPart.Position
		local toTarget = targetPosition - hrp.Position
		local distance = toTarget.Magnitude

		if distance <= self.TriggerDistance then
			if self.GoNextAuto then
				self:_moveToNextTarget()

				if self:_getCurrentTarget() == nil then
					self:Disable()
				end
			else
				self:Disable()
			end

			return
		end

		local moveStep = self.Speed * deltaTime
		local nextPosition: Vector3

		if moveStep >= distance then
			nextPosition = targetPosition
		else
			nextPosition = hrp.Position + toTarget.Unit * moveStep
		end

		character:PivotTo(CFrame.new(nextPosition, targetPart.Position))
	end)

	return true,
		string.format(
			"Enabled for tag '%s' at speed %s with trigger distance %s and auto-next %s",
			self.Tag,
			tostring(self.Speed),
			tostring(self.TriggerDistance),
			tostring(self.GoNextAuto)
		)
end

function TeleportToItemsAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnectHeartbeat()

	self.Tag = nil
	self.Speed = 80
	self.TriggerDistance = 50
	self.GoNextAuto = false

	self._orderedTargets = {}
	self._currentTargetIndex = 1

	return true, "Disabled"
end

function TeleportToItemsAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function TeleportToItemsAction:Destroy()
	self:Disable()
end

return TeleportToItemsAction
