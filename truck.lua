-- Truck profile for OSRM (US-wide friendly)
-- Optimized for 32-foot moving trucks, relaxed restrictions to maximize coverage

-- Vehicle properties
vehicle_height = 4.0   -- meters (~13 feet)
vehicle_width  = 2.6   -- meters (~8.5 feet)
vehicle_length = 9.8   -- meters (~32 feet)
maxweight      = 12.0  -- tons

-- Function to determine speed per road type
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

    if max_speed and max_speed > 0 then
        speed = math.min(speed, max_speed)
    end
    return speed
end

-- Process each road
function process_way(way, result, relations)
    local highway = way:get_value_by_key("highway")
    if not highway then return end

    -- Skip only clearly non-drivable paths
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

    -- Relaxed height restrictions (commented out for full coverage)
    -- local maxheight = tonumber((way:get_value_by_key("maxheight") or ""):match("([%d%.]+)"))
    -- if maxheight and maxheight < vehicle_height - 1 then
    --     return
    -- end

    -- Ignore weight restrictions to maximize coverage
    -- local maxweight_way = tonumber((way:get_value_by_key("maxweight") or ""):match("([%d%.]+)"))
    -- if maxweight_way and maxweight_way < maxweight - 2 then
    --     return
    -- end

    -- Assign speed
    local base_speed = get_speed(way, highway, nil)
    result:set_speed(base_speed * 0.85) -- apply truck penalty

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
