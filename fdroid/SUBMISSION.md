# Submitting Halo to F-Droid — checklist

## Order of operations

1. **Decide the app name → applicationId.** It is permanent. It sets:
   - `mobile/android/app/build.gradle.kts` → `applicationId` + `namespace`
   - the metadata filename → `metadata/<applicationId>.yml`
   - `fastlane/.../title.txt`
   Do this BEFORE tagging a release.

2. **Tag the release.** F-Droid builds from a tag, never a branch:
   ```
   git tag -a v0.1.0-alpha -m "first release"
   git push origin v0.1.0-alpha
   ```

3. **Publish the repo.** It must be publicly cloneable (GitHub/GitLab/Codeberg).
   Confirm `git clone <url>` works from a machine that has never seen it.

4. **Build the signed release APK from the tagged commit**, and record its
   certificate digest:
   ```
   cd mobile/android && ./gradlew assembleRelease -Ptarget-platform=android-arm64
   apksigner verify --print-certs ../build/app/outputs/flutter-apk/app-release.apk
   ```
   Take the **certificate SHA-256**, lowercase, colons removed →
   `AllowedAPKSigningKeys`.

5. **Fill in every FILL_ME in halo.yml**, rename it to
   `<applicationId>.yml`, and open a merge request against
   https://gitlab.com/fdroid/fdroiddata

## Known risks, honestly

- **Flutter SDK pin.** Reproducible builds require F-Droid to use the *exact*
  Flutter 3.41.7. If their `flutter` srclib doesn't carry that version, it must
  be added there first. This is the single most likely thing to stall the MR.

- **Full-APK reproducibility is unproven.** `repro/` currently reproduces
  `libhalo.so` only. The Dart/Flutter half (gradle, R8/dexing, asset ordering,
  zip timestamps) has not been verified to produce byte-identical output yet.
  If F-Droid's build doesn't match your APK, the fallback is to drop
  `AllowedAPKSigningKeys` and let F-Droid sign it instead — that still gets the
  app published, just without the verified-binary claim.

- **NDK availability.** The recipe asks for 28.2.13676358 (r28c). If the
  buildserver lacks it, either add a `sudo` step to install it via sdkmanager
  or move to an NDK version they already provide (and re-pin `repro/` to match,
  or reproducibility breaks again).

- **`flutter pub get --offline`** assumes the vendored `third_party/` packages
  resolve without network. If the buildserver disallows any fetch and something
  still reaches out, drop `--offline` — F-Droid permits pub.dev fetches.

## What's already handled

- No prebuilt binaries in the repo (verified: no .so/.jar/.aar/.zip/.dex)
- No proprietary dependencies (MLKit scanner replaced with FOSS zxing-cpp)
- No analytics, telemetry, or tracking of any kind
- All fonts ship their OFL licenses
- SPDX headers across Dart and Go sources
- Fastlane metadata (title, descriptions, changelog) in place
- Engine builds from source with a portable, path-discovering script
