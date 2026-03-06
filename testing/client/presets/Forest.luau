--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ambience = require(ReplicatedStorage.Package)
local Track = Ambience.Track

local function makeSound(id: string, volume: number, looped: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped or false
	return sound
end

local birdsAmbient = makeSound("rbxassetid://9116971174", 0.4, true)

return Ambience.preset({
	priority = 0,
	sounds = {
		Track.looping(birdsAmbient):ModifyVolume(0.6):AutoFadeInOut(2),
	},
})
