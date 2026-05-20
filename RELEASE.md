# Release process

Pre-alpha release checklist. Run from the repo root.

## 1. Version bump
- Edit `mobile/pubspec.yaml` → `version: 0.1.x-alpha+N` (N = versionCode, monotonic)
- Add a section to `CHANGELOG.md`
- Add a per-version changelog at `fastlane/metadata/android/en-US/changelogs/N.txt`

## 2. Build
```
cd engine && bash build_android.sh && cd ../mobile
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64,android-x64
```

## 3. Tag
```
cd ~/halo
git tag -a v0.1.x-alpha -m "halo 0.1.x-alpha"
git push origin v0.1.x-alpha
```

## 4. F-Droid
- Bump `Builds:` block in `fdroiddata/com.halo.halo_app.yml` (versionCode, versionName, commit)
- Bump `CurrentVersion` + `CurrentVersionCode`
- Open a PR against the fdroiddata repo

## 5. GitHub release
- Cut a GitHub release from the tag
- Attach the signed APK (for users who want to sideload before F-Droid index updates)

## Reproducibility
F-Droid builds on their own servers. To verify locally that the build is deterministic, build twice with a fresh clone — the APK SHA-256 should match.

If they differ, common culprits:
- timestamps baked into AndroidManifest (`android:versionName` with build date)
- non-deterministic protobuf code generation
- shell-detected git commit hash leaking into a generated file
