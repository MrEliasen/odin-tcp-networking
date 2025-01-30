package network

import "../logger"
import "base:runtime"
import "core:net"
import "core:sync"
import "core:slice"
import "core:sync/chan"
import "core:thread"
import "core:time"

@(private)
FRAMER := framer_new()
@(private)
network_thread: ^thread.Thread
@(private)
game_packets: Message_Queue

@(private)
Message_Queue :: struct {
    queue: [128]Parsed_Packet,
    index: int,
    mutex: sync.Mutex,
}

@(private)
Parsed_Packet :: struct {
    type: Packet_Type,
    payload: []byte,
}

Connection_Status :: enum {
    disconnected,
    disconnecting,
    reconnecting,
    connecting,
    connected,
}

status:: proc() -> (Connection_Status, int) {
    return FRAMER.status, FRAMER.attempts
}

connect :: proc(addr: net.Address, port: int = 24816) {
    context = runtime.default_context()

    if FRAMER.status != .disconnected {
        return
    }

    FRAMER.remote_addr = net.Endpoint {
        port    = port,
        address = addr,
    }

    framer_reset(&FRAMER)
    FRAMER.status = .connecting

    if network_thread != nil {
        disconnect()
    }

    network_thread = thread.create(framer_run)
    network_thread.init_context = context
    network_thread.data = &FRAMER
    thread.start(network_thread)
}

@(private)
handle_new_packets :: proc(framer: ^Packet_Framer, packet: Packet) {
    sync.lock(&game_packets.mutex)
    game_packets.queue[game_packets.index] = Parsed_Packet {
        type    = Packet_Type(packet.data[1]),
        payload = packet.data[HEADER_SIZE:],
    }
    game_packets.index += 1
    sync.unlock(&game_packets.mutex)
}

parse_payload :: proc(packet: Parsed_Packet, $T: typeid) -> ^T {
    if size_of(T) != len(packet.payload) {
        logger.error("Size mismatch between T and packet.payload", typeid_of(T), size_of(T), len(packet.payload), packet.payload)
        return nil
    }

    payload_ptr, ok := slice.get_ptr(packet.payload, 0)
    assert(ok, "failed to get raw pointer of packet payload")

    return cast(^T)payload_ptr
}

disconnect :: proc() {
    defer logger.info("stopped network thread, closing connection.")
    FRAMER.status = .disconnecting
    game_packets.index = 0

    if network_thread != nil {
        thread.join(network_thread)
        thread.destroy(network_thread)
    }

    framer_reset(&FRAMER)
}

get_packet_queue :: proc() -> []Parsed_Packet {
    sync.lock(&game_packets.mutex)
    defer sync.unlock(&game_packets.mutex)
    defer game_packets.index = 0

    if game_packets.index == 0 {
        return {}
    }

    return game_packets.queue[:game_packets.index]
}

send_packet :: proc(t: Packet_Type, payload: $T) {
    bytes := packet_new(t, payload)

    if FRAMER.status != .connected {
        logger.info("failed to send packet, not connrected", t)
        return
    }

    _, err := net.send_tcp(FRAMER.connection, bytes.data)
    if err != nil {
        logger.warn(err)
    }
}
