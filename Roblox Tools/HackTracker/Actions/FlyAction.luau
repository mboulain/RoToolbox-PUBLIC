local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local FlyAction = {}
FlyAction.__index = FlyAction

function FlyAction.new()
	local self = setmetatable({}, FlyAction)

	self.Name = "Fly"
	self.Description = "Allows the character to fly freely using movement keys."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "Speed",
			Label = "Fly speed",
			Type = "number",
			Default = 60,
			Placeholder = "Example: 60",
		},
	}

	self.Enabled = false
	self.Speed = 60

	self._heartbeatConnection = nil
	self._inputBeganConnection = nil
	self._inputEndedConnection = nil

	self._moveState = {
		Forward = false,
		Backward = false,
		Left = false,
		Right = false,
		Up = false,
		Down = false,
	}

	self._hoverY = nil

	return self
end

function FlyAction:_disconnectConnections()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	if self._inputBeganConnection then
		self._inputBeganConnection:Disconnect()
		self._inputBeganConnection = nil
	end

	if self._inputEndedConnection then
		self._inputEndedConnection:Disconnect()
		self._inputEndedConnection = nil
	end
end

function FlyAction:_resetMoveState()
	self._moveState.Forward = false
	self._moveState.Backward = false
	self._moveState.Left = false
	self._moveState.Right = false
	self._moveState.Up = false
	self._moveState.Down = false
end

function FlyAction:_getCharacterParts()
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then
		return nil, nil
	end

	return humanoid, hrp
end

function FlyAction:_setMovementKey(keyCode: Enum.KeyCode, isPressed: boolean)
	if keyCode == Enum.KeyCode.W then
		self._moveState.Forward = isPressed
	elseif keyCode == Enum.KeyCode.S then
		self._moveState.Backward = isPressed
	elseif keyCode == Enum.KeyCode.A then
		self._moveState.Left = isPressed
	elseif keyCode == Enum.KeyCode.D then
		self._moveState.Right = isPressed
	elseif keyCode == Enum.KeyCode.Space then
		self._moveState.Up = isPressed
	elseif keyCode == Enum.KeyCode.LeftControl or keyCode == Enum.KeyCode.C then
		self._moveState.Down = isPressed
	end
end

function FlyAction:_computeMoveDirection(): Vector3
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	local forward = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector

	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	local flatRight = Vector3.new(right.X, 0, right.Z)

	if flatForward.Magnitude > 0 then
		flatForward = flatForward.Unit
	end

	if flatRight.Magnitude > 0 then
		flatRight = flatRight.Unit
	end

	local direction = Vector3.zero

	if self._moveState.Forward then
		direction += flatForward
	end

	if self._moveState.Backward then
		direction -= flatForward
	end

	if self._moveState.Right then
		direction += flatRight
	end

	if self._moveState.Left then
		direction -= flatRight
	end

	if self._moveState.Up then
		direction += Vector3.yAxis
	end

	if self._moveState.Down then
		direction -= Vector3.yAxis
	end

	if direction.Magnitude > 0 then
		return direction.Unit
	end

	return Vector3.zero
end

function FlyAction:Enable(values)
	values = values or {}

	local speed = values.Speed
	if typeof(speed) ~= "number" then
		speed = 60
	end

	speed = math.max(speed, 0)

	if self.Enabled then
		self:Disable()
	end

	local humanoid, hrp = self:_getCharacterParts()
	if not humanoid or not hrp then
		return false, "Character not ready"
	end

	self.Enabled = true
	self._hoverY = hrp.Position.Y
	self.Speed = speed
	self:_resetMoveState()
	self:_disconnectConnections()

	self._inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.Enabled then
			return
		end

		self:_setMovementKey(input.KeyCode, true)
	end)

	self._inputEndedConnection = UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if not self.Enabled then
			return
		end

		self:_setMovementKey(input.KeyCode, false)
	end)

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		if not self.Enabled then
			return
		end

		local currentHumanoid, currentHrp = self:_getCharacterParts()
		if not currentHumanoid or not currentHrp then
			self:Disable()
			return
		end

		currentHumanoid:ChangeState(Enum.HumanoidStateType.Freefall)

		local moveDirection = self:_computeMoveDirection()
		local horizontal = Vector3.new(moveDirection.X, 0, moveDirection.Z)
		if horizontal.Magnitude > 0 then
			horizontal = horizontal.Unit * self.Speed
		else
			horizontal = Vector3.zero
		end

		local verticalVelocity = 0

		if self._moveState.Up then
			verticalVelocity = self.Speed
			self._hoverY = currentHrp.Position.Y
		elseif self._moveState.Down then
			verticalVelocity = -self.Speed
			self._hoverY = currentHrp.Position.Y
		else
			if self._hoverY == nil then
				self._hoverY = currentHrp.Position.Y
			end

			local deltaY = self._hoverY - currentHrp.Position.Y
			verticalVelocity = deltaY * 10
		end

		currentHrp.AssemblyLinearVelocity = Vector3.new(horizontal.X, verticalVelocity, horizontal.Z)
	end)

	return true, string.format("Enabled at speed %s", tostring(self.Speed))
end

function FlyAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnectConnections()
	self:_resetMoveState()

	local humanoid, hrp = self:_getCharacterParts()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
	end

	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	self._hoverY = nil
	return true, "Disabled"
end

function FlyAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function FlyAction:Destroy()
	self:Disable()
end

return FlyAction
