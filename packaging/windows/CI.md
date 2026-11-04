# Windows builds on GitHub Actions

`.github/workflows/windows.yml` builds the Windows app in public, from a tag
(`v*`) or by hand (Actions, windows, Run workflow). What it makes is what a
release ships, so anyone can see the source, the scripts and the tools that
went into it.

## The two jobs

1. **natives** (Linux, in a pinned Ubuntu 26.04 image): `halo.dll`,
   `kryfo_signal.dll` and `sqlcipher.dll` cross-built with mingw-w64, and
   `tor.exe` taken from the pinned Tor expert bundle. These are the same
   scripts a local build runs: `engine/build-windows.sh`,
   `mobile/native/kryfo_signal/build-windows.sh`,
   `mobile/windows/build-sqlcipher.sh`, `packaging/windows/stage-tor.sh`.
   Each one checks its PE flags, imports and exports with `check-pe.sh`.
2. **app** (Windows Server 2022): Flutter builds `kryfo.exe` from the source
   at a fixed path (`C:\kryfo`), `check-bundle.ps1` checks the folder against
   the natives job's sums, and Inno Setup makes the installer.

## What it publishes

The `kryfo-windows-x64` artifact holds:

| file | what it is |
| :- | :- |
| `kryfo-<version>-windows-x64-setup.exe` | the installer |
| `kryfo-<version>-windows-x64.zip` | the same app folder, without installing |
| `SHA256SUMS` | sums of the two files above |
| `SHA256SUMS-files` | the sum of every file in the app folder |
| `SHA256SUMS-natives` | the sums of the three dlls and tor.exe from the natives job |

The installer and the zip also get a build provenance attestation, which ties
them to this workflow run and commit:
`gh attestation verify <file> --repo GnosiWorks/Kryfo`.

## Pinned

| what | pin |
| :- | :- |
| Linux image | `ubuntu@sha256:c098726d...` (resolute-20261006) |
| apt packages | the Ubuntu snapshot of 2026-11-01, and exact mingw-w64 versions (gcc 13.2.0-6ubuntu1+26.1, binutils 2.45.90.20260125-1ubuntu1+13.3, headers 13.0.0-2ubuntu1) |
| Go | 1.26.9, tarball sha256 checked, modules vendored, no network |
| Rust | 1.97.0, rustup-init and the channel manifest by sha256, rustc commit checked; crates from `Cargo.lock` |
| protoc | 36.2, sha256 checked |
| Tor | the expert bundle and tor.exe in `tor-pin.txt`; halo.dll refuses any other tor.exe |
| SQLCipher, OpenSSL | the tarballs pinned in `build-sqlcipher.sh` |
| Flutter | 3.41.7, commit `cc0734ac` checked; packages from `pubspec.lock` |
| Inno Setup | 6.7.3, installer sha256 checked |
| Actions | every action by full commit sha |

## Not pinned yet

- The Windows runner image (`windows-2022`) and its Visual Studio change
  every few weeks. MSVC also writes a timestamp into each PE file it links,
  so `kryfo.exe` and the plugin dlls differ from build to build. Linking with
  `/Brepro` would fix the timestamps; that is the next step.
- The zip and the installer carry file times, so their sums differ between
  runs even when every file inside is the same. `SHA256SUMS-files` is the
  list to compare.

## Comparing with a build of your own

The three dlls and tor.exe should come out byte for byte the same from the
natives job, from a local build on Ubuntu 26.04 with the pins
above, at any path. To check:

1. Download the `natives` artifact of a run.
2. Build the natives yourself with the scripts above.
3. `sha256sum -c SHA256SUMS` in the artifact folder, run against your files.

For the app folder, compare `SHA256SUMS-files` with your own build:
`flutter_windows.dll`, `data\icudtl.dat`, `data\flutter_assets\` and the
natives should match; `kryfo.exe` and the plugin dlls will not until the
MSVC step above is done.

## Signing

Releases are meant to be signed through SignPath from this workflow's
artifacts, so the signed files are exactly the ones built here. Until then
the installer is unsigned and Windows SmartScreen warns before it runs.
