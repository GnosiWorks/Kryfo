# servers

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

both of the "no" rows move.

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

## before a new service ships

- which box (not the relay's)
- does the phone reach it over tor in every mode
- what it could log, written down here
