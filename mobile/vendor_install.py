#!/usr/bin/env python3
# vendor_install: your wifi cannot survive pub's big archive download, and pub
# cannot resume one. so the packages come vendored in this tgz instead
# (flutter_zxing v2.1.0 with the zxing-cpp sources, camera 0.11.4 + its
# platform packages) and pubspec points at them as path deps. after this,
# pub NEVER downloads them again - they are part of the repo.
import io, os, re, sys

assert os.path.isdir("third_party/flutter_zxing"), "run from mobile/ after extracting the tgz"
assert os.path.isdir("third_party/camera/camera"), "camera vendor dir missing"

s = io.open("pubspec.yaml", encoding="utf-8").read()

# swap the hosted entries (whatever constraint pub add left) for path deps
n1 = len(re.findall(r"(?m)^  flutter_zxing:.*$", s))
n2 = len(re.findall(r"(?m)^  camera:.*$", s))
assert n1 == 1, f"flutter_zxing entry x{n1} in pubspec - paste your pubspec dependencies block"
assert n2 == 1, f"camera entry x{n2} in pubspec - paste your pubspec dependencies block"
s = re.sub(r"(?m)^  flutter_zxing:.*$",
           "  flutter_zxing:\n    path: third_party/flutter_zxing", s)
s = re.sub(r"(?m)^  camera:.*$",
           "  camera:\n    path: third_party/camera/camera", s)

if "dependency_overrides:" not in s:
    s += (
        "\n"
        "# vendored camera platform packages (federated plugin) - keeps the\n"
        "# whole scanner stack building offline, forever.\n"
        "dependency_overrides:\n"
        "  camera_android_camerax:\n"
        "    path: third_party/camera/camera_android_camerax\n"
        "  camera_avfoundation:\n"
        "    path: third_party/camera/camera_avfoundation\n"
        "  camera_platform_interface:\n"
        "    path: third_party/camera/camera_platform_interface\n"
        "  camera_web:\n"
        "    path: third_party/camera/camera_web\n"
    )
else:
    print("NOTE: dependency_overrides already exists - add the camera overrides manually")

io.open("pubspec.yaml", "w", encoding="utf-8").write(s)
print("pubspec now uses vendored paths")

r = os.system("flutter pub get --offline")
if r != 0:
    print("\nOFFLINE RESOLVE FAILED - the error above names a missing package.")
    print("small packages fetch fine on your wifi with a resumable wget:")
    print("  until wget -c https://pub.dev/api/archives/<name>-<ver>.tar.gz -O /tmp/p.tgz; do sleep 3; done")
    print("  mkdir -p ~/.pub-cache/hosted/pub.dev/<name>-<ver> && tar xzf /tmp/p.tgz -C ~/.pub-cache/hosted/pub.dev/<name>-<ver>")
    print("then rerun: flutter pub get --offline")
    sys.exit(1)
print("VENDOR_OK - no more pub downloads needed, ever")
