# Forward secrecy

what a key taken from a phone can and can't open later, in plain terms.
THREAT_MODEL.md covers the rest.

## chats and groups

1:1 chats use the signal protocol (libsignal). from 0.6 a chat starts with
pqxdh and runs the double ratchet together with spqr, signal's post-quantum
ratchet, so recorded traffic stays closed to a future quantum computer too.
every message gets its own key and old keys are deleted as the conversation
moves on. someone who records the traffic and later takes the phone can't
open messages that were already received. after a compromise the ratchet
heals once both sides have sent again.

a chat from before 0.6 started classically. once both phones run 0.6 it
restarts on pqxdh with the same addresses, both phones show a line when it
has, and the classic state is deleted 16 days after the first message on the
new one. a chat with a phone still on 0.5 stays classic. a new chat needs
0.6 on both sides.

groups are pairwise: a group message goes to each member over that member's
1:1 session, so the same holds for groups.

## the first messages

a conversation started from your invite link, qr or handle starts from the
prekey bundle in it: a signed prekey and a post-quantum prekey that stay the
same until you reset your invite link. what someone sends you before you
have ever replied is encrypted to those kept keys: whoever recorded it and
later gets your phone's keys can read those first messages. once you reply,
the ratchet moves and everything after has full forward secrecy. "reset my
invite link" replaces the kept prekeys, and bundles handed out before stop
working.

a chat started with a pair code uses a one-time invite made for that pairing,
whose prekeys are deleted once used, so its first messages have forward
secrecy too.

what post-quantum keys do not cover: the nip-44/59 wrapping around every
message, the first-contact hello and the heal frames sent after a restore
are classical, and the first message of a chat carries the sender's
identity key. someone who records relay traffic now and breaks it later
could learn who first contacted whom, never what was said. a chat from
before 0.6 keeps addresses made from the two public keys, so the same
attacker could see when that pair talked.

## relays

a message that waits on a nostr relay is the signal ciphertext, sealed to the
conversation (nip-44) and gift wrapped with a throwaway key (nip-59). the relay
keeps it until it is fetched or expires. the signal layer inside is what
protects it, so everything above applies.

## burner rooms

rooms don't use the ratchet. their messages are sealed with keys made for
that room alone. whoever takes a member's phone while the room is alive can
read what that phone received, and room traffic recorded during its life.
when the room ends, the app deletes the room keys: from then on nothing on
the phone opens that room's traffic.

## on the phone

forward secrecy is about keys, not about what is stored. messages kept on the
phone sit in an encrypted database whose key lives in android's keystore;
whoever can open the app can read them. disappearing messages delete the
message and its file when the timer runs out.

hidden chats: while the hidden chats are shut, their new messages are opened
as usual and then sealed to the hidden chats' own key until you open them.

## backups

a backup is a full copy: identity, sessions, history and files, encrypted
with your passphrase. anyone with the file and the passphrase has all of it.
a backup made inside the hidden chats carries them too. keep both apart and
safe.

after a restore or a move the old sessions may be stale, so the phone sends
each contact a signed heal and the chat starts a new session. the contact
sees "set up Kryfo again" in that chat, and a verified contact's sends wait
until they have looked.
