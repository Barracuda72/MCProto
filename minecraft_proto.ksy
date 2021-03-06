meta:
  id: minecraft_proto
  file-extension: mcproto
  imports:
    - var_int
    - var_long
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
  - id: a_23 # Update light & load chunk data, also gameplay packets
    type: packet_w(true, game_state::play)
    repeat: expr
    repeat-expr: 905
  - id: a_24 # SB Handshake
    type: packet_w(false, game_state::handshake)
  - id: a_25 # SB Request
    type: packet_w(false, game_state::status)
  - id: a_26 # SB Response
    type: packet_w(false, game_state::status)
  - id: a_27 # CB Ping
    type: packet_w(false, game_state::status)
  - id: a_28 # SB Ping
    type: packet_w(false, game_state::status)
    
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
            0x00: cb_spawn_entity
            0x01: cb_spawn_experience_orb
            0x02: cb_spawn_weather_entity
            0x03: cb_spawn_living_entity
            0x04: cb_spawn_painting
            0x05: cb_spawn_player
            0x06: cb_entity_animation
            0x07: cb_statistics
            0x08: cb_acknowledge_digging
            0x09: cb_block_break_animation
            0x0A: cb_block_entity_data
            0x0B: cb_block_action
            0x0C: cb_block_change
            0x0D: cb_boss_bar
            0x0E: cb_server_difficulty
            0x0F: cb_chat_message
            0x10: cb_multi_block_change
            0x11: cb_tab_complete
            0x12: cb_declare_commands
            0x13: csb_window_confirmation
            0x14: csb_close_window
            0x15: cb_window_items
            0x16: cb_window_property
            0x17: cb_set_slot
            0x18: cb_set_cooldown
            0x19: csb_plugin_message
            0x1A: cb_named_sound_effect
            0x1B: cb_disconnect
            0x1C: cb_entity_status
            0x1D: cb_explosion
            0x1E: cb_unload_chunk
            0x1F: cb_change_game_state
            0x20: cb_open_horse_window
            0x21: csb_keepalive
            0x22: cb_chunk_data
            0x23: cb_effect
            0x24: cb_particle
            0x25: cb_update_light
            0x26: cb_play_join_game
            0x27: cb_map_data
            0x28: cb_trade_list
            0x29: cb_entity_position
            0x2A: cb_entity_position_and_rotation
            0x2B: cb_entity_rotation
            0x2C: cb_entity_movement
            0x2D: csb_vehicle_move
            0x2E: cb_open_book
            0x2F: cb_open_window
            0x30: cb_open_sign_editor
            0x31: cb_craft_recipe_response
            0x32: cb_player_abilities
            0x33: cb_combat_event
            0x34: cb_player_info
            0x35: cb_face_player
            0x36: cb_player_position_and_look
            0x37: cb_unlock_recipies
            0x38: cb_destroy_entities
            0x39: cb_remove_entity_effect
            0x3A: cb_resource_pack_send
            0x3B: cb_respawn
            0x3C: cb_entity_head_look
            0x3D: cb_select_advancement_tab
            0x3E: cb_world_border
            0x3F: cb_camera
            0x40: cb_held_item_change
            0x41: cb_update_view_position
            0x42: cb_update_view_distance
            0x43: cb_display_scoreboard
            0x44: cb_entity_metadata
            0x45: cb_attach_entity
            0x46: cb_entity_velocity
            0x47: cb_entity_equipment
            0x48: cb_set_experience
            0x49: cb_update_health
            0x4A: cb_scoreboard_objective
            0x4B: cb_set_passengers
            0x4C: cb_teams
            0x4D: cb_update_score
            0x4E: cb_spawn_position
            0x4F: cb_time_update
            0x50: cb_title
            0x51: cb_entity_sound_effect
            0x52: cb_sound_effect
            0x53: cb_stop_sound
            0x54: cb_player_list_header_and_footer
            0x55: cb_nbt_query_response
            0x56: cb_collect_item
            0x57: cb_entity_teleport
            0x58: cb_advancements
            0x59: cb_entity_properties
            0x5A: cb_entity_effect
            0x5B: cb_declare_recipies
            0x5C: cb_tags
            _: uncompressed_data

      - id: sb
        if: server_bound
        type:
          switch-on: _parent.packet_id.value
          cases:
            0x00: sb_teleport_confirm
            0x01: sb_query_block_nbt
            0x02: sb_set_difficulty
            0x03: sb_chat_message
            0x04: sb_client_status
            0x05: sb_client_settings
            0x06: sb_tab_complete
            0x07: csb_window_confirmation
            0x08: sb_click_window_button
            0x09: sb_click_window
            0x0A: csb_close_window
            0x0B: csb_plugin_message
            0x0C: sb_edit_book
            0x0D: sb_query_entity_nbt
            0x0E: sb_interact_entity
            0x0F: csb_keepalive
            0x10: sb_lock_difficulty
            0x11: sb_player_position
            0x12: sb_player_position_and_rotation
            0x13: sb_player_rotation
            0x14: sb_player_movement
            0x15: csb_vehicle_move
            0x16: sb_steer_boat
            0x17: sb_pick_item
            0x18: sb_craft_recipe_request
            0x19: sb_player_abilities
            0x1A: sb_player_digging
            0x1B: sb_entity_action
            0x1C: sb_steer_vehicle
            0x1D: sb_recipe_book_data
            0x1E: sb_name_item
            0x1F: sb_resource_pack_status
            0x20: sb_advancement_tab
            0x21: sb_select_trade
            0x22: sb_beacon_effect
            0x23: sb_held_item_change
            0x24: sb_update_command_block
            0x25: sb_update_command_minecart
            0x26: sb_creative_inventory_action
            0x27: sb_update_jigsaw_block
            0x28: sb_update_structure_block
            0x29: sb_update_sign
            0x2A: sb_animation
            0x2B: sb_spectate
            0x2C: sb_player_block_placement
            0x2D: sb_use_item
            _: uncompressed_data

  cb_spawn_entity: # 0x00
    seq:
      - id: entity_id 
        type: var_int
      - id: uuid 
        type: uuid
      - id: type 
        type: var_int
      - id: position 
        type: vec3d_xyz
      - id: pitch 
        type: angle
      - id: yaw 
        type: angle
      - id: data 
        type: s4
      - id: velocity 
        type: vec3s_xyz

  cb_spawn_experience_orb: # 0x01
    seq:
      - id: entity_id
        type: var_int
      - id: position
        type: vec3d_xyz
      - id: count
        type: s2
        
  cb_spawn_weather_entity: # 0x02
    seq:
      - id: entity_id
        type: var_int
      - id: type
        type: u1
        enum: weather_entity
      - id: position
        type: vec3d_xyz

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
  
  cb_spawn_painting: # 0x04
    seq:
      - id: entity_id 
        type: var_int
      - id: entity_uuid 
        type: uuid
      - id: motive 
        type: var_int 
        #enum: painting
      - id: location 
        type: position
      - id: direction 
        type: u1 
        enum: painting_direction
  
  cb_spawn_player: # 0x05
    seq:
      - id: entity_id
        type: var_int
      - id: uuid
        type: uuid
      - id: location
        type: vec3d_xyz
      - id: yaw
        type: angle
      - id: pitch
        type: angle
        
  cb_entity_animation: # 0x06
    seq:
      - id: entity_id
        type: var_int
      - id: animation_id
        type: u1
        enum: entity_animation_id
        
  cb_statistics: # 0x07
    seq:
      - id: count
        type: var_int
      - id: statistics
        type: statistic
        repeat: expr
        repeat-expr: count.value
      - id: value
        type: var_int
        
  cb_acknowledge_digging: # 0x08
    seq:
      - id: location 
        type: position
      - id: block 
        type: var_int
      - id: status 
        type: var_int 
        #enum: player_digging_status
      - id: successful 
        type: bool
  
  cb_block_break_animation: # 0x09
    seq:
      - id: entity_id
        type: var_int
      - id: location
        type: position
      - id: destroy_stage
        type: u1 # 0-9

  cb_block_entity_data: # 0x0A
    seq:
      - id: location
        type: position
      - id: action
        type: u1
        enum: block_entity_data_action
      - id: data
        type: nbt

  cb_block_action: # 0x0B
    seq:
      - id: location
        type: position
      - id: action_id
        type: u1
      - id: action_param
        type: u1
      - id: block_type
        type: var_int
        
  cb_block_change: # 0x0C
    seq:
      - id: location
        type: position
      - id: block_id
        type: var_int
        
  cb_boss_bar: # 0x0D
    seq:
      - id: uuid
        type: uuid
      - id: action
        type: var_int
        #enum: boss_bar_action
      - id: title 
        type: string 
        if: action.value == boss_bar_action::add.to_i or action.value == boss_bar_action::update_title.to_i
      - id: health 
        type: f4 
        if: action.value == boss_bar_action::add.to_i or action.value == boss_bar_action::update_title.to_i
      - id: style 
        type: boss_bar_style 
        if: action.value == boss_bar_action::add.to_i or action.value == boss_bar_action::update_title.to_i
      - id: flags 
        type: boss_bar_flags 
        if: action.value == boss_bar_action::add.to_i or action.value == boss_bar_action::update_title.to_i

  cb_server_difficulty: # 0x0E
    seq:
      - id: difficulty
        type: u1
        enum: server_difficulty
      - id: locked
        type: bool
        
  cb_chat_message: # 0x0F
    seq:
      - id: data
        type: string
      - id: channel
        type: u1
        enum: chat_channel
  
  cb_multi_block_change: # 0x10
    seq:
      - id: coords
        type: vec2i_xz
      - id: record_count
        type: var_int
      - id: records
        type: block_change_record
        repeat: expr
        repeat-expr: record_count.value

  cb_tab_complete: # 0x11
    seq:
      - id: id
        type: var_int
      - id: start
        type: var_int
      - id: length
        type: var_int
      - id: count
        type: var_int
      - id: matches
        type: tab_complete_match
        repeat: expr
        repeat-expr: count.value

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
        
  csb_window_confirmation: # 0x13 (cb), 0x07 (sb)
    seq:
      - id: window_id
        type: u1
      - id: action_number
        type: s2
      - id: accepted 
        type: bool
        
  csb_close_window: # 0x14 (cb), 0x0A (sb)
    seq:
      - id: window_id
        type: u1
        
  cb_window_items: # 0x15
    seq:
      - id: window_id
        type: u1
      - id: count
        type: s2
      - id: data
        type: slot
        repeat: expr
        repeat-expr: count

  cb_window_property: # 0x16
    seq:
      - id: window_id
        type: u1
      - id: property
        type: s2
        #enum: beacon_properties
        #enum: brewing_stand_properties
        #enum: enchantment_table_properties
        #enum: furnace_properties
        #enum: anvil_properties
      - id: value
        type: s2

  cb_set_slot: # 0x17
    seq:
      - id: window_id
        type: u1
      - id: slot
        type: s2
      - id: data
        type: slot

  cb_set_cooldown: # 0x18
    seq:
      - id: item_id
        type: var_int
      - id: cooldown_ticks
        type: var_int

  csb_plugin_message: # 0x19 (cb), 0x0B (sb)
    seq:
      - id: channel
        type: string
      - id: data
        type: u1
        repeat: expr
        repeat-expr: _parent._parent._parent.length.value - channel.len.value - channel.len.len - 2 # TODO!

  cb_named_sound_effect: # 0x1A 
    seq: # TODO: almost the same as "Sound effect", maybe move common part into structure?
      - id: sound_id
        type: string
      - id: sound_category
        type: var_int
        # enum: sound_source
      - id: effect_position
        type: vec3i_xyz
      - id: volume
        type: f4
      - id: pitch
        type: f4

  cb_disconnect: # 0x1B
    seq:
      - id: reason
        type: string

  cb_entity_status: # 0x1C
    seq:
      - id: entity_id
        type: s4
      - id: entity_status
        type: u1

  cb_explosion: # 0x1D
    seq:
      - id: coords
        type: vec3f_xyz
      - id: strength
        type: f4
      - id: record_count
        type: s4
      - id: affected_blocks_offsets
        type: vec3b_xyz
        repeat: expr
        repeat-expr: record_count
      - id: player_motion
        type: vec3f_xyz

  cb_unload_chunk: # 0x1E
    seq:
      - id: coords
        type: vec2i_xz
        
  cb_change_game_state: # 0x1F
    seq:
      - id: reason
        type: u1
        enum: state_change_reason
      - id: value
        type: f4

  cb_open_horse_window: # 0x20
    seq: # TODO: description on wiki.vg is pretty vague
      - id: window_id
        type: u1 # ?
      - id: number_of_slots
        type: var_int # ?
      - id: entity_id
        type: s4 # ?

  csb_keepalive: # 0x21 (cb), 0x0F (sb)
    seq:
      - id: keep_alive_id
        type: s8

  cb_chunk_data: # 0x22
    seq:
      - id: coords
        type: vec2i_xz
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

  cb_effect: # 0x23
    seq:
      - id: effect_id 
        type: s4
        enum: effect_id
      - id: location 
        type: position
      - id: data 
        type: s4
      - id: disable_relative_volume 
        type: bool
        
  cb_particle: # 0x24
    seq:
      - id: id
        type: s4
      - id: is_long_distance
        type: bool
      - id: position
        type: vec3d_xyz
      - id: offset
        type: vec3f_xyz
      - id: particle_data
        type: f4
      - id: particle_count
        type: s4
      - id: data
        type: particle_data(id)

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
  
  cb_map_data: # 0x27
    seq:
      - id: map_id
        type: var_int
      - id: scale
        type: s1
      - id: tracking_position
        type: bool
      - id: locked
        type: bool
      - id: icon_count
        type: var_int
      - id: icons
        type: map_icon
        repeat: expr
        repeat-expr: icon_count.value
      - id: columns
        type: u1
      - id: rows
        type: s1
        if: columns != 0
      - id: offset
        type: vec2b_xz
        if: columns != 0
      - id: length
        type: var_int
        if: columns != 0
      - id: data
        type: u1
        if: columns != 0
        repeat: expr
        repeat-expr: length.value
  
  cb_trade_list: # 0x28
    seq:
      - id: window_id
        type: var_int
      - id: size
        type: u1
      - id: trades
        type: trade
        repeat: expr
        repeat-expr: size
      - id: villager_level
        type: var_int
      - id: experience
        type: var_int
      - id: is_regular_villager
        type: bool
      - id: can_restock
        type: bool
        
  cb_entity_position: # 0x29
    seq:
      - id: entity_id
        type: var_int
      - id: position_delta
        type: vec3s_xyz
      - id: is_on_ground
        type: bool
    
  cb_entity_position_and_rotation: # 0x2A
    seq:
      - id: entity_id
        type: var_int
      - id: position_delta
        type: vec3s_xyz
      - id: yaw
        type: angle
      - id: pitch
        type: angle
      - id: is_on_ground
        type: bool
        
  cb_entity_rotation: # 0x2B
    seq:
      - id: entity_id
        type: var_int
      - id: yaw
        type: angle
      - id: pitch
        type: angle
      - id: is_on_ground
        type: bool
        
  cb_entity_movement: # 0x2C
    seq:
      - id: entity_id
        type: var_int
  
  csb_vehicle_move: # 0x2D (cb), 0x15 (sb)
    seq:
      - id: position
        type: vec3d_xyz
      - id: yaw
        type: f4
      - id: pitch
        type: f4
  
  cb_open_book: # 0x2E
    seq:
      - id: hand
        type: var_int
        #enum: hand
        
  cb_open_window: # 0x2F
    seq:
      - id: window_id 
        type: var_int
      - id: window_type 
        type: var_int
        #enum: window_type
      - id: window_title 
        type: string
        
  cb_open_sign_editor: # 0x30
    seq:
      - id: location
        type: position
        
  cb_craft_recipe_response: # 0x31
    seq:
      - id: window_id
        type: u1
      - id: recipe
        type: string
        
  cb_player_abilities: # 0x32
    seq: # TODO: flags are VERY similar to those of SB version; bug in wiki.vg description?
      - id: reserved
        type: b4
        valid: '0b0000'
      - id: is_creative_mode
        type: b1
      - id: is_flying_allowed
        type: b1
      - id: is_flying
        type: b1
      - id: is_invulnerable
        type: b1
      - id: flying_speed
        type: f4
      - id: fov_modifier
        type: f4
        
  cb_combat_event: # 0x33
    seq:
      - id: event
        type: var_int
        # enum: combat_event_type
      - id: combat_end
        type: combat_end
        if: event.value == combat_event_type::combat_end.to_i
      - id: entity_dead
        type: entity_dead
        if: event.value == combat_event_type::entity_dead.to_i
        
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
    
  cb_face_player: # 0x35
    seq:
      - id: aim_from
        type: var_int
        #enum: look_target
      - id: target_position
        type: vec3d_xyz
      - id: is_entity
        type: bool
      - id: entity_id
        type: var_int
        if: is_entity.value != 0
      - id: aim_to
        type: var_int
        if: is_entity.value != 0
        
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
      - id: recipe_book_state
        type: recipe_book_state
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
        
  cb_destroy_entities: # 0x38
    seq:
      - id: count
        type: var_int
      - id: entity_ids
        type: var_int
        repeat: expr
        repeat-expr: count.value
        
  cb_remove_entity_effect: # 0x39
    seq:
      - id: entity_id
        type: var_int
      - id: effect_id
        type: u1
        enum: status_effect
    
  cb_resource_pack_send: # 0x3A
    seq:
      - id: url
        type: string # limited to 32k bytes
      - id: hash
        type: string # limited to 40 bytes
    
  cb_respawn: # 0x3B
    seq:
      - id: dimension 
        type: s4 
        enum: dimension
      - id: hashed_seed 
        type: s8
      - id: game_mode 
        type: u1 
        enum: game_mode
      - id: level_type 
        type: string
        #enum: level_type
    
  cb_entity_head_look: # 0x3C
    seq:
      - id: entity_id
        type: var_int
      - id: head_yaw
        type: angle
        
  cb_select_advancement_tab: # 0x3D
    seq:
      - id: has_id 
        type: bool
      - id: identifier 
        type: string 
        if: has_id.value != 0
      
  cb_world_border: # 0x3E
    seq:
      - id: action
        type: var_int
        # enum: world_border_action
      - id: diameter
        type: f8
        if: action.value == world_border_action::set_size.to_i
      - id: lerp_data
        type: world_border_lerp_data
        if: action.value == world_border_action::lerp_size.to_i
      - id: center
        type: vec2d_xz
        if: action.value == world_border_action::set_center.to_i
      - id: init_data
        type: world_border_init_data
        if: action.value == world_border_action::initialize.to_i
      - id: warning_time
        type: var_int
        if: action.value == world_border_action::set_warning_time.to_i
      - id: warning_blocks
        type: var_int
        if: action.value == world_border_action::set_warning_blocks.to_i
        
  cb_camera: # 0x3F
    seq:
      - id: camera_id # entity ID
        type: var_int
        
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
        
  cb_update_view_distance: # 0x42
    seq:
      - id: view_distance
        type: var_int
        
  cb_display_scoreboard: # 0x43
    seq:
      - id: position
        type: u1
        enum: scoreboard_position
      - id: score_name
        type: string # limited to 16 bytes
        
  cb_entity_metadata: # 0x44
    seq:
      - id: entity_id
        type: var_int
      - id: metadata
        type: enity_metadata
        
  cb_attach_entity: # 0x45
    seq:
      - id: attached_entity_id
        type: var_int
      - id: holding_entity_id
        type: var_int
        
  cb_entity_velocity: # 0x46
    seq:
      - id: entity_id
        type: var_int
      - id: velocity
        type: vec3s_xyz
        
  cb_entity_equipment: # 0x47
    seq:
      - id: entity_id
        type: var_int
      - id: slot
        type: var_int
        # enum: slot
      - id: item
        type: slot
        
  cb_set_experience: # 0x48
    seq:
      - id: experience_bar
        type: f4
      - id: level
        type: var_int
      - id: total_experience
        type: var_int
        
  cb_update_health: # 0x49
    seq:
      - id: health
        type: f4
      - id: food
        type: var_int
      - id: saturation
        type: f4
        
  cb_scoreboard_objective: # 0x4A
    seq:
      - id: objective_name 
        type: string
      - id: mode 
        type: u1
        enum: scoreboard_objective_mode
      - id: objective_value
        type: string 
        if: mode == scoreboard_objective_mode::create_scoreboard or mode == scoreboard_objective_mode::update_display_text
      - id: type 
        type: var_int 
        #enum: scoreboard_objective_type
        if: mode == scoreboard_objective_mode::create_scoreboard or mode == scoreboard_objective_mode::update_display_text
        
  cb_set_passengers: # 0x4B
    seq:
      - id: entity_id 
        type: var_int
      - id: passenger_count 
        type: var_int
      - id: passengers 
        type: var_int 
        repeat: expr 
        repeat-expr: passenger_count.value
  
  cb_teams: # 0x4C
    seq:
      - id: team_name
        type: string # limit 16 bytes
      - id: mode
        type: s1
        enum: teams_mode
      - id: display_name
        type: string
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: friendly_flags
        type: team_friendly_flags
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: name_tag_visibility
        type: string 
        #enum: name_tag_visibility
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: collision_rule
        type: string 
        #enum: team_collision_rule
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: color
        type: var_int 
        #enum: team_color
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: prefix
        type: string
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: suffix
        type: string
        if: mode == teams_mode::create or mode == teams_mode::update
      - id: entity_count
        type: var_int
        if: mode == teams_mode::create or mode == teams_mode::add_players or mode == teams_mode::remove_players
      - id: entities
        type: string
        if: mode == teams_mode::create or mode == teams_mode::add_players or mode == teams_mode::remove_players
        repeat: expr
        repeat-expr: entity_count.value
      
  cb_update_score: # 0x4D
    seq:
      - id: entity_name
        type: string # limited to 40 bytes
      - id: action
        type: u1
        enum: score_update_action
      - id: objective_name
        type: string # limited to 16 bytes
      - id: value
        type: var_int
        if: action != score_update_action::remove
        
  cb_spawn_position: # 0x4E
    seq:
      - id: location
        type: position
  
  cb_time_update: # 0x4F
    seq:
      - id: world_age
        type: s8
      - id: time_of_day
        type: s8
  
  cb_title: # 0x50
    seq:
      - id: action
        type: var_int
        #enum: title_action
      - id: title
        type: string
        if: action.value == title_action::set_title.to_i
      - id: subtitle
        type: string
        if: action.value == title_action::set_subtitle.to_i
      - id: action_bar
        type: string
        if: action.value == title_action::set_action_bar.to_i
      - id: timings
        type: title_timings
  
  cb_entity_sound_effect: # 0x51
    seq:
      - id: sound_id
        type: var_int
      - id: sound_category
        type: var_int
        # enum: sound_source
      - id: entity_id
        type: var_int
      - id: volume
        type: f4
      - id: pitch
        type: f4
  
  cb_sound_effect: # 0x52
    seq:
      - id: sound_id
        type: var_int
      - id: sound_category
        type: var_int
        # enum: sound_source
      - id: effect_position
        type: vec3i_xyz
      - id: volume
        type: f4
      - id: pitch
        type: f4
        
  cb_stop_sound: # 0x53
    seq:
      - id: stop_sound_flags
        type: stop_sound_flags
      - id: source
        type: var_int
        #enum: sound_source
        if: stop_sound_flags.has_source
      - id: sound_name
        type: string
        if: stop_sound_flags.has_name
        
  cb_player_list_header_and_footer: # 0x54
    seq:
      - id: header
        type: string
      - id: footer
        type: string
        
  cb_nbt_query_response: # 0x55
    seq:
      - id: transaction_id
        type: var_int
      - id: nbt
        type: nbt
        
  cb_collect_item: # 0x56
    seq:
      - id: collected_entity_id
        type: var_int
      - id: collector_entity_id
        type: var_int
      - id: pickup_item_count
        type: var_int
        
  cb_entity_teleport: # 0x57
    seq:
      - id: entity_id
        type: var_int
      - id: position
        type: vec3d_xyz
      - id: yaw
        type: angle
      - id: pitch
        type: angle
      - id: is_on_ground
        type: bool
      
  cb_advancements: # 0x58
    seq:
      - id: reset
        type: bool
      - id: mapping_size
        type: var_int
      - id: advancement_mapping
        type: advancement_mapping
        repeat: expr
        repeat-expr: mapping_size.value
      - id: list_size
        type: var_int
      - id: identifiers
        type: string
        repeat: expr
        repeat-expr: list_size.value
      - id: progress_size
        type: var_int
      - id: progress_mapping
        type: progress_mapping
        repeat: expr
        repeat-expr: progress_size.value
  
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
        
  cb_entity_effect: # 0x5A
    seq:
      - id: entity_id 
        type: var_int
      - id: effect_id 
        type: u1
      - id: amplifier 
        type: u1
      - id: duration 
        type: var_int
      - id: flags 
        type: entity_effect_flags
    
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

### Serverbound play packets

  sb_teleport_confirm: # 0x00
    seq:
      - id: teleport_id
        type: var_int
        
  sb_query_block_nbt: # 0x01
    seq:
      - id: transaction_id 
        type: var_int
      - id: location
        type: position
  
  sb_set_difficulty: # 0x02
    seq:
      - id: new_difficulty
        type: u1
        enum: server_difficulty
        
  sb_chat_message: # 0x03
    seq:
      - id: data
        type: string # no more than 256 bytes
        
  sb_client_status: # 0x04
    seq:
      - id: action_id
        type: var_int
        # enum: client_status_action
        
  sb_client_settings: # 0x05
    seq:
      - id: locale 
        type: string
      - id: view_distance 
        type: u1
      - id: chat_mode 
        type: var_int 
        #enum: chat_mode
      - id: chat_colors 
        type: bool
      - id: displayed_skin_parts 
        type: displayed_skin_parts
      - id: main_hand 
        type: var_int 
        #enum: main_hand
        
  sb_tab_complete: # 0x06
    seq:
      - id: transaction_id
        type: var_int
      - id: text
        type: string # no more than 32500 bytes
        
  sb_click_window_button: # 0x08
    seq:
      - id: window_id
        type: u1
      - id: button_id
        type: u1
        #enum: many
        
  sb_click_window: # 0x09
    seq:
      - id: window_id
        type: u1
      - id: slot
        type: s2
      - id:  button
        type: u1
      - id: action_number
        type: s2
      - id: mode
        type: var_int
        #enum: click_mode
      - id: item
        type: slot
        
  sb_edit_book: # 0x0C
    seq:
      - id: new_book
        type: slot
      - id: is_signing
        type: bool
      - id: hand
        type: var_int
        #enum: hand
  
  sb_query_entity_nbt: # 0x0D
    seq:
      - id: transaction_id
        type: var_int
      - id: entity_id
        type: var_int
        
  sb_interact_entity: #0x0E
    seq:
      - id: entity_id
        type: var_int
      - id: type
        type: var_int
        #enum: interact_entity_type
      - id: target_xyz
        type: vec3d_xyz
        if: type.value == interact_entity_type::interact_at.to_i
      - id: hand
        type: var_int
        if: type.value == interact_entity_type::interact_at.to_i
        #enum: hand
        
  sb_lock_difficulty: # 0x10
    seq:
      - id: locked
        type: bool
        
  sb_player_position: # 0x11
    seq:
      - id: position
        type: vec3d_xyz
      - id: is_on_ground
        type: bool
    
  sb_player_position_and_rotation: # 0x12
    seq:
      - id: position
        type: vec3d_xyz
      - id: yaw
        type: f4
      - id: pitch
        type: f4
      - id: is_on_ground
        type: bool
    
  sb_player_rotation: # 0x13
    seq:
      - id: yaw
        type: f4
      - id: pitch
        type: f4
      - id: is_on_ground
        type: bool
        
  sb_player_movement: # 0x14
    seq:
      - id: is_on_ground
        type: bool
  
  sb_steer_boat: # 0x16
    seq:
      - id: left_paddle_turning
        type: bool
      - id: right_paddle_turning
        type: bool
        
  sb_pick_item: # 0x17
    seq:
      - id: slot
        type: var_int
        
  sb_craft_recipe_request: # 0x18
    seq:
      - id: window_id 
        type: u1
      - id: recipe 
        type: string
      - id: make_all 
        type: bool
  
  sb_player_abilities: # 0x19
    seq: # TODO: flags are VERY similar to CB version of the packet, maybe incorrect description at wiki.vg?
      - id: reserved
        type: b4
        valid: '0b0000'
      - id: is_invulnerable
        type: b1
      - id: is_flying_allowed
        type: b1
      - id: is_flying
        type: b1
      - id: is_creative_mode
        type: b1
      - id: flying_speed
        type: f4
      - id: walking_speed
        type: f4
        
  sb_player_digging: # 0x1A
    seq:
      - id: status
        type: var_int 
        # enum: player_digging_status
      - id: location
        type: position
      - id: face
        type: u1
        enum: block_face
        
  sb_entity_action: # 0x1B
    seq:
      - id: entity_id
        type: var_int
      - id: action_id
        type: var_int 
        #enum: entity_action
      - id: jump_boost
        type: var_int
        
  sb_steer_vehicle: # 0x1C
    seq:
      - id: sideways
        type: f4
      - id: forward
        type: f4
      - id: flags
        type: steer_vehicle_flags
        
  sb_recipe_book_data: # 0x1D
    seq:
      - id: type
        type: var_int
        #enum: recipe_book_data
      - id: data
        type:
          switch-on: type.value
          cases:
            recipe_book_data::displayed_recipe.to_i: displayed_recipe_data
            recipe_book_data::recipe_book_state.to_i: recipe_book_state
            _: force_parser_error
        
  sb_name_item: # 0x1E
    seq:
      - id: item_name
        type: string # No more than 32767 bytes
        
  sb_resource_pack_status: # 0x1F
    seq:
      - id: result
        type: var_int
        #enum: resource_pack_status
        
  sb_advancement_tab: # 0x20
    seq:
      - id: action
        type: var_int 
        #enum: advancement_tab_action
      - id: tab_id
        type: string
        if: action.value == advancement_tab_action::opened_tab.to_i
        
  sb_select_trade: # 0x21
    seq:
      - id: selected_slot
        type: var_int
        
  sb_beacon_effect: # 0x22
    seq:
      - id: primary_effect
        type: var_int
        #enum: status_effect
      - id: secondary_effect
        type: var_int
        #enum: status_effect
        
  sb_held_item_change: # 0x23
    seq:
      - id: slot
        type: s2
        
  sb_update_command_block: # 0x24
    seq:
      - id: location
        type: position
      - id: command
        type: string # 32k limit
      - id: mode
        type: var_int
        #enum: command_block_mode
      - id: flags
        type: command_block_flags
        
  sb_update_command_minecart: # 0x25
    seq:
      - id: entity_id
        type: var_int
      - id: command
        type: string
      - id: track_output
        type: bool
  
  sb_creative_inventory_action: # 0x26
    seq:
      - id: slot
        type: s2
      - id: item
        type: slot
        
  sb_update_jigsaw_block: # 0x27
    seq:
      - id: location
        type: position
      - id: attachment_type
        type: string
      - id: pool
        type: string
      - id: final_state
        type: string
  
  sb_update_structure_block: # 0x28
    seq:
      - id: location
        type: position
      - id: action
        type: var_int 
        #enum: update_structure_block_action
      - id: mode
        type: var_int 
        #enum: update_structure_block_mode
      - id: name 
        type: string
      - id: offset
        type: vec3b_xyz
      - id: size
        type: vec3b_xyz
      - id: mirror
        type: var_int 
        #enum: update_structure_block_mirror
      - id: rotation
        type: var_int 
        #enum: update_structure_block_rotation
      - id: metadata
        type: string
      - id: integrity
        type: f4
      - id: seed
        type: var_long
      - id: flags
        type: update_structure_block_flags
        
  sb_update_sign: # 0x29
    seq:
      - id: location
        type: position
      - id: lines
        type: string # limited to 384 bytes
        repeat: expr
        repeat-expr: 4
        
  sb_animation: # 0x2A
    seq:
      - id: hand
        type: var_int
        #enum: hand
        
  sb_spectate: # 0x2B
    seq:
      - id: target
        type: uuid
        
  sb_player_block_placement: # 0x2C
    seq:
      - id: hand
        type: var_int
        #enum: hand
      - id: location
        type: position
      - id: face
        type: var_int
        #enum: block_face
      - id: cursor_position
        type: vec3f_xyz
      - id: is_inside_block
        type: bool
  
  sb_use_item: # 0x2D
    seq:
      - id: hand
        type: var_int
        #enum: hand

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
        
  vec2b_xz:
    seq:
      - id: x
        type: s1
      - id: y
        type: s1
  
  vec2f_xy:
    seq:
      - id: x
        type: f4
      - id: y
        type: f4
        
  vec2d_xz:
    seq:
      - id: x
        type: f8
      - id: z
        type: f8
        
  vec2i_xz:
    seq:
      - id: x
        type: s4
      - id: z
        type: s4
        
  vec3f_xyz:
    seq:
      - id: x
        type: f4
      - id: y
        type: f4
      - id: z
        type: f4
        
  vec3d_xyz:
    seq:
      - id: x
        type: f8
      - id: y
        type: f8
      - id: z
        type: f8
        
  vec3b_xyz:
    seq:
      - id: x
        type: s1
      - id: y
        type: s1
      - id: z
        type: s1
        
  vec3s_xyz:
    seq:
      - id: x
        type: s2
      - id: y
        type: s2
      - id: z
        type: s2
        
  vec3i_xyz:
    seq:
      - id: x
        type: s4
      - id: y
        type: s4
      - id: z
        type: s4
        
  force_parser_error:
    seq:
      - id: dummy
        type: u1
        repeat: expr
        repeat-expr: 0xBABECAFE
        
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

  displayed_recipe_data:
    seq:
      - id: recipe_id
        type: string
        
  recipe_book_state:
    seq:
      - id: crafting_book_open
        type: bool
      - id: crafting_book_filtered
        type: bool
      - id: smelting_book_open
        type: bool
      - id: smelting_book_filtered
        type: bool

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
        valid: '0b000'
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
        valid: '0b000000'
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
        valid: '0b000000'
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
        valid: '0b000000'
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
        valid: '0b000000'
      - id: allow_players_only
        type: b1
      - id: allow_single_entity
        type: b1
        
  
  command_arg_score_holder:
    seq:
      - id: reserved
        type: b7
        valid: '0b0000000'
      - id: allow_multiple
        type: b1
    
  command_arg_range:
    seq:
      - id: decimals
        type: bool
        
  tab_complete_match:
    seq:
      - id: match 
        type: string
      - id: has_tooltip 
        type: bool
      - id: tooltip 
        type: string 
        if: has_tooltip.value != 0
      
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
        if: action == player_list_action::add.to_i
      - id: number_of_properties
        type: var_int
        if: action == player_list_action::add.to_i
      - id: properties
        type: player_property
        repeat: expr
        repeat-expr: number_of_properties.value
        if: action == player_list_action::add.to_i
      - id: game_mode
        type: var_int
        # enum: game_mode
        if: action == player_list_action::add.to_i or action == player_list_action::update_gamemode.to_i
      - id: ping
        type: var_int
        if: action == player_list_action::add.to_i or action == player_list_action::update_latency.to_i
      - id: display_name
        type: player_display_name
        if: action == player_list_action::add.to_i or action == player_list_action::update_display_name.to_i
        
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
        valid: '0b000'
      
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
      - id: data
        type: particle_data(id.value)
        
  particle_data:
    params:
      - id: id
        type: s4
        #enum: particle_id
    seq:
      - id: block_state
        type: var_int
        if: id == particle_id::block.to_i or id == particle_id::falling_dust.to_i
      - id: color
        type: color
        if: id == particle_id::dust.to_i
      - id: item
        type: slot
        if: id == particle_id::item.to_i
        
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
        
  world_border_lerp_data:
    seq:
      - id: old_diameter
        type: f8
      - id: new_diameter
        type: f8
      - id: speed
        type: var_long
        
  world_border_init_data:
    seq:
      - id: center
        type: vec2d_xz
      - id: lerp_data
        type: world_border_lerp_data
      - id: portal_teleport_boundary
        type: var_int
      - id: warning_time
        type: var_int
      - id: warning_blocks
        type: var_int
  
  displayed_skin_parts:
    seq:
      - id: reserved
        type: b1
        #valid: '0b0'
      - id: hat_enabled
        type: b1
      - id: right_leg_enabled
        type: b1
      - id: left_leg_enabled
        type: b1
      - id: right_sleeve_enabled
        type: b1
      - id: left_sleeve_enabled
        type: b1
      - id: jacket_enabled
        type: b1
      - id: cape_enabled
        type: b1

  combat_end:
    seq:
      - id: duration 
        type: var_int
      - id: entity_id 
        type: s4
      
  entity_dead:
    seq:
      - id: player_id 
        type: var_int
      - id: entity_id 
        type: int
      - id: message 
        type: string

  block_change_record:
    seq:
      - id: x
        type: b4
      - id: z
        type: b4
      - id: y
        type: u1
      - id: block_id
        type: var_int

  entity_effect_flags:
    seq:
      - id: reserved
        type: b5
        valid: '0b00000'
      - id: show_icon 
        type: b1
      - id: show_particles 
        type: b1
      - id: is_ambient 
        type: b1

  steer_vehicle_flags:
    seq:
      - id: reserved
        type: b6
        valid: '0b000000'
      - id: unmount
        type: b1
      - id: jump
        type: b1

### Advancements

  advancement_mapping:
    seq:
      - id: key
        type: string
      - id: value
        type: advancement_structure
        
  progress_mapping:
    seq:
      - id: key
        type: string
      - id: value
        type: advancement_progress

  advancement_structure:
    seq:
      - id: has_parent 
        type: bool
      - id: parent_id 
        type: string
        if: has_parent.value != 0
      - id: has_display 
        type: bool
      - id: display_data 
        type: advancement_display
        if: has_display.value != 0
      - id: number_of_criteria 
        type: var_int
      - id: criteria 
        type: advancement_structure_criteria 
        repeat: expr
        repeat-expr: number_of_criteria.value
      - id: number_of_requirements 
        type: var_int
      - id: requirements 
        type: advancement_structure_requirement 
        repeat: expr
        repeat-expr: number_of_requirements.value
      
  advancement_structure_requirement:
    seq:
      - id: length
        type: var_int
      - id: data
        type: string
        repeat: expr
        repeat-expr: length.value
    
  advancement_structure_criteria:
    seq:
      - id: key
        type: string
      - id: value
        #type: none
        size: 0

  advancement_display:
    seq:
      - id: title 
        type: string
      - id: description 
        type: string
      - id: icon 
        type: slot
      - id: frame_type 
        type: var_int 
        #enum: advancement_diplay_frame_type
      - id: flags 
        type: advancement_display_flags
      - id: background_texture 
        type: string 
        if: flags.has_background
      - id: coord 
        type: vec2f_xy

  advancement_display_flags:
    seq:
      - id: reserved
        type: b29
        valid: '0b0000_0000_0000_0000_0000_0000_0000_0'
      - id: hidden
        type: b1
      - id: show_toast
        type: b1
      - id: has_background
        type: b1

  advancement_progress:
    seq:
      - id: size
        type: var_int
      - id: criteria
        type: advancement_progress_criteria
        repeat: expr
        repeat-expr: size.value

  advancement_progress_criteria:
    seq:
      - id: identifier
        type: string
      - id: progress
        type: criterion_progress

  criterion_progress:
    seq:
      - id: achieved
        type: bool
      - id: date_of_achieving
        type: s8
        if: achieved.value != 0

  statistic:
    seq:
      - id: category_id
        type: var_int
        #enum: statistic_category
      - id: statistic_id
        type: var_int
        #enum: statistic_category_custom # Only for "custom" category

### Command block

  command_block_flags:
    seq:
      - id: reserved
        type: b5
        valid: '0b00000'
      - id: automatic
        type: b1
      - id: conditional
        type: b1
      - id: track_output
        type: b1

### Misc
  stop_sound_flags:
    seq:
      - id: reserved
        type: b6
        valid: '0b000000'
      - id: has_name
        type: b1
      - id: has_source
        type: b1
        
  update_structure_block_flags:
    seq:
      - id: reserved
        type: b5
      - id: show_bounding_box
        type: b1
      - id: show_air
        type: b1
      - id: ignore_entities
        type: b1

  boss_bar_style:
    seq:
      - id: color 
        type: var_int 
        #enum: boss_bar_color
      - id: division 
        type: var_int 
        #enum: boss_bar_division

  boss_bar_flags:
    seq:
      - id: reserved
        type: b5
        valid: '0b00000'
      - id: create_fog
        type: b1
      - id: is_dragon_bar
        type: b1
      - id: darken_sky
        type: b1

  trade:
    seq:
      - id: input_item_1
        type: slot
      - id: output_item
        type: slot
      - id: has_second_item
        type: bool
      - id: input_item_2
        type: slot
        if: has_second_item.value != 0
      - id: disabled
        type: bool
      - id: number_of_uses
        type: s4
      - id: maximum_number_of_uses
        type: s4
      - id: experience
        type: s4
      - id: special_price
        type: s4
      - id: price_multiplier
        type: f4
      - id: demand
        type: s4

  title_timings:
    seq:
      - id: fade_in 
        type: s4
      - id: stay 
        type: s4
      - id: fade_out 
        type: s4

  map_icon:
    seq:
      - id: type
        type: var_int
      - id: coords
        type: vec2b_xz
      - id: direction
        type: s1
      - id: has_display_name
        type: bool
      - id: display_name
        type: string
        if: has_display_name.value != 0

  team_friendly_flags:
    seq:
      - id: reserved
        type: b6
        valid: '0b000000'
      - id: see_invisible
        type: b1
      - id: friendly_fire
        type: b1

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
    2: update_latency
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
  world_border_action:
    0: set_size
    1: lerp_size
    2: set_center
    3: initialize
    4: set_warning_time
    5: set_warning_blocks
  client_status_action:
    0: perform_respawn
    1: request_stats
  main_hand:
    0: left
    1: right
  chat_mode:
    0: enabled
    1: commands_only
    2: hidden
  advancement_diplay_frame_type:
    0: task
    1: challenge
    2: goal
  hand:
    0: main_hand
    1: off_hand
  player_digging_status:
    0: started_digging
    1: cancelled_digging
    2: finished_digging
    3: drop_item_stack
    4: drop_item
    5: use_item # Shoot arrow, finish eating
    6: swap_item_in_hand
  block_face:
    0: bottom
    1: top
    2: north
    3: south
    4: west
    5: east
  interact_entity_type:
    0: interact
    1: attack
    2: interact_at
  entity_animation_id:
    0: swing_main_arm
    1: take_damage
    2: leave_bed
    3: swing_offhand
    4: critical_effect
    5: magic_critical_effect
  combat_event_type:
    0: combat_enter
    1: combat_end
    2: entity_dead
  effect_id:
    # Sounds
    1000: dispenser_dispensed 	
    1001: dispenser_failed
    1002: dispenser_shot
    1003: ender_eye_launched 	
    1004: firework_shot 	
    1005: iron_door_opened 	
    1006: wooden_door_opened 	
    1007: wooden_trapdoor_opened 	
    1008: fence_gate_opened 	
    1009: fire_extinguished 	
    1010: record_played # Special case
    1011: iron_door_closed
    1012: wooden_door_closed 	
    1013: wooden_trapdoor_closed 	
    1014: fence_gate_closed 	
    1015: ghast_warned 	
    1016: ghast_shot 	
    1017: enderdragon_shot
    1018: blaze_shot
    1019: zombie_attacked_wood_door 	
    1020: zombie_attacked_iron_door 	
    1021: zombie_broke_wood_door 	
    1022: wither_broke_block 	
    1023: wither_spawned 	
    1024: wither_shot 	
    1025: bat_takes_off 	
    1026: zombie_infected
    1027: zombie_villager_converted 	
    1028: ender_dragon_dead
    1029: anvil_destroyed	
    1030: anvil_used 	
    1031: anvil_landed 	
    1032: portal_travelled
    1033: chorus_flower_grown 	
    1034: chorus_flower_died 	
    1035: brewing_stand_brewed 	
    1036: iron_trapdoor_opened 	
    1037: iron_trapdoor_closed
    # Particles
    2000: spawn_ten_smoke_particles # e.g. from a fire; direction, see below
    2001: block_break_with_sound # Block state, as an index into the global palette
    2002: splash_potion # Particle effect + glass break sound. Potion ID
    2003: eye_of_ender # entity break animation — particles and sound 	
    2004: mob_spawn_particle # effect: smoke + flames 	
    2005: bonemeal_particles # how many particles to spawn (if set to 0, 15 are spawned)
    2006: dragon_breath
    2007: instant_splash_potion # Potion ID
    3000: end_gateway_spawn
    3001: enderdragon_growl
  smoke_direction:
    0: southeast
    1: south
    2: southwest
    3: east
    4: up # or middle ?
    5: west
    6: northeast
    7: north
    8: northwest
  chat_channel:
    0: chat
    1: system
    2: game_info
  window_type:
    0:  generic_9x1
    1:  generic_9x2
    2:  generic_9x3
    3:  generic_9x4
    4:  generic_9x5
    5:  generic_9x6
    6:  generic_3x3
    7:  anvil
    8:  beacon
    9:  blast_furnace
    10: brewing_stand
    11: crafting
    12: enchantment
    13: furnace
    14: grindstone
    15: hopper
    16: lectern
    17: loom
    18: merchant
    19: shulker_box
    20: smoker
    21: cartography
    22: stonecutter
  entity_action:
    0: start_sneaking
    1: stop_sneaking
    2: leave_bed
    3: start_sprinting
    4: stop_sprinting
    5: start_horse_jump
    6: stop_horse_jump
    7: open_horse_inventory
    8: start_elytra_flying
  state_change_reason:
    0:  invalid_bed # Would be used to switch between messages, but the only used message is 0 for invalid bed
    1:  end_raining 	
    2:  begin_raining 	
    3:  change_gamemode # 	0: Survival, 1: Creative, 2: Adventure, 3: Spectator
    4:  exit_end # 0: Immediately send Client Status of respawn without showing end credits; 1: Show end credits and respawn at the end (or when esc is pressed). 1 is sent if the player has not yet received the "The end?" advancement, while if they do have it 0 is used.
    5:  demo_message # 0: Show welcome to demo screen, 101: Tell movement controls, 102: Tell jump control, 103: Tell inventory control, 104: Tell that the demo is over and print a message about how to take a screenshot
    6:  arrow_hitting_player # Appears to be played when an arrow strikes another player in Multiplayer
    7:  fade_value # The current darkness value. 1 = Dark, 0 = Bright, Setting the value higher causes the game to change color and freeze
    8:  fade_time # Time in ticks for the sky to fade
    9:  pufferfish_sting_sound
    10: elder_guardian_appearance # effect and sound
    11: enable_respawn_screen # 0: Enable respawn screen, 1: Immediately respawn (sent when the doImmediateRespawn gamerule changes) 
  weather_entity:
    1: thunderbolt
  status_effect:
    1:  speed
    2:  slowness
    3:  haste
    4:  mining_fatigue
    5:  strength
    6:  instant_health
    7:  instant_damage
    8:  jump_boost
    9:  nausea
    10: regeneration
    11: resistance
    12: fire_resistance
    13: water_breathing
    14: invisibility
    15: blindness
    16: night_vision
    17: hunger
    18: weakness
    19: poison
    20: wither
    21: health_boost
    22: absorption
    23: saturation
    24: glowing
    25: levitation
    26: luck
    27: unluck
    28: slow_falling
    29: conduit_power
    30: dolphins_grace
    31: bad_omen
    32: hero_of_the_village
  furnace_properties:
    0: fuel_left
    1: fuel_burn_time
    2: progress_arrow
    3: maximum_progress
  enchantment_table_properties:
    0: level_requirement_top
    1: level_requirement_middle
    2: level_requirement_bottom
    3: enchantment_seed
    4: enchantment_id_top
    5: enchantment_id_middle
    6: enchantment_id_bottom
    7: enchantment_level_top
    8: enchantment_level_middle
    9: enchantment_level_bottom
  beacon_properties:
    0: power_level
    1: first_potion_effect
    2: second_potion_effect
  anvil_properties:
    0: repair_cost
  brewing_stand_properties:
    0: brew_time
    1: fuel_time
  enchantment_id:
    0:	protection
    1:	fire_protection
    2:	feather_falling
    3:	blast_protection
    4:	projectile_protection
    5:	respiration
    6:	aqua_affinity
    7:	thorns
    8:	depth_strider
    9:	frost_walker
    10:	binding_curse
    11:	sharpness
    12:	smite
    13:	bane_of_arthropods
    14:	knockback
    15:	fire_aspect
    16:	looting
    17:	sweeping
    18:	efficiency
    19:	silk_touch
    20:	unbreaking
    21:	fortune
    22:	power
    23:	punch
    24:	flame
    25:	infinity
    26:	luck_of_the_sea
    27:	lure
    28:	loyalty
    29:	impaling
    30:	riptide
    31:	channeling
    32:	mending
    33:	vanishing_curse
  recipe_book_data:
    0: displayed_recipe
    1: recipe_book_state
  click_mode:
    0: normal_click
    1: shift_click
    2: number_key
    3: middle_click
    4: drop_and_click_outside
    5: drag
    6: double_click
  resource_pack_status:
    0: successfully_loaded
    1: declined
    2: download_failed
    3: accepted
  advancement_tab_action:
    0: opened_tab
    1: closed_screen
  command_block_mode:
    0: sequence
    1: auto
    2: redstone
  statistic_category:
    0: blocks_mined
    1: items_crafted
    2: items_used
    3: items_broken
    4: items_picked_up
    5: items_dropped
    6: entities_killed
    7: entities_killed_by
    8: custom
  statistic_category_custom:
    0:	leave_game 
    1:	play_one_minute 
    2:	time_since_death 
    3:	sneak_time 
    4:	walk_one_cm 
    5:	crouch_one_cm 
    6:	sprint_one_cm 
    7:	swim_one_cm 
    8:	fall_one_cm 
    9:	climb_one_cm 
    10:	fly_one_cm 
    11:	dive_one_cm 
    12:	minecart_one_cm 
    13:	boat_one_cm 
    14:	pig_one_cm 
    15:	horse_one_cm 
    16:	aviate_one_cm 
    17:	jump 
    18:	drop 
    19:	damage_dealt 
    20:	damage_taken 
    21:	deaths 
    22:	mob_kills 
    23:	animals_bred 
    24:	player_kills 
    25:	fish_caught 
    26:	talked_to_villager 
    27:	traded_with_villager 
    28:	eat_cake_slice 
    29:	fill_cauldron 
    30:	use_cauldron 
    31:	clean_armor 
    32:	clean_banner 
    33:	interact_with_brewingstand 
    34:	interact_with_beacon 
    35:	inspect_dropper 
    36:	inspect_hopper 
    37:	inspect_dispenser 
    38:	play_noteblock 
    39:	tune_noteblock 
    40:	pot_flower 
    41:	trigger_trapped_chest 
    42:	open_enderchest 
    43:	enchant_item 
    44:	play_record 
    45:	interact_with_furnace 
    46:	interact_with_crafting_table 
    47:	open_chest 
    48:	sleep_in_bed 
    49:	open_shulker_box 
  scoreboard_position:
    0: list
    1: sidebar
    2: below_name
    #3-18: team specific, depends on color
  scoreboard_objective_mode:
    0: create_scoreboard
    1: remove_scoreboard
    2: update_display_text
  scoreboard_objective_type:
    0: integer
    1: hearts
  sound_source:
    0:	master
    1:	music
    2:	record
    3:	weather
    4:	block
    5:	hostile
    6:	neutral
    7:	player
    8:	ambient
    9:	voice
  score_update_action:
    0:  update
    1:  remove
  look_target:
    0: feet
    1: eyes
  block_entity_data_action:
    1:  mob_spawner_data 
    2:  command_block_text
    3:  beacon_data
    4:  mob_head_data
    5:  conduit_declaration
    6:  banner_data
    7:  structure_tile_entity_data
    8:  end_gateway_destination
    9:  sign_text
    10: unused
    11: bed_declaration
    12: jigsaw_block_data
    13: campfire_items
    14: beehive_information
  painting:
    0:	kebab 
    1:	aztec 
    2:	alban 
    3:	aztec2 
    4:	bomb 
    5:	plant 
    6:	wasteland 
    7:	pool 
    8:	courbet 
    9:	sea 
    10:	sunset 
    11:	creebet 
    12:	wanderer 
    13:	graham 
    14:	match 
    15:	bust 
    16:	stage 
    17:	void 
    18:	skull_and_roses 
    19:	wither 
    20:	fighters 
    21:	pointer 
    22:	pigscene 
    23:	burning_skull 
    24:	skeleton 
    25:	donkey_kong 
  painting_direction:
    0: south
    1: west
    2: north
    3: east
  update_structure_block_action:
    0: update_data
    1: save_structure
    2: load_structure
    3: detect_size
  update_structure_block_mode:
    0: save
    1: load
    2: corner
    3: data
  update_structure_block_mirror:
    0: none
    1: left_right
    2: front_back
  update_structure_block_rotation:
    0: none
    1: clockwise_90
    2: clockwise_180
    3: counterclockwise_90
  boss_bar_action:
    0: add
    1: remove
    2: update_health
    3: update_title
    4: update_style
    5: update_flags
  boss_bar_color:
    0:  pink
    1:  blue
    2:  red
    3:  green
    4:  yellow
    5:  purple
    6:  white 
  boss_bar_division:
    0:  no_division
    1:  notches_6
    2:  notches_10
    3:  notches_12
    4:  notches_20
  title_action:
    0: set_title
    1: set_subtitle
    2: set_action_bar
    3: set_timings
    4: hide
    5: reset
  teams_mode:
    0: create
    1: remove
    2: update
    3: add_players
    4: remove_players
  #name_tag_visibility:
    # always, hideForOtherTeams, hideForOwnTeam, never
  #team_collision_rule:
    # always, pushOtherTeams, pushOwnTeam, never
  team_color:
    #0-15 	Color formatting, same values as Chat colors.
    16: obfuscated
    17: bold
    18: strikethrough
    19: underlined
    20: italic
    21: reset
