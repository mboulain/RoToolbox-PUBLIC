local Helpers = {}

function Helpers.GetCamera()
	return workspace.CurrentCamera
end

function Helpers.WorldToScreenPosition(worldPosition: Vector3)
	local camera = Helpers.GetCamera()
	if not camera then
		return nil
	end

	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)

	return {
		Position = UDim2.fromOffset(viewportPoint.X, viewportPoint.Y),
		OnScreen = onScreen,
		Depth = viewportPoint.Z,
	}
end

return Helpers