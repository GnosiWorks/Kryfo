package nostr

import (
	jlexer "github.com/mailru/easyjson/jlexer"
	jwriter "github.com/mailru/easyjson/jwriter"
	"github.com/templexxx/xhex"
)

func easyjson33014d6eDecodeFiatjafComNostr(in *jlexer.Lexer, out *ProfilePointer) {
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
		key := in.UnsafeFieldName(false)
		in.WantColon()
		if in.IsNull() {
			in.Skip()
			in.WantComma()
			continue
		}
		switch key {
		case "pubkey":
			if in.IsNull() {
				in.Skip()
			} else {
				xhex.Decode(out.PublicKey[:], in.UnsafeBytes())
			}
		case "relays":
			if in.IsNull() {
				in.Skip()
				out.Relays = nil
			} else {
				in.Delim('[')
				if out.Relays == nil {
					if !in.IsDelim(']') {
						out.Relays = make([]string, 0, 4)
					} else {
						out.Relays = []string{}
					}
				} else {
					out.Relays = (out.Relays)[:0]
				}
				for !in.IsDelim(']') {
					out.Relays = append(out.Relays, in.String())
					in.WantComma()
				}
				in.Delim(']')
			}
		default:
			in.SkipRecursive()
		}
		in.WantComma()
	}
	in.Delim('}')
	if isTopLevel {
		in.Consumed()
	}
}

func easyjson33014d6eEncodeFiatjafComNostr(out *jwriter.Writer, in ProfilePointer) {
	out.RawByte('{')
	first := true
	_ = first
	{
		const prefix string = ",\"pubkey\":"
		out.RawString(prefix[1:])
		out.String(in.PublicKey.Hex())
	}
	if len(in.Relays) != 0 {
		const prefix string = ",\"relays\":"
		out.RawString(prefix)
		{
			out.RawByte('[')
			for v4, v5 := range in.Relays {
				if v4 > 0 {
					out.RawByte(',')
				}
				out.String(v5)
			}
			out.RawByte(']')
		}
	}
	out.RawByte('}')
}

// MarshalJSON supports json.Marshaler interface
func (v ProfilePointer) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{}
	easyjson33014d6eEncodeFiatjafComNostr(&w, v)
	return w.Buffer.BuildBytes(), w.Error
}

// MarshalEasyJSON supports easyjson.Marshaler interface
func (v ProfilePointer) MarshalEasyJSON(w *jwriter.Writer) {
	easyjson33014d6eEncodeFiatjafComNostr(w, v)
}

// UnmarshalJSON supports json.Unmarshaler interface
func (v *ProfilePointer) UnmarshalJSON(data []byte) error {
	r := jlexer.Lexer{Data: data}
	easyjson33014d6eDecodeFiatjafComNostr(&r, v)
	return r.Error()
}

// UnmarshalEasyJSON supports easyjson.Unmarshaler interface
func (v *ProfilePointer) UnmarshalEasyJSON(l *jlexer.Lexer) {
	easyjson33014d6eDecodeFiatjafComNostr(l, v)
}

func easyjson33014d6eDecodeFiatjafComNostr1(in *jlexer.Lexer, out *EventPointer) {
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
		key := in.UnsafeFieldName(false)
		in.WantColon()
		if in.IsNull() {
			in.Skip()
			in.WantComma()
			continue
		}
		switch key {
		case "id":
			if in.IsNull() {
				in.Skip()
			} else {
				xhex.Decode(out.ID[:], in.UnsafeBytes())
			}
		case "relays":
			if in.IsNull() {
				in.Skip()
				out.Relays = nil
			} else {
				in.Delim('[')
				if out.Relays == nil {
					if !in.IsDelim(']') {
						out.Relays = make([]string, 0, 4)
					} else {
						out.Relays = []string{}
					}
				} else {
					out.Relays = (out.Relays)[:0]
				}
				for !in.IsDelim(']') {
					out.Relays = append(out.Relays, in.String())
					in.WantComma()
				}
				in.Delim(']')
			}
		case "author":
			if in.IsNull() {
				in.Skip()
			} else {
				xhex.Decode(out.Author[:], in.UnsafeBytes())
			}
		case "kind":
			out.Kind = Kind(in.Uint16())
		default:
			in.SkipRecursive()
		}
		in.WantComma()
	}
	in.Delim('}')
	if isTopLevel {
		in.Consumed()
	}
}

func easyjson33014d6eEncodeFiatjafComNostr1(out *jwriter.Writer, in EventPointer) {
	out.RawByte('{')
	first := true
	_ = first
	{
		const prefix string = ",\"id\":"
		out.RawString(prefix[1:])
		out.String(in.ID.Hex())
	}
	if len(in.Relays) != 0 {
		const prefix string = ",\"relays\":"
		out.RawString(prefix)
		{
			out.RawByte('[')
			for v10, v11 := range in.Relays {
				if v10 > 0 {
					out.RawByte(',')
				}
				out.String(v11)
			}
			out.RawByte(']')
		}
	}
	if in.Author != ZeroPK {
		const prefix string = ",\"author\":"
		out.RawString(prefix)
		out.String(in.Author.Hex())
	}
	if in.Kind != 0 {
		const prefix string = ",\"kind\":"
		out.RawString(prefix)
		out.Uint(uint(in.Kind))
	}
	out.RawByte('}')
}

// MarshalJSON supports json.Marshaler interface
func (v EventPointer) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{}
	easyjson33014d6eEncodeFiatjafComNostr1(&w, v)
	return w.Buffer.BuildBytes(), w.Error
}

// MarshalEasyJSON supports easyjson.Marshaler interface
func (v EventPointer) MarshalEasyJSON(w *jwriter.Writer) {
	easyjson33014d6eEncodeFiatjafComNostr1(w, v)
}

// UnmarshalJSON supports json.Unmarshaler interface
func (v *EventPointer) UnmarshalJSON(data []byte) error {
	r := jlexer.Lexer{Data: data}
	easyjson33014d6eDecodeFiatjafComNostr1(&r, v)
	return r.Error()
}

// UnmarshalEasyJSON supports easyjson.Unmarshaler interface
func (v *EventPointer) UnmarshalEasyJSON(l *jlexer.Lexer) {
	easyjson33014d6eDecodeFiatjafComNostr1(l, v)
}

func easyjson33014d6eDecodeFiatjafComNostr2(in *jlexer.Lexer, out *EntityPointer) {
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
		key := in.UnsafeFieldName(false)
		in.WantColon()
		if in.IsNull() {
			in.Skip()
			in.WantComma()
			continue
		}
		switch key {
		case "pubkey":
			if in.IsNull() {
				in.Skip()
			} else {
				xhex.Decode(out.PublicKey[:], in.UnsafeBytes())
			}
		case "kind":
			out.Kind = Kind(in.Uint16())
		case "identifier":
			out.Identifier = in.String()
		case "relays":
			if in.IsNull() {
				in.Skip()
				out.Relays = nil
			} else {
				in.Delim('[')
				if out.Relays == nil {
					if !in.IsDelim(']') {
						out.Relays = make([]string, 0, 4)
					} else {
						out.Relays = []string{}
					}
				} else {
					out.Relays = (out.Relays)[:0]
				}
				for !in.IsDelim(']') {
					out.Relays = append(out.Relays, in.String())
					in.WantComma()
				}
				in.Delim(']')
			}
		default:
			in.SkipRecursive()
		}
		in.WantComma()
	}
	in.Delim('}')
	if isTopLevel {
		in.Consumed()
	}
}

func easyjson33014d6eEncodeFiatjafComNostr2(out *jwriter.Writer, in EntityPointer) {
	out.RawByte('{')
	first := true
	_ = first
	{
		const prefix string = ",\"pubkey\":"
		out.RawString(prefix[1:])
		out.String(in.PublicKey.Hex())
	}
	{
		const prefix string = ",\"kind\":"
		out.RawString(prefix)
		out.Uint(uint(in.Kind))
	}
	if in.Identifier != "" || in.Kind.IsAddressable() {
		// this is expected, no identifiers in replaceable events, so don't print
		// but we do print in case there is an identifier, incorrectly, to assist debug
		const prefix string = ",\"identifier\":"
		out.RawString(prefix)
		out.String(in.Identifier)
	}
	if len(in.Relays) != 0 {
		const prefix string = ",\"relays\":"
		out.RawString(prefix)
		{
			out.RawByte('[')
			for v16, v17 := range in.Relays {
				if v16 > 0 {
					out.RawByte(',')
				}
				out.String(v17)
			}
			out.RawByte(']')
		}
	}
	out.RawByte('}')
}

// MarshalJSON supports json.Marshaler interface
func (v EntityPointer) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{}
	easyjson33014d6eEncodeFiatjafComNostr2(&w, v)
	return w.Buffer.BuildBytes(), w.Error
}

// MarshalEasyJSON supports easyjson.Marshaler interface
func (v EntityPointer) MarshalEasyJSON(w *jwriter.Writer) {
	easyjson33014d6eEncodeFiatjafComNostr2(w, v)
}

// UnmarshalJSON supports json.Unmarshaler interface
func (v *EntityPointer) UnmarshalJSON(data []byte) error {
	r := jlexer.Lexer{Data: data}
	easyjson33014d6eDecodeFiatjafComNostr2(&r, v)
	return r.Error()
}

// UnmarshalEasyJSON supports easyjson.Unmarshaler interface
func (v *EntityPointer) UnmarshalEasyJSON(l *jlexer.Lexer) {
	easyjson33014d6eDecodeFiatjafComNostr2(l, v)
}
