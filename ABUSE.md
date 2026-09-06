# Child safety

Kryfo is end to end encrypted. Message content is readable only on the phones
at either end. No server can read it, including ours, so Kryfo cannot scan
messages and we are not going to build a way to. Signal, Threema and SimpleX
are all in the same position for the same reason.

That is the short answer. Here is the longer one, because "we cannot scan" on
its own does not tell you much about whether an app is safe to use.

## The design closes the usual door

Harm on a messaging app usually starts with a stranger being able to reach
someone. Kryfo does not give them a way in.

There is no directory and no search. You cannot look someone up by name,
phone number or email, because Kryfo never asks for a phone number or an
email in the first place. There is nobody to browse.

You cannot be messaged out of the blue. A new contact has to arrive through a
QR code you scanned, an invite link you handed out, or a six digit code you
read to someone in the room. Anything else waits in a requests inbox until
you decide.

First contact also costs a small amount of work on the sender's phone, which
makes messaging thousands of people expensive and slow.

Public handles are off unless you turn one on, and you can retire yours at
any time. Old invites stop working and your conversations carry on as normal.

The scam shield adds a second layer. It notices when a new request is using
the name of someone you already know, and it flags the patterns that show up
in messages from strangers. It runs on your phone, checks nothing with a
server, and gives you the call rather than making it for you.

## Why not scan anyway

Scanning on the phone would mean building a channel that reports what you
write to somebody else. Once that channel exists, what it looks for is a
setting, and settings get changed by whoever is in charge later. It also gets
things wrong often enough that at any real scale it means private messages
being sent to strangers by mistake.

We would rather build an app where that channel does not exist.

## What we hold

Nothing much, and that is deliberate. No message content, no contact list, no
phone numbers, no email addresses, no account records. There are no accounts
to have records of. Our relay passes along encrypted blobs, keeps them for a
short window so a phone that was offline can catch up, and does not write
connection logs to disk.

If someone asks us for a user's messages, we have nothing to hand over. That
is the point of building it this way.

## If something goes wrong

You can block anyone, leave any group, and delete any conversation from both
sides. Group admins can remove members.

For anything involving a child, your national child protection service can
act where we cannot see. In the EU those are reachable through INHOPE, and in
the US through the NCMEC CyberTipline.

For anything about the app itself, open an issue or write to
gnosiworks@proton.me.
