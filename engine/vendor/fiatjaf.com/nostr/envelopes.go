package nostr

import (
	"errors"
	"fmt"
	"strconv"
	"strings"
	"unsafe"

	"github.com/mailru/easyjson"
	jwriter "github.com/mailru/easyjson/jwriter"
	"github.com/templexxx/xhex"
	"github.com/tidwall/gjson"
)

var (
	UnknownLabel        = errors.New("unknown envelope label")
	InvalidJsonEnvelope = errors.New("invalid json envelope")
)

func ParseMessage(message string) (Envelope, error) {
	firstQuote := strings.IndexByte(message, '"')
	if firstQuote == -1 {
		return nil, InvalidJsonEnvelope
	}
	secondQuote := strings.IndexByte(message[firstQuote+1:], '"')
	if secondQuote == -1 {
		return nil, InvalidJsonEnvelope
	}
	label := message[firstQuote+1 : firstQuote+1+secondQuote]

	var v Envelope
	switch label {
	case "EVENT":
		v = &EventEnvelope{}
	case "REQ":
		v = &ReqEnvelope{}
	case "COUNT":
		v = &CountEnvelope{}
	case "NOTICE":
		x := NoticeEnvelope("")
		v = &x
	case "EOSE":
		x := EOSEEnvelope("")
		v = &x
	case "OK":
		v = &OKEnvelope{}
	case "AUTH":
		v = &AuthEnvelope{}
	case "CLOSED":
		v = &ClosedEnvelope{}
	case "CLOSE":
		x := CloseEnvelope("")
		v = &x
	default:
		return nil, UnknownLabel
	}

	if err := v.FromJSON(message); err != nil {
		return nil, err
	}

	return v, nil
}

// Envelope is the interface for all nostr message envelopes.
type Envelope interface {
	Label() string
	FromJSON(string) error
	MarshalJSON() ([]byte, error)
	String() string
}

var (
	_ Envelope = (*EventEnvelope)(nil)
	_ Envelope = (*ReqEnvelope)(nil)
	_ Envelope = (*CountEnvelope)(nil)
	_ Envelope = (*NoticeEnvelope)(nil)
	_ Envelope = (*EOSEEnvelope)(nil)
	_ Envelope = (*CloseEnvelope)(nil)
	_ Envelope = (*OKEnvelope)(nil)
	_ Envelope = (*AuthEnvelope)(nil)
)

// EventEnvelope represents an EVENT message.
type EventEnvelope struct {
	SubscriptionID *string
	Event
}

func (_ EventEnvelope) Label() string { return "EVENT" }

func (v *EventEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	switch len(arr) {
	case 2:
		return easyjson.Unmarshal(unsafe.Slice(unsafe.StringData(arr[1].Raw), len(arr[1].Raw)), &v.Event)
	case 3:
		subid := string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str)))
		v.SubscriptionID = &subid
		return easyjson.Unmarshal(unsafe.Slice(unsafe.StringData(arr[2].Raw), len(arr[2].Raw)), &v.Event)
	default:
		return fmt.Errorf("failed to decode EVENT envelope")
	}
}

func (v EventEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["EVENT",`)
	if v.SubscriptionID != nil {
		w.RawString(`"`)
		w.RawString(*v.SubscriptionID)
		w.RawString(`",`)
	}
	v.Event.MarshalEasyJSON(&w)
	w.RawString(`]`)
	return w.BuildBytes()
}

// ReqEnvelope represents a REQ message.
type ReqEnvelope struct {
	SubscriptionID string
	Filters        []Filter
}

func (_ ReqEnvelope) Label() string { return "REQ" }
func (c ReqEnvelope) String() string {
	v, _ := json.Marshal(c)
	return string(v)
}

func (v *ReqEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 3 {
		return fmt.Errorf("failed to decode REQ envelope: missing filters")
	}
	v.SubscriptionID = string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str)))

	v.Filters = make([]Filter, len(arr)-2)
	for i, filterj := range arr[2:] {
		if err := easyjson.Unmarshal(unsafe.Slice(unsafe.StringData(filterj.Raw), len(filterj.Raw)), &v.Filters[i]); err != nil {
			return fmt.Errorf("on filter: %w", err)
		}
	}

	return nil
}

func (v ReqEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["REQ","`)
	w.RawString(v.SubscriptionID)
	w.RawString(`",`)
	v.Filters[0].MarshalEasyJSON(&w)
	w.RawString(`]`)
	return w.BuildBytes()
}

// CountEnvelope represents a COUNT message.
type CountEnvelope struct {
	SubscriptionID string
	Filter
	Count       *uint32
	HyperLogLog []byte
}

func (_ CountEnvelope) Label() string { return "COUNT" }
func (c CountEnvelope) String() string {
	v, _ := json.Marshal(c)
	return string(v)
}

func (v *CountEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 3 {
		return fmt.Errorf("failed to decode COUNT envelope: missing filters")
	}
	v.SubscriptionID = string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str)))

	var countResult struct {
		Count *uint32
		HLL   string
	}
	if err := json.Unmarshal(unsafe.Slice(unsafe.StringData(arr[2].Raw), len(arr[2].Raw)), &countResult); err == nil && countResult.Count != nil {
		v.Count = countResult.Count
		if len(countResult.HLL) == 512 {
			v.HyperLogLog, err = HexDecodeString(countResult.HLL)
			if err != nil {
				return fmt.Errorf("invalid \"hll\" value in COUNT message: %w", err)
			}
		}
		return nil
	}

	item := unsafe.Slice(unsafe.StringData(arr[2].Raw), len(arr[2].Raw))
	if err := easyjson.Unmarshal(item, &v.Filter); err != nil {
		return fmt.Errorf("on filter: %w", err)
	}

	return nil
}

func (v CountEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["COUNT","`)
	w.RawString(v.SubscriptionID)
	w.RawString(`",`)
	if v.Count != nil {
		w.RawString(`{"count":`)
		w.RawString(strconv.FormatUint(uint64(*v.Count), 10))
		if v.HyperLogLog != nil {
			w.RawString(`,"hll":"`)
			hllHex := make([]byte, 512)
			xhex.Encode(hllHex, v.HyperLogLog)
			w.Buffer.AppendBytes(hllHex)
			w.RawString(`"`)
		}
		w.RawString(`}`)
	} else {
		v.Filter.MarshalEasyJSON(&w)
	}
	w.RawString(`]`)
	return w.BuildBytes()
}

// NoticeEnvelope represents a NOTICE message.
type NoticeEnvelope string

func (_ NoticeEnvelope) Label() string { return "NOTICE" }
func (n NoticeEnvelope) String() string {
	v, _ := json.Marshal(n)
	return string(v)
}

func (v *NoticeEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 2 {
		return fmt.Errorf("failed to decode NOTICE envelope")
	}
	*v = NoticeEnvelope(string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str))))
	return nil
}

func (v NoticeEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["NOTICE",`)
	w.Raw(json.Marshal(string(v)))
	w.RawString(`]`)
	return w.BuildBytes()
}

// EOSEEnvelope represents an EOSE (End of Stored Events) message.
type EOSEEnvelope string

func (_ EOSEEnvelope) Label() string { return "EOSE" }
func (e EOSEEnvelope) String() string {
	v, _ := json.Marshal(e)
	return string(v)
}

func (v *EOSEEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 2 {
		return fmt.Errorf("failed to decode EOSE envelope")
	}
	*v = EOSEEnvelope(string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str))))
	return nil
}

func (v EOSEEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["EOSE",`)
	w.Raw(json.Marshal(string(v)))
	w.RawString(`]`)
	return w.BuildBytes()
}

// CloseEnvelope represents a CLOSE message.
type CloseEnvelope string

func (_ CloseEnvelope) Label() string { return "CLOSE" }
func (c CloseEnvelope) String() string {
	v, _ := json.Marshal(c)
	return string(v)
}

func (v *CloseEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	switch len(arr) {
	case 2:
		*v = CloseEnvelope(string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str))))
		return nil
	default:
		return fmt.Errorf("failed to decode CLOSE envelope")
	}
}

func (v CloseEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["CLOSE",`)
	w.Raw(json.Marshal(string(v)))
	w.RawString(`]`)
	return w.BuildBytes()
}

// ClosedEnvelope represents a CLOSED message.
type ClosedEnvelope struct {
	SubscriptionID string
	Reason         string
}

func (_ ClosedEnvelope) Label() string { return "CLOSED" }
func (c ClosedEnvelope) String() string {
	v, _ := json.Marshal(c)
	return string(v)
}

func (v *ClosedEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	switch len(arr) {
	case 3:
		*v = ClosedEnvelope{
			string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str))),
			string(unsafe.Slice(unsafe.StringData(arr[2].Str), len(arr[2].Str))),
		}
		return nil
	default:
		return fmt.Errorf("failed to decode CLOSED envelope")
	}
}

func (v ClosedEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["CLOSED",`)
	w.Raw(json.Marshal(string(v.SubscriptionID)))
	w.RawString(`,`)
	w.Raw(json.Marshal(v.Reason))
	w.RawString(`]`)
	return w.BuildBytes()
}

// OKEnvelope represents an OK message.
type OKEnvelope struct {
	EventID ID
	OK      bool
	Reason  string
}

func (_ OKEnvelope) Label() string { return "OK" }
func (o OKEnvelope) String() string {
	v, _ := json.Marshal(o)
	return string(v)
}

func (v *OKEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 4 {
		return fmt.Errorf("failed to decode OK envelope: missing fields")
	}
	if err := xhex.Decode(v.EventID[:], []byte(arr[1].Str)); err != nil {
		return err
	}
	v.OK = arr[2].Raw == "true"
	v.Reason = string(unsafe.Slice(unsafe.StringData(arr[3].Str), len(arr[3].Str)))

	return nil
}

func (v OKEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["OK","`)
	w.RawString(HexEncodeToString(v.EventID[:]))
	w.RawString(`",`)
	ok := "false"
	if v.OK {
		ok = "true"
	}
	w.RawString(ok)
	w.RawString(`,`)
	w.Raw(json.Marshal(v.Reason))
	w.RawString(`]`)
	return w.BuildBytes()
}

// AuthEnvelope represents an AUTH message.
type AuthEnvelope struct {
	Challenge *string
	Event     Event
}

func (_ AuthEnvelope) Label() string { return "AUTH" }
func (a AuthEnvelope) String() string {
	v, _ := json.Marshal(a)
	return string(v)
}

func (v *AuthEnvelope) FromJSON(data string) error {
	r := gjson.Parse(data)
	arr := r.Array()
	if len(arr) < 2 {
		return fmt.Errorf("failed to decode Auth envelope: missing fields")
	}
	if arr[1].IsObject() {
		return easyjson.Unmarshal(unsafe.Slice(unsafe.StringData(arr[1].Raw), len(arr[1].Raw)), &v.Event)
	} else {
		challenge := string(unsafe.Slice(unsafe.StringData(arr[1].Str), len(arr[1].Str)))
		v.Challenge = &challenge
	}
	return nil
}

func (v AuthEnvelope) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	w.RawString(`["AUTH",`)
	if v.Challenge != nil {
		w.Raw(json.Marshal(*v.Challenge))
	} else {
		v.Event.MarshalEasyJSON(&w)
	}
	w.RawString(`]`)
	return w.BuildBytes()
}
