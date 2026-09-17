# servers

what runs where, and the one rule about it.

## the rule

**anything a user's phone talks to that is not the relay goes on a box that
is not the relay's box.**

the relay sees a pubkey's traffic: when it connects, when it publishes, how
much. it does not know who that pubkey is, and tor keeps it from learning
where they are. any other service on the same machine is a second clock in
the same room. someone claims @wren at 14:02:07, and at 14:02:09 a pubkey that
had been idle publishes. nobody logged a name and nobody had to: whoever holds
that one machine, by seizure, by court order or by breaking in, can line the
two up. turning logs off narrows it. it does not remove it, because the
timing exists while the traffic does.

two machines means two seizures, two providers and two sets of clocks that
have to be compared on purpose. a second vps is a few euros a month. that is
cheap against a correlation there is no other way to take out.

this goes for everything that comes later too: a gif proxy, call rendezvous,
whatever is next. if a phone reaches it and it is not the relay, it does not
live with the relay.

## today

| service | reached at | box | follows the rule |
|---|---|---|---|
| relay (`relay-live/`) | `wss://relay.kryfo.app` and its onion | relay box | it is the relay |
| handle registry (`server/handle/`) | `https://relay.kryfo.app/handle/*`, `/@name` | relay box | **no** |
| badge service | its own onion | relay box | **no** |

both of the no rows move. until they have, THREAT_MODEL.md says so.

## moving the badge service

the app only knows the onion address, and an onion address is a key file, not
a machine. copy the hidden service directory (`hs_ed25519_secret_key` and its
neighbours) and the service to the new box, start tor there, stop it on the
old one. no app change, no release, receipts stay valid. never run both at
once: two boxes publishing one onion take turns answering.

## moving the handle registry

this one has a hostname in it, so it takes a release.

1. a new name on the new box, say `id.kryfo.app`. nginx, the
   `kryfo-handles` unit and `handles.json` move with it. `/handle/font/` has
   to reach the service as well as `/handle/` and `/@`.
2. the app changes in two places that must agree: `handleBase` in
   `engine/handle.go` and `kHandleRegistry` in `mobile/lib/handle_lookup.dart`.
   `handleFromInput` has to keep taking the old links, they are in people's
   bios.
3. the old box keeps answering `relay.kryfo.app/@name` with a redirect to the
   new name, for good. that traffic is people with a browser, not phones
   with a relay connection, so it is not the correlation above.
4. the old box keeps serving `/handle/*` until the last release that calls it
   has aged out. those phones stay correlatable until they update. say so in
   the changelog of the release that moves it.

## what a new service has to answer before it ships

- which box. not the relay's.
- does the phone reach it over tor in every mode, or only in onion mode.
- what it could log if it wanted to, written down here.
