-- Minimal Restrictive Truck Profile for OSRM (32-foot trucks)
-- OSRM API v4

api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
WayHandlers = require("lib/way_handlers")
Obstacles = require("lib/obstacles")

-- Toggle parsing mode (true = parsing, false = routing)
PARSING_MODE = true

-- Real truck dimensions (routing)
REAL_HEIGHT = 4.0     -- meters (13 ft)
REAL_WIDTH  = 2.6     -- meters (8.5 ft)
REAL_LENGTH = 9.8     -- meters (32 ft)
REAL_WEIGHT = 12000   -- kg (12 tons)

-- Relaxed dimensions for parsing (no edges removed)
PARSE_HEIGHT = 0.1
PARSE_WIDTH  = 0.1
PARSE_LENGTH = 0.1
PARSE_WEIGHT = 1

function setup()
  return {
    properties = {
      max_speed_for_map_matching     = 130/3.6,
      weight_name                    = 'routability',
      process_call_tagless_node      = false,
      u_turn_penalty                 = 30,
      continue_straight_at_waypoint  = true,
      use_turn_restrictions          = false,
      left_hand_driving              = false,
    },

    default_mode         = mode.driving,
    default_speed        = 15,
    oneway_handling      = true,
    side_road_multiplier = 0.9,
    turn_penalty         = 10,
    speed_reduction      = 0.9,
    turn_bias            = 1.0,
    cardinal_directions  = false,

    -- Vehicle dimensions (switch parsing/routing)
    vehicle_height = PARSING_MODE and PARSE_HEIGHT or REAL_HEIGHT,
    vehicle_width  = PARSING_MODE and PARSE_WIDTH or REAL_WIDTH,
    vehicle_length = PARSING_MODE and PARSE_LENGTH or REAL_LENGTH,
    vehicle_weight = PARSING_MODE and PARSE_WEIGHT or REAL_WEIGHT,

    suffix_list = { 'N','NE','E','SE','S','SW','W','NW' },

    barrier_whitelist = Set { 'cattle_grid', 'toll_booth', 'gate', 'lift_gate' },

    access_tag_whitelist = Set { 'yes', 'vehicle', 'permissive', 'designated', 'unknown' },
    access_tag_blacklist = Set {},  -- don't block any roads
    restricted_access_tag_list = Set {},
    access_tags_hierarchy = Sequence { 'vehicle', 'access' },

    service_tag_forbidden = Set {},
    restrictions = Sequence {},
    classes = Sequence { 'toll', 'ferry', 'restricted', 'tunnel' },
    excludable = Sequence { Set {'toll'}, Set {'ferry'} },

    -- Only avoid truly impassable
    avoid = Set { 'impassable', 'steps', 'construction', 'proposed' },

    speeds = Sequence {
      highway = {
        motorway        = 80,
        motorway_link   = 40,
        trunk           = 75,
        trunk_link      = 35,
        primary         = 60,
        primary_link    = 30,
        secondary       = 50,
        secondary_link  = 25,
        tertiary        = 40,
        tertiary_link   = 20,
        unclassified    = 25,
        residential     = 20,
        living_street   = 10,
        service         = 15
      }
    },

    service_penalties = { alley = 0.5, parking = 0.5, driveway = 0.5 },

    restricted_highway_whitelist = Set {
      'motorway','trunk','primary','secondary','tertiary',
      'residential','living_street','unclassified','service'
    },

    construction_whitelist = Set { 'no', 'minor' },
    route_speeds = { ferry = 5, shuttle_train = 10 },
    bridge_speeds = { movable = 5 },

    surface_speeds = {
      asphalt = nil, concrete = nil, paved = nil,
      dirt = 30, gravel = 40, sand = 20, mud = 10
    },

    tracktype_speeds = { grade1=50, grade2=40, grade3=30, grade4=25, grade5=20 },
    smoothness_speeds = {
      intermediate=50, bad=30, very_bad=20, horrible=10,
      very_horrible=5, impassable=0
    },

    maxspeed_table_default = { urban=50, rural=80, trunk=90, motorway=100 },
    maxspeed_table = {},
    relation_types = Sequence { "route" },
    highway_turn_classification = {},
    access_turn_classification = {}
  }
end

function process_node(profile, node, result, relations)
  Obstacles.process_node(profile, node)
end

function process_way(profile, way, result, relations)
  local data = {
    highway = way:get_value_by_key('highway'),
    bridge  = way:get_value_by_key('bridge'),
    route   = way:get_value_by_key('route')
  }

  if (not data.highway or data.highway == '') and (not data.route or data.route == '') then
    return
  end

  local handlers = Sequence {
    WayHandlers.default_mode,
    WayHandlers.speed,
    WayHandlers.maxspeed,
    WayHandlers.surface,
    WayHandlers.weights,
    WayHandlers.classes
  }

  WayHandlers.run(profile, way, result, data, handlers, relations)
end

function process_turn(profile, turn)
  local turn_penalty = profile.turn_penalty

  if turn.number_of_roads > 2 or turn.source_mode ~= turn.target_mode or turn.is_u_turn then
    turn.duration = turn.duration + turn_penalty
    if turn.is_u_turn then
      turn.duration = turn.duration + profile.properties.u_turn_penalty
    end
  end

  if profile.properties.weight_name == 'distance' then
     turn.weight = 0
  else
     turn.weight = turn.duration
  end
end

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn
}
