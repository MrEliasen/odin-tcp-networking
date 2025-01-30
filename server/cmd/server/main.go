package main

import (
	"fmt"
	"log"
	"math/rand"
	"net"

	"github.com/placeholder/untitled-server/pkg/packet"
)

type Vec2 struct {
	X float32
	Y float32
}

type Player struct {
	Id    uint64
	Conn  net.Conn
	Pos   Vec2
	Axis  Vec2
	Ready bool
}

var PlayerList = map[net.Conn]*Player{}

func main() {
	server, err := net.Listen("tcp", ":24816")
	if err != nil {
		log.Fatal(err)
	}
	defer server.Close()

	fmt.Println("listening on :24816")

	for {
		c, err := server.Accept()
		if err != nil {
			fmt.Println(err)
			return
		}

		go handleClientConnection(c)
	}
}

func handleClientConnection(c net.Conn) {
	defer c.Close()

	player := Player{
		Id:   rand.Uint64(),
		Conn: c,
		Pos:  Vec2{X: 0, Y: 0},
		Axis: Vec2{X: 0, Y: 0},
	}

	PlayerList[c] = &player

	fmt.Printf("Serving %s\n", c.RemoteAddr().String())
	framer := packet.NewFramer()
	go packet.RunFramer(&framer, c)

	// send the character details to the client:
	err := send_character_info(player)
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	for {
		pkt := <-framer.Ch
		fmt.Printf("packet received: (%+v) %s\n", pkt.Type(), pkt.String())

		// if we got a disconnect packet from the framer
		if pkt.IsDisconnected() {
			fmt.Printf("%s disconnected.\n", c.RemoteAddr().String())
			return
		}

		fmt.Println("sending:", pkt.Out())

		// echo every packet the client send to everyone else
		for pc, p := range PlayerList {
			if p.Id != player.Id {
				pc.Write(pkt.Out())
			}
		}
	}
}

func send_character_info(player Player) error {
	pkt, err := packet.PacketFromStruct(packet.PacketTypePlayerCreate, packet.PayloadPlayerCreate{
		Id:   player.Id,
		PosX: player.Pos.X,
		PosY: player.Pos.Y,
	})
	if err != nil {
		return err
	}

	// send the character info to the client
	player.Conn.Write(pkt.Out())

	// the packet we send to other players, to create the new entity/player in their game
	pkt, err = packet.PacketFromStruct(packet.PacketTypeEntityCreate, packet.PayloadEntityCreate{
		Id:   player.Id,
		PosX: player.Pos.X,
		PosY: player.Pos.Y,
	})
	if err != nil {
		return err
	}

	// send the new player to all other players and so on
	for conn, p := range PlayerList {
		if p.Id != player.Id {
			conn.Write(pkt.Out())
			continue
		}

		// send this character to the new player
		pkt0, err := packet.PacketFromStruct(packet.PacketTypeEntityCreate, packet.PayloadEntityCreate{
			Id:   p.Id,
			PosX: p.Pos.X,
			PosY: p.Pos.Y,
		})
		if err != nil {
			fmt.Println(err.Error())
		}

		player.Conn.Write(pkt0.Out())
	}

	return nil
}
