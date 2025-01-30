package network

// these need to be in the same order as on the server
Packet_Type :: enum u8 {
    nil,
    disconnected,
    player_ready,
    player_create,
    entity_leave,
    entity_create,
    entity_move,
}

Payload_Blank :: struct {}

Payload_Move :: struct {
    id:        u64,
    pos_x:     f32,
    pos_y:     f32,
    axis_x:    i8,
    axis_y:    i8,
    is_moving: u8,
}

Payload_Player_Create :: struct {
    id:    u64,
    pos_x: f32,
    pos_y: f32,
}

Payload_Entity_Create :: struct {
    id:    u64,
    pos_x: f32,
    pos_y: f32,
}

Payload_Entity_Remove :: struct {
    id: u64,
}
