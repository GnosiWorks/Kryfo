# forward secrecy

what a key taken from a phone can and can't open later, in plain terms.
THREAT_MODEL.md covers the rest.

## chats and groups

1:1 chats use the signal protocol (libsignal): x3dh to start, the double
ratchet after that. every message gets its own key and old keys are deleted
as the conversation moves on. someone who records the traffic and later takes
the phone can't open messages that were already received. after a compromise
the ratchet heals once both sides have sent again.

groups are pairwise: a group message goes to each member over that member's
1:1 session, so the same holds for groups.

## the first messages

a new conversation starts from the prekey bundle in your invite. it holds a
signed prekey and an invite prekey that stay the same until you reset your
invite link. what someone sends you before you have ever replied is encrypted
to those kept keys: whoever recorded it and later gets your phone's keys can
read those first messages. once you reply, the ratchet moves and everything
after has full forward secrecy. "reset my invite link" replaces the invite
prekey, and bundles handed out before stop working.

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
