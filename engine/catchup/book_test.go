// SPDX-License-Identifier: GPL-3.0-or-later
package catchup

import "testing"

// our relay is an onion and its clearnet name; the third relay is public
var bookOwn = []string{"onion", "clear"}

func TestOnlyOurRelayHolds(t *testing.T) {
	b := NewBook()
	b.Start(bookOwn, 500, 900)
	if h := b.Holds["onion"]; h != (Hold{Floor: 500, Began: 900}) || !b.Holds["clear"].Held() {
		t.Fatalf("our relay's entries hold %+v and %+v from the file", h, b.Holds["clear"])
	}
	if b.Holds["public"].Held() {
		t.Fatal("a public relay holds from the file")
	}
	c := b.Connect("public", bookOwn, 700, 1000)
	if c.Own || c.Base != 700 || c.Owed.Held() {
		t.Fatalf("a public relay's connection: %+v", c)
	}
	b.Owe(c)
	b.KeepFirst(c, 650, 1300)
	b.Cut(c, Mark{Top: 1300, Cursor: 600})
	if b.Holds["public"].Held() {
		t.Fatal("a public relay's cut walk holds")
	}
	if !b.Marks["public"].Started() {
		t.Fatal("a public relay's cut walk kept no place")
	}
	if f, held := b.Floor(bookOwn); !held || f != 500 {
		t.Fatalf("the floor is %d, %v", f, held)
	}
	// a hold left on a relay that is not ours does not count
	b.Holds["public"] = Hold{Floor: 100, Began: 900}
	if f, _ := b.Floor(bookOwn); f != 500 {
		t.Fatalf("a public relay's hold moved the floor to %d", f)
	}
}

// each entry takes its window from the lowest floor either owes, and a clean
// pass on one lets both go
func TestEitherEntryOfOurRelayCoversTheOther(t *testing.T) {
	b := NewBook()
	b.Holds["onion"] = Hold{Floor: 300, Began: 800}
	b.Marks["onion"] = Mark{Top: 900, Cursor: 400}
	c := b.Connect("clear", bookOwn, 700, 1000)
	if !c.Own || c.Base != 300 || c.Owed != (Hold{Floor: 300, Began: 1000}) {
		t.Fatalf("the clearnet name's connection: %+v", c)
	}
	b.Owe(c)
	b.Done(c, false)
	if b.Holds["clear"].Held() || b.Holds["onion"].Held() || b.Marks["onion"].Started() {
		t.Fatalf("a clean pass from the lowest floor left %+v, %+v", b.Holds, b.Marks)
	}
	if f, held := b.Floor(bookOwn); held {
		t.Fatalf("nothing is owed and the floor is %d", f)
	}
}

// a pass that did not reach down to the other entry's floor leaves it owing
func TestAPassAboveTheOtherFloorLeavesIt(t *testing.T) {
	b := NewBook()
	c := b.Connect("clear", bookOwn, 700, 1000)
	if c.Base != 700 {
		t.Fatalf("base %d", c.Base)
	}
	// the onion's walk was cut from a lower floor after the clearnet
	// name connected
	b.Holds["onion"] = Hold{Floor: 300, Began: 800}
	b.Done(c, false)
	if h := b.Holds["onion"]; h != (Hold{Floor: 300, Began: 800}) {
		t.Fatalf("a pass from 700 let go of a walk owing from 300: %+v", h)
	}
}

// a walk that stepped over its own stretches leaves one more pass owed from
// when it began, and lets the other entry go
func TestASteppedPassLetsTheOtherGo(t *testing.T) {
	b := NewBook()
	b.Start(bookOwn, 500, 900)
	b.Marks["clear"] = Mark{Top: 950, Cursor: 600}
	c := b.Connect("clear", bookOwn, 700, 1000)
	if !c.Resumed || c.Base != 500 {
		t.Fatalf("%+v", c)
	}
	b.Done(c, true)
	if h := b.Holds["clear"]; h != (Hold{Floor: 900, Began: 900}) {
		t.Fatalf("the walk that stepped over holds %+v", h)
	}
	if b.Holds["onion"].Held() {
		t.Fatal("the onion still holds after a pass that covered it")
	}
}

// a connection on the other entry that began before the pass does not hold
// again for what the pass took, and one whose walk reaches lower does
func TestAWalkUnderWayDoesNotHoldAgainForWhatAPassTook(t *testing.T) {
	b := NewBook()
	b.Start(bookOwn, 500, 900)
	onion := b.Connect("onion", bookOwn, 700, 1000)
	b.Owe(onion)
	clear := b.Connect("clear", bookOwn, 700, 1010)
	b.Done(clear, false)
	if b.Holds["onion"].Held() {
		t.Fatal("the clean pass did not let the onion go")
	}
	b.Cut(onion, Mark{Top: 1300, Cursor: 800})
	b.KeepFirst(onion, 800, 1300)
	b.Owe(onion)
	if b.Holds["onion"].Held() || b.Marks["onion"].Started() {
		t.Fatalf("a walk the pass covered holds again: %+v, %+v", b.Holds["onion"], b.Marks["onion"])
	}
	// the next connection is its own
	next := b.Connect("onion", bookOwn, 1000, 1100)
	b.Owe(next)
	if !b.Holds["onion"].Held() {
		t.Fatal("a connection after the pass did not hold")
	}

	// a walk that owes from lower than a pass reached still holds
	b = NewBook()
	b.Holds["onion"] = Hold{Floor: 200, Began: 800}
	low := b.Connect("onion", bookOwn, 700, 1000)
	delete(b.Holds, "onion")
	high := b.Connect("clear", bookOwn, 700, 1010)
	b.Done(high, false)
	b.Cut(low, Mark{Top: 1300, Cursor: 800})
	if h := b.Holds["onion"]; h.Floor != 200 {
		t.Fatalf("a walk owing from 200 was let go by a pass from 700: %+v", h)
	}
}

// a relay that answers the subscription with CLOSED owes nothing, and what
// its connection had under way does not hold again
func TestARefusalHoldsNothing(t *testing.T) {
	b := NewBook()
	b.Start(bookOwn, 500, 900)
	c := b.Connect("onion", bookOwn, 700, 1000)
	b.Marks["onion"] = Mark{Top: 1300, Cursor: 800}
	b.Refused(c)
	if b.Holds["onion"].Held() || b.Marks["onion"].Started() {
		t.Fatal("a relay that refused still holds")
	}
	b.Cut(c, Mark{Top: 1300, Cursor: 700})
	if b.Holds["onion"].Held() || b.Marks["onion"].Started() {
		t.Fatal("what the refused connection had under way held again")
	}
	if f, _ := b.Floor(bookOwn); f != 500 {
		t.Fatalf("the clearnet name's hold went with the onion's: floor %d", f)
	}
}
