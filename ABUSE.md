# Child safety

Kryfo is end to end encrypted. Only the phones at either end can read a
message. No server can, including ours, so Kryfo can't scan messages and we
won't build a way to. Signal, Threema and SimpleX are in the same position.

## Strangers can't reach you

- There is no directory and no search by name, phone number or email. Kryfo
  never asks for either.
- A new contact comes through a QR code you scanned, an invite link you gave
  out, or a six digit code read out in person. Anything else waits in a
  requests inbox until you decide.
- First contact costs the sender's phone some work, so messaging thousands of
  people is slow and expensive.
- Public handles are off unless you turn one on, and you can retire yours at
  any time.
- The scam shield warns when a new request uses the name of someone you
  already know, and flags common scam messages. It runs on your phone and
  leaves the decision to you.

## Why not scan anyway

Scanning on the phone means a channel that reports what you write to someone
else. Once it exists, what it looks for is a setting anyone in charge later
can change, and it gets things wrong often enough to send private messages to
strangers by mistake. We'd rather that channel not exist.

## What we hold

No message content, no contact lists, no phone numbers, no email addresses,
no accounts. The relay passes encrypted blobs, keeps them for a short window
so an offline phone can catch up, and writes no connection logs. If someone
asks us for a user's messages, we have nothing to hand over.

## If something goes wrong

You can block anyone, leave any group, and delete a conversation on both
sides. Group admins can remove members.

For anything involving a child, contact your national child protection
service: through INHOPE in the EU, the NCMEC CyberTipline in the US.

For anything about the app, open an issue or write to gnosiworks@proton.me.
