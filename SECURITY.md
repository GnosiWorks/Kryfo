# security

if you found a way to read someone's messages, learn who talks to whom,
unmask a kryfo user, get past the app lock, or make the app or the servers
do something they shouldn't, please tell me privately first.

## how to report

- email: gnosiworks@proton.me
- in the app, from kryfo 0.5.0: the "Marios · built Kryfo" chat at the top
  of the chat list. its key is pinned inside the app, so nobody else can
  answer as me. you can write from your own identity or anonymously from a
  throwaway one.

the pinned developer identity:

    three words   scare-raven-rare
    key           2f3b ddfa dec1 e445 a44e 0b76 08b5 fcac
                  a5b8 4f00 b1ba 0341 c233 fc84 0ca8 7d3a

the key is what counts. anyone can pick three words; the key is checked by
the app. the same fingerprint is on kryfo.app.

a short description, the version (settings, about), the phone and android
version, and steps to reproduce are enough. no need for a polished write-up.

## what happens next

- i answer within 3 days, usually sooner.
- a fix for anything that exposes messages, contacts or identities comes
  first. i tell you when it ships and credit you in the changelog if you want.
- please give me 90 days, or until a fix is out, before you publish. if it is
  being exploited we can go faster together.

i won't take legal action against good faith research that stays within
this: test on your own identities and devices, don't read or change other
people's data, don't degrade the servers for others.

## in scope

- the android app (mobile/) and the engine (engine/): crypto, storage, the
  lock layer, decoy and hidden chats (from 0.5.0), backups, the tor and
  relay transport
- relay.kryfo.app: the relay, the handle registry, people search
- kryfo.app

## out of scope

- attacks that need an unlocked phone in someone else's hands, beyond what
  THREAT_MODEL.md says the app should still hold
- denial of service by volume
- findings in tor, libsignal or other upstream projects: report those
  upstream, but tell me too if kryfo uses them in a way that makes it worse
- social engineering and physical attacks on me or the servers

kryfo has not been audited yet. an audit is planned. THREAT_MODEL.md says what
it protects against and what it doesn't.
