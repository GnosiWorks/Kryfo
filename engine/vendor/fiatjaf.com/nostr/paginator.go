package nostr

import (
	"context"
	"math"
	"time"
)

func (pool *Pool) PaginatorWithInterval(
	interval time.Duration,
) func(ctx context.Context, urls []string, filter Filter, opts SubscriptionOptions) chan RelayEvent {
	return func(ctx context.Context, urls []string, filter Filter, opts SubscriptionOptions) chan RelayEvent {
		nextUntil := Now()
		if filter.Until != 0 {
			nextUntil = filter.Until
		}

		globalLimit := uint64(filter.Limit)
		if globalLimit == 0 && !filter.LimitZero {
			globalLimit = math.MaxUint64
		}
		var globalCount uint64 = 0
		globalCh := make(chan RelayEvent)

		repeatedCache := make([]ID, 0, 300)
		nextRepeatedCache := make([]ID, 0, 300)

		go func() {
			defer close(globalCh)

			for {
				filter.Until = nextUntil
				time.Sleep(interval)

				keepGoing := false
				for evt := range pool.FetchMany(ctx, urls, filter, opts) {
					if ContainsID(repeatedCache, evt.ID) {
						continue
					}

					keepGoing = true // if we get one that isn't repeated, then keep trying to get more
					nextRepeatedCache = append(nextRepeatedCache, evt.ID)

					globalCh <- evt

					globalCount++
					if globalCount >= globalLimit {
						return
					}

					if evt.CreatedAt < filter.Until {
						nextUntil = evt.CreatedAt
					}
				}

				if !keepGoing {
					return
				}

				repeatedCache = nextRepeatedCache
				nextRepeatedCache = nextRepeatedCache[:0]
			}
		}()

		return globalCh
	}
}
