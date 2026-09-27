# nostr

A comprehensive Go library for the Nostr protocol, providing everything needed to build relays, clients, or hybrid applications.

This is a new, much improved in all aspects, version of [go-nostr](https://github.com/nbd-wtf/go-nostr).

## Installation

```sh
go get fiatjaf.com/nostr
```

## Components

- **eventstore**: Pluggable storage backends (Bleve, BoltDB, LMDB, in-memory, MMM)
- **khatru**: Flexible framework for building Nostr relays
- **khatru/blossom**: Plugin for a Khatru server that adds flexible Blossom server support
- **khatru/grasp**: Plugin for a Khatru server that adds Grasp server support
- **sdk**: Client SDK with caching, data loading, and outbox relay management
- **keyer**: Key and bunker management utilities
- NIP-specific libraries with helpers and other things for many NIPs and related stuff, including blossom, negentropy and cashu mini-libraries.
