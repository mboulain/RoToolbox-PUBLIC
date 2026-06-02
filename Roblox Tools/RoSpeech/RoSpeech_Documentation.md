# RoSpeech Documentation

## Overview

**RoSpeech** is a modular speech-to-text system for Roblox that allows developers to capture player voice input, convert it into text, and process it securely on the server.

It is built on top of Roblox's `AudioSpeechToText` system and provides:

- Controlled listening sessions (manual start/stop)
- Clean client-server architecture
- Observable state for UI integration
- Safe server-side validation and normalization

---

## Architecture

RoSpeech is split into two main parts:

### Client (`RoSpeech.Client`)
Responsible for:
- Capturing microphone input
- Converting speech to text
- Managing listening sessions
- Sending speech data to the server

### Server (`RoSpeech.Server`)
Responsible for:
- Receiving speech data
- Validating and sanitizing input
- Emitting clean, usable speech events


###### BONUS : ServerStorage (`TextCommandMatcher`)
Responsible for:
- Translating what RoSpeech receives into a usable command by the developer
- Given with the tool, but to place manually inside ServerStorage

---

## Installation

Place the `RoSpeech` module inside `ReplicatedStorage`.

Expected structure:

```
RoSpeech
├── Client
│   └── RoSpeechClient.luau
├── Server
│   └── RoSpeechServer.luau
├── Shared
│   ├── Constants.luau
│   ├── ObservableValue.luau
│   ├── Signal.luau
│   └── TextHelpers.luau
└── init.luau
```

---

## Basic Usage

### Client

```lua
local RoSpeech = require(ReplicatedStorage.RoSpeech)

local speechClient = RoSpeech.Client.new()

speechClient:StartListening()

-- Later...
speechClient:StopListening("manual")
```

---

### Server

```lua
local RoSpeech = require(ReplicatedStorage.RoSpeech)

local speechServer = RoSpeech.Server.new()

speechServer.OnSpeech:Connect(function(data)
    print(data.Player.Name, data.CleanedText)
end)
```

---

## Listening Flow

1. `StartListening()` begins a capture session
2. Player speaks into microphone
3. Roblox generates live transcript updates
4. `StopListening()` finalizes the capture
5. Client sends payload to server
6. Server validates and emits clean result

---

## Client API

### Constructor

```lua
RoSpeech.Client.new(config?)
```

#### Config options

| Property | Type | Default | Description |
|--------|------|--------|------------|
| MaxListeningDuration | number | 8 | Max session duration |
| StopCommitGracePeriod | number | 0.25 | Delay before commit |
| VoiceEndDebounce | number | 0.9 | Delay after voice stops |
| RemoteWaitTimeout | number | 5 | Remote lookup timeout |
| Parent | Instance | workspace | Runtime objects parent |

---

### Methods

#### `StartListening()`

Starts a listening session.

#### `StopListening(reason?)`

Stops the session and commits captured speech.

Common reasons:
- `"manual"`
- `"no_voice"`

#### `Destroy()`

Cleans up the instance and all resources.

---

## Client Observables

```lua
speechClient.IsListening:Observe(function(value) end)
```

| Property | Description |
|--------|------------|
| IsInitialized | Client ready |
| IsListening | Currently capturing |
| IsVoiceEligible | Voice enabled for player |
| HasRuntimeObjects | Audio objects created |
| IsMicrophoneMuted | Mic muted state |
| IsVoiceDetected | Voice currently detected |
| LastTranscript | Raw transcript |
| LastNormalizedTranscript | Cleaned transcript |
| LastError | Last warning/error |

---

## Client Signals

### `OnRawTranscript`

```lua
speechClient.OnRawTranscript:Connect(function(text)
    print(text)
end)
```

### `OnCommittedSpeech`

```lua
speechClient.OnCommittedSpeech:Connect(function(payload)
    print(payload.normalizedText)
end)
```

Payload:

```
{
    rawText: string,
    normalizedText: string,
    clientEndedReason: string,
    capturedAt: number,
}
```

---

## Server API

### Constructor

```lua
RoSpeech.Server.new(config?)
```

#### Config options

| Property | Type | Default | Description |
|--------|------|--------|------------|
| MaxRawLength | number | 300 |
| MaxNormalizedLength | number | 160 |

---

## Server Signals

### `OnSpeech`

```lua
speechServer.OnSpeech:Connect(function(data)
    print(data.Player, data.CleanedText)
end)
```

Payload:

```
{
    Player: Player,
    RawText: string,
    CleanedText: string,
    ClientEndedReason: string,
    ClientCapturedAt: number?,
    ServerReceivedAt: number,
}
```

---

## Important Notes

### No Automatic Silence Commit

RoSpeech does NOT auto-stop on silence.

You must explicitly call:

```
StopListening("no_voice")
```

---

### Voice Requirements

- Voice chat must be enabled
- Microphone must not be muted
- Experience must support voice

---

### Language Behavior

Roblox speech recognition may:
- Translate some words to English
- Leave others unchanged

Do not rely on consistent translation.

---

## Best Practices

- Handle gameplay logic on the server
- Use flexible matching (not strict equality)
- Expect imperfect transcripts
- Use observables for UI

---

## Example

```lua
speechClient.IsVoiceDetected:Observe(function(isTalking)
    if isTalking then
        speechClient:StartListening()
    else
        speechClient:StopListening("no_voice")
    end
end)
```

---

## Summary

RoSpeech is a lightweight, robust speech system for Roblox:

- Modular
- Secure
- Real-time capable
- Designed for gameplay integration

---

Enjoy building voice-driven gameplay 🚀
