package nostr

import (
	jlexer "github.com/mailru/easyjson/jlexer"
	jwriter "github.com/mailru/easyjson/jwriter"
	"github.com/templexxx/xhex"
)

func easyjsonDecodeFilter(in *jlexer.Lexer, out *Filter) {
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
		case "ids":
			in.Delim('[')
			if out.IDs == nil {
				if !in.IsDelim(']') {
					out.IDs = make([]ID, 0, 20)
				} else {
					out.IDs = []ID{}
				}
			} else {
				out.IDs = (out.IDs)[:0]
			}
			for !in.IsDelim(']') {
				id := ID{}
				b := in.UnsafeBytes()
				if len(b) == 64 {
					xhex.Decode(id[:], b)
				}
				out.IDs = append(out.IDs, id)
				in.WantComma()
			}
			in.Delim(']')
		case "kinds":
			in.Delim('[')
			if out.Kinds == nil {
				if !in.IsDelim(']') {
					out.Kinds = make([]Kind, 0, 8)
				} else {
					out.Kinds = []Kind{}
				}
			} else {
				out.Kinds = (out.Kinds)[:0]
			}
			for !in.IsDelim(']') {
				out.Kinds = append(out.Kinds, Kind(in.Int()))
				in.WantComma()
			}
			in.Delim(']')
		case "authors":
			in.Delim('[')
			if out.Authors == nil {
				if !in.IsDelim(']') {
					out.Authors = make([]PubKey, 0, 40)
				} else {
					out.Authors = []PubKey{}
				}
			} else {
				out.Authors = (out.Authors)[:0]
			}
			for !in.IsDelim(']') {
				pk := PubKey{}
				b := in.UnsafeBytes()
				if len(b) == 64 {
					xhex.Decode(pk[:], b)
				}
				out.Authors = append(out.Authors, pk)
				in.WantComma()
			}
			in.Delim(']')
		case "since":
			out.Since = Timestamp(in.Int64())
		case "until":
			out.Until = Timestamp(in.Int64())
		case "limit":
			out.Limit = int(in.Int())
			if out.Limit == 0 {
				out.LimitZero = true
			}
		case "search":
			out.Search = in.String()
		default:
			if len(key) > 1 && key[0] == '#' {
				if out.Tags == nil {
					out.Tags = make(TagMap, 1)
				}

				tagValues := make([]string, 0, 40)
				in.Delim('[')
				if out.Authors == nil {
					if !in.IsDelim(']') {
						tagValues = make([]string, 0, 4)
					} else {
						tagValues = []string{}
					}
				} else {
					tagValues = (tagValues)[:0]
				}
				for !in.IsDelim(']') {
					tagValues = append(tagValues, in.String())
					in.WantComma()
				}
				in.Delim(']')
				out.Tags[key[1:]] = tagValues
			} else {
				in.SkipRecursive()
			}
		}
		in.WantComma()
	}
	in.Delim('}')
	if isTopLevel {
		in.Consumed()
	}
}

func easyjsonEncodeFilter(out *jwriter.Writer, in Filter) {
	out.RawByte('{')
	first := true
	_ = first
	if len(in.IDs) != 0 {
		first = false
		out.RawString("\"ids\":")
		{
			out.RawByte('[')
			for i, id := range in.IDs {
				if i > 0 {
					out.RawByte(',')
				}
				out.RawString("\"" + HexEncodeToString(id[:]) + "\"")
			}
			out.RawByte(']')
		}
	}
	if len(in.Kinds) != 0 {
		const prefix string = ",\"kinds\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		{
			out.RawByte('[')
			for i, kind := range in.Kinds {
				if i > 0 {
					out.RawByte(',')
				}
				out.Int(int(kind))
			}
			out.RawByte(']')
		}
	}
	if len(in.Authors) != 0 {
		const prefix string = ",\"authors\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		{
			out.RawByte('[')
			for i, pk := range in.Authors {
				if i > 0 {
					out.RawByte(',')
				}
				out.RawString("\"" + HexEncodeToString(pk[:]) + "\"")
			}
			out.RawByte(']')
		}
	}
	if in.Since != 0 {
		const prefix string = ",\"since\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		out.Int64(int64(in.Since))
	}
	if in.Until != 0 {
		const prefix string = ",\"until\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		out.Int64(int64(in.Until))
	}
	if in.Limit != 0 || in.LimitZero {
		const prefix string = ",\"limit\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		out.Int(int(in.Limit))
	}
	if in.Search != "" {
		const prefix string = ",\"search\":"
		if first {
			first = false
			out.RawString(prefix[1:])
		} else {
			out.RawString(prefix)
		}
		out.String(in.Search)
	}
	for tag, values := range in.Tags {
		const prefix string = ",\"authors\":"
		if first {
			first = false
			out.RawString("\"#" + tag + "\":")
		} else {
			out.RawString(",\"#" + tag + "\":")
		}
		{
			out.RawByte('[')
			for i, v := range values {
				if i > 0 {
					out.RawByte(',')
				}
				out.String(v)
			}
			out.RawByte(']')
		}
	}
	out.RawByte('}')
}

// MarshalJSON supports json.Marshaler interface
func (v Filter) MarshalJSON() ([]byte, error) {
	w := jwriter.Writer{NoEscapeHTML: true}
	easyjsonEncodeFilter(&w, v)
	return w.Buffer.BuildBytes(), w.Error
}

// MarshalEasyJSON supports easyjson.Marshaler interface
func (v Filter) MarshalEasyJSON(w *jwriter.Writer) {
	w.NoEscapeHTML = true
	easyjsonEncodeFilter(w, v)
}

// UnmarshalJSON supports json.Unmarshaler interface
func (v *Filter) UnmarshalJSON(data []byte) error {
	r := jlexer.Lexer{Data: data}
	easyjsonDecodeFilter(&r, v)
	return r.Error()
}

// UnmarshalEasyJSON supports easyjson.Unmarshaler interface
func (v *Filter) UnmarshalEasyJSON(l *jlexer.Lexer) {
	easyjsonDecodeFilter(l, v)
}
