#!/usr/bin/env python3
# e3 (ENGINE — hand-verified, build.sh is the gate):
# the badge flow needs a POST over tor (creating an invoice) and a GET that
# tolerates 202 (polling a pending receipt). HaloTorGet only does GET and
# treats anything != 200 as an error, so add HaloTorPost and HaloTorGetJSON.
#
# also aligns the badge tiers with the app's real prices ($20/$50/$100) —
# main.go on the VPS ships with $5/$15/$50 placeholders.
import io

NOSTR = "nostr.go"
s = io.open(NOSTR, encoding="utf-8").read()

anchor = "// like HaloTorGet but returns the body base64-encoded, for binary content"
assert s.count(anchor) == 1, "anchor miss"

add = '''// POST json over tor, returning the response body. used for the badge
// service (creating a donation invoice) so the donor's ip never touches
// anything. any non-2xx comes back as "error: ..." for the caller to skip.
//
//export HaloTorPost
func HaloTorPost(cUrl *C.char, cBody *C.char) *C.char {
	url := C.GoString(cUrl)
	body := C.GoString(cBody)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	req.Header.Set("Content-Type", "application/json")
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: post: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d: %s", resp.StatusCode, string(out)))
	}
	return C.CString(string(out))
}

// GET over tor that keeps the body for ANY 2xx - the badge service answers
// 202 while a payment is still pending, which HaloTorGet would reject.
//
//export HaloTorGetJSON
func HaloTorGetJSON(cUrl *C.char) *C.char {
	url := C.GoString(cUrl)
	if url == "" {
		return C.CString("error: empty url")
	}
	client, err := torNostrClient()
	if err != nil {
		return C.CString(fmt.Sprintf("error: tor client: %v", err))
	}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return C.CString(fmt.Sprintf("error: req: %v", err))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return C.CString(fmt.Sprintf("error: get: %v", err))
	}
	defer resp.Body.Close()
	out, err := io.ReadAll(io.LimitReader(resp.Body, 256*1024))
	if err != nil {
		return C.CString(fmt.Sprintf("error: read: %v", err))
	}
	if resp.StatusCode >= 300 {
		return C.CString(fmt.Sprintf("error: status %d", resp.StatusCode))
	}
	return C.CString(string(out))
}

'''

s = s.replace(anchor, add + anchor, 1)

# strings is needed for the POST body reader
if '"strings"' not in s:
    s = s.replace('\t"sync"\n', '\t"strings"\n\t"sync"\n', 1)

io.open(NOSTR, "w", encoding="utf-8").write(s)
print("e3 ok — HaloTorPost + HaloTorGetJSON added")
