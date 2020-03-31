meta:
  id: var_int
seq:
  - id: groups
    type: group
    repeat: until
    repeat-until: not _.has_next
types:
  group:
    seq:
      - id: b
        type: u1
    instances:
      has_next:
        value: (b & 0b1000_0000) != 0
        doc: If true, then we have more bytes to read
      value:
        value: b & 0b0111_1111
        doc: The 7-bit (base128) numeric value chunk of this group
      bit_count:
        value: >-
          ((b >> 0) & 1) + 
          ((b >> 1) & 1) +
          ((b >> 2) & 1) +
          ((b >> 3) & 1) +
          ((b >> 4) & 1) +
          ((b >> 5) & 1) +
          ((b >> 6) & 1)
instances:
  len:
    value: groups.size
  value:
    value: >-
      groups[0].value
      + (len >= 2 ? (groups[1].value << 7) : 0)
      + (len >= 3 ? (groups[2].value << 14) : 0)
      + (len >= 4 ? (groups[3].value << 21) : 0)
      + (len >= 5 ? (groups[4].value << 28) : 0)
    doc: Resulting value as normal integer
  bit_count:
    value: >-
      groups[0].bit_count
      + (len >= 2 ? (groups[1].bit_count) : 0)
      + (len >= 3 ? (groups[2].bit_count) : 0)
      + (len >= 4 ? (groups[3].bit_count) : 0)
      + (len >= 5 ? (groups[4].bit_count) : 0)