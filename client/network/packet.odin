#+private
package network

import "../logger"
import "core:encoding/endian"
import "core:fmt"
import "core:mem"
import "core:slice"

/*
========================================================================+=====================+
  Packet Header	(4 Bytes)												|Packet Data (N Bytes)|
========================================================================+=====================+
  1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8 | 1 2 3 4 5 6 7 8 * N |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
|     version     |   packet type   |    packet payload length (N)      |    data...          |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
        255               255                       65535                     2^(8*N) - 1
*/

Packet :: struct {
    data: []u8,
    len:  int,
}

packet_get_version :: proc(p: ^Packet) -> u8 {
    return p.data[0]
}

packet_get_type :: proc(p: ^Packet) -> Packet_Type {
    return Packet_Type(p.data[1])
}

packet_to_string :: proc(p: ^Packet) -> string {
    return fmt.aprintf("%v", p.data)
}

packet_from_bytes :: proc(data: []byte) -> Packet {
    // check we at least have a header
    assert(len(data) >= HEADER_SIZE, "missing header: this should have been handled in the framer")

    // check version
    assert(
        data[0] == CURRENT_VERSION,
        "version mismatch: this should have been handled in the framer",
    )

    // check data length
    packetSize, ok := endian.get_u16(data[2:5], .Big)
    assert(
        ok && len(data) == int(packetSize),
        fmt.aprint(
            "size mismatch: the data size does not match the expected size of the packet",
            len(data),
            int(packetSize),
            ok,
        ),
    )

    return Packet{data = data, len = len(data)}
}

packet_new :: proc(type: Packet_Type, payload: $T) -> Packet {
    packet_size := size_of(T) + HEADER_SIZE
    b := make([]byte, packet_size)

    b[0] = CURRENT_VERSION
    b[1] = byte(type)
    endian.put_u16(b[2:4], .Big, cast(u16)packet_size)

    if packet_size > HEADER_SIZE {
        data := transmute([size_of(T)]byte)payload

        data_ptr, ok := slice.get_ptr(data[:], 0)
        assert(ok, "failed to get raw pointer of packet data")

        dest_ptr, ok2 := slice.get_ptr(b[HEADER_SIZE:], 0)
        assert(ok2, "failed to get raw pointer of packet buffer")

        mem.copy(dest_ptr, data_ptr, len(data))
    }

    return Packet{data = b, len = packet_size}
}
