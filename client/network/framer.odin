#+private
package network

import "../logger"
import "base:runtime"
import "core:encoding/endian"
import "core:fmt"
import "core:mem"
import "core:net"
import "core:slice"
import "core:sync/chan"
import "core:thread"
import "core:time"

Packet_Framer :: struct {
    allocator:   mem.Allocator,
    buffer:      []byte,
    cursor:      int,
    queue:       chan.Chan(Packet),
    connection:  net.TCP_Socket,
    remote_addr: net.Endpoint,
    status:      Connection_Status,
    attempts:    int,
}

framer_new :: proc() -> Packet_Framer {
    mchan, err := chan.create(chan.Chan(Packet), context.allocator)
    assert(err == nil, "failed to create packet framer channel")

    return Packet_Framer {
        allocator = context.allocator,
        buffer = make([]byte, PAYLOAD_MAX_SIZE),
        queue = mchan,
        status = .disconnected,
        attempts = 0,
    }
}

framer_reset :: proc(framer: ^Packet_Framer) {
    net.close(framer.connection)
    framer.attempts = 0
    framer.status = .disconnected
    framer.cursor = 0

    // empty channel
    for {
        pkt, ok := chan.try_recv(framer.queue)
        if !ok {
            break
        }
    }
}

framer_run :: proc(t: ^thread.Thread) {
    framer := (cast(^Packet_Framer)t.data)
    buffer := make([]byte, 100)
    framer.status = .connecting

    for i in 0 ..< MAX_ATTEMPTS {
        if framer.status != .connecting {
            return
        }

        framer.attempts += 1
        conn, err := net.dial_tcp_from_endpoint(framer.remote_addr)
        if err != nil {
            logger.warn(err)
            time.sleep(time.Second * CONNECT_ATTEMPT_DELAY)
            continue
        }

        framer.connection = conn
        framer.status = .connected
        break
    }

    if framer.status != .connected {
        logger.warn("failed to connect to server.")
        return
    }

    logger.info("listening..")

    for framer.status == .connected {
        n, err := net.recv_tcp(framer.connection, buffer)
        if err != nil {
            logger.error("framer error:", err)
            continue
        }

        if n == 0 {
            continue
        }

        framer_push(framer, buffer[:n])
    }
}

framer_push :: proc(framer: ^Packet_Framer, data: []byte) -> string {
    bytesLeft := len(framer.buffer) - framer.cursor

    if len(data) > bytesLeft {
        new_buffer := make([]byte, len(framer.buffer) + (len(data) - bytesLeft))
        mem.copy(&new_buffer, &framer.buffer, len(framer.buffer))
        delete(framer.buffer)
        framer.buffer = new_buffer
    }

    data_ptr, ok := slice.get_ptr(data, 0)
    assert(ok, "failed to get raw pointer of packet data in framer_push")
    buffer_ptr, ok2 := slice.get_ptr(framer.buffer, framer.cursor)
    assert(ok2, "failed to get raw pointer of framer buffer in framer_push")

    mem.copy(buffer_ptr, data_ptr, len(data))
    framer.cursor += len(data)

    for {
        pkt, err := framer_pull(framer)
        if err != "" || len(pkt.data) == 0 {
            return err
        }

        // push packet to channel
        handle_new_packets(framer, pkt)
    }
}

framer_pull :: proc(framer: ^Packet_Framer) -> (Packet, string) {
    if len(framer.buffer[:framer.cursor]) < HEADER_SIZE {
        return {}, ""
    }

    if framer.buffer[0] != CURRENT_VERSION {
        return {}, fmt.aprintf("wrong packet version: %x", framer.buffer[0])
    }

    expectedLen, ok := endian.get_u16(framer.buffer[2:4], .Big)
    if !ok {
        return {}, "failed to get expected packet length"
    }

    payloadLen := len(framer.buffer[HEADER_SIZE:framer.cursor])
    fullLen := HEADER_SIZE + payloadLen

    if int(expectedLen) != fullLen {
        return {}, fmt.aprintf(
            "packet data (%d) size does not match packet header size (%d)",
            fullLen,
            expectedLen
        )
    }

    // if we actually have enough data for a packet
    if fullLen <= framer.cursor {
        out := make([]byte, fullLen)
        copy(out, framer.buffer[:fullLen])
        copy(framer.buffer, framer.buffer[fullLen:])
        framer.cursor = 0
        return packet_from_bytes(out), ""
    }

    return {}, ""
}
