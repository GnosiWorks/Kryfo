package nostr

import (
	"iter"
	"slices"
)

type Tag []string

type Tags []Tag

// GetD gets the first "d" tag (for parameterized replaceable events) value or ""
func (tags Tags) GetD() string {
	for _, v := range tags {
		if len(v) >= 2 && v[0] == "d" {
			return v[1]
		}
	}
	return ""
}

// Has returns true if a tag exists with the given key (whether or not it has a value)
func (tags Tags) Has(key string) bool {
	for _, v := range tags {
		if len(v) >= 1 && v[0] == key {
			return true
		}
	}
	return false
}

// Find returns the first tag with the given key/tagName that also has one value (i.e. at least 2 items)
func (tags Tags) Find(key string) Tag {
	for _, v := range tags {
		if len(v) >= 2 && v[0] == key {
			return v
		}
	}
	return nil
}

// FindAll yields all the tags the given key/tagName that also have one value (i.e. at least 2 items)
func (tags Tags) FindAll(key string) iter.Seq[Tag] {
	return func(yield func(Tag) bool) {
		for _, v := range tags {
			if len(v) >= 2 && v[0] == key {
				if !yield(v) {
					return
				}
			}
		}
	}
}

// FindWithValue is like Find, but also checks if the value (the second item) matches
func (tags Tags) FindWithValue(key, value string) Tag {
	for _, v := range tags {
		if len(v) >= 2 && v[1] == value && v[0] == key {
			return v
		}
	}
	return nil
}

// FindLast is like Find, but starts at the end
func (tags Tags) FindLast(key string) Tag {
	for i := len(tags) - 1; i >= 0; i-- {
		v := tags[i]
		if len(v) >= 2 && v[0] == key {
			return v
		}
	}
	return nil
}

// FindLastWithValue is like FindLast, but starts at the end
func (tags Tags) FindLastWithValue(key, value string) Tag {
	for i := len(tags) - 1; i >= 0; i-- {
		v := tags[i]
		if len(v) >= 2 && v[1] == value && v[0] == key {
			return v
		}
	}
	return nil
}

// Clone creates a new array with these tags inside.
func (tags Tags) Clone() Tags {
	newArr := make(Tags, len(tags))
	copy(newArr, tags)
	return newArr
}

// CloneDeep creates a new array with clones of these tags inside.
func (tags Tags) CloneDeep() Tags {
	newArr := make(Tags, len(tags))
	for i := range newArr {
		newArr[i] = tags[i].Clone()
	}
	return newArr
}

// Clone creates a new array with these tag items inside.
func (tag Tag) Clone() Tag {
	newArr := make(Tag, len(tag))
	copy(newArr, tag)
	return newArr
}

func (tags Tags) ContainsAny(tagName string, values []string) bool {
	for _, tag := range tags {
		if len(tag) < 2 {
			continue
		}

		if tag[0] != tagName {
			continue
		}

		if slices.Contains(values, tag[1]) {
			return true
		}
	}

	return false
}

func (tags Tags) Eq(other Tags) bool {
	if len(tags) != len(other) {
		return false
	}

	for i, tag := range tags {
		otherTag := other[i]

		if !slices.Equal(tag, otherTag) {
			return false
		}
	}

	return true
}
