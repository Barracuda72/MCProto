meta:
  id: var_long
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
      + (len >= 6 ? (groups[5].value << 35) : 0)
      + (len >= 7 ? (groups[6].value << 42) : 0)
      + (len >= 8 ? (groups[7].value << 49) : 0)
      + (len >= 9 ? (groups[8].value << 56) : 0)
      + (len >= 10 ? (groups[9].value << 63) : 0)
    doc: Resulting value as normal integer
