# Privacy Policy

Kryfo is built so there is almost nothing to collect.

## what we collect

nothing. there is no Kryfo account, no sign-up, no email, no phone number. we run no server that stores your messages, your contacts, or who you talk to. we have no analytics, no tracking, no crash reporting that phones home. nothing about how you use the app is sent to us, because there is no "us" on the other end to receive it.

## what stays on your phone

your identity, your contacts, and your messages live on your device, encrypted at rest. if you lose the phone without a backup, that data is gone. that is the trade for not keeping a copy anywhere else.

backups are files you make and control. they are encrypted with a passphrase only you hold and stored wherever you choose to put them. we never see them.

## what travels over the network

to deliver a message, Kryfo routes it through tor and, when the other person is offline, leaves it in an encrypted mailbox on public nostr relays. relays only ever hold sealed, encrypted data. they do not hold your contact list or a record of your account, because no such account exists.

your ip is hidden behind tor on the default private mode. relay mode and fast mode skip tor to go quicker. relay mode connects straight to our own relay, which then sees your ip for that connection and writes nothing down. fast mode adds public relays, and each of them sees your ip too. both are off by default and labeled where you turn them on.

## handles and people search

a handle (@name) is optional. without one, nothing about you sits anywhere central. if you claim one, the handle registry on relay.kryfo.app holds the handle, the invite it points to (already public), a bio if you write one, and the key that claimed it. anyone who knows the handle can open its page and message you.

people search is a second choice on top of that, off by default. only handles whose owner turned on "Show me in search" come up, next to a name they picked. turning it off takes you out of search at once. releasing the handle deletes its entry, though a server backup can hold an older copy for a while.

the app reaches the registry the same way it sends messages, so over tor in private mode. the registry keeps no record of who looked anyone up or what was searched for.

## the developer chat

the "Marios · built Kryfo" chat at the top of the list talks to the person who builds the app. its key is built into Kryfo, so nobody else can answer in it. nothing connects and nothing is sent until you write the first message: no hello, no lookup, no app version, no logs.

with your three words, Marios sees them and can write back like any contact. the face you picked, your onion address and any supporter badge are not sent. "Write anonymously" makes a new name and keys for that chat alone: they stay on your phone, are never used anywhere else and are left out of backups. either way Marios sees what you write and when, and delivery receipts tell each side when a message arrived. anonymous does not hide your writing style, the details you share, or your ip in relay and fast modes. voice notes in an anonymous chat always go through the voice disguise.

deleting the chat deletes it on your phone, and it does not come back unless you open it again from settings. Marios keeps his copy of what you sent, as any person you write to does.

## notifications

there is no push service. the app checks for messages itself, over the same route it sends on, and shows a notification when one arrives. nothing outside the app is told that a message is waiting for you.

## third parties

Kryfo talks to tor relays and nostr relays. these are infrastructure for moving sealed data, not partners we share anything with. we do not sell, rent, or trade data, because we do not have any to give.

## law enforcement and data requests

we have no account records, no message store, and no logs of who talks to whom. if someone asks us to hand over your data, there is nothing to hand over. we cannot produce what we never collected.

## children

Kryfo is not directed at children. you should be old enough to consent to using a messaging app in your country.

## who maintains Kryfo

Kryfo is an open-source project maintained by an independent developer. the code is public so anyone can check these claims against what the app actually does.

## changes

Kryfo is in alpha and open source. this policy may change as the app does. the current version always lives in the repository.

## contact

questions or a privacy issue: gnosiworks@proton.me
