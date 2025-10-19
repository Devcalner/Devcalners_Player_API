player_api = {}

-- Player animation blending
-- Note: This is currently broken due to a bug in Irrlicht, leave at 0
local animation_blend = 1.5

player_api.registered_models = {}

-- Local for speed.
local models = player_api.registered_models

local function collisionbox_equals(collisionbox, other_collisionbox)
	if collisionbox == other_collisionbox then
		return true
	end
	for index = 1, 6 do
		if collisionbox[index] ~= other_collisionbox[index] then
			return false
		end
	end
	return true
end

function player_api.register_model(name, def)
	models[name] = def
	def.visual_size = def.visual_size or {x = 1, y = 1}
	def.collisionbox = def.collisionbox or {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}
	def.stepheight = def.stepheight or 0.6
	def.eye_height = def.eye_height or 1.47

	-- Sort animations into property classes:
	-- Animations with same properties have the same _equals value
	for animation_name, animation in pairs(def.animations) do
		animation.eye_height = animation.eye_height or def.eye_height
		animation.collisionbox = animation.collisionbox or def.collisionbox
		animation.override_local = animation.override_local or false

		for _, other_animation in pairs(def.animations) do
			if other_animation._equals then
				if collisionbox_equals(animation.collisionbox, other_animation.collisionbox)
						and animation.eye_height == other_animation.eye_height then
					animation._equals = other_animation._equals
					break
				end
			end
		end
		animation._equals = animation._equals or animation_name
	end
end

-- Player stats and animations
-- model, textures, animation
local players = {}
player_api.player_attached = {}

local function get_player_data(player)
	return assert(players[player:get_player_name()])
end

function player_api.get_animation(player)
	return get_player_data(player)
end

-- Called when a player's appearance needs to be updated
function player_api.set_model(player, model_name)
	local player_data = get_player_data(player)
	if player_data.model == model_name then
		return
	end
	-- Update data
	player_data.model = model_name
	-- Clear animation data as the model has changed
	-- (required for setting the `stand` animation not to be a no-op)
	player_data.animation, player_data.animation_speed, player_data.animation_loop = nil, nil, nil

	local model = models[model_name]
	if model then
		player:set_properties({
			mesh = model_name,
			textures = player_data.textures or model.textures,
			visual = "mesh",
			visual_size = model.visual_size,
			stepheight = model.stepheight
		})
		-- sets local_animation, collisionbox & eye_height
		player_api.set_animation(player, "stand")
	else
		player:set_properties({
			textures = {"player.png", "player_back.png"},
			visual = "upright_sprite",
			visual_size = {x = 1, y = 2},
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.75, 0.3},
			stepheight = 0.6,
			eye_height = 1.625,
		})
	end
end

function player_api.get_textures(player)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	return assert(player_data.textures or (model and model.textures))
end

function player_api.set_textures(player, textures)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	local new_textures = assert(textures or (model and model.textures))
	player_data.textures = new_textures
	player:set_properties({textures = new_textures})
end

function player_api.set_texture(player, index, texture)
	local textures = table.copy(player_api.get_textures(player))
	textures[index] = texture
	player_api.set_textures(player, textures)
end

function player_api.set_animation(player, anim_name, speed, loop)
	local player_data = get_player_data(player)
	local model = models[player_data.model]
	if not (model and model.animations[anim_name]) then
		return
	end
	speed = speed or model.animation_speed
	if loop == nil then
		loop = true
	end
	if player_data.animation == anim_name
		and player_data.animation_speed == speed
		and player_data.animation_loop == loop
	then
		return
	end
	local previous_anim = model.animations[player_data.animation] or {}
	local anim = model.animations[anim_name]
	player_data.animation = anim_name
	player_data.animation_speed = speed
	player_data.animation_loop = loop
	-- If necessary change the local animation (only seen by the client of *that* player)
	-- `override_local` <=> suspend local animations while this one is active
	-- (this is basically a hack, proper engine feature needed...)
	if anim.override_local ~= previous_anim.override_local then
		if anim.override_local then
			local none = {x=0, y=0}
			player:set_local_animation(none, none, none, none, 1)
		else
			local a = model.animations
player:set_local_animation(
    a.crouch or a.stand,
    a.crouch_walk or a.walk,
    a.crouch_mine or a.mine,
    a.crouch_mine_walk or a.walk_mine,
    model.animation_speed or 30
)
end
	end
	-- Set the animation seen by everyone else
	player:set_animation(anim, speed, animation_blend, loop)
	-- Update related properties if they changed
	if anim._equals ~= previous_anim._equals then
		player:set_properties({
			collisionbox = anim.collisionbox,
			eye_height = anim.eye_height
		})
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	players[name] = {}
	player_api.player_attached[name] = false
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	players[name] = nil
	player_api.player_attached[name] = nil
end)

-- Localize for better performance.
local player_set_animation = player_api.set_animation
local player_attached = player_api.player_attached

-- Prevent knockback for attached players
local old_calculate_knockback = minetest.calculate_knockback
function minetest.calculate_knockback(player, ...)
	if player_attached[player:get_player_name()] then
		return 0
	end
	return old_calculate_knockback(player, ...)
end

-- Check each player and apply animations
function player_api.globalstep()
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local player_data = players[name]
        local model = player_data and models[player_data.model]
        if model and not player_attached[name] then
           local controls = player:get_player_control()
local vel = player:get_velocity()
local speed = math.sqrt(vel.x^2 + vel.z^2)


-- Check head position for water
local pos = player:get_pos()
local head_height = model.eye_height or 1.47
local head_pos = vector.add(pos, {x=0, y=head_height, z=0})
local node_head = minetest.get_node(head_pos)
local node_def = minetest.registered_nodes[node_head.name]
local is_swimming = node_def and node_def.liquidtype ~= "none"

-- Detect if player's feet are touching solid ground
local pos_feet = vector.add(pos, {x=0, y=0.1, z=0})
local node_feet = minetest.get_node(pos_feet)
local node_feet_def = minetest.registered_nodes[node_feet.name]
local touching_ground = node_feet_def
    and node_feet_def.walkable
    and not node_feet_def.climbable

-- Detect climbing
local pos_feet = vector.add(pos, {x = 0, y = 0.1, z = 0})
local node_feet = minetest.get_node(pos_feet)
local is_climbing = false
if minetest.registered_nodes[node_feet.name] then
    is_climbing = minetest.registered_nodes[node_feet.name].climbable or false
end

-- Movement detection
local is_moving = controls.up or controls.down or controls.left or controls.right

-- Sneaking detection (respect toggle_sneak setting)
local toggle_sneak = minetest.settings:get_bool("toggle_sneak")
local is_sneaking = controls.sneak and not toggle_sneak

-- Floating detection: in water, not moving, not mining
local is_floating = is_swimming and not is_moving and not is_mining

-- Mining detection
local is_mining = controls.LMB or controls.RMB
-- swim detection

-- Set animation speed modifier
local animation_speed_mod = model.animation_speed or 30
if is_sneaking then
    animation_speed_mod = animation_speed_mod / 2
end

-- Determine animation
local anim_to_set = "stand" -- default
if player:get_hp() == 0 then
    anim_to_set = "lay"

elseif is_swimming then
    if touching_ground then
        anim_to_set = "walk" -- walking on seabed
    elseif is_moving then
        anim_to_set = "swimming" -- swimming motion
    else
        anim_to_set = "float" -- idle floating
    end

elseif is_climbing then
    if is_moving or vel.y ~= 0 then
        anim_to_set = "climb"
    else
        anim_to_set = "climb_idle"
    end

elseif is_sneaking then
    if is_mining and is_moving then
        anim_to_set = "crouch_mine_walk"
    elseif is_mining then
        anim_to_set = "crouch_mine"
    elseif is_moving then
        anim_to_set = "crouch_walk"
    else
        anim_to_set = "crouch"
    end

elseif is_moving then
    if is_mining then
        anim_to_set = "walk_mine"
    else
        anim_to_set = "walk"
    end

elseif is_mining then
    anim_to_set = "mine"
end

if anim_to_set ~= player_data.animation then
    player_set_animation(player, anim_to_set, animation_speed_mod, true)
end


        end
    end
end

-- Register the globalstep outside the function
minetest.register_globalstep(function(...)
    player_api.globalstep(...)
end)

for _, api_function in pairs({"get_animation", "set_animation", "set_model", "set_textures"}) do
	local original_function = player_api[api_function]
	player_api[api_function] = function(player, ...)
		if not players[player:get_player_name()] then
			-- HACK for keeping backwards compatibility
			minetest.log("warning", api_function .. " called on offline player")
			return
		end
		return original_function(player, ...)
	end
end
