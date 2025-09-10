api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")

function setup()
    return {
        properties = {
            max_speed_for_map_matching = 200/3.6,
            weight_name = 'routability',
            process_call_tagless_node = false,
            u_turn_penalty = 10,
            continue_straight_at_waypoint = true,
            use_turn_restrictions = true,
            left_hand_driving = false,
        },
        default_mode = mode.driving,
        default_speed = 13,
        vehicle_height = 4.0,
        vehicle_width  = 2.5,
        vehicle_length = 12.0,
        vehicle_weight = 20000
    }
end

-- Use OSRM’s built-in handlers for way processing
function process_way(profile, way, result)
    Handlers.handle_default(profile, way, result)
end

function process_node(node, result) end
function process_turn(turn) end

return {
    setup = setup,
    process_way = process_way,
    process_node = process_node,
    process_turn = process_turn
}
