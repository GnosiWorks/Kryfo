package nostr

import (
	"math"
	"slices"

	"github.com/mailru/easyjson"
)

type Filter struct {
	IDs     []ID
	Kinds   []Kind
	Authors []PubKey
	Tags    TagMap
	Since   Timestamp
	Until   Timestamp
	Limit   int
	Search  string

	// LimitZero is or must be set when there is a "limit":0 in the filter, and not when "limit" is just omitted
	LimitZero bool `json:"-"`
}

type TagMap map[string][]string

func (ef Filter) String() string {
	j, _ := easyjson.Marshal(ef)
	return string(j)
}

func (ef Filter) Matches(event Event) bool {
	if !ef.MatchesIgnoringTimestampConstraints(event) {
		return false
	}

	if ef.Since != 0 && event.CreatedAt < ef.Since {
		return false
	}

	if ef.Until != 0 && event.CreatedAt > ef.Until {
		return false
	}

	return true
}

//go:inline
func (ef Filter) MatchesIgnoringTimestampConstraints(event Event) bool {
	if ef.IDs != nil && !slices.Contains(ef.IDs, event.ID) {
		return false
	}

	if ef.Kinds != nil && !slices.Contains(ef.Kinds, event.Kind) {
		return false
	}

	if ef.Authors != nil && !slices.Contains(ef.Authors, event.PubKey) {
		return false
	}

	for f, v := range ef.Tags {
		if !event.Tags.ContainsAny(f, v) {
			return false
		}
	}

	return true
}

func FilterEqual(a Filter, b Filter) bool {
	if !similar(a.Kinds, b.Kinds) {
		return false
	}

	if !similarID(a.IDs, b.IDs) {
		return false
	}

	if !similarPublicKey(a.Authors, b.Authors) {
		return false
	}

	if len(a.Tags) != len(b.Tags) {
		return false
	}

	for f, av := range a.Tags {
		if bv, ok := b.Tags[f]; !ok {
			return false
		} else {
			if !similar(av, bv) {
				return false
			}
		}
	}

	if a.Since != b.Since {
		return false
	}

	if a.Until != b.Until {
		return false
	}

	if a.Search != b.Search {
		return false
	}

	if a.LimitZero != b.LimitZero {
		return false
	}

	return true
}

func (ef Filter) Clone() Filter {
	clone := Filter{
		Kinds:     slices.Clone(ef.Kinds),
		Limit:     ef.Limit,
		Search:    ef.Search,
		LimitZero: ef.LimitZero,
		Since:     ef.Since,
		Until:     ef.Until,
	}

	if ef.IDs != nil {
		clone.IDs = make([]ID, len(ef.IDs))
		for i, src := range ef.IDs {
			copy(clone.IDs[i][:], src[:])
		}
	}

	if ef.Authors != nil {
		clone.Authors = make([]PubKey, len(ef.Authors))
		for i, src := range ef.Authors {
			copy(clone.Authors[i][:], src[:])
		}
	}

	if ef.Tags != nil {
		clone.Tags = make(TagMap, len(ef.Tags))
		for k, v := range ef.Tags {
			clone.Tags[k] = slices.Clone(v)
		}
	}

	return clone
}

// GetTheoreticalLimit gets the maximum number of events that a normal filter would ever return, for example, if
// there is a number of "ids" in the filter, the theoretical limit will be that number of ids.
//
// It returns math.MaxInt if there are no theoretical limits.
//
// The given .Limit present in the filter is ignored.
func (filter Filter) GetTheoreticalLimit() int {
	if filter.IDs != nil {
		return len(filter.IDs)
	}

	if filter.Authors != nil && filter.Kinds != nil {
		allAreReplaceable := true
		for _, kind := range filter.Kinds {
			if !kind.IsReplaceable() {
				allAreReplaceable = false
				break
			}
		}
		if allAreReplaceable {
			return len(filter.Authors) * len(filter.Kinds)
		}

		if len(filter.Tags["d"]) > 0 {
			allAreAddressable := true
			for _, kind := range filter.Kinds {
				if !kind.IsAddressable() {
					allAreAddressable = false
					break
				}
			}
			if allAreAddressable {
				return len(filter.Authors) * len(filter.Kinds) * len(filter.Tags["d"])
			}
		}
	}

	if filter.Limit > 0 {
		return filter.Limit
	}

	if filter.LimitZero {
		return 0
	}

	return math.MaxInt
}
