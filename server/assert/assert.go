package assert

import "fmt"

func Assert(r bool, msg string, args ...any) {
	if !r {
		s, _ := fmt.Print(msg, args)
		panic(s)
	}
}

func NoError(err error, msg string, args ...any) {
	if err != nil {
		s, _ := fmt.Print(msg, args)
		panic(s)
	}
}
