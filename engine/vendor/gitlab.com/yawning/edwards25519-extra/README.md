### edwards25519-extra

This package provides extensions to the Go standard library's Ed25519 and
curve25519 implementations, primarily extracted from [curve25519-voi][1].
This package is intended for interoperability with the standard library
and the [edwards25519][2] package as much as possible.

 * h2c: [Hashing to Elliptic Curves (RFC 9380)][3]
 * vrf: [Verifiable Random Functions (draft version 7 to 10, RFC 9381)][4]

[1]: https://github.com/oasisprotocol/curve25519-voi
[2]: https://filippo.io/edwards25519
[3]: https://datatracker.ietf.org/doc/rfc9380/
[4]: https://datatracker.ietf.org/doc/rfc9381/
