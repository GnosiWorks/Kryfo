package nostr

import (
	"context"
	"iter"
)

type Publisher interface {
	Publish(context.Context, Event) error
}

type Querier interface {
	QueryEvents(Filter) iter.Seq[Event]
}

type QuerierPublisher interface {
	Querier
	Publisher
}
