package logger

import "core:fmt"

@(private)
COLOUR_RESET :: "\033[0m"
@(private)
COLOUR_RED :: "\033[31m"
@(private)
COLOUR_YELLOW :: "\033[33m"
@(private)
COLOUR_BLUE :: "\033[34m"

Log_Type :: enum {
    info,
    warn,
    error,
}

info :: proc(args: ..any, sep := " ", flush := true) -> int {
    if ODIN_DEBUG {
        return logger(.info, args, sep = sep, flush = flush)
    }

    return 1
}

warn :: proc(args: ..any, sep := " ", flush := true) -> int {
    return logger(.warn, args, sep = sep, flush = flush)
}

error :: proc(args: ..any, sep := " ", flush := true) -> int {
    return logger(.error, args, sep = sep, flush = flush)
}

@(private)
logger :: proc(type: Log_Type, args: ..any, sep := " ", flush := true) -> int {
    col := ""
    switch type {
    case .info:
        col = COLOUR_BLUE
    case .warn:
        col = COLOUR_YELLOW
    case .error:
        col = COLOUR_RED
    }

    fmt.print(col)
    r := fmt.println(..args, sep = sep, flush = flush)
    fmt.print(COLOUR_RESET)
    return r
}
