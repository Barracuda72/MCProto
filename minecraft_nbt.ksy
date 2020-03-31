meta:
  id: nbt
  file-extension: nbt
  endian: be
  application: Named Binary Tag (NBT) (uncompressed)
  
seq:
  - id: root_element
    type: compound_element
    
types:
  tag_byte:
    seq:
      - id: content
        type: s1
        
  tag_short:
    seq:
      - id: content
        type: s2
        
  tag_int:
    seq:
      - id: content
        type: s4
        
  tag_long:
    seq:
      - id: content
        type: s8
        
  tag_float:
    seq:
      - id: content
        type: f4
        
  tag_double:
    seq:
      - id: content
        type: f8
        
  tag_byte_array:
    seq:
      - id: length
        type: s4
      - id: content
        type: s1
        repeat: expr
        repeat-expr: length
        
  tag_int_array:
    seq:
      - id: length
        type: s4
      - id: content
        type: s4
        repeat: expr
        repeat-expr: length
        
  tag_long_array:
    seq:
      - id: length
        type: s4
      - id: content
        type: s8
        repeat: expr
        repeat-expr: length
        
  tag_string:
    seq:
      - id: length
        type: u2
      - id: content
        size: length
        type: str
        encoding: UTF-8
        
  tag_list:
    seq:
      - id: tag_id
        type: u1
        enum: tags
      - id: length
        type: s4
      - id: content
        repeat: expr
        repeat-expr: length
        type:
          switch-on: tag_id
          cases:
            tags::byte:       tag_byte
            tags::short:      tag_short
            tags::int:        tag_int
            tags::long:       tag_long
            tags::float:      tag_float
            tags::double:     tag_double
            tags::byte_array: tag_byte_array
            tags::string:     tag_string
            tags::list:       tag_list
            tags::compound:   tag_compound
            tags::int_array:  tag_int_array
            tags::long_array: tag_long_array
            
  tag_compound:
    seq:
      - id: data
        type: compound_element
        repeat: until
        repeat-until: _.tag_id == tags::end
        
  compound_element:
    seq:
      - id: tag_id
        type: u1
        enum: tags
      - id: tag_name
        type: tag_string
        if: tag_id != tags::end
      - id: tag_data
        type:
          switch-on: tag_id
          cases:
            tags::byte:       tag_byte
            tags::short:      tag_short
            tags::int:        tag_int
            tags::long:       tag_long
            tags::float:      tag_float
            tags::double:     tag_double
            tags::byte_array: tag_byte_array
            tags::string:     tag_string
            tags::list:       tag_list
            tags::compound:   tag_compound
            tags::int_array:  tag_int_array
            tags::long_array: tag_long_array
        if: tag_id != tags::end
        
enums:
  tags:
    0: end
    1: byte
    2: short
    3: int
    4: long
    5: float
    6: double
    7: byte_array
    8: string
    9: list
    10: compound
    11: int_array
    12: long_array
      