meta:
  id: minecraft_proto
  file-extension: mcproto
  imports:
    - var_int
    - minecraft_nbt
  endian: be

####################################
  
seq:
  - id: a_0 # SB Handshake
    type: packet_w(false, game_state::handshake)
  - id: a_1 # SB Request
    type: packet_w(false, game_state::status)
  - id: a_2 # SB Response
    type: packet_w(false, game_state::status)
  - id: a_3 # CB Ping
    type: packet_w(false, game_state::status)
  - id: a_4 # SB Ping
    type: packet_w(false, game_state::status)
  - id: a_5 # SB Handshake
    type: packet_w(false, game_state::handshake)
  - id: a_6 # SB Login Start
    type: packet_w(false, game_state::login)
  - id: a_7 # CB Set Compression
    type: packet_w(false, game_state::login)
  - id: a_8 # CB Login Success
    type: packet_w(true, game_state::login)
  - id: a_9 # CB Play Join Game
    type: packet_w(true, game_state::play)  
  - id: a_10 # CB Plugin Message
    type: packet_w(true, game_state::play)
  - id: a_11 # CB Server Difficulty
    type: packet_w(true, game_state::play)
  - id: a_12 # CB Player Abilities
    type: packet_w(true, game_state::play)
  - id: a_13 # CB Held Item Change
    type: packet_w(true, game_state::play)
  - id: a_14 # CB Declare Recipies
    type: packet_w(true, game_state::play)
  - id: a_15 # CB Tags
    type: packet_w(true, game_state::play)
  - id: a_16 # CB Entity Status
    type: packet_w(true, game_state::play)
  - id: a_17 # CB Declare Commands
    type: packet_w(true, game_state::play)
  - id: a_18 # CB Unlock Recipies
    type: packet_w(true, game_state::play)
  - id: a_19 # Player position and look
    type: packet_w(true, game_state::play)
  - id: a_20 # Update Player List
    type: packet_w(true, game_state::play)
  - id: a_21 # Update Player List (latency)
    type: packet_w(true, game_state::play)
  - id: a_22 # Set View position
    type: packet_w(true, game_state::play)
  - id: a_23 # Update light & load chunk data
    type: packet_w(true, game_state::play)
    repeat: expr
    repeat-expr: 200
    
####################################
    
types:

  packet_w:
    params:
      - id: compressed
        type: bool
      - id: game_state
        type: u1
        enum: game_state
    seq:
      - id: serverbound
        type: u1
      - id: packet
        type: packet(compressed, serverbound == 1, game_state)

  packet:
    params:
      - id: compressed
        type: bool
      - id: server_bound
        type: bool
      - id: game_state
        type: u1
        enum: game_state
    seq:
      - id: length
        type: var_int
      - id: data_length
        type: var_int
        if: compressed
      - id: payload_c
        size: length.value - data_length.len
        if: compressed and (data_length.value != 0)
        process: zlib
        type: packet_data(server_bound, game_state)
      - id: payload_u1
        size: length.value
        if: not compressed
        type: packet_data(server_bound, game_state)
      - id: payload_u2
        size: length.value - data_length.len
        if: compressed and data_length.value == 0
        type: packet_data(server_bound, game_state)

  packet_data:
    params:
      - id: server_bound
        type: bool
      - id: game_state
        type: u1
        enum: game_state
    seq:
      - id: packet_id
        type: var_int
      - id: data
        type:
          switch-on: game_state
          cases:
            game_state::handshake: handshake_data(server_bound)
            game_state::status: status_data(server_bound)
            game_state::login: login_data(server_bound)
            game_state::play: play_data(server_bound)
            
  uncompressed_data:
    seq:
      - id: data_c
        type: u1
        if: _parent._parent._parent.data_length.value > 0
        repeat: expr
        repeat-expr: _parent._parent._parent.data_length.value - 1 # TODO!      
      - id: data_u
        type: u1
        if: _parent._parent._parent.data_length.value == 0
        repeat: expr
        repeat-expr: _parent._parent._parent.length.value - 2 # TODO!
            
####################################

### Handshake packets

  handshake_data:
    params:
      - id: server_bound
        type: bool
    seq:
      - id: sb
        if: server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: sb_handshake

  sb_handshake:
    seq:
      - id: protocol_version
        type: var_int
      - id: server_address
        type: string
      - id: server_port
        type: u2
      - id: next_state
        type: var_int
#        enum: handshake_state

### Status packets

  status_data:
    params:
      - id: server_bound
        type: bool
    seq:
      - id: cb
        if: not server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: cb_response
            0x01: csb_ping
      - id: sb
        if: server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: sb_request
            0x01: csb_ping
        
  sb_request:
    seq: [] 
        
  cb_response:
    seq:
      - id: json_response
        type: string
        
  csb_ping:
    seq:
      - id: payload
        type: s8

### Login packets

  login_data:
    params:
      - id: server_bound
        type: bool
    seq:
      - id: cb
        if: not server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: cb_disconnect
            0x01: cb_encryption_request
            0x02: cb_login_success
            0x03: cb_set_compression
            0x04: cb_login_plugin_request
      - id: sb
        if: server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: sb_login_start
            0x01: sb_encryption_response
            0x02: sb_login_plugin_response

  cb_disconnect: # 0x00
    seq:
      - id: reason
        type: string
        
  cb_encryption_request: # 0x01
    seq:
      - id: server_id
        type: string # no more than 20 chars
      - id: public_key_length
        type: var_int
      - id: public_key
        type: u1
        repeat: expr
        repeat-expr: public_key_length.value
      - id: verify_token_length
        type: var_int
      - id: verify_token
        type: u1
        repeat: expr
        repeat-expr: verify_token_length.value

  cb_login_success: # 0x02
    seq:
      - id: uuid
        type: string # No more than 36 chars
      - id: username
        type: string
        
  cb_set_compression: # 0x03
    seq:
      - id: threshold
        type: var_int
        
  cb_login_plugin_request: # 0x04
    seq:
      - id: message_id
        type: var_int
      - id: identifier
        type: string
      - id: data
        type: u1
        repeat: expr
        repeat-expr: _parent._parent._parent.length.value - message_id.len - identifier.len.len - identifier.len.value # TODO!
        
  sb_login_start: # 0x00
    seq:
      - id: name
        type: string # 16 chars
        
  sb_encryption_response: # 0x01
    seq:
      - id: shared_secret_length
        type: var_int
      - id: shared_secret
        type: u1
        repeat: expr
        repeat-expr: shared_secret_length.value
        
  sb_login_plugin_response: # 0x02
    seq:
      - id: message_id
        type: var_int
      - id: successful
        type: bool
      - id: data
        type: u1
        repeat: expr
        repeat-expr: _parent._parent._parent.length.value - message_id.len - 1 # TODO!

### Play packets

  play_data:
    params:
      - id: server_bound
        type: bool
    seq:
      - id: cb
        if: not server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x03: cb_spawn_living_entity
            0x0E: cb_server_difficulty
            0x12: cb_declare_commands
            0x19: cb_plugin_message
            0x1C: cb_entity_status
            0x22: cb_chunk_data
            0x25: cb_update_light
            0x26: cb_play_join_game
            0x32: cb_player_abilities
            0x34: cb_player_info
            0x36: cb_player_position_and_look
            0x37: cb_unlock_recipies
            0x40: cb_held_item_change
            0x41: cb_update_view_position
            0x44: cb_entity_metadata
            0x47: cb_entity_equipment
            0x59: cb_entity_properties
            0x5B: cb_declare_recipies
            0x5C: cb_tags
            _: uncompressed_data

      - id: sb
        if: server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            _: uncompressed_data

  cb_spawn_living_entity: # 0x03
    seq:
      - id: entity_id 
        type: var_int
      - id: entity_uuid 
        type: uuid
      - id: type 
        type: var_int
      - id: x 
        type: f8
      - id: y 
        type: f8
      - id: z 
        type: f8
      - id: yaw 
        type: angle
      - id: pitch 
        type: angle
      - id: head_pitch 
        type: angle
      - id: velocity_x 
        type: s2
      - id: velocity_y 
        type: s2
      - id: velocity_z 
        type: s2

  cb_server_difficulty: # 0x0E
    seq:
      - id: difficulty
        type: u1
        enum: server_difficulty
      - id: locked
        type: bool

  cb_declare_commands: # 0x12
    seq:
      - id: count
        type: var_int
      - id: nodes
        type: command_node
        repeat: expr
        repeat-expr: count.value
      - id: root_index
        type: var_int

  cb_plugin_message: # 0x19
    seq:
      - id: channel
        type: string
      - id: data
        type: u1
        repeat: expr
        repeat-expr: _parent._parent._parent.length.value - channel.len.value - channel.len.len - 2 # TODO!

  cb_entity_status: # 0x1C
    seq:
      - id: entity_id
        type: s4
      - id: entity_status
        type: u1

  cb_chunk_data: # 0x22
    seq:
      - id: chunk_x
        type: s4
      - id: chunk_z
        type: s4
      - id: is_full_chunk
        type: bool
      - id: primary_bit_mask
        type: var_int
      - id: heightmaps
        type: nbt
      - id: biomes
        type: s4
        repeat: expr
        repeat-expr: 1024
        if: is_full_chunk.value != 0
      - id: size # Unused; size of data in bytes
        type: var_int
      - id: data
        type: chunk_section
        repeat: expr
        repeat-expr: primary_bit_mask.bit_count
      - id: number_of_block_entities
        type: var_int
      - id: block_entities
        type: nbt
        repeat: expr
        repeat-expr: number_of_block_entities.value

  cb_update_light: # 0x25
    seq:
      - id: chunk_x
        type: var_int
      - id: chunk_z
        type: var_int
      - id: sky_mask
        type: var_int
      - id: block_mask
        type: var_int
      - id: empty_sky_mask
        type: var_int
      - id: empty_block_mask
        type: var_int
      - id: sky_light_arrays
        type: light_array
        repeat: expr
        repeat-expr: sky_mask.bit_count
      - id: block_light_arrays
        type: light_array
        repeat: expr
        repeat-expr: block_mask.bit_count

  cb_play_join_game: # 0x26
    seq:
      - id: entity_id 
        type: s4
      - id: game_mode 
        type: b7
        enum: game_mode
      - id: is_hardcore
        type: b1
      - id: dimension 
        type: s4 
        enum: dimension
      - id: hashed_seed 
        type: s8
      - id: max_players 
        type: u1
      - id: level_type 
        type: string 
        #enum: level_type
      - id: view_distance 
        type: var_int
      - id: reduced_debug_info 
        type: bool
      - id: enable_spawn_screen 
        type: bool
        
  cb_player_abilities: # 0x32
    seq:
      - id: is_invulterable
        type: b1
      - id: is_flying
        type: b1
      - id: is_flying_allowed
        type: b1
      - id: is_creative_mode
        type: b1
      - id: reserved
        type: b4
      - id: flying_speed
        type: f4
      - id: fov_modifier
        type: f4
        
  cb_player_info: # 0x34
    seq:
      - id: action
        type: var_int
      - id: number_of_players
        type: var_int
      - id: players
        type: player_info(action.value)
        repeat: expr
        repeat-expr: number_of_players.value
        
  cb_player_position_and_look: # 0x36
    seq:
      - id: x
        type: f8
      - id: y
        type: f8
      - id: z
        type: f8
      - id: yaw
        type: f4
      - id: pitch
        type: f4
      - id: flags
        type: position_and_look_flags
      - id: teleport_id
        type: var_int
        
  cb_unlock_recipies: # 0x37
    seq:
      - id: action
        type: var_int
        # enum: recipes_action
      - id: crafting_book_open
        type: bool
      - id: crafting_book_filtered
        type: bool
      - id: smelting_book_open
        type: bool
      - id: smelting_book_filtered
        type: bool
      - id: main_recipes_count
        type: var_int
      - id: main_recipes
        type: string
        repeat: expr
        repeat-expr: main_recipes_count.value
      - id: extra_recipes_count
        type: var_int
        if: action.value == 0
      - id: extra_recipes
        type: string
        repeat: expr
        repeat-expr: extra_recipes_count.value
        if: action.value == 0
        
  cb_held_item_change: # 0x40
    seq:
      - id: slot
        type: u1
        
  cb_update_view_position: # 0x41
    seq:
      - id: chunk_x
        type: var_int
      - id: chunk_z
        type: var_int
        
  cb_entity_metadata: # 0x44
    seq:
      - id: entity_id
        type: var_int
      - id: metadata
        type: enity_metadata
        
  cb_entity_equipment: # 0x47
    seq:
      - id: entity_id
        type: var_int
      - id: slot
        type: var_int
        # enum: slot
      - id: item
        type: slot
        
  cb_entity_properties: # 0x59
    seq:
      - id: entity_id
        type: var_int
      - id: number_of_properties
        type: s4
      - id: properties
        type: entity_property
        repeat: expr
        repeat-expr: number_of_properties
        
  cb_declare_recipies: # 0x5B
    seq:
      - id: num_recipies
        type: var_int
      - id: recipies
        type: crafting_recipe
        repeat: expr
        repeat-expr: num_recipies.value
        
  cb_tags: # 0x5C
    seq:
      - id: block_tags
        type: tag_array
      - id: item_tags
        type: tag_array
      - id: fluid_tags
        type: tag_array
      - id: entity_tags
        type: tag_array

####################################

### Generic types

  string:
    seq:
      - id: len
        type: var_int
      - id: value
        type: str
        size: len.value
        encoding: UTF-8
        
  bool:
    seq:
      - id: value
        type: u1
        
  int:
    seq:
      - id: value
        type: s4
        
  uuid:
    seq:
      - id: value
        type: u1
        repeat: expr
        repeat-expr: 16
        
  angle:
    seq:
      - id: value
        type: u1
        
### Crafting-related
        
  crafting_recipe:
    seq:
      - id: type
        type: string
      - id: recipe_id
        type: string
      - id: shapeless_data
        type: shapeless_crafting_data
        if: type.value == "minecraft:crafting_shapeless"
      - id: shaped_data
        type: shaped_crafting_data
        if: type.value == "minecraft:crafting_shaped"
      - id: smelting_data
        type: smelting_data
        if: type.value == "minecraft:smelting"
      - id: stonecutting_data
        type: stonecutting_data
        if: type.value == "minecraft:stonecutting"
      - id: campfire_cooking_data
        type: campfire_cooking_data
        if: type.value == "minecraft:campfire_cooking"
      - id: blasting_data
        type: smelting_data
        if: type.value == "minecraft:blasting"
      - id: smoking_data
        type: smelting_data
        if: type.value == "minecraft:smoking"   
        
  shapeless_crafting_data:
    seq:
      - id: group
        type: string
      - id: ingredient_count
        type: var_int
      - id: ingredients
        type: ingredient
        repeat: expr
        repeat-expr: ingredient_count.value
      - id: result
        type: slot
        
  shaped_crafting_data:
    seq:
      - id: width
        type: var_int
      - id: height
        type: var_int
      - id: group
        type: string
      - id: ingredients
        type: ingredient
        repeat: expr
        repeat-expr: width.value * height.value
      - id: result
        type: slot
        
  smelting_data:
    seq:
      - id: group
        type: string
      - id: ingredient 
        type: ingredient
      - id: result 
        type: slot
      - id: experience 
        type: f4
      - id: cooking_time 
        type: var_int
        
  stonecutting_data:
    seq:
      - id: group
        type: string
      - id: ingredient 
        type: ingredient
      - id: result 
        type: slot
        
  campfire_cooking_data:
    seq:
      - id: group
        type: string
      - id: ingredient 
        type: ingredient
      - id: result 
        type: slot
      - id: experience 
        type: f4
      - id: cooking_time 
        type: var_int
      
  ingredient:
    seq:
      - id: count
        type: var_int
      - id: items
        type: slot
        repeat: expr
        repeat-expr: count.value
        
  slot:
    seq:
      - id: present
        type: bool
      - id: item_id
        type: var_int
        if: present.value != 0
      - id: item_count
        type: u1
        if: present.value != 0
      - id: nbt
        type: nbt
        if: present.value != 0
      
### Tags
      
  tag_array:
    seq:
      - id: length
        type: var_int
      - id: elements
        type: tag_record
        repeat: expr
        repeat-expr: length.value
      
  tag_record:
    seq:
      - id: tag_name
        type: string
      - id: count
        type: var_int
      - id: entries
        type: var_int
        repeat: expr
        repeat-expr: count.value
        
### Commands
        
  command_node:
    seq:
      - id: flags
        type: command_node_flags
      - id: children_count
        type: var_int
      - id: children
        type: var_int
        repeat: expr
        repeat-expr: children_count.value
      - id: redirect
        type: var_int
        if: flags.has_redirect
      - id: name
        type: string
        if: flags.node_type == command_node_type::argument or flags.node_type == command_node_type::literal
      - id: parser
        type: command_parser
        if: flags.node_type == command_node_type::argument
      - id: suggestions
        type: string
        if: flags.has_suggestions
      
  command_node_flags:
    seq:
      - id: reserved 
        type: b3
      - id: has_suggestions 
        type: b1
      - id: has_redirect 
        type: b1
      - id: is_executable 
        type: b1
      - id: node_type 
        type: b2
        enum: command_node_type
        
  command_parser:
    seq:
      - id: parser_name
        type: string
      - id: arg_double
        type: command_arg_double
        if: parser_name.value == "brigadier:double"
      - id: arg_float
        type: command_arg_float
        if: parser_name.value == "brigadier:float"
      - id: arg_integer
        type: command_arg_integer
        if: parser_name.value == "brigadier:integer"
      - id: arg_string
        type: command_arg_string
        if: parser_name.value == "brigadier:string"
      - id: arg_entity
        type: command_arg_entity
        if: parser_name.value == "minecraft:entity"
      - id: arg_score_holder
        type: command_arg_score_holder
        if: parser_name.value == "minecraft:score_holder"
      - id: arg_range
        type: command_arg_range
        if: parser_name.value == "minecraft:range"
      
  command_arg_double:
    seq: 
      - id: min_present
        type: b1
      - id: max_present
        type: b1
      - id: reserved
        type: b6
      - id: min
        type: f8
        if: min_present
      - id: max
        type: f8
        if: max_present
    
  command_arg_float:
    seq: 
      - id: min_present
        type: b1
      - id: max_present
        type: b1
      - id: reserved
        type: b6
      - id: min
        type: f4
        if: min_present
      - id: max
        type: f4
        if: max_present
  
  command_arg_integer:
    seq:
      - id: min_present
        type: b1
      - id: max_present
        type: b1
      - id: reserved
        type: b6
      - id: min
        type: s4
        if: min_present
      - id: max
        type: s4
        if: max_present
    
  command_arg_string:
    seq: 
      - id: match_type
        type: var_int
        # enum: command_arg_string_match_type
  
  command_arg_entity:
    seq: 
      - id: reserved
        type: b6
      - id: allow_players_only
        type: b1
      - id: allow_single_entity
        type: b1
        
  
  command_arg_score_holder:
    seq:
      - id: reserved
        type: b7
      - id: allow_multiple
        type: b1
    
  command_arg_range:
    seq:
      - id: decimals
        type: bool
      
### Player, Position, Look, etc

  player_info:
    params:
      - id: action
        type: u1
        #enum: player_list_action
    seq:
      - id: uuid
        type: uuid
      - id: name
        type: string # 16 chars max
      - id: number_of_properties
        type: var_int
        if: action == 0 # player_list_action::add
      - id: properties
        type: player_property
        repeat: expr
        repeat-expr: number_of_properties.value
        if: action == 0 # player_list_action::add
      - id: game_mode
        type: var_int
        # enum: game_mode
        if: action == 0 or action == 1 # player_list_action::add or player_list_action::update_gamemode
      - id: ping
        type: var_int
        if: action == 0 or action == 2 # player_list_action::add or player_list_action::update_ping
      - id: display_name
        type: player_display_name
        if: action == 0 or action == 3 # player_list_action::add or player_list_action::update_display_name
        
  player_property:
    seq:
      - id: name 
        type: string
      - id: value 
        type: string
      - id: is_signed 
        type: bool
      - id: signature 
        type: string
        if: is_signed.value != 0

  player_display_name:
    seq:
      - id: has_display_name
        type: bool
      - id: value
        type: string
        if: has_display_name.value != 0

  position_and_look_flags:
    seq:
      - id: is_x_relative
        type: b1
      - id: is_y_relative
        type: b1
      - id: is_z_relative
        type: b1
      - id: is_yaw_relative
        type: b1
      - id: is_pitch_relative
        type: b1
      - id: reserved
        type: b3
      
  light_array:
    seq:
      - id: length
        type: var_int
      - id: data
        type: b4
        repeat: expr
        repeat-expr: length.value * 2
        
  chunk_section:
    seq:
      - id: block_count
        type: s2
      - id: bits_per_block
        type: u1
      - id: palette
        type: chunk_palette
        if: bits_per_block <= 8
      - id: data_length
        type: var_int
      - id: data
        type: s8
        repeat: expr
        repeat-expr: data_length.value
      
  chunk_palette:
    seq:
      - id: length
        type: var_int
      - id: data
        type: var_int
        repeat: expr
        repeat-expr: length.value
        
  enity_metadata:
    seq:
      - id: data
        type: entity_metadata_record
        repeat: until
        repeat-until: _.index == 0xFF # TODO!
        
  entity_metadata_record:
    seq:
      - id: index
        type: u1
      - id: type
        type: var_int
        if: index != 0xFF # TODO!
      - id: value
        if: index != 0xFF
        type: 
          switch-on: type.value
          cases:
            0:  u1
            1:  var_int
            2:  f4
            3:  string
            4:  string # Chat
            5:  opt_string
            6:  slot
            7:  bool
            8:  rotation
            9:  position
            10: opt_position
            11: var_int # Direction
            12: opt_uuid
            13: var_int # OptBlockID
            14: nbt
            15: particle
            16: villager_data
            17: opt_var_int
            18: var_int # enum: pose
            
  position:
    seq:
      - id: x
        type: b26
      - id: z
        type: b26
      - id: y
        type: b12
        
  opt_position:
    seq:
      - id: present
        type: bool
      - id: data
        type: position
        if: present.value != 0
  
  opt_var_int:
    seq:
      - id: present
        type: bool
      - id: data
        type: var_int
        if: present.value != 0
        
  opt_uuid:
    seq:
      - id: present
        type: bool
      - id: data
        type: uuid
        if: present.value != 0
        
  opt_string:
    seq:
      - id: present
        type: bool
      - id: data
        type: string
        if: present.value != 0
        
  particle:
    seq:
      - id: id
        type: var_int
        # enum: particle_id
      - id: block_state
        type: var_int
        if: id.value == 3 or id.value == 23 # id == particle_id::block or id == particle_id::falling_dust
      - id: color
        type: color
        if: id.value == 14 # id == particle_id::dust
      - id: item
        type: slot
        if: id.value == 32 # id == particle_id::item
        
  color:
    seq:
      - id: red
        type: f4
      - id: green
        type: f4
      - id: blue
        type: f4
      - id: scale
        type: f4
        
  rotation:
    seq:
      - id: pitch
        type: f4
      - id: yaw
        type: f4
      - id: roll
        type: f4
        
  villager_data:
    seq:
      - id: type
        type: var_int
      - id: profession
        type: var_int
      - id: level
        type: var_int
        
  entity_property:
    seq:
      - id: key
        type: string
      - id: value
        type: f8
      - id: number_of_modifiers
        type: var_int
      - id: modifiers
        type: entity_modifier
        repeat: expr
        repeat-expr: number_of_modifiers.value
        
  entity_modifier:
    seq:
      - id: uuid
        type: uuid
      - id: amount
        type: f8
      - id: operation
        type: u1
        enum: entity_modifier_operation
        
### Enums      

enums:
  game_state:
    0: handshake
    1: status
    2: login
    3: play
  handshake_state:
    0: status
    1: login
  dimension:
    -1: nether
    0: overworld
    1: the_end
  game_mode:
    0: survival
    1: creative
    2: adventure
    3: spectator
  server_difficulty:
    0: peaceful
    1: easy
    2: normal
    3: hard 
  #level_type:
  # default, flat, largeBiomes, amplified, customized, buffet, default_1_1  
  command_node_type:
    0: root
    1: literal 
    2: argument 
    3: reserved
  command_arg_string_match_type:
    0: single_word
    1: quotable_phrase
    2: greedy_phrase
  recipes_action:
    0: init
    1: add
    2: remove
  player_list_action:
    0: add
    1: update_gamemode
    2: update_latncy
    3: update_display_name
    4: remove_player
  particle_id:
    0: ambient_entity_effect
    1: angry_villager
    2: barrier
    3: block
    # TODO
    14: dust
    23: falling_dust
    32: item
  pose:
    0: standing
    1: fall_flying
    2: sleeping
    3: swimming
    4: spin_attack
    5: sneaking
    6: dying
  slot:
    0: main_hand
    1: off_hand
    2: boots
    3: leggings
    4: chestplate
    5: helmet
  entity_modifier_operation:
    0: add_amount
    1: add_percent
    2: mult_percent