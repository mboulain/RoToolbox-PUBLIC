local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Shared.Constants)
local Signal = require(script.Parent.Parent.Shared.Signal)
local TextHelpers = require(script.Parent.Parent.Shared.TextHelpers)

export type ServerConfig = {
	MaxRawLength: number?,
	MaxNormalizedLength: number?,
}

export type SpeechPayload = {
	rawText: string,
	normalizedText: string,
	clientEndedReason: string,
	capturedAt: number,
}

export type CleanedSpeechPayload = {
	Player: Player,
	RawText: string,
	CleanedText: string,
	ClientEndedReason: string,
	ClientCapturedAt: number?,
	ServerReceivedAt: number,
}

export type RoSpeechServer = typeof(setmetatable({} :: {
	_config: ServerConfig,
	_destroyed: boolean,

	_remotesFolder: Folder?,
	_speechRemote: RemoteEvent?,

	OnSpeech: any,
	OnWarning: any,
}, {}))

local RoSpeechServer = {}
RoSpeechServer.__index = RoSpeechServer

local DEFAULT_MAX_RAW_LENGTH = 300
local DEFAULT_MAX_NORMALIZED_LENGTH = 160

local function mergeConfig(config: ServerConfig?): ServerConfig
	config = config or {}

	return {
		MaxRawLength = config.MaxRawLength or DEFAULT_MAX_RAW_LENGTH,
		MaxNormalizedLength = config.MaxNormalizedLength or DEFAULT_MAX_NORMALIZED_LENGTH,
	}
end

function RoSpeechServer.new(config: ServerConfig?): RoSpeechServer
	assert(RunService:IsServer(), "RoSpeechServer.new() can only be called on the server.")

	local self = setmetatable({}, RoSpeechServer)

	self._config = mergeConfig(config)
	self._destroyed = false

	self._remotesFolder = nil
	self._speechRemote = nil

	self.OnSpeech = Signal.new()
	self.OnWarning = Signal.new()

	self:_bootstrap()

	return self
end

function RoSpeechServer:_warn(message: string)
	warn("[RoSpeechServer] " .. message)
	self.OnWarning:Fire(message)
end

function RoSpeechServer:_bootstrap()
	self:_ensureRemotes()
	self:_bindRemote()
end

function RoSpeechServer:_ensureRemotes()
	local remotesFolder = ReplicatedStorage:FindFirstChild(Constants.REMOTES_FOLDER_NAME)
	if remotesFolder and not remotesFolder:IsA("Folder") then
		remotesFolder:Destroy()
		remotesFolder = nil
	end

	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = Constants.REMOTES_FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	local speechRemote = remotesFolder:FindFirstChild(Constants.SPEECH_REMOTE_NAME)
	if speechRemote and not speechRemote:IsA("RemoteEvent") then
		speechRemote:Destroy()
		speechRemote = nil
	end

	if not speechRemote then
		speechRemote = Instance.new("RemoteEvent")
		speechRemote.Name = Constants.SPEECH_REMOTE_NAME
		speechRemote.Parent = remotesFolder
	end

	self._remotesFolder = remotesFolder
	self._speechRemote = speechRemote
end

function RoSpeechServer:_bindRemote()
	if not self._speechRemote then
		self:_warn("Speech remote could not be created.")
		return
	end

	self._speechRemote.OnServerEvent:Connect(function(player: Player, payload: any)
		print(("Received speech from %s: %s"):format(player.Name, tostring(payload)))
		self:_onSpeechReceived(player, payload)
	end)
end

function RoSpeechServer:_isPayloadValid(payload: any): boolean
	if type(payload) ~= "table" then
		return false
	end

	if type(payload.rawText) ~= "string" then
		return false
	end

	if type(payload.normalizedText) ~= "string" then
		return false
	end

	if type(payload.clientEndedReason) ~= "string" then
		return false
	end

	if payload.capturedAt ~= nil and type(payload.capturedAt) ~= "number" then
		return false
	end

	return true
end

function RoSpeechServer:_cleanPayload(player: Player, payload: SpeechPayload): CleanedSpeechPayload?
	local rawText = payload.rawText
	local normalizedText = payload.normalizedText

	if #rawText > (self._config.MaxRawLength :: number) then
		rawText = string.sub(rawText, 1, self._config.MaxRawLength :: number)
	end

	if #normalizedText > (self._config.MaxNormalizedLength :: number) then
		normalizedText = string.sub(normalizedText, 1, self._config.MaxNormalizedLength :: number)
	end

	local cleanedFromRaw = TextHelpers.NormalizeForServer(rawText, self._config.MaxNormalizedLength)
	local cleanedFromClientNormalized = TextHelpers.NormalizeForServer(normalizedText, self._config.MaxNormalizedLength)

	local cleanedText = cleanedFromRaw
	if cleanedFromClientNormalized ~= "" then
		cleanedText = cleanedFromClientNormalized
	end

	if not TextHelpers.IsMeaningful(cleanedText) then
		return nil
	end

	local result: CleanedSpeechPayload = {
		Player = player,
		RawText = rawText,
		CleanedText = cleanedText,
		ClientEndedReason = payload.clientEndedReason,
		ClientCapturedAt = payload.capturedAt,
		ServerReceivedAt = os.clock(),
	}

	return result
end

function RoSpeechServer:_onSpeechReceived(player: Player, payload: any)
	if self._destroyed then
		warn(("Received speech from %s after server was destroyed. Ignoring."):format(player.Name))
		return
	end

	if not self:_isPayloadValid(payload) then
		self:_warn(("Rejected invalid speech payload from %s."):format(player.Name))
		return
	end

	local cleanedPayload = self:_cleanPayload(player, payload)
	if not cleanedPayload then
		self:_warn(("Rejected speech from %s because it was not meaningful after cleaning."):format(player.Name))
		return
	end

	self.OnSpeech:Fire(cleanedPayload)
end

function RoSpeechServer:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true

	self.OnSpeech:Destroy()
	self.OnWarning:Destroy()
end

return RoSpeechServer