package packet

import (
	"bytes"
	"encoding/binary"
	"fmt"

	"github.com/placeholder/untitled-server/assert"
)

func PacketFromStruct[T any](t PacketType, payload T) (*Packet, error) {
	payloadSize := binary.Size(payload)
	packetSize := payloadSize + HEADER_SIZE

	buf := new(bytes.Buffer)
	// write header
	buf.WriteByte(CURRENT_VERSION)
	buf.WriteByte(uint8(t))
	binary.Write(buf, binary.BigEndian, uint16(packetSize))

	// Write the packet payload
	err := binary.Write(buf, binary.BigEndian, payload)
	if err != nil {
		return nil, fmt.Errorf("failed to encode struct payload: %w", err)
	}

	packet := PacketFromBytes(buf.Bytes())
	assert.Assert(bytes.Equal(buf.Bytes(), packet.data), "packet data did not match the buffer bytes.")
	return &packet, nil
}

type Payload_Blank struct{}

type PayloadPlayerCreate struct {
	Id   uint64
	PosX float32
	PosY float32
}

type PayloadEntityCreate struct {
	Id   uint64
	PosX float32
	PosY float32
}

type PayloadEntityMove struct {
	Id     uint64
	PosX   float32
	PosY   float32
	AxisX  int8
	AxisY  int8
	Moving uint8
}

type PayloadEntityRemove struct {
	Id uint64
}
