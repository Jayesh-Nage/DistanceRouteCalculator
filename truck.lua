api_version = 4
Set = require('lib/set')
Sequence = require('lib/sequence')

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
        vehicle_width = 2.5,
        vehicle_length = 12.0,
        vehicle_weight = 20000
    }
end

-- Minimal process_way: mark every highway as usable
function process_way(way, result)
    local highway = way:get_value_by_key("highway")
    if not highway then return end
    result.forward_speed = 50
    result.backward_speed = 50
    result.weight = 1
    result.duration = 1
end

-- Minimal empty functions
function process_node(node, result) end
function process_turn(turn) end

return {
    setup = setup,
    process_way = process_way,
    process_node = process_node,
    process_turn = process_turn
}
