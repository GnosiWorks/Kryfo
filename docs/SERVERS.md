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
| relay (`relay-live/`) | `wss://relay.kryfo.app` and its onion | first box | it is the relay |
| second relay (`relay-live/`) | `wss://relay2.kryfo.app` and its onion | second box, another hosting company | it is the relay |
| handle registry (`server/handle/`) | `https://relay.kryfo.app/handle/*`, `/@name` | first box | no |
| badge service (`server/badge/`) | its own onion | first box | no |
| gif relay (`server/gif/`) | `https://relay.kryfo.app/gif/*` | first box | no |
| files service (`server/files/`) | `https://files.kryfo.app`, over tor only | second box | no |
| push gateway (`server/push/`) | the first relay only, through a tunnel (endpoints read `https://relay.kryfo.app/push/*`) | second box | no |

the handle registry and the badge service move. where the gif relay, the
files service and the push gateway go is not decided yet.

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

## the files service

photos, videos, voice notes and files bigger than one message. a phone seals
the file with a key of its own and sends the key inside the message, so the
service holds sealed bytes it cannot open. phones reach it over tor only.
what it could log: a file's random id, its size rounded up, how many
recipients it has, and when it went up and came down. a file goes once every
recipient has it, a week at most. it writes no access log.

## the push gateway

google push in the play build. a relay posts an empty knock to
`/push/<sealed token>`; the gateway opens the token (a phone's fcm token
sealed to the gateway's key, a different seal for each of the phone's
sixteen endpoints) and asks fcm to wake the phone with an empty
high-priority message. what it could log: nothing per token. it keeps no
table on disk and writes no file; in ram it holds a keyed hash of a token with the
times of its last pushes for an hour, to keep one push per phone every 45
seconds and thirty an hour, a keyed hash of a token fcm calls no phone's for
a day, short hashes of the seals each token was knocked on, up to a day
each, to refuse copies, and a held-back push's token for up to 45 seconds. it logs
nothing but its start, no counts either. google sees the install and when it
is woken, never by whom or with what. it has no public route: only our relay
posts to it, on loopback (`RELAY_KNOCK_GATEWAY_LOCAL`, 127.0.0.1:3340 by
default), which on the first box is a tunnel to the gateway on the second.
the app never talks to it. the relay's endpoint table and the gateway's key
are on different boxes, so tying a phone's sixteen endpoints together takes
both. we run both.

## logs

since 13 november 2026 neither box keeps logs:

- the system journal stores nothing, not even in ram.
- the web servers keep no access or error logs.
- no login records (wtmp, btmp, lastlog, auth.log) and no shell history.
- package logs (apt, dpkg, unattended upgrades) live in ram and are emptied every hour.
- no core dumps.
- no traffic statistics (sysstat is off).
- the push gateway counts nothing.
- the handle registry keeps no claim time. the time of a handle's last signed change
  and of its last search switch are needed only to refuse replays inside the ten
  minute clock window, so they are blanked once 20 minutes old.

the one thing kept is on the donation server (btcpay): its invoice records, because
payments need them, and an error file it writes only on a crash.

the old logs were deleted. a check runs after every change to a box and goes
through each item above, one by one, and fails if any of them is back.

## watching them

`server/watch/` checks every service from outside every two minutes and
restarts a relay or registry (or its bridge) that stopped answering. it keeps
nothing but its last result.

## before a new service ships

- which box (not the relay's)
- does the phone reach it over tor in every mode
- what it could log, written down here
