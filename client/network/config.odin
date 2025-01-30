package network

// increment if the structure of the packets change. Make sure version is always the first byte
CURRENT_VERSION :: 1

// if you add or remove data from the header, adjust this to the correct size (bytes)
HEADER_SIZE :: 4

// the max size a packet can be (bytes)
PACKET_MAX_SIZE :: 512

// the max size the payload of a packet can be (bytes)
PAYLOAD_MAX_SIZE :: PACKET_MAX_SIZE - HEADER_SIZE

// how many times we want to attempt to connect the server before giving up
MAX_ATTEMPTS :: 5

// how long we should wait between connection attempts (seconds)
CONNECT_ATTEMPT_DELAY :: 10
