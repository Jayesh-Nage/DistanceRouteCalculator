api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
WayHandlers = require("lib/way_handlers")
Relations = require("lib/relations")
Obstacles = require("lib/obstacles")
find_access_tag = require("lib/access").find_access_tag
limit = require("lib/maxspeed").limit
Utils = require("lib/utils")
Measure = require("lib/measure")

function setup()
  return {
    properties = {
      max_speed_for_map_matching      = 120/3.6, -- 120 km/h
      weight_name                     = 'routability',
      process_call_tagless_node       = false,
      u_turn_penalty                  = 40,
      continue_straight_at_waypoint   = true,
      use_turn_restrictions           = true,
      left_hand_driving               = false,
    },

    default_mode              = mode.driving,
    default_speed             = 10,
    oneway_handling           = true,
    side_road_multiplier      = 0.7,
    turn_penalty              = 15.0,
    speed_reduction           = 0.75,
    turn_bias                 = 1.05,
    cardinal_directions       = false,

    -- Vehicle dimensions (bigger than car)
    vehicle_height = 4.0,   -- meters
    vehicle_width  = 2.6,   -- meters
    vehicle_length = 9.8,   -- meters
    vehicle_weight = 12000, -- kg (12 tons)

    suffix_list = {
      'N','NE','E','SE','S','SW','W','NW','North','South','West','East'
    },

    barrier_whitelist = Set {
      'cattle_grid','toll_booth','border_control','gate','lift_gate','no','entrance'
    },

    access_tag_whitelist = Set {
      'yes','motor_vehicle','hgv','goods','vehicle','permissive','designated'
    },

    access_tag_blacklist = Set {
      'no','private','forestry','agricultural','delivery','destination','psv'
    },

    service_access_tag_blacklist = Set { 'private' },

    restricted_access_tag_list = Set {
      'private','delivery','destination'
    },

    access_tags_hierarchy = Sequence {
      'hgv','goods','motor_vehicle','vehicle','access'
    },

    service_tag_forbidden = Set {
      'emergency_access'
    },

    restrictions = Sequence {
      'hgv','goods','motor_vehicle','vehicle'
    },

    classes = Sequence {
        'toll','motorway','ferry','restricted','tunnel'
    },

    excludable = Sequence {
        Set{'toll'},
        Set{'ferry'}
    },

    avoid = Set {
      'area','reversible','impassable','hov_lanes','steps','construction','proposed'
    },

    -- Speeds adapted for trucks (lower than cars)
    speeds = Sequence {
      highway = {
        motorway        = 88, -- ~55 mph
        motorway_link   = 40,
        trunk           = 75,
        trunk_link      = 35,
        primary         = 64, -- ~40 mph
        primary_link    = 30,
        secondary       = 55,
        secondary_link  = 25,
        tertiary        = 40,
        tertiary_link   = 20,
        unclassified    = 25,
        residential     = 25,
        living_street   = 10,
        service         = 15
      }
    },

    service_penalties = {
      alley             = 0.4,
      parking           = 0.3,
      parking_aisle     = 0.3,
      driveway          = 0.3,
      ["drive-through"] = 0.3,
      ["drive-thru"]    = 0.3
    },

    restricted_highway_whitelist = Set {
      'motorway','motorway_link','trunk','trunk_link','primary','primary_link',
      'secondary','secondary_link','tertiary','tertiary_link','residential','unclassified','service'
    },

    construction_whitelist = Set {
      'no','widening','minor'
    },

    route_speeds = {
      ferry = 5,
      shuttle_train = 8
    },

    bridge_speeds = { movable = 5 },

    -- Surfaces (slower tolerance for trucks)
    surface_speeds = {
      asphalt = nil,
      concrete = nil,
      paved = nil,
      compacted = 60,
      fine_gravel = 50,
      gravel = 40,
      unpaved = 30,
      dirt = 20,
      sand = 15,
      mud = 5
    },

    tracktype_speeds = {
      grade1 = 50,
      grade2 = 30,
      grade3 = 20,
      grade4 = 15,
      grade5 = 10
    },

    smoothness_speeds = {
      intermediate =  60,
      bad          =  30,
      very_bad     =  15,
      horrible     =  5,
      impassable   =  0
    },

    maxspeed_table_default = {
      urban = 50,
      rural = 80,
      trunk = 90,
      motorway = 100
    },

    maxspeed_table = {
      ["de:motorway"] = 80,
      ["de:rural"] = 60,
      ["ru:motorway"] = 90,
      ["pl:motorway"] = 90,
      ["none"] = 100
    },

    relation_types = Sequence { "route" },

    highway_turn_classification = {},
    access_turn_classification  = {}
  }
end

-- Node processing
function process_node(profile, node, result, relations)
  local access = find_access_tag(node, profile.access_tags_hierarchy)
  if access and profile.access_tag_blacklist[access] then
    obstacle_map:add(node, Obstacle.new(obstacle_type.barrier))
  end
  Obstacles.process_node(profile, node)
end

-- Way processing
function process_way(profile, way, result, relations)
  local data = {
    highway = way:get_value_by_key('highway'),
    bridge = way:get_value_by_key('bridge'),
    route = way:get_value_by_key('route')
  }

  if (not data.highway or data.highway == '') and
     (not data.route or data.route == '') then
    return
  end

  handlers = Sequence {
    WayHandlers.default_mode,
    WayHandlers.blocked_ways,
    WayHandlers.avoid_ways,
    WayHandlers.handle_height,
    WayHandlers.handle_width,
    WayHandlers.handle_length,
    WayHandlers.handle_weight,
    WayHandlers.access,
    WayHandlers.oneway,
    WayHandlers.destinations,
    WayHandlers.ferries,
    WayHandlers.movables,
    WayHandlers.service,
    WayHandlers.speed,
    WayHandlers.maxspeed,
    WayHandlers.surface,
    WayHandlers.penalties,
    WayHandlers.classes,
    WayHandlers.turn_lanes,
    WayHandlers.classification,
    WayHandlers.roundabouts,
    WayHandlers.startpoint,
    WayHandlers.driving_side,
    WayHandlers.names,
    WayHandlers.weights,
    WayHandlers.way_classification_for_turn
  }

  WayHandlers.run(profile, way, result, data, handlers, relations)
end

-- Turn processing
function process_turn(profile, turn)
  local penalty = profile.turn_penalty
  if turn.is_u_turn then
    turn.duration = turn.duration + penalty + profile.properties.u_turn_penalty
  else
    turn.duration = turn.duration + penalty
  end
  turn.weight = turn.duration
end

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn
}
