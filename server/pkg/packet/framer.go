package packet

import (
	"encoding/binary"
	"fmt"
	"io"
)

func NewFramer() PacketFramer {
	return PacketFramer{
		buf: make([]byte, PAYLOAD_MAX_SIZE),
		Ch:  make(chan *Packet, 10),
	}
}

func RunFramer(framer *PacketFramer, reader io.Reader) {
	data := make([]byte, 100)

	for {
		n, err := reader.Read(data)
		if err != nil {
			fmt.Println("err", err.Error())
			if err == io.EOF {
				framer.Ch <- &DISCONNECT_PACKET
				break
			}
		}

		framer.Push(data[:n])
	}

	fmt.Printf("client disconnected, closing framer.")
}

type PacketFramer struct {
	buf    []byte
	cursor int
	Ch     chan *Packet
}

func (pf *PacketFramer) Push(data []byte) error {
	n := copy(pf.buf[pf.cursor:], data)

	if n < len(data) {
		pf.buf = append(pf.buf, data[n:]...)
	}

	pf.cursor += len(data)

	for {
		fmt.Println("pulling..")
		pckt, err := pf.Pull()
		if err != nil || pckt == nil {
			fmt.Println("err", err)
			return err
		}

		fmt.Println("pushing packet", pckt)
		select {
		case pf.Ch <- pckt:
			fmt.Println("Packet successfully sent to channel")
		default:
			fmt.Println("Dropped packet: channel is full")
		}
	}
}

func (pf *PacketFramer) Pull() (*Packet, error) {
	if len(pf.buf[:pf.cursor]) < HEADER_SIZE {
		return nil, nil
	}

	// check version
	if pf.buf[0] != CURRENT_VERSION {
		return nil, fmt.Errorf("wrong packet version: %d", pf.buf[0])
	}

	expectedLen := int(binary.BigEndian.Uint16(pf.buf[2:5]))

	// if we actually have enough data for a packet
	if expectedLen <= pf.cursor {
		out := make([]byte, expectedLen)
		copy(out, pf.buf[:expectedLen])
		copy(pf.buf, pf.buf[expectedLen:])
		pf.cursor = 0
		pckt := PacketFromBytes(out)
		return &pckt, nil
	}

	return nil, nil
}
