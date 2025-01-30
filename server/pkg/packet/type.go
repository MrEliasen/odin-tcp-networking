package packet

type (
	PacketType uint8
)

// these need to be in the same order as on the client
const (
	PacketTypeNil PacketType = iota
	PacketTypeDisconnected
	PacketTypePlayerReady
	PacketTypePlayerCreate
	PacketTypeEntityLeave
	PacketTypeEntityCreate
	PacketTypeEntityMove
)

// this is just an example of how you can create a packet in the framer when a player disconnects, so you can handle it outside
// the framer.
var DISCONNECT_PACKET = PacketFromBytes([]byte{CURRENT_VERSION, uint8(PacketTypeDisconnected), 0, uint8(HEADER_SIZE)})
