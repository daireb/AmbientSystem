--!strict
--[[
	Ambience - Unified ambient lighting and sound system for Roblox

	Usage:
	```lua
	local Ambience = require(path.to.Ambience)

	-- Lighting
	Ambience.Lighting.Register(myScene)
	Ambience.Lighting.SetActive("sunset", { tweenTime = 2 })

	-- Sound
	Ambience.Sound.Register(mySoundscape)
	Ambience.Sound.SetActive("forest", { fadeTime = 1 })
	```
]]

local Lighting = require(script.LightingSceneService)
local Sound = require(script.Soundscapes)

return {
	Lighting = Lighting,
	Sound = Sound,

	-- Re-export constructors for convenience
	LightingScene = Lighting.Scene,
	Soundscape = Sound.Soundscape,
	SoundscapeTrack = Sound.Track,
}
