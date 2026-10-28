# Servers

## the rule

anything a phone talks to that is not the relay runs on a different box than
the relay.

the relay sees when a key connects and publishes. any other service on the
same machine gives whoever holds that machine a second clock to line up with
it: a handle claimed at 14:02:07, an idle key publishing at 14:02:09. turning
logs off doesn't remove that, the timing exists while the traffic does. two
boxes means two seizures and two providers.

## today

| service | reached at | box | follows the rule |
|---|---|---|---|
| relay (`relay-live/`) | `wss://relay.kryfo.app` and its onion | relay box | it is the relay |
| handle registry (`server/handle/`) | `https://relay.kryfo.app/handle/*`, `/@name` | relay box | no |
| badge service (`server/badge/`) | its own onion | relay box | no |
| gif relay (`server/gif/`) | `https://relay.kryfo.app/gif/*` | relay box | no |
| push gateway (`server/push/`) | `https://relay.kryfo.app/push/*`, the relay on loopback | relay box | no |

the handle registry and the badge service move. the gif relay runs on the relay box too; where it
goes is not decided yet.

## moving the badge service

the app only knows the onion address. copy the hidden service directory and
the service to the new box, start tor there, stop it on the old one. no app
change. never run both at once.

## moving the handle registry

this needs a release, the hostname is in the app.

1. a new name on the new box, e.g. `id.kryfo.app`, with nginx, the
   `kryfo-handles` unit and `handles.json`. `/handle/`, `/handle/font/` and
   `/@` all have to reach it.
2. change `handleBase` in `engine/handle.go` and `kHandleRegistry` in
   `mobile/lib/handle_lookup.dart` together. `handleFromInput` keeps taking
   the old links.
3. the old box redirects `relay.kryfo.app/@name` to the new name for good.
4. the old box keeps serving `/handle/*` until the last release that calls it
   is gone.

## the push gateway

google push in the play build. a relay posts an empty knock to
`/push/<sealed token>`; the gateway opens the token (a phone's fcm token
sealed to the gateway's key, a different seal for each of the phone's
sixteen endpoints) and asks fcm to wake the phone with an empty
high-priority message. what it could log: nothing per token. it keeps no
table and writes no file; in ram it holds a keyed hash of a token with the
times of its last pushes, for an hour at most, to keep one push per phone
every 45 seconds and thirty an hour. once an hour it logs counts. google
sees the install and when it is woken, never by whom or with what. nginx
logs nothing for `/push/`, since the path carries a sealed token. our relay
posts to it on loopback (`RELAY_KNOCK_GATEWAY_LOCAL`), since it refuses
names that point at its own box.

## watching them

`server/watch/` checks every service from outside every two minutes and
restarts a relay or registry (or its bridge) that stopped answering. it keeps
nothing but its last result.

## before a new service ships

- which box (not the relay's)
- does the phone reach it over tor in every mode
- what it could log, written down here
