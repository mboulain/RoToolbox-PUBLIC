local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VoiceChatService = game:GetService("VoiceChatService")

local LocalPlayer = Players.LocalPlayer

local Constants = require(script.Parent.Parent.Shared.Constants)
local ObservableValue = require(script.Parent.Parent.Shared.ObservableValue)
local Signal = require(script.Parent.Parent.Shared.Signal)
local TextHelpers = require(script.Parent.Parent.Shared.TextHelpers)

type ObservableValue<T> = typeof(ObservableValue.new(nil :: any))

export type ClientConfig = {
	MaxListeningDuration: number?,
	RemoteWaitTimeout: number?,
	Parent: Instance?,
	StopCommitGracePeriod: number?,
	VoiceEndDebounce: number?,
}

export type SpeechCommitPayload = {
	rawText: string,
	normalizedText: string,
	clientEndedReason: string,
	capturedAt: number,
}

export type RoSpeechClient = typeof(setmetatable({} :: {
	_config: ClientConfig,
	_destroyed: boolean,
	_connections: { RBXScriptConnection | { Disconnect: (self: any) -> () } },

	_runtimeFolder: Folder?,
	_deviceInput: AudioDeviceInput?,
	_speechToText: AudioSpeechToText?,
	_wire: Wire?,
	_serverRemote: RemoteEvent?,

	_latestRawText: string,
	_rawAtSessionStart: string,

	_listeningStartedAt: number?,
	_heartbeatConnection: RBXScriptConnection?,
	_stopToken: number,

	IsInitialized: ObservableValue<boolean>,
	IsListening: ObservableValue<boolean>,
	IsVoiceEligible: ObservableValue<boolean>,
	HasRuntimeObjects: ObservableValue<boolean>,
	IsMicrophoneMuted: ObservableValue<boolean>,
	IsVoiceDetected: ObservableValue<boolean>,
	LastTranscript: ObservableValue<string>,
	LastNormalizedTranscript: ObservableValue<string>,
	LastError: ObservableValue<string?>,

	OnRawTranscript: any,
	OnCommittedSpeech: any,
	OnWarning: any,
}, {}))

local RoSpeechClient = {}
RoSpeechClient.__index = RoSpeechClient

local DEFAULT_STOP_COMMIT_GRACE_PERIOD = 0.25
local DEFAULT_VOICE_END_DEBOUNCE = 0.9

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(connections)
end

local function mergeConfig(config: ClientConfig?): ClientConfig
	config = config or {}

	return {
		MaxListeningDuration = config.MaxListeningDuration or Constants.DEFAULTS.MaxListeningDuration,
		RemoteWaitTimeout = config.RemoteWaitTimeout or Constants.DEFAULTS.RemoteWaitTimeout,
		Parent = config.Parent or Constants.DEFAULTS.Parent,
		StopCommitGracePeriod = config.StopCommitGracePeriod or DEFAULT_STOP_COMMIT_GRACE_PERIOD,
		VoiceEndDebounce = config.VoiceEndDebounce or DEFAULT_VOICE_END_DEBOUNCE,
	}
end

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

local function extractSurplus(previousText: string, currentText: string): string
	if currentText == "" then
		return ""
	end

	if previousText == "" then
		return trim(currentText)
	end

	if currentText == previousText then
		return ""
	end

	if string.sub(currentText, 1, #previousText) == previousText then
		return trim(string.sub(currentText, #previousText + 1))
	end

	return trim(currentText)
end

function RoSpeechClient.new(config: ClientConfig?): RoSpeechClient
	local self = setmetatable({}, RoSpeechClient)

	self._config = mergeConfig(config)
	self._destroyed = false
	self._connections = {}

	self._runtimeFolder = nil
	self._deviceInput = nil
	self._speechToText = nil
	self._wire = nil
	self._serverRemote = nil

	self._latestRawText = ""
	self._rawAtSessionStart = ""

	self._listeningStartedAt = nil
	self._heartbeatConnection = nil
	self._stopToken = 0

	self.IsInitialized = ObservableValue.new(false)
	self.IsListening = ObservableValue.new(false)
	self.IsVoiceEligible = ObservableValue.new(false)
	self.HasRuntimeObjects = ObservableValue.new(false)
	self.IsMicrophoneMuted = ObservableValue.new(false)
	self.IsVoiceDetected = ObservableValue.new(false)
	self.LastTranscript = ObservableValue.new("")
	self.LastNormalizedTranscript = ObservableValue.new("")
	self.LastError = ObservableValue.new(nil)

	self.OnRawTranscript = Signal.new()
	self.OnCommittedSpeech = Signal.new()
	self.OnWarning = Signal.new()

	self:_bootstrap()

	return self
end

function RoSpeechClient:_warn(message: string)
	warn("[RoSpeechClient] " .. message)
	self.LastError:Set(message)
	self.OnWarning:Fire(message)
end

function RoSpeechClient:_track(connection)
	table.insert(self._connections, connection)
	return connection
end

function RoSpeechClient:_bootstrap()
	self:_refreshVoiceEligibility()
	self:_createRuntimeObjects()
	self:_bindRuntimeObservers()
	self:_resolveServerRemote()

	self.IsInitialized:Set(true)
end

function RoSpeechClient:_refreshVoiceEligibility()
	local success, result = pcall(function()
		return VoiceChatService:IsVoiceEnabledForUserIdAsync(LocalPlayer.UserId)
	end)

	if not success then
		self.IsVoiceEligible:Set(false)
		self:_warn("Unable to determine whether the local player has voice enabled.")
		return
	end

	self.IsVoiceEligible:Set(result == true)

	if result ~= true then
		self:_warn("The local player does not currently appear to have voice enabled.")
	end
end

function RoSpeechClient:_createRuntimeObjects()
	local parent = self._config.Parent
	if not parent then
		self:_warn("No valid parent was provided for RoSpeech runtime objects.")
		return
	end

	local existing = parent:FindFirstChild(Constants.RUNTIME_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = Constants.RUNTIME_FOLDER_NAME
	folder.Parent = parent

	local deviceInput = Instance.new("AudioDeviceInput")
	deviceInput.Name = "MicrophoneInput"
	deviceInput.Player = LocalPlayer
	deviceInput.Parent = folder

	local speechToText = Instance.new("AudioSpeechToText")
	speechToText.Name = "SpeechToText"
	speechToText.Enabled = true
	speechToText.Parent = folder

	local wire = Instance.new("Wire")
	wire.Name = "MicrophoneToSpeechToText"
	wire.SourceInstance = deviceInput
	wire.TargetInstance = speechToText
	wire.Parent = folder

	self._runtimeFolder = folder
	self._deviceInput = deviceInput
	self._speechToText = speechToText
	self._wire = wire

	self.HasRuntimeObjects:Set(true)
	self:_refreshRuntimeState()
end

function RoSpeechClient:_bindRuntimeObservers()
	if not self._deviceInput or not self._speechToText then
		self:_warn("Runtime objects were not created, so runtime observers could not be bound.")
		return
	end

	self:_track(self._deviceInput:GetPropertyChangedSignal("Muted"):Connect(function()
		self:_refreshRuntimeState()
	end))

	self:_track(self._speechToText:GetPropertyChangedSignal("VoiceDetected"):Connect(function()
		self:_onVoiceDetectedChanged()
	end))

	self:_track(self._speechToText:GetPropertyChangedSignal("Text"):Connect(function()
		self:_onTextChanged()
	end))
end

function RoSpeechClient:_resolveServerRemote()
	local remotesFolder = ReplicatedStorage:FindFirstChild(Constants.REMOTES_FOLDER_NAME)
	if not remotesFolder then
		local success, result = pcall(function()
			return ReplicatedStorage:WaitForChild(Constants.REMOTES_FOLDER_NAME, self._config.RemoteWaitTimeout)
		end)

		if success then
			remotesFolder = result
		end
	end

	if not remotesFolder then
		self:_warn("RoSpeech remotes folder was not found. Client captures will stay local until the server bridge exists.")
		return
	end

	local remote = remotesFolder:FindFirstChild(Constants.SPEECH_REMOTE_NAME)
	if not remote then
		local success, result = pcall(function()
			return remotesFolder:WaitForChild(Constants.SPEECH_REMOTE_NAME, self._config.RemoteWaitTimeout)
		end)

		if success then
			remote = result
		end
	end

	if remote and remote:IsA("RemoteEvent") then
		self._serverRemote = remote
	else
		self:_warn("Speech remote was not found or is not a RemoteEvent.")
	end
end

function RoSpeechClient:_refreshRuntimeState()
	local deviceInput = self._deviceInput
	local speechToText = self._speechToText

	if not deviceInput or not speechToText then
		self.HasRuntimeObjects:Set(false)
		self.IsMicrophoneMuted:Set(false)
		self.IsVoiceDetected:Set(false)
		return
	end

	self.HasRuntimeObjects:Set(true)
	self.IsMicrophoneMuted:Set(deviceInput.Muted == true)
	self.IsVoiceDetected:Set(speechToText.VoiceDetected == true)
end

function RoSpeechClient:_onVoiceDetectedChanged()
	if self._destroyed or not self._speechToText then
		return
	end

	self.IsVoiceDetected:Set(self._speechToText.VoiceDetected == true)
end

function RoSpeechClient:_onTextChanged()
	if self._destroyed or not self._speechToText then
		return
	end

	local rawText = self._speechToText.Text or ""
	self._latestRawText = rawText

	self.LastTranscript:Set(rawText)
	self.OnRawTranscript:Fire(rawText)
end

function RoSpeechClient:_canListen(): boolean
	if not self.HasRuntimeObjects:Get() then
		self:_warn("Cannot start listening because runtime objects are missing.")
		return false
	end

	if not self.IsVoiceEligible:Get() then
		self:_warn("Cannot start listening because the local player does not appear voice-enabled.")
		return false
	end

	if self.IsMicrophoneMuted:Get() then
		self:_warn("Cannot start listening because the microphone is muted.")
		return false
	end

	return true
end

function RoSpeechClient:StartListening(): boolean
	if self._destroyed then
		return false
	end

	self._stopToken += 1

	if self.IsListening:Get() then
		return true
	end

	if not self:_canListen() then
		return false
	end

	self._rawAtSessionStart = self._latestRawText
	self._listeningStartedAt = os.clock()

	self.IsListening:Set(true)

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self._heartbeatConnection = RunService.Heartbeat:Connect(function()
		self:_updateListeningWindow()
	end)

	return true
end

function RoSpeechClient:_updateListeningWindow()
	if not self.IsListening:Get() then
		return
	end

	local now = os.clock()

	if self._listeningStartedAt and (now - self._listeningStartedAt) >= (self._config.MaxListeningDuration :: number) then
		self:_commitAndClose("max_duration")
	end
end

function RoSpeechClient:_buildCommitPayload(reason: string): SpeechCommitPayload?
	local rawText = extractSurplus(self._rawAtSessionStart, self._latestRawText)
	rawText = TextHelpers.PrepareRawForTransport(rawText)

	if not TextHelpers.IsMeaningful(rawText) then
		return nil
	end

	local normalized = TextHelpers.NormalizeForServer(rawText)

	if not TextHelpers.IsMeaningful(normalized) then
		return nil
	end

	self.LastNormalizedTranscript:Set(normalized)

	local payload: SpeechCommitPayload = {
		rawText = rawText,
		normalizedText = normalized,
		clientEndedReason = reason,
		capturedAt = os.clock(),
	}

	return payload
end

function RoSpeechClient:_resetSessionState()
	self._rawAtSessionStart = self._latestRawText
	self._listeningStartedAt = nil
end

function RoSpeechClient:_commitAndClose(reason: string): string?
	if not self.IsListening:Get() then
		return nil
	end

	self.IsListening:Set(false)

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	local payload = self:_buildCommitPayload(reason)
	self:_resetSessionState()

	if not payload then
		return nil
	end

	self.OnCommittedSpeech:Fire(payload)

	if self._serverRemote then
		self._serverRemote:FireServer(payload)
	else
		self:_warn("Speech was captured locally but no server remote is currently available.")
	end

	return payload.normalizedText
end

function RoSpeechClient:StopListening(reason: string?): string?
	if self._destroyed then
		return nil
	end

	if not self.IsListening:Get() then
		return nil
	end

	local finalReason = reason or "manual"

	self._stopToken += 1
	local stopToken = self._stopToken

	local delayToUse: number
	if finalReason == "no_voice" then
		delayToUse = self._config.VoiceEndDebounce :: number
	else
		delayToUse = self._config.StopCommitGracePeriod :: number
	end

	if delayToUse <= 0 then
		return self:_commitAndClose(finalReason)
	end

	task.delay(delayToUse, function()
		if self._destroyed then
			return
		end

		if stopToken ~= self._stopToken then
			return
		end

		if not self.IsListening:Get() then
			return
		end

		self:_commitAndClose(finalReason)
	end)

	return nil
end

function RoSpeechClient:Destroy()
	if self._destroyed then
		return
	end

	self._stopToken += 1
	self:_commitAndClose("destroy")
	self._destroyed = true

	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	disconnectAll(self._connections)

	if self._runtimeFolder then
		self._runtimeFolder:Destroy()
		self._runtimeFolder = nil
	end

	self.OnRawTranscript:Destroy()
	self.OnCommittedSpeech:Destroy()
	self.OnWarning:Destroy()

	self.IsInitialized:Destroy()
	self.IsListening:Destroy()
	self.IsVoiceEligible:Destroy()
	self.HasRuntimeObjects:Destroy()
	self.IsMicrophoneMuted:Destroy()
	self.IsVoiceDetected:Destroy()
	self.LastTranscript:Destroy()
	self.LastNormalizedTranscript:Destroy()
	self.LastError:Destroy()
end

return RoSpeechClient