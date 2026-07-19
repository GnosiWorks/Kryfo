package nostr

import (
	jlexer "github.com/mailru/easyjson/jlexer"
	jwriter "github.com/mailru/easyjson/jwriter"
	"github.com/templexxx/xhex"
)

func easyjsonDecodeEvent(in *jlexer.Lexer, out *Event) {
	isTopLevel := in.IsStart()
	if in.IsNull() {
		if isTopLevel {
			in.Consumed()
		}
		in.Skip()
		return
	}
	in.Delim('{')
	for !in.IsDelim('}') {
		key := in.UnsafeFieldName(true)
		in.WantColon()
		if in.IsNull() {
			in.Skip()
			in.WantComma()
			continue
		}
		switch key {
		case "id":
			b := in.UnsafeBytes()
			if len(b) == 64 {
				xhex.Decode(out.ID[:], b)
			}
		case "pubkey":
			b := in.UnsafeBytes()
			if len(b) == 64 {
				xhex.Decode(out.PubKey[:], b)
			}
		case "created_at":
			out.CreatedAt = Timestamp(in.Int64())
		case "kind":
			out.Kind = Kind(in.Int())
		case "tags":
			in.Delim('[')
			if out.Tags == nil {
				if !in.IsDelim(']') {
					out.Tags = make(Tags, 0, 7)
				} else {
					out.Tags = Tags{}
				}
			} else {
				out.Tags = (out.Tags)[:0]
			}
			for !in.IsDelim(']') {
				var v Tag
				in.Delim('[')
				if !in.IsDelim(']') {
					v = make(Tag, 0, 5)
				} else {
					v = Tag{}
				}
				for !in.IsDelim(']') {
					v = append(v, in.String())
					in.WantComma()
				}
				in.Delim(']')
				out.Tags = append(out.Tags, v)
				in.WantComma()
			}
			in.Delim(']')
		case "content":
			out.Content = in.String()
		case "sig":
			b := in.UnsafeBytes()
			if len(b) == 128 {
				xhex.Decode(out.Sig[:], b)
			}
		}
		in.WantComma()
	}
	in.Delim('}')
	if isTopLevel {
		in.Consumed()
	}
}

func easyjsonEncodeEvent(out *jwriter.Writer, in Event) {
	out.RawByte('{')

	out.RawString("\"kind\":")
	out.Int(int(in.Kind))

	if in.ID != ZeroID {
		out.RawString(",\"id\":\"")
		out.RawString(HexEncodeToString(in.ID[:]) + "\"")
	}

	if in.PubKey != ZeroPK {
		out.RawString(",\"pubkey\":\"")
		out.RawString(HexEncodeToString(in.PubKey[:]) + "\"")
	}

	out.RawString(",\"created_at\":")
	out.Int64(int64(in.CreatedAt))

	out.RawString(",\"tags\":")
	out.RawByte('[')
	for v3, v4 := range in.Tags {
		if v3 > 0 {
			out.RawByte(',')
		}
		out.RawByte('[')
		for v5, v6 := range v4 {
			if v5 > 0 {
				out.RawByte(',')
			}
			out.String(v6)
		}
		out.RawByte(']')
	}
	out.RawByte(']')

	out.RawString(",\"content\":")
	out.String(in.Content)

	if in.Sig != [64]byte{} {
		out.RawString(",\"sig\":\"")
		out.RawString(HexEncodeToString(in.Sig[:]) + "\"")
	}

	out.RawByte('}')
}

// MarshalJSON supports json.Marshaler interface
func (v Event) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	easyjsonEncodeEvent(&w, v)
	return w.Buffer.BuildBytes(), w.Error
}

// MarshalEasyJSON supports easyjson.Marshaler interface
func (v Event) MarshalEasyJSON(w *jwriter.Writer) {
	w.NoEscapeHTML = true
	easyjsonEncodeEvent(w, v)
}

// UnmarshalJSON supports json.Unmarshaler interface
func (v *Event) UnmarshalJSON(data []byte) error {
	r := jlexer.Lexer{Data: data}
	easyjsonDecodeEvent(&r, v)
	return r.Error()
}

// UnmarshalEasyJSON supports easyjson.Unmarshaler interface
func (v *Event) UnmarshalEasyJSON(l *jlexer.Lexer) {
	easyjsonDecodeEvent(l, v)
}
