--!strict
local SoundService = game:GetService("SoundService")

export type Track = {
	IsActive: (self: Track) -> boolean,
	Activate: (self: Track) -> nil,
	Stop: (self: Track) -> nil,

	ModifyVolume: (self: Track, modifier: ((Sound) -> number) | number) -> Track,
	AutoFadeInOut: (self: Track, fade_length: number?) -> Track,
	OnlyStartPlayingIf: (self: Track, callback: () -> boolean) -> Track,
	OnlyPlayWhile: (self: Track, callback: (Sound) -> boolean) -> Track,
	AddRandomDelay: (self: Track, min: number, max: number) -> Track,

	_SetTransitionVolume: (self: Track, volume: number) -> nil,
}

type TrackPrivate = Track & {
	_currentSound: Sound?,
	_pickNextSound: ({ [string]: any }) -> Sound?,
	_computeVolume: (Sound) -> number,
	_continuePlaying: (Sound) -> boolean,
	_data: { [string]: any },
	_playingId: number,
	_transitionVolume: number,
}

local SOUND_FOLDER = Instance.new("Folder")
SOUND_FOLDER.Name = "AmbienceTrackSounds"
SOUND_FOLDER.Parent = SoundService

local Track = {}
Track.__index = Track

function Track.new(pick_new_sound: ({ [string]: any }) -> Sound?): Track
	local self = setmetatable({}, Track) :: any

	self._currentSound = nil
	self._pickNextSound = pick_new_sound
	self._data = {}
	self._computeVolume = function()
		return 1
	end
	self._continuePlaying = function()
		return true
	end
	self._playingId = -1
	self._transitionVolume = 1

	return self
end

function Track.looping(sound: Sound): Track
	return Track.new(function()
		return sound
	end)
end

function Track.random(sounds: { Sound }): Track
	return Track.new(function()
		return sounds[math.random(1, #sounds)]
	end)
end

function Track.ModifyVolume(self: TrackPrivate, modifier: ((Sound) -> number) | number): Track
	local callback: (Sound) -> number = if typeof(modifier) == "number"
		then function()
			return modifier
		end
		else modifier

	local old_callback = self._computeVolume
	self._computeVolume = function(sound: Sound)
		return old_callback(sound) * callback(sound)
	end

	return self
end

function Track.OnlyPlayWhile(self: TrackPrivate, callback: (Sound) -> boolean): Track
	local old_callback = self._continuePlaying
	self._continuePlaying = function(sound: Sound)
		return old_callback(sound) and callback(sound)
	end

	return self
end

function Track.AutoFadeInOut(self: TrackPrivate, fade_length: number?): Track
	local len = fade_length or 1
	return self:ModifyVolume(function(sound: Sound)
		local distance = (sound.TimeLength - sound.TimePosition) / len
		return math.clamp(distance, 0, 1) * math.clamp(sound.TimePosition / len, 0, 1)
	end)
end

function Track.OnlyStartPlayingIf(self: TrackPrivate, callback: () -> boolean): Track
	local old_f = self._pickNextSound
	self._pickNextSound = function(data)
		if not callback() then
			return nil
		end
		return old_f(data)
	end
	return self
end

function Track.AddRandomDelay(self: TrackPrivate, min: number, max: number): Track
	local old_f = self._pickNextSound
	self._pickNextSound = function(data: { nextSound: number? })
		if data.nextSound == nil then
			data.nextSound = os.clock() + min + math.random() * (max - min)
		end
		if os.clock() < (data.nextSound :: number) then
			return nil
		end

		data.nextSound = nil
		local new_sound = old_f(data)
		if new_sound then
			data.nextSound = os.clock() + min + math.random() * (max - min) + new_sound.TimeLength
		end
		return new_sound
	end
	return self
end

function Track.IsActive(self: TrackPrivate): boolean
	return self._playingId ~= -1
end

function Track.Activate(self: TrackPrivate)
	if self._playingId ~= -1 then
		return
	end

	local my_id = os.clock()
	self._playingId = my_id

	task.spawn(function()
		while self._playingId == my_id do
			if self._currentSound then
				self._currentSound:Stop()
			end

			local base_sound = self._pickNextSound(self._data)
			if not base_sound then
				self._currentSound = nil
				task.wait()
				continue
			end

			local sound = base_sound:Clone()
			sound.Parent = SOUND_FOLDER
			self._currentSound = sound

			sound:Play()
			local base_volume = sound.Volume
			local playing = true

			task.spawn(function()
				while playing and self._currentSound do
					sound.Volume = base_volume * self._computeVolume(self._currentSound) * self._transitionVolume

					local should_be_playing = self._continuePlaying(self._currentSound)
					if not should_be_playing then
						if sound.IsPlaying then
							sound:Pause()
						end
					elseif not sound.IsPlaying then
						sound:Resume()
					end

					task.wait()
				end
			end)

			sound.Ended:Wait()
			sound:Destroy()
			playing = false
		end
	end)
end

function Track.Stop(self: TrackPrivate)
	if self._playingId == -1 then
		return
	end

	self._playingId = -1
	if self._currentSound then
		self._currentSound:Stop()
		self._currentSound = nil
	end
end

function Track._SetTransitionVolume(self: TrackPrivate, volume: number)
	self._transitionVolume = volume
end

return Track
