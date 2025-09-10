-- Minimal truck profile for testing (US-wide)
-- No restrictions, includes all roads

-- Speed assignment per road type
function get_speed(way, highway, max_speed)
    local speed = 25 -- default speed
    if highway == "motorway" then speed = 80
    elseif highway == "trunk" then speed = 75
    elseif highway == "primary" then speed = 60
    elseif highway == "secondary" then speed = 50
    elseif highway == "tertiary" then speed = 40
    elseif highway == "unclassified" then speed = 35
    elseif highway == "residential" then speed = 25
    elseif highway == "service" then speed = 20
    elseif highway == "track" then speed = 10
    end
    return speed
end

-- Process each way: no filtering at all
function process_way(way, result, relations)
    -- Assign speed
    local highway = way:get_value_by_key("highway")
    local base_speed = get_speed(way, highway, nil)
    result:set_speed(base_speed)

    -- Handle oneway if present
    local oneway = way:get_value_by_key("oneway")
    if oneway == "yes" or oneway == "1" or oneway == "true" then
        result.backward_mode = 0
    elseif oneway == "-1" then
        result.forward_mode = 0
    end
end

-- Node processing (do nothing)
function process_node(node, result)
    return
end

-- Turn processing (do nothing)
function process_turn(turn, result)
    return
end
