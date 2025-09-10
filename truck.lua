-- US-wide truck profile for OSRM extraction
-- Minimal restrictions to ensure extraction works

api_version = 4

-- Required libraries
Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")
Relations = require("lib/relations")
Obstacles = require("lib/obstacles")
find_access_tag = require("lib/access").find_access_tag
Measure = require("lib/measure")

function setup()
  return {
    properties = {
      weight_name = 'routability',
      u_turn_penalty = 20,
      continue_straight_at_waypoint = true,
      use_turn_restrictions = true,
      left_hand_driving = false,
      max_speed_for_map_matching = 180/3.6 -- 180 km/h in m/s
    },

    default_mode = mode.driving,
    default_speed = 25,  -- default speed m/s (~90 km/h)
    oneway_handling = true,
    side_road_multiplier = 0.9,
    turn_penalty = 7.5,
    turn_bias = 1.0,

    vehicle_height = 4.5, -- meters
    vehicle_width  = 2.6,
    vehicle_length = 16.0,
    vehicle_weight = 36000, -- kg

    -- Keep barrier whitelist generous
    barrier_whitelist = Set {
      'cattle_grid','toll_booth','gate','lift_gate','no','entrance','arch'
    },

    -- Relaxed access tags
    access_tag_whitelist = Set {
      'yes','motorcar','motor_vehicle','vehicle','permissive','designated','hov'
    },

    access_tag_blacklist = Set {
      'private','emergency'
    },

    restricted_access_tag_list = Set {}, -- none for US-wide extraction

    access_tags_hierarchy = Sequence {
      'motorcar','motor_vehicle','vehicle','access'
    },

    -- Basic highway speed mapping (km/h)
    speeds = Sequence {
      highway = {
        motorway = 100,
        motorway_link = 50,
        trunk = 80,
        trunk_link = 40,
        primary = 70,
        primary_link = 30,
        secondary = 60,
        secondary_link = 25,
        tertiary = 50,
        tertiary_link = 20,
        unclassified = 25,
        residential = 20,
        living_street = 10,
        service = 15
      }
    },

    -- Simple excludable
    excludable = Sequence { Set {} },

    -- Minimal avoid set
    avoid = Set { 'impassable','steps','construction' },

    -- Use default maxspeed tables
    maxspeed_table_default = { urban = 50, rural = 90, trunk = 110, motorway = 130 },

    relation_types = Sequence { "route" },

    -- empty classifications
    highway_turn_classification = {},
    access_turn_classification = {}
  }
end

-- Minimal node processor
function process_node(profile, node, result, relations)
  Obstacles.process_node(profile, node)
end

-- Minimal way processor
function process_way(profile, way, result, relations)
  local data = {
    highway = way:get_value_by_key('highway'),
    bridge  = way:get_value_by_key('bridge')
  }
  if not data.highway or data.highway == '' then return end

  -- FIX: use Handlers (imported above) instead of undefined WayHandlers
  Handlers.run(profile, way, result, data, Sequence {
    Handlers.default_mode,
    Handlers.speed,
    Handlers.oneway,
    Handlers.names
  }, relations)
end

-- Minimal turn processor
function process_turn(profile, turn)
  turn.duration = turn.duration or 0
  turn.weight = turn.duration
end

return {
  setup = setup,
  process_node = process_node,
  process_way = process_way,
  process_turn = process_turn
}
