# f-droid

the recipe is `fdroiddata/app.kryfo.yml`, a copy of what went to
https://gitlab.com/fdroid/fdroiddata. it builds v0.2.10 (version codes
121/122/123) and sets `AutoUpdateMode: Version` with `UpdateCheckMode: Tags`,
so later tags are picked up without another merge request.

## tags

- the first tag after the merge is v0.3.2, on the 0.3.2 release commit.
  0.2.11 to 0.3.1 are never tagged.
- a tag is `v` + versionName from mobile/pubspec.yaml, nothing else. f-droid
  reads versionName and versionCode from pubspec.yaml at the tag.
- tag only after `repro/verify.sh` says MATCH and SAME for all three abis.

## go

go is 1.25.14 from 0.3.0 on. the v0.2.10 blocks pin `go@go1.25.0` and must
keep it. `AutoUpdateMode` copies the last block, so the v0.3.2 block needs
`go@go1.25.14` and `checkout -f go1.25.14` in both places, or the offline
buildserver fails to fetch the toolchain. every go bump moves go.mod, both
dockerfiles, prep-offline.sh and the recipe together.

## what can go wrong

- the flutter srclib may not have 3.41.7 yet
- the buildserver may lack ndk 28.2.13676358
- `flutter pub get --offline` needs the vendored third_party packages to
  resolve without network

## already done

- no prebuilt binaries, no proprietary deps (zxing-cpp for scanning), no
  analytics
- fonts ship their ofl licenses, spdx headers on dart and go sources
- fastlane metadata and screenshots
- the engine builds from source with build.sh
