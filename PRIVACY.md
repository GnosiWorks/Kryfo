# Privacy policy

## what we collect

nothing. there is no Kryfo account, no sign-up, no email, no phone number. we run no server that stores your messages in readable form, your contacts, or who you talk to. we have no analytics, no tracking, no crash reporting that phones home. nothing about how you use the app is sent to us.

## what stays on your phone

your identity, your contacts, and your messages live on your device, encrypted at rest. if you lose the phone without a backup, that data is gone. that is the trade for not keeping a copy anywhere else.

backups are files you make and control. they are encrypted with a passphrase only you hold and stored wherever you choose to put them. we never see them.

## what travels over the network

to deliver a message, Kryfo routes it through tor and, when the other person is offline, leaves it in an encrypted mailbox on nostr relays: a few public ones and ours in onion and fast mode, only ours in relay mode. relays only ever hold sealed, encrypted data. they do not hold your contact list or a record of your account, because no such account exists. messages from 0.5.2 on are padded to one of five sizes, so a relay sees roughly how big a message is, not how long. how many you send and when still shows.

your ip is hidden behind tor on the default private mode. relay mode and fast mode skip tor to go quicker. relay mode connects straight to our own relay, which then sees your ip for that connection and writes nothing down. fast mode adds public relays, and each of them sees your ip too. both are off by default and labeled where you turn them on.

## bridges

bridges help tor start when your network blocks it. on automatic, where new installs start, Kryfo first tries tor the usual way and only tries a bridge when that is blocked. you can also pick a bridge yourself, or pick direct, and then Kryfo makes none of the connections below on its own.

when a bridge is used, some connections leave your phone outside tor so that tor can start. an obfs4 bridge, built in or from a friend, is reached directly at its address. a webtunnel bridge is reached at its web address. snowflake asks public stun servers for your address, reaches the tor project's broker through a cdn, and connects through a volunteer's computer. these see your ip address and when you connect.

when you ask Kryfo to get bridges, it asks the tor project for them. the request goes through a cdn, so your network sees a connection to the cdn, not to the tor project. the tor project sees your ip address, and from it roughly where you are. that is normal: it is how tor browser and every tor app get bridges, and all it tells them is that someone asked for bridges. nothing about your chats, your contacts or who you talk to. Kryfo only asks after you say yes.

once tor is connected, Kryfo checks about once a week for changes to the tor project's built-in bridges. that request goes through tor, so it shows nobody your ip address.

a bridge is your first tor hop. whoever runs it sees your ip address and when you use tor, not what you send or to whom.

## handles and people search

a handle (@name) is optional. without one, nothing about you sits anywhere central. if you claim one, the handle registry on relay.kryfo.app holds the handle, the invite it points to (already public), a bio if you write one, and the key that claimed it. anyone who knows the handle can open its page and message you.

people search is a second choice on top of that, off by default. only handles whose owner turned on "Show me in search" come up, next to a name they picked. turning it off takes you out of search at once. releasing the handle deletes its entry at once. the server keeps one backup copy a day and deletes each copy once it is a week old, so no copy of a released handle is left after 8 days.

the app reaches the registry, people search and the badge service over tor on every route, also in relay and fast modes. the registry keeps no record of who looked anyone up or what was searched for.

## the developer chat

the "Marios · built Kryfo" chat at the top of the list talks to the person who builds the app. its key is built into Kryfo, so nobody else can answer in it. nothing connects and nothing is sent until you write the first message: no hello, no lookup, no app version, no logs.

with your three words, Marios sees them and can write back like any contact. the face you picked, your onion address and any supporter badge are not sent. "Write anonymously" makes a new name and keys for that chat alone: they stay on your phone, are never used anywhere else and are left out of backups. either way Marios sees what you write and when, and delivery receipts tell each side when a message arrived. anonymous does not hide your writing style, the details you share, or your ip in relay and fast modes. voice notes in an anonymous chat always go through the voice disguise.

deleting the chat deletes it on your phone, and it does not come back unless you open it again from settings. Marios keeps a copy of what you sent, as any person you write to does.

## notifications

by default there is no push service. the app checks for messages itself, over the same route it sends on, and shows a notification when one arrives. nothing outside the app is told that a message is waiting for you.

## the helper app mode

"Through a helper app" is a way of getting messages you can choose, off by default and only on the default private route. a unifiedpush helper app (ntfy or another) keeps one connection for all your apps, and our relay knocks on it when something arrives for you. the knock is an empty request: no sender, no count, no content. Kryfo then fetches over tor as always.

what our relay learns: for each of your mailbox addresses that is registered, a web address on your helper's server to knock (an endpoint). Kryfo always uses sixteen endpoints. addresses that share an endpoint are ones that already reach the relay together over one tor circuit, and while there are free endpoints each address has one of its own. rooms past the free endpoints are not registered. the registration travels over tor, on the same circuit as the address it names, and only to our relay. the relay keeps a hash of the address, the endpoint and two times, for at most 30 days.

hidden chats are never registered, though their mailboxes are still read. each ordinary contact's mailbox also goes unregistered now and then, about one month in five at a time of its own, and nothing is ever sent to forget an address that stops being registered: its registration just runs out. that only blurs the first month or so. a relay that watches can tell a hidden chat's mailbox, read and never registered, within two or three months.

what the helper's server learns: your phone's ip address, as it does for every app that uses it, that it holds sixteen endpoints for Kryfo, and when each one is knocked. the knocks come from our relay's address, so it can tell you use Kryfo. our relay also sends fake knocks at random times, which makes it harder to tell when real messages arrive. it never learns what a message says, who sent it, or how many came.

if you run your own helper server, its name is part of every endpoint, so our relay learns that all of your endpoints belong to one person. on a public server that many people use, the name says nothing.

leaving the mode tells the helper app to drop the endpoints at once, so our relay's next knock finds them gone, and our relay is asked to forget them, a few at a time. both are best effort: whatever is missed runs out within 30 days. moving Kryfo to another phone drops the endpoints without asking the relay. a panic wipe makes no call at all, so the helper app keeps its endpoints until our relay's registrations run out, and its server sees knocks that nothing answers.

## third parties

Kryfo talks to tor relays and nostr relays, to your helper app's server if you choose the helper app mode, to the tor project when you ask it for bridges, and, while a bridge is in use, to that bridge and what it needs: snowflake volunteers, public stun servers and the cdn in front of the tor project. we share nothing with them, and we have no data to sell, rent or trade.

## law enforcement and data requests

we have no account records, no message store, and no logs of who talks to whom. if someone asks us to hand over your data, there is nothing to hand over.

## children

Kryfo is not directed at children. you should be old enough to consent to using a messaging app in your country.

## who maintains Kryfo

Kryfo is an open-source project maintained by an independent developer. the code is public, so anyone can check these claims against what the app does.

## changes

Kryfo is in alpha and open source. this policy may change as the app does. the current version is in the repository.

## contact

questions or a privacy issue: gnosiworks@proton.me
