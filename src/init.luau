--!strict
local LightingModule = require(script.Lighting)
local TrackModule = require(script.Track)

type Track = TrackModule.Track
type LightingData = LightingModule.LightingData
type ResolvableLightingData = LightingModule.ResolvableLightingData

export type Preset = {
	priority: number?,
	lighting: ResolvableLightingData?,
	sounds: { Track }?,
}

type LayerState = {
	id: string,
	preset: Preset,
	fadeToken: number,
}

type TransitionOptions = {
	transition: number?,
}

local presets: { [string]: Preset } = {}
local active_layers: { LayerState } = {}

local lighting_transition_token = 0
local dynamic_loop_token = 0
local current_lighting_state: LightingData = {}

local function is_empty_lighting(data: LightingData): boolean
	return next(data) == nil
end

local function get_priority(preset: Preset): number
	return preset.priority or 0
end

local function sort_active_layers()
	table.sort(active_layers, function(a, b)
		return get_priority(a.preset) > get_priority(b.preset)
	end)
end

local function set_layer_tracks_volume(layer: LayerState, volume: number)
	local sounds = layer.preset.sounds
	if not sounds then
		return
	end
	for _, track in ipairs(sounds) do
		(track :: any):_SetTransitionVolume(volume)
	end
end

local function fade_layer_tracks(
	layer: LayerState,
	from_volume: number,
	to_volume: number,
	duration: number,
	stop_after: boolean
)
	local sounds = layer.preset.sounds
	if not sounds then
		return
	end

	layer.fadeToken += 1
	local my_token = layer.fadeToken

	if duration <= 0 then
		set_layer_tracks_volume(layer, to_volume)
		if stop_after then
			for _, track in ipairs(sounds) do
				track:Stop()
			end
		end
		return
	end

	task.spawn(function()
		local start_time = os.clock()
		while os.clock() - start_time < duration do
			if layer.fadeToken ~= my_token then
				return
			end
			local alpha = (os.clock() - start_time) / duration
			local volume = from_volume + (to_volume - from_volume) * alpha
			set_layer_tracks_volume(layer, volume)
			task.wait()
		end

		if layer.fadeToken ~= my_token then
			return
		end

		set_layer_tracks_volume(layer, to_volume)
		if stop_after then
			for _, track in ipairs(sounds) do
				track:Stop()
			end
		end
	end)
end

local function collect_lighting_layers(): { ResolvableLightingData }
	local layers = {}
	for _, layer in ipairs(active_layers) do
		if layer.preset.lighting then
			table.insert(layers, layer.preset.lighting :: ResolvableLightingData)
		end
	end
	return layers
end

local function write_lighting_snapshot(data: LightingData)
	if is_empty_lighting(data) then
		LightingModule.clear_lighting()
	else
		LightingModule.write_lightingdata(data)
		LightingModule.clear_stale_instances(data)
	end
end

local function apply_lighting_target(target: LightingData, transition: number?)
	lighting_transition_token += 1
	local my_token = lighting_transition_token
	local duration = transition or 0

	if duration <= 0 or is_empty_lighting(current_lighting_state) then
		write_lighting_snapshot(target)
		current_lighting_state = target
		return
	end

	task.spawn(function()
		local start_state = current_lighting_state
		LightingModule.do_tween(duration, function(alpha)
			if lighting_transition_token ~= my_token then
				return false
			end
			local lerped = LightingModule.lerp_lightingdata(start_state, target, alpha)
			LightingModule.write_lightingdata(lerped)
			return true
		end)

		if lighting_transition_token ~= my_token then
			return
		end

		write_lighting_snapshot(target)
		current_lighting_state = target
	end)
end

local function refresh_lighting(transition: number?)
	local layers = collect_lighting_layers()
	local resolved, has_dynamic = LightingModule.resolve_lighting(layers)
	apply_lighting_target(resolved, transition)

	dynamic_loop_token += 1
	local my_token = dynamic_loop_token
	if not has_dynamic then
		return
	end

	task.spawn(function()
		while dynamic_loop_token == my_token do
			task.wait()
			local dynamic_resolved, still_dynamic = LightingModule.resolve_lighting(collect_lighting_layers())
			LightingModule.write_lightingdata(dynamic_resolved)
			LightingModule.clear_stale_instances(dynamic_resolved)
			current_lighting_state = dynamic_resolved
			if not still_dynamic then
				return
			end
		end
	end)
end

local function add_layer(id: string, preset: Preset, transition: number)
	local layer: LayerState = {
		id = id,
		preset = preset,
		fadeToken = 0,
	}
	table.insert(active_layers, layer)
	sort_active_layers()

	local sounds = preset.sounds
	if sounds then
		if transition > 0 then
			set_layer_tracks_volume(layer, 0)
		else
			set_layer_tracks_volume(layer, 1)
		end
		for _, track in ipairs(sounds) do
			track:Activate()
		end
		if transition > 0 then
			fade_layer_tracks(layer, 0, 1, transition, false)
		end
	end
end

local function remove_layer_at(index: number, transition: number)
	local layer = active_layers[index]
	table.remove(active_layers, index)

	if layer.preset.sounds then
		if transition > 0 then
			fade_layer_tracks(layer, 1, 0, transition, true)
		else
			for _, track in ipairs(layer.preset.sounds :: { Track }) do
				track:Stop()
			end
		end
	end
end

local function find_active_layer_index(id: string): number?
	for index, layer in ipairs(active_layers) do
		if layer.id == id then
			return index
		end
	end
	return nil
end

local function preset(p: Preset): Preset
	return p
end

local function register(id: string, value: Preset)
	if presets[id] then
		error(`Ambience: Preset "{id}" is already registered`)
	end
	presets[id] = value
end

local function registerFromFolder(folder: Instance)
	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("ModuleScript") then
			local preset_module = require(child) :: Preset
			register(child.Name, preset_module)
		end
	end
end

local function push(id: string, options: TransitionOptions?)
	local preset_data = presets[id]
	if not preset_data then
		error(`Ambience: No preset registered with id "{id}"`)
	end
	if find_active_layer_index(id) then
		return
	end

	local transition = options and options.transition or 0
	add_layer(id, preset_data, transition)
	refresh_lighting(transition)
end

local function pop(id: string, options: TransitionOptions?)
	local index = find_active_layer_index(id)
	if not index then
		return
	end

	local transition = options and options.transition or 0
	remove_layer_at(index, transition)
	refresh_lighting(transition)
end

local function clear(options: TransitionOptions?)
	local transition = options and options.transition or 0
	while #active_layers > 0 do
		remove_layer_at(1, transition)
	end
	refresh_lighting(transition)
end

local function set(id: string, options: TransitionOptions?)
	local transition = options and options.transition or 0
	for index = #active_layers, 1, -1 do
		if active_layers[index].id ~= id then
			remove_layer_at(index, transition)
		end
	end
	if not find_active_layer_index(id) then
		local preset_data = presets[id]
		if not preset_data then
			error(`Ambience: No preset registered with id "{id}"`)
		end
		add_layer(id, preset_data, transition)
	end
	refresh_lighting(transition)
end

local function isActive(id: string): boolean
	return find_active_layer_index(id) ~= nil
end

local function getActive(): { string }
	local ids = {}
	for _, layer in ipairs(active_layers) do
		table.insert(ids, layer.id)
	end
	return ids
end

return {
	register = register,
	registerFromFolder = registerFromFolder,
	push = push,
	pop = pop,
	set = set,
	clear = clear,
	isActive = isActive,
	getActive = getActive,
	preset = preset,
	Track = TrackModule,
}
