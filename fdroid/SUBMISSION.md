# submitting to f-droid

## order

1. decide the app name and applicationId. it is permanent. it sets
   mobile/android/app/build.gradle.kts (applicationId + namespace), the
   metadata filename (metadata/<applicationId>.yml), and fastlane title.txt.
   do this before tagging.

2. tag the release. f-droid builds from a tag, not a branch:

       git tag -a v0.1.0-alpha -m "first release"
       git push origin v0.1.0-alpha

3. publish the repo. it must clone cleanly from a machine that has never
   seen it.

4. build the signed release apk from the tagged commit and record the cert
   digest:

       cd mobile/android && ./gradlew assembleRelease -Ptarget-platform=android-arm64
       apksigner verify --print-certs ../build/app/outputs/flutter-apk/app-release.apk

   take the certificate sha-256, lowercase, colons removed. that goes in
   AllowedAPKSigningKeys.

5. DONE. the recipe is `fdroiddata/app.kryfo.yml` in this repo, which is the
   copy of what went to https://gitlab.com/fdroid/fdroiddata. it pins
   v0.2.10 on versionCodes 121/122/123 and sets `AutoUpdateMode: Version`
   with `UpdateCheckMode: Tags`, so every tag after that is picked up without
   another merge request. the template this was written from is gone; edit
   the recipe itself.

   full-apk reproducibility is no longer unproven either - see the note under
   "what can go wrong" below, which is kept for the record. `repro/release.sh`
   builds the three apks in the pinned container and `repro/verify.sh` checks
   them with apksigcopier, which is the check f-droid runs. 0.2.12 came back
   MATCH and SAME on all three, and every release since is checked the same
   way before it is tagged.

   **the first tag after f-droid merges is v0.3.0**, and it has to match
   `versionName` in mobile/pubspec.yaml exactly (`version: 0.3.0+15`, so
   versionCodes 151/152/153). f-droid's update check finds the tag, then
   reads versionName and versionCode out of pubspec.yaml at that tag
   (`UpdateCheckData`), so a tag that says one thing while pubspec says
   another publishes under pubspec's number and not the tag's. no suffix,
   no missing digit: `v` + versionName, nothing else.

   0.2.11 and 0.2.12 are never tagged. 0.2.11's commit, `2da465f9`, carries
   the control-port wedge that left a phone offline for ten and a half hours
   (see `~/kryfo-notes/CONTROL-PORT-2026-09-19.md`). 0.2.12 was verified
   MATCH + SAME on `d6f3ab12` but is folded into 0.3.0, which adds the tor
   and openssl security updates and the delivery fixes on top. the tag goes
   on the 0.3.0 commit that comes back MATCH + SAME on all three abis, and
   only once f-droid has merged.

   **go is 1.25.14 from 0.3.0 on** (`engine/go.mod`, `repro/Dockerfile`).
   the recipe copy in `fdroiddata/app.kryfo.yml` pins `go@go1.25.0` and
   `git -C $$go$$ checkout -f go1.25.0`, which is right for the v0.2.10
   builds it describes and must stay so for them. but `AutoUpdateMode`
   copies the last build block to make the next one, so a v0.3.0 entry would
   inherit go 1.25.0 - and with `go 1.25.14` in go.mod, go 1.25.0 tries to
   download the newer toolchain, which fails on the offline buildserver.
   that failure is the good outcome: the alternative would be an engine built
   with a different go, and no MATCH. so the v0.3.0 build block needs
   `go@go1.25.14` and `checkout -f go1.25.14` in both places, in the merge
   request that adds it (or a follow-up to fdroiddata before the tag). the
   same goes for every later go bump: go.mod, both dockerfiles,
   prep-offline.sh and the recipe move together.

## what can go wrong

- the flutter srclib may not carry 3.41.7 yet. reproducible builds need the
  exact sdk, so it may need adding there first. most likely stall.
- full-apk reproducibility is unproven. repro/ covers libhalo.so; the
  dart/gradle/r8 half has not been verified byte for byte. if f-droid's
  build does not match, drop AllowedAPKSigningKeys and let them sign. still
  publishes, loses the verified-binary claim.
- the buildserver may lack ndk 28.2.13676358. either add a sudo step to
  install it or move to one they ship, and re-pin repro/ to match.
- flutter pub get --offline assumes the vendored third_party packages
  resolve without network. if not, drop --offline. f-droid allows pub.dev.

## already handled

- no prebuilt binaries in the repo (no .so/.jar/.aar/.zip/.dex tracked)
- no proprietary deps (mlkit scanner replaced with zxing-cpp)
- no analytics or telemetry
- fonts ship their ofl licenses
- spdx headers on dart and go sources
- fastlane metadata and screenshots in place
- engine builds from source with a path-discovering build.sh
