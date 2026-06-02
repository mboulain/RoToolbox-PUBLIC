--!strict
local RunService = game:GetService("RunService")

local module = {}

if RunService:IsClient() then
	module.Client = require(script.Client.RoSpeechClient)

	return setmetatable(module, {
		__index = function(_, key)
			if key == "Server" then
				error("Cannot access RoSpeech.Server on the client!")
			end

			error("RoSpeech has no member named '" .. tostring(key) .. "'")
		end,
	})
else
	module.Server = require(script.Server.RoSpeechServer)

	return setmetatable(module, {
		__index = function(_, key)
			if key == "Client" then
				error("Cannot access RoSpeech.Client on the server!")
			end

			error("RoSpeech has no member named '" .. tostring(key) .. "'")
		end,
	})
end