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

local rainAmbient = makeSound("rbxassetid://9064263922", 0.5, true)
local thunderSounds = {
	makeSound("rbxassetid://4961240438", 0.8),
}

return Ambience.preset({
	priority = 10,
	lighting = {
		Lighting = {
			FogEnd = 1800,
			FogStart = 80,
			FogColor = Color3.fromRGB(95, 103, 120),
			Brightness = 1.4,
		},
		Atmosphere = {
			Density = 0.45,
			Haze = 3,
			Color = Color3.fromRGB(150, 165, 180),
		},
	},
	sounds = {
		Track.looping(rainAmbient):ModifyVolume(0.7):AutoFadeInOut(3),
		Track.random(thunderSounds):ModifyVolume(0.6):AddRandomDelay(10, 30),
	},
})
