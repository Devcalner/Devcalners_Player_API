dofile(minetest.get_modpath("player_api") .. "/api.lua")

-- Default player appearance
player_api.register_model("character.b3d", {
    animation_speed = 30,
    textures = {"character.png"},
    animations = {
        -- Standard animations
        stand          = {x = 0,   y = 79},
        lay            = {x = 162, y = 166, eye_height = 0.3, override_local = true,
                          collisionbox = {-0.6, 0.0, -0.6, 0.6, 0.3, 0.6}},
        walk           = {x = 168, y = 187, override_local = true},
        mine           = {x = 189, y = 198, override_local = true},
        walk_mine      = {x = 200, y = 219, override_local = true},

        -- Crouching animations
        crouch         = {x = 221, y = 225, speed = 5},
        crouch_walk    = {x = 226, y = 256, speed = 25, override_local = true},
        crouch_mine    = {x = 257, y = 270, speed = 50, override_local = true},
        crouch_mine_walk = {x = 271, y = 285, speed = 25, override_local = true},

        -- Climbing
climb = {x = 348, y = 370, override_local = true},
climb_idle = {x = 371, y = 400, override_local = true},

        -- Swimming
        swimming       = {x = 286, y = 310, speed = 10, override_local = true},
        float          = {x = 311, y = 347, override_local = true},

        -- Sitting animation
        sit            = {x = 81,  y = 160, eye_height = 0.8, override_local = true,
                          collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.0, 0.3}},
    },  -- Close animations table
    collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
    stepheight = 0.6,
    eye_height = 1.47,
})  -- Close register_model table

-- Update appearance when the player joins
minetest.register_on_joinplayer(function(player)
    player_api.set_model(player, "character.b3d")


end)