-- Truck profile for 32-foot moving trucks (movers and packers)
-- Optimized for real-world truck routing with proper restrictions

-- Vehicle properties
vehicle_height = 4.0   -- meters (13 feet)
vehicle_width  = 2.6   -- meters (8.5 feet) 
vehicle_length = 9.8   -- meters (32 feet)
maxweight      = 12.0  -- tons

-- Function to get base speed for different road types
function get_speed(way, highway, max_speed)
    local speed = 0

    if highway == "motorway" then
        speed = 80
    elseif highway == "trunk" then
        speed = 75
    elseif highway == "primary" then
        speed = 60
    elseif highway == "secondary" then
        speed = 50
    elseif highway == "tertiary" then
        speed = 40
    elseif highway == "unclassified" then
        speed = 30
    elseif highway == "residential" then
        speed = 25
    elseif highway == "service" then
        speed = 15
    elseif highway == "track" then
        speed = 10
    else
        speed = 25
    end

    if max_speed and max_speed > 0 then
        speed = math.min(speed, max_speed)
    end

    return speed
end

-- Way processing
function process_way(way, result, relations)
    local highway = way:get_value_by_key("highway")
    if not highway then
        return
    end

    -- Skip obvious non-drivable roads
    if highway == "footway" or highway == "cycleway" or highway == "path" or
       highway == "steps" or highway == "pedestrian" or highway == "bridleway" then
        return
    end

    -- Skip very narrow roads
    local width = way:get_value_by_key("width")
    if width then
        local width_num = tonumber(width:match("([%d%.]+)"))
        if width_num and width_num < 2.5 then
            return
        end
    end

    -- Skip roads with low height restrictions
    local maxheight = way:get_value_by_key("maxheight")
    if maxheight then
        local height_num = tonumber(maxheight:match("([%d%.]+)"))
        if height_num and height_num < vehicle_height then
            return
        end
    end

    -- Skip roads with low weight restrictions
    local maxweight_way = way:get_value_by_key("maxweight")
    if maxweight_way then
        local weight_num = tonumber(maxweight_way:match("([%d%.]+)"))
        if weight_num and weight_num < maxweight then
            return
        end
    end

    -- Access restrictions
    local access = way:get_value_by_key("access")
    if access == "no" or access == "private" then
        return
    end

    local vehicle = way:get_value_by_key("vehicle")
    if vehicle == "no" then
        return
    end

    local motor_vehicle = way:get_value_by_key("motor_vehicle")
    if motor_vehicle == "no" then
        return
    end

    -- Compute base speed
    local base_speed = get_speed(way, highway, nil)
    if base_speed <= 0 then
        return
    end

    -- Apply truck penalty
    local truck_speed = base_speed * 0.85

    -- Assign speed
    result:set_speed(truck_speed)

    -- Handle oneway
    local oneway = way:get_value_by_key("oneway")
    if oneway == "yes" or oneway == "1" or oneway == "true" then
        result.backward_mode = 0
    elseif oneway == "-1" then
        result.forward_mode = 0
    end
end

-- Node processing (we don’t need restrictions at node level here)
function process_node(node, result)
    return
end

-- Turn restrictions (can be extended if needed)
function process_turn(turn, result)
    return
end
