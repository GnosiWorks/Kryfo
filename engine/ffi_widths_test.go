// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"go/ast"
	"go/parser"
	"go/token"
	"path/filepath"
	"strings"
	"testing"
)

// dart binds every export with fixed widths. C.long and C.ulong are 64 bits
// on linux and android and 32 on windows, so an export that took or gave one
// would read half a value, or write past dart's slot, on the pc alone
func TestExportsHaveFixedWidths(t *testing.T) {
	// the check itself sees one
	for src, want := range map[string]string{"*C.long": "long", "C.ulong": "ulong", "C.longlong": "", "*C.char": ""} {
		e, err := parser.ParseExpr(src)
		if err != nil {
			t.Fatal(err)
		}
		if got := widthOf(e); got != want {
			t.Errorf("%s: got %q, want %q", src, got, want)
		}
	}
	fset := token.NewFileSet()
	paths, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	n := 0
	for _, p := range paths {
		if strings.HasSuffix(p, "_test.go") {
			continue
		}
		f, err := parser.ParseFile(fset, p, nil, parser.ParseComments)
		if err != nil {
			t.Fatal(err)
		}
		for _, d := range f.Decls {
			fd, ok := d.(*ast.FuncDecl)
			if !ok || fd.Recv != nil || !isExport(fd) {
				continue
			}
			n++
			var fields []*ast.Field
			fields = append(fields, fd.Type.Params.List...)
			if fd.Type.Results != nil {
				fields = append(fields, fd.Type.Results.List...)
			}
			for _, fl := range fields {
				if w := widthOf(fl.Type); w != "" {
					t.Errorf("%s: %s takes or gives C.%s", fset.Position(fl.Pos()), fd.Name.Name, w)
				}
			}
		}
	}
	if n < 100 {
		t.Fatalf("only %d exports found", n)
	}
}

// the C type of e, through pointers, when its width differs by platform
func widthOf(e ast.Expr) string {
	for {
		s, ok := e.(*ast.StarExpr)
		if !ok {
			break
		}
		e = s.X
	}
	for _, name := range []string{"long", "ulong", "wchar_t"} {
		if isC(e, name) {
			return name
		}
	}
	return ""
}
