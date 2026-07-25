# Privacy Policy

kryfo is built so there is almost nothing to collect. this page says plainly what that means.

## what we collect

nothing. there is no kryfo account, no sign-up, no email, no phone number. we run no server that stores your messages, your contacts, or who you talk to. we have no analytics, no tracking, no crash reporting that phones home. nothing about how you use the app is sent to us, because there is no "us" on the other end to receive it.

## what stays on your phone

your identity, your contacts, and your messages live on your device, encrypted at rest. if you lose the phone without a backup, that data is gone. that is the trade for not keeping a copy anywhere else.

backups are files you make and control. they are encrypted with a passphrase only you hold and stored wherever you choose to put them. we never see them.

## what travels over the network

to deliver a message, kryfo routes it through tor and, when the other person is offline, leaves it in an encrypted mailbox on public nostr relays. relays only ever hold sealed, encrypted data. they do not hold your contact list or a record of your account, because no such account exists.

your ip is hidden behind tor on the default private mode. if you turn on fast mode, messages skip the extra tor hops to go quicker, which can expose your ip to a relay. fast mode is off by default and labeled where you turn it on.

## optional notifications

you can turn on push notifications. these use a relay (ntfy) to wake the app when a message is waiting. the ping carries no message content and no sender, only a signal to fetch. the relay can see that a wake-up reached your notification address, but not what the message is or who sent it. push is off by default. if you leave it off, the app checks for messages itself when open.

## third parties

kryfo talks to tor relays, nostr relays, and optionally an ntfy server. these are infrastructure for moving sealed data, not partners we share anything with. we do not sell, rent, or trade data, because we do not have any to give.

## law enforcement and data requests

we have no account records, no message store, and no logs of who talks to whom. if someone asks us to hand over your data, there is nothing to hand over. we cannot produce what we never collected.

## children

kryfo is not directed at children. you should be old enough to consent to using a messaging app in your country.

## who maintains kryfo

kryfo is an open-source project maintained by an independent developer. the code is public so anyone can check these claims against what the app actually does.

## changes

kryfo is pre-alpha and open source. this policy may change as the app does. the current version always lives in the repository.

## contact

questions or a privacy issue: gnosiworks@proton.me
