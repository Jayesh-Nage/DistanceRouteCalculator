-- Car profile for OSRM
api_version = 4

Set = require('lib/set')
Sequence = require('lib/sequence')
Handlers = require("lib/way_handlers")
Relations = require("lib/relations")
Obstacles = require("lib/obstacles")
find_access_tag = require("lib/access").find_access_tag
limit = require("lib/maxspeed").limit
Utils = require("lib/utils")
Measure = require("lib/measure")

function setup()
  return {
    properties = {
      max_speed_for_map_matching      = 200/3.6, -- 200 km/h -> m/s
      weight_name                     = 'routability',
      process_call_tagless_node       = false,
      u_turn_penalty                  = 10,
      continue_straight_at_waypoint   = true,
      use_turn_restrictions           = true,
      left_hand_driving               = false,
    },

    default_mode             = mode.driving,
    default_speed            = 13,
    oneway_handling          = true,
    side_road_multiplier     = 0.9,
    turn_penalty             = 5,
    speed_reduction          = 0.9,
    turn_bias                = 1.05,
    cardinal_directions      = false,

    -- Car-specific vehicle dimensions
    vehicle_height = 1.6,  -- meters
    vehicle_width  = 1.8,  -- meters
    vehicle_length = 4.5,  -- meters
    vehicle_weight = 1500, -- kg

    suffix_list = {
      'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'North', 'South', 'West', 'East'
    },

    barrier_whitelist = Set {
      'cattle_grid',
      'border_control',
      'toll_booth',
      'sally_port',
      'gate',
      'lift_gate',
      'no',
      'entrance',
      'height_restrictor',
      'arch'
    },

    access_tag_whitelist = Set {
      'yes',
      'motorcar',
      'motor_vehicle',
      'vehicle',
      'permissive',
      'designated',
      'hov'
    },

    access_tag_blacklist = Set {
      'no',
      'agricultural',
      'forestry',
      'emergency',
      'psv',
      'customers',
      'private',
      'delivery',
      'destination'
    },

    restricted_access_tag_list = Set {
      'private',
      'delivery',
      'destination',
      'customers'
    },

    access_tags_hierarchy = Sequence {
      'motorcar',
      'motor_vehicle',
      'vehicle',
      'access'
    },

    service_tag_forbidden = Set {
      'emergency_access'
    },

    restrictions = Sequence {
      'motorcar',
      'motor_vehicle',
      'vehicle'
    },

    classes = Sequence {
      'toll', 'motorway', 'ferry', 'restricted', 'tunnel'
    },

    excludable = Sequence {
      Set {'toll'},
      Set {'motorway'},
      Set {'ferry'}
    },

    avoid = Set {
      'area',
      'reversible',
      'impassable',
      'hov_lanes',
      'steps',
      'construction',
      'proposed'
    },

    speeds = Sequence {
      highway = {
        motorway        = 110,
        motorway_link   = 60,
        trunk           = 100,
        trunk_link      = 50,
        primary         = 80,
        primary_link    = 40,
        secondary       = 60,
        secondary_link  = 30,
        tertiary        = 50,
        tertiary_link   = 25,
        unclassified    = 30,
        residential     = 30,
        living_street   = 15,
        service         = 20
      }
    },

    service_penalties = {
      alley             = 0.5,
      parking           = 0.5,
      parking_aisle     = 0.5,
      driveway          = 0.5,
      ["drive-through"] = 0.5,
      ["drive-thru"]    = 0.5
    },

    restricted_highway_whitelist = Set {
      'motorway', 'motorway_link', 'trunk', 'trunk_link',
      'primary', 'primary_link', 'secondary', 'secondary_link',
      'tertiary', 'tertiary_link', 'residential', 'living_street',
      'unclassified', 'service'
    },

    construction_whitelist = Set {
      'no', 'widening', 'minor'
    },

    route_speeds = {
      ferry = 5,
      shuttle_train = 10
    },

    bridge_speeds = {
      movable = 5
    },

    surface_speeds = {
      asphalt = nil,
      concrete = nil,
      ["concrete:plates"] = nil,
      ["concrete:lanes"] = nil,
      paved = nil,
      cement = 100,
      compacted = 80,
      fine_gravel = 60,
      paving_stones = 50,
      metal = 60,
      bricks = 50,
      grass = 30,
      wood = 30,
      sett = 30,
      gravel = 40,
      unpaved = 40,
      dirt = 30,
      cobblestone = 20,
      mud = 10
    },

    tracktype_speeds = {
      grade1 =  60,
      grade2 =  40,
      grade3 =  30,
      grade4 =  25,
      grade5 =  20
    },

    smoothness_speeds = {
      intermediate    =  80,
      bad             =  40,
      very_bad        =  20,
      horrible        =  10,
      very_horrible   =  5,
      impassable      =  0
    },

    maxspeed_table_default = {
      urban = 50,
      rural = 90,
      trunk = 110,
      motorway = 130
    },

    relation_types = Sequence {
      "route"
    },

    highway_turn_classification = {},
    access_turn_classification = {}
  }
end

-- Node, way, turn processing logic can remain identical to truck.lua
process_node = require("truck").process_node
process_way  = require("truck").process_way
process_turn = require("truck").process_turn

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn
}
