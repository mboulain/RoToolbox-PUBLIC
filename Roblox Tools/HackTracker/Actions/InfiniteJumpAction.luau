local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local InfiniteJumpAction = {}
InfiniteJumpAction.__index = InfiniteJumpAction

function InfiniteJumpAction.new()
	local self = setmetatable({}, InfiniteJumpAction)

	self.Name = "Infinite Jump"
	self.Description = "Allows jumping even while in the air."
	self.Kind = "Toggle"
	self.DefaultEnabled = false

	self.Inputs = {
		{
			Key = "JumpHeight",
			Label = "Jump height",
			Type = "number",
			Default = 50,
			Placeholder = "Example: 50",
		},
	}

	self.Enabled = false
	self.JumpHeight = 50

	self._connection = nil

	return self
end

function InfiniteJumpAction:_disconnect()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

function InfiniteJumpAction:_getCharacter()
	local player = Players.LocalPlayer
	return player and player.Character
end

function InfiniteJumpAction:_getHumanoid()
	local character = self:_getCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function InfiniteJumpAction:_getHRP()
	local character = self:_getCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function InfiniteJumpAction:Enable(values)
	values = values or {}

	local jumpHeight = values.JumpHeight
	if typeof(jumpHeight) ~= "number" then
		jumpHeight = 50
	end

	jumpHeight = math.max(jumpHeight, 0)

	if self.Enabled then
		self:Disable()
	end

	self.Enabled = true
	self.JumpHeight = jumpHeight
	self:_disconnect()

	self._connection = UserInputService.JumpRequest:Connect(function()
		if not self.Enabled then
			return
		end

		local humanoid = self:_getHumanoid()
		local hrp = self:_getHRP()

		if not humanoid or not hrp then
			return
		end

		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

		local currentVelocity = hrp.AssemblyLinearVelocity

		hrp.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, self.JumpHeight, currentVelocity.Z)
	end)

	return true, string.format("Enabled (JumpHeight = %s)", tostring(self.JumpHeight))
end

function InfiniteJumpAction:Disable()
	if not self.Enabled then
		return true, "Already disabled"
	end

	self.Enabled = false
	self:_disconnect()

	return true, "Disabled"
end

function InfiniteJumpAction:Toggle(values)
	if self.Enabled then
		return self:Disable()
	else
		return self:Enable(values)
	end
end

function InfiniteJumpAction:Destroy()
	self:Disable()
end

return InfiniteJumpAction
