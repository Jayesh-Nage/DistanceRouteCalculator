-- Minimal truck profile for OSRM (US-wide / Texas)
api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')

-- Setup function
function setup()
  return {
    properties = {
      max_speed_for_map_matching    = 200/3.6, -- 200 km/h -> m/s
      weight_name                   = 'routability',
      process_call_tagless_node     = false,
      u_turn_penalty                = 10,
      continue_straight_at_waypoint = true,
      use_turn_restrictions         = true,
      left_hand_driving             = false,
    },

    default_mode        = mode.driving,
    default_speed       = 13,
    oneway_handling     = true,
    side_road_multiplier= 1.0,
    turn_penalty        = 5,
    speed_reduction     = 1.0,
    turn_bias           = 1.0,
    cardinal_directions = false,

    -- Truck dimensions (realistic)
    vehicle_height = 4.0,  -- meters
    vehicle_width  = 2.5,  -- meters
    vehicle_length = 12.0, -- meters
    vehicle_weight = 20000,-- kg

    -- Minimal restrictions: allow all roads
    barrier_whitelist          = Set {},
    access_tag_whitelist       = Set { 'yes', 'vehicle', 'motor_vehicle', 'truck' },
    access_tag_blacklist       = Set {},  -- no blacklisted tags
    restricted_access_tag_list = Set {},

    speeds = Sequence {
      highway = {
        motorway        = 90,
        motorway_link   = 60,
        trunk           = 80,
        trunk_link      = 50,
        primary         = 70,
        primary_link    = 40,
        secondary       = 60,
        secondary_link  = 30,
        tertiary        = 50,
        tertiary_link   = 25,
        unclassified    = 30,
        residential     = 25,
        living_street   = 15,
        service         = 20
      }
    },

    service_penalties = {},
    restricted_highway_whitelist = Set {},
    construction_whitelist        = Set {},
    route_speeds                  = {},
    bridge_speeds                 = {},
    surface_speeds                = {},
    tracktype_speeds              = {},
    smoothness_speeds             = {},
    maxspeed_table_default        = { urban=50, rural=90, trunk=110, motorway=130 },
    relation_types                = Sequence { "route" },
    highway_turn_classification   = {},
    access_turn_classification    = {}
  }
end

-- Minimal processing functions (do nothing)
function process_node(node, result) end
function process_way(way, result) end
function process_turn(turn) end

return {
  setup = setup,
  process_node = process_node,
  process_way = process_way,
  process_turn = process_turn
}
