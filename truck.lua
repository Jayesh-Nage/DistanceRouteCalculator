-- Car profile for OSRM (US-wide friendly)
-- Optimized for regular cars, relaxed restrictions to maximize coverage

-- Vehicle properties
vehicle_height = 2.0   -- meters (~6.5 feet)
vehicle_width  = 2.0   -- meters (~6.5 feet)
vehicle_length = 5.0   -- meters (~16 feet)
maxweight      = 3.0   -- tons

-- Function to determine speed per road type
function get_speed(way, highway, max_speed)
    local speed = 30 -- default speed

    if highway == "motorway" then speed = 100
    elseif highway == "trunk" then speed = 90
    elseif highway == "primary" then speed = 70
    elseif highway == "secondary" then speed = 60
    elseif highway == "tertiary" then speed = 50
    elseif highway == "unclassified" then speed = 40
    elseif highway == "residential" then speed = 30
    elseif highway == "service" then speed = 20
    elseif highway == "track" then speed = 10
    end

    if max_speed and max_speed > 0 then
        speed = math.min(speed, max_speed)
    end
    return speed
end

-- Process each road
function process_way(way, result, relations)
    local highway = way:get_value_by_key("highway")
    if not highway then return end

    -- Skip non-drivable paths
    if highway == "footway" or highway == "cycleway" or highway == "steps" or
       highway == "bridleway" or highway == "pedestrian" then
        return
    end

    -- Access restrictions
    local access = way:get_value_by_key("access")
    if access == "no" or access == "private" then return end

    local vehicle = way:get_value_by_key("vehicle")
    if vehicle == "no" then return end

    local motor_vehicle = way:get_value_by_key("motor_vehicle")
    if motor_vehicle == "no" then return end

    -- Height restrictions (optional, usually not needed for cars)
    -- local maxheight = tonumber((way:get_value_by_key("maxheight") or ""):match("([%d%.]+)"))
    -- if maxheight and maxheight < vehicle_height then return end

    -- Assign speed
    local base_speed = get_speed(way, highway, nil)
    result:set_speed(base_speed)

    -- Handle oneway
    local oneway = way:get_value_by_key("oneway")
    if oneway == "yes" or oneway == "1" or oneway == "true" then
        result.backward_mode = 0
    elseif oneway == "-1" then
        result.forward_mode = 0
    end
end

-- Node processing
function process_node(node, result)
    return
end

-- Turn restrictions (optional)
function process_turn(turn, result)
    return
end
