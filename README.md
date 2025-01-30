# Odin Networking Example

This is an example of how you can add networking (client) to your Odin project, connecting to a remote server.

The intention when making this was for adding multiplayer capability to a game, assuming a remote server,
however the implementation is not far off if you wanted to move the TCP server into Odin, the same
framer and packets can be used for that as well.

I do not have a lot of experience with Odin so take it for what it is, a prototype.

# The Client

The TCP client runs in its own thread, the Packet_Framer is what consumes and handles incoming data,
and makes sure it is in the format we need.

The packets are no super compact as I am relying on the size of a piece of data being at least a byte
long, even if it could be stored in 2 bits. This in intentional as it means I can make the encoding and
decoding very generic so all you need to update a packet is change that packet's payload struct on the client and server.

Word of caution, some types do not encode/decode as you would hope, eg. I had issue with booleans as an example, not decoding properly when transmuted/cast.
I would recommend sticking to just numeric/scalar types (u/i8, u/i16, u/i/f32, uint16 etc..).
However this could very likely just be a skill issue, so don't take that as gospel. Also the packets are not encrypted in this code.


# The Server

It is a very very basic Go application, it is no more than an example of the pieces needed to add to your own
application.

Similarly with the client code, the encoding and decoding is kept generic so all you really need to do
is update the structs so they are the same as on the client.


# Implementation (client)

Copy the `client/network` folder into your Odin project and you can now do the following. I left a very basic logger in there as well as it might be useful.


# Packet structure

Its a pretty simple structure, and if you needed to add or change it, it shouldn't be too much trouble.

```
========================================================================+=====================+
  Packet Header	(4 Bytes)                                               |Packet Data (N Bytes)|
========================================================================+=====================+
  1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8   1 2 3 4 5 6 7 8 | 1 2 3 4 5 6 7 8 * N |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
|     version     |   packet type   |    packet payload length (N)      |    data...          |
+ - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - + - - - - - - - - - - +
        255               255                       65535                     2^(8*N) - 1
```


## Connection Status

`network.status()`: will return a tuple of "Connection_Status" and "Attempts". The "attempts" is how many attempts it made to try and connect.

```odin
Connection_Status :: enum {
    disconnected,
    disconnecting,
    reconnecting,
    connecting,
    connected,
}
```


## Connect 

This will attempt to connect to the ip and port, you can follow the status with the above `network.connection_status()` it will try for as many times as the `MAX_ATTEMPTS` are set to in the `client/network/framer.odin` file.

```odin
import "core:net"

ip := net.parse_address("127.0.0.1")
port := 24816
network.connect(ip, port)`
```


## Connect 

Calling `network.disconnect()` will disconnect the client, kill the network thread and reset the framer. Should work.**



## Send Message/Packet

You can send packets to the server using the following procedure: `network.send_packet(network.Packet_Type, network.Payload_Struct)`

It takes the type of packet you are sending, and its associated payload struct, both can be found and changed in `network/packet_type.odin`.

If we wanted to send an  `entity move` packet, it would look something like this:

```odin
entity := game_state.entities[id]

network.send_packet(network.Packet_Type.entity_move, network.Payload_Entity_Move{
    id = id,
    pos_x = entity.pos.x,
    pos_x = entity.pos.x
    is_moving  = entity.input_axis.x * entity.input_axis.y != 0
})
```

The packet struct examples in this repo are just to give you an idea, you will of cause need to add/remove/adjust as you see fit.


## Handling Messages/Packets

To consume the packets which have been received and framed, you can call `network.get_packet_queue()` 
this will return a list of all the packet which you can then handle how you see fit.

A very basic example below (pseudo code):

```odin
package game

import "network"

game_loop_handle_network :: proc(game_state: ^Game_State) {
    // get the packets we received
    packets := network.get_packet_queue()

    for &packet in packets {
        // based on the type of packet
        #partial switch packet.type {
        case network.Packet_Type.entity_create:
            {
                // we can parse the packet into its related struct
                data := network.parse_payload(packet, network.Payload_Entity_Create)
                if data == nil {
                    continue
                }

                // and access the data within in our game.
                create_entity(game_state, data.id, Vector2{data.pos_x, data.pos_y})
            }
        case network.Packet_Type.entity_leave:
            {
                data := network.parse_payload(packet, network.Payload_Entity_Remove)
                if data == nil {
                    continue
                }

                delete_entity(game_state, data.id)
            }
        case network.Packet_Type.entity_move:
            {
                data := network.parse_payload(packet, network.Payload_Move)
                if data == nil {
                    continue
                }

                game_state.entities[data.id].pos = Vector2{data.pos_x, data.pos_y}
                game_state.entities[data.id].axis = Vector2{f32(data.axis_x), f32(data.axis_y)}
                game_state.entities[data.id].is_moving = data.is_moving == 1
            }
        }
    }
}
```
