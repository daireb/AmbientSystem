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

local windAmbient = makeSound("rbxassetid://5799870105", 0.4, true)

return Ambience.preset({
	priority = 0,
	sounds = {
		Track.looping(windAmbient)
			:ModifyVolume(function()
				local time = os.clock()
				return 0.7 + 0.3 * math.sin(time * 0.5)
			end)
			:AutoFadeInOut(2),
	},
})
