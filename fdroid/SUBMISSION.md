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

5. fill every FILL_ME in halo.yml, rename it to <applicationId>.yml, open a
   merge request against https://gitlab.com/fdroid/fdroiddata

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
