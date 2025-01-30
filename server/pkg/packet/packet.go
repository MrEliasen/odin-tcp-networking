package packet

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"

	"github.com/placeholder/untitled-server/assert"
)

const (
	CURRENT_VERSION  uint8 = 1
	HEADER_SIZE            = 4
	PACKET_MAX_SIZE        = 512
	PAYLOAD_MAX_SIZE       = PACKET_MAX_SIZE - HEADER_SIZE
)

type PacketEncoder interface {
	io.Reader
	Type() PacketType
}

/*
========================================================================+=====================+
  Packet Header	(4 Bytes)												|Packet Data (N Bytes)|
========================================================================+=====================+
  1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8 | 1 2 3 4 5 6 7 8 * N |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
|     version     |   packet type   |    packet payload length (N+4)    |    data...          |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
        255               255                       65535                     2^(8*N) - 1
*/

type Packet struct {
	data []byte
	len  int
}

func (p *Packet) Version() uint8 {
	return p.data[0]
}

func (p *Packet) Type() PacketType {
	return PacketType(p.data[1])
}

func (p *Packet) Data() []byte {
	return p.data[HEADER_SIZE:p.len]
}

func (p *Packet) Out() []byte {
	return p.data
}

func (p *Packet) String() string {
	return fmt.Sprintf("Packet(%d) -> %v", p.len, p.data)
}

func (p *Packet) IsDisconnected() bool {
	return bytes.Equal(p.data, DISCONNECT_PACKET.data)
}

func PacketFromBytes(data []byte) Packet {
	// check we at least have a header
	assert.Assert(len(data) >= HEADER_SIZE, "missing header: this should have been handled in the framer")

	// check version
	assert.Assert(data[0] == CURRENT_VERSION, "version mismatch: this should have been handled in the framer")

	// check data length
	packetSize := binary.BigEndian.Uint16(data[2:4])
	assert.Assert(len(data) == int(packetSize), "size mismatch: the data size does not match the expected size of the packet.")

	return Packet{
		data: data,
		len:  len(data),
	}
}

func NewPacket(encoder PacketEncoder) Packet {
	b := make([]byte, PACKET_MAX_SIZE)

	data := b[HEADER_SIZE:]
	n, err := encoder.Read(data)
	assert.NoError(err, "encoding failed: packet data could not be encoded")
	assert.Assert(n == PAYLOAD_MAX_SIZE, "encoded data max size exceeded", n)

	b[0] = CURRENT_VERSION
	b[1] = uint8(encoder.Type())

	binary.BigEndian.PutUint16(b[2:], uint16(n))

	return Packet{
		data: b,
		len:  n + HEADER_SIZE,
	}
}
