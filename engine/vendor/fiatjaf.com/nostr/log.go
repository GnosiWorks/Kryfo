package nostr

import (
	"log"
	"os"
)

var (
	// call SetOutput on InfoLogger to enable info logging
	InfoLogger = log.New(os.Stderr, "[nl][info] ", log.LstdFlags)

	// call SetOutput on DebugLogger to enable debug logging
	DebugLogger = log.New(os.Stderr, "[nl][debug] ", log.LstdFlags)
)
