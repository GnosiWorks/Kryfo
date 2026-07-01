# ECCN 5D002 / TSU export notification

Halo bundles real crypto (libsignal Double Ratchet, Tor, Nostr encryption).
US export rules classify this as 5D002 (encryption source). Publicly available
open-source gets License Exception TSU (15 CFR 740.13(e)) — you NOTIFY, not ask.

## The one-time email (send WHEN repo goes public, URL must resolve)

To: crypt@bis.doc.gov and enc@nsa.gov
Subject: TSU notification - publicly available encryption source code

Body:
This is a notification under License Exception TSU, 15 CFR 740.13(e), of the
internet location of publicly available encryption source code.

Project: Halo (open-source private messenger)
URL: https://github.com/GnosiWorks/Halo
Description: End-to-end encrypted messaging client. Uses the Signal Double
Ratchet (libsignal), Tor onion routing, and encrypted Nostr transport.
Source is publicly available under GPLv3.

This notification is provided per 740.13(e)(3).

## Notes
- one-time email; re-notify if the URL changes
- you are the exporter as publisher; no company needed
- covers the US crypto-export leg only; separate from F-Droid reproducible build
- keep a copy of the sent email as record
- VERIFY addresses + CFR citation against current bis.doc.gov before sending;
  rules change and this is not legal advice. confirm at send-time.

STATUS: ready to send at repo-public time. blocked only on the public URL existing.
