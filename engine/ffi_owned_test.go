// SPDX-License-Identifier: GPL-3.0-or-later
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"path/filepath"
	"strings"
	"testing"
)

// dart frees every string an export returns with HaloFree, so each one has
// to be a fresh C.CString, never a pointer the engine keeps or shares
func TestExportedStringsAreOwned(t *testing.T) {
	fset := token.NewFileSet()
	paths, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	o := owned{funcs: map[string]*ast.FuncDecl{}, seen: map[string]bool{}}
	var exports []*ast.FuncDecl
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
			if !ok || fd.Recv != nil {
				continue
			}
			o.funcs[fd.Name.Name] = fd
			if isExport(fd) && returnsCString(fd) {
				exports = append(exports, fd)
			}
		}
	}
	if len(exports) < 100 {
		t.Fatalf("only %d string exports found", len(exports))
	}
	for _, fd := range exports {
		for _, bad := range o.returns(fd, 0) {
			t.Errorf("%s: %s returns %s, not a fresh C.CString",
				fset.Position(bad.Pos()), fd.Name.Name, types.ExprString(bad))
		}
	}
	free := o.funcs["HaloFree"]
	if free == nil || !callsC(free, "free") {
		t.Error("HaloFree does not hand the string to C.free")
	}
}

func isExport(fd *ast.FuncDecl) bool {
	if fd.Doc == nil {
		return false
	}
	for _, c := range fd.Doc.List {
		if strings.HasPrefix(c.Text, "//export ") {
			return true
		}
	}
	return false
}

func isC(e ast.Expr, name string) bool {
	sel, ok := e.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	x, ok := sel.X.(*ast.Ident)
	return ok && x.Name == "C" && sel.Sel.Name == name
}

func returnsCString(fd *ast.FuncDecl) bool {
	r := fd.Type.Results
	if r == nil || len(r.List) != 1 || len(r.List[0].Names) > 1 {
		return false
	}
	s, ok := r.List[0].Type.(*ast.StarExpr)
	return ok && isC(s.X, "char")
}

func callsC(fd *ast.FuncDecl, name string) bool {
	found := false
	ast.Inspect(fd.Body, func(n ast.Node) bool {
		if c, ok := n.(*ast.CallExpr); ok && isC(c.Fun, name) {
			found = true
		}
		return !found
	})
	return found
}

type owned struct {
	funcs map[string]*ast.FuncDecl
	// helpers already looked at, by name and result index
	seen map[string]bool
}

// the returns of fd whose result idx is not a fresh string
func (o owned) returns(fd *ast.FuncDecl, idx int) []ast.Expr {
	var bad []ast.Expr
	ast.Inspect(fd.Body, func(n ast.Node) bool {
		if _, ok := n.(*ast.FuncLit); ok {
			return false
		}
		r, ok := n.(*ast.ReturnStmt)
		if !ok {
			return true
		}
		if len(r.Results) <= idx {
			bad = append(bad, &ast.Ident{Name: "a bare return", NamePos: r.Pos()})
		} else if e := r.Results[idx]; !o.fresh(fd, e) {
			bad = append(bad, e)
		}
		return true
	})
	return bad
}

func (o owned) fresh(in *ast.FuncDecl, e ast.Expr) bool {
	switch v := e.(type) {
	case *ast.ParenExpr:
		return o.fresh(in, v.X)
	case *ast.Ident:
		return v.Name == "nil" || o.assigned(in, v.Name)
	case *ast.CallExpr:
		if isC(v.Fun, "CString") {
			return true
		}
		if id, ok := v.Fun.(*ast.Ident); ok {
			return o.helper(id.Name, 0)
		}
	}
	return false
}

// a function of this package whose result idx is fresh on every return
func (o owned) helper(name string, idx int) bool {
	fd := o.funcs[name]
	if fd == nil || fd.Type.Results == nil {
		return false
	}
	key := fmt.Sprintf("%s/%d", name, idx)
	if ok, done := o.seen[key]; done {
		return ok
	}
	// a cycle holds until one of its returns says otherwise
	o.seen[key] = true
	ok := len(o.returns(fd, idx)) == 0
	o.seen[key] = ok
	return ok
}

// a local of fn whose every assignment is fresh
func (o owned) assigned(fn *ast.FuncDecl, name string) bool {
	found, ok := false, true
	ast.Inspect(fn.Body, func(n ast.Node) bool {
		a, isAssign := n.(*ast.AssignStmt)
		if !isAssign {
			return true
		}
		for i, l := range a.Lhs {
			if id, isID := l.(*ast.Ident); !isID || id.Name != name {
				continue
			}
			found = true
			if len(a.Rhs) == len(a.Lhs) {
				ok = ok && o.fresh(fn, a.Rhs[i])
				continue
			}
			// a, b, c := helper(...)
			call, isCall := a.Rhs[0].(*ast.CallExpr)
			id, isID := ast.Expr(nil).(*ast.Ident)
			if isCall {
				id, isID = call.Fun.(*ast.Ident)
			}
			ok = ok && len(a.Rhs) == 1 && isID && o.helper(id.Name, i)
		}
		return true
	})
	return found && ok
}
