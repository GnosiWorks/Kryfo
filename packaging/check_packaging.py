# SPDX-License-Identifier: GPL-3.0-or-later
# reads the flatpak manifest and the inno script the way their tools would
# and checks them against a repo tree (real, or the stand-in test.sh makes).
#   check_packaging.py flatpak <repo> <app-out>
#   check_packaging.py iss <repo>
import glob
import os
import re
import shutil
import subprocess
import sys

import yaml

# each one is argued for in app.kryfo.Kryfo.yml; a new one needs a reason there
# and here
FINISH_ARGS = {
    "--share=network",
    "--socket=wayland",
    "--socket=fallback-x11",
    "--share=ipc",
    "--device=dri",
    "--socket=pulseaudio",
    "--talk-name=org.freedesktop.Notifications",
}

failed = False


def fail(msg):
    global failed
    failed = True
    print("FAIL " + msg)


def ok(msg):
    print("ok   " + msg)


def flatpak(repo, app):
    mdir = os.path.join(repo, "packaging", "flatpak")
    with open(os.path.join(mdir, "app.kryfo.Kryfo.yml")) as f:
        m = yaml.safe_load(f)
    ok("manifest parses as yaml")
    if m.get("id") != "app.kryfo.Kryfo" or m.get("command") != "kryfo":
        fail("id or command changed: %s %s" % (m.get("id"), m.get("command")))
    if m.get("runtime") != "org.freedesktop.Platform" or m.get("sdk") != "org.freedesktop.Sdk":
        fail("runtime is not org.freedesktop.Platform")
    if not re.fullmatch(r"\d\d\.08", str(m.get("runtime-version"))):
        fail("runtime-version is not a yy.08 release: %r" % m.get("runtime-version"))
    args = set(m.get("finish-args", []))
    if args != FINISH_ARGS:
        fail("finish-args differ: added %s, removed %s"
             % (sorted(args - FINISH_ARGS), sorted(FINISH_ARGS - args)))
    else:
        ok("finish-args are the justified set")
    if any(a.startswith("--filesystem") for a in args):
        fail("filesystem access: files go through portals")

    mods = {mod["name"]: mod for mod in m["modules"]}
    for name in ["sqlcipher", "ffmpeg"]:
        for src in mods[name]["sources"]:
            if src["type"] != "archive":
                fail("%s builds from a %s, not a pinned archive" % (name, src["type"]))
                continue
            sha = str(src.get("sha256", ""))
            if not re.fullmatch(r"[0-9a-f]{64}", sha) or sha == "0" * 64:
                fail("%s sha256 is not a real pin: %r" % (name, sha))
            if not re.search(r"\d+\.\d+\.\d+\.tar\.[gx]z$", src["url"]):
                fail("%s is not pinned to a release: %s" % (name, src["url"]))
    # one sqlcipher for the linux build and the flatpak
    sh = open(os.path.join(repo, "mobile", "linux", "build-sqlcipher.sh")).read()
    ver = re.search(r"^ver=(\S+)$", sh, re.M).group(1)
    sum_ = re.search(r"^sum=(\S+)$", sh, re.M).group(1)
    src = mods["sqlcipher"]["sources"][0]
    if src["sha256"] != sum_ or "/v%s.tar.gz" % ver not in src["url"]:
        fail("the flatpak's sqlcipher is not build-sqlcipher.sh's %s %s" % (ver, sum_))
    else:
        ok("sqlcipher pin equals build-sqlcipher.sh")
    cfg = set(mods["sqlcipher"]["config-opts"])
    for opt in re.findall(r"--[a-z0-9-]+(?:=\S+)?", sh.split("./configure", 1)[1].split(">", 1)[0]):
        if opt not in cfg:
            fail("build-sqlcipher.sh configures %s, the flatpak does not" % opt)
    ld = re.search(r'^export LDFLAGS="\$\{EXTRA_LDFLAGS:-\} (.*)"$', sh, re.M).group(1)
    if ld.split() != str(mods["sqlcipher"]["build-options"]["ldflags"]).split():
        fail("the flatpak's sqlcipher links with %r, build-sqlcipher.sh with %r"
             % (mods["sqlcipher"]["build-options"]["ldflags"], ld))
    else:
        ok("sqlcipher ldflags equal build-sqlcipher.sh")

    # lay the kryfo module's sources out as flatpak-builder would, then run
    # its build commands with /app moved to app-out
    kryfo = mods["kryfo"]
    work = app + ".src"
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    for src in kryfo["sources"]:
        path = os.path.normpath(os.path.join(mdir, src["path"]))
        if not os.path.exists(path):
            fail("manifest source missing: " + os.path.relpath(path, repo))
            continue
        if src["type"] == "dir":
            shutil.copytree(path, os.path.join(work, src.get("dest", "")),
                            symlinks=True, dirs_exist_ok=True)
        elif src["type"] == "file":
            name = src.get("dest-filename", os.path.basename(path))
            shutil.copy(path, os.path.join(work, name))
        else:
            fail("unexpected source type " + src["type"])
    env = dict(os.environ, FLATPAK_DEST=app)
    for cmd in kryfo["build-commands"]:
        r = subprocess.run(["sh", "-ec", cmd], cwd=work, env=env)
        if r.returncode != 0:
            fail("build command failed: " + cmd)
            return
    ok("kryfo module build commands ran")
    exe = os.path.join(app, "bin", m["command"])
    if not (os.path.isfile(exe) and os.access(exe, os.X_OK)):
        fail("/app/bin/%s does not reach the runner" % m["command"])
    for rel in ["lib/kryfo/lib/libhalo.so",
                "lib/kryfo/lib/libkryfo_signal.so",
                "lib/kryfo/data/icudtl.dat",
                "share/applications/app.kryfo.Kryfo.desktop",
                "share/metainfo/app.kryfo.Kryfo.metainfo.xml",
                "share/icons/hicolor/512x512/apps/app.kryfo.Kryfo.png"]:
        if not os.path.isfile(os.path.join(app, rel)):
            fail("/app/%s missing" % rel)
    # the app takes the bundle's lib/ first: only the module's copy may be there
    if os.path.exists(os.path.join(app, "lib/kryfo/lib/libsqlcipher.so.0")):
        fail("the bundle's libsqlcipher.so.0 would shadow /app/lib's")
    ok("/app layout checked")


def iss_eval(expr, defs):
    # just enough ispp: names and quoted strings joined with +
    out = ""
    for part in re.findall(r'"[^"]*"|\'[^\']*\'|[A-Za-z_]\w*', expr):
        if part[0] in "\"'":
            out += part[1:-1]
        elif part in defs:
            out += defs[part]
        else:
            raise ValueError("unknown name %s in %r" % (part, expr))
    return out


# what the pubspec reader in kryfo.iss makes of mobile/pubspec.yaml
def pubspec_version(repo):
    for line in open(os.path.join(repo, "mobile", "pubspec.yaml")):
        line = line.rstrip("\r\n")
        if line.startswith("version: "):
            return line[9:].split("+", 1)[0]
    return ""


def iss(repo):
    path = os.path.join(repo, "packaging", "windows", "kryfo.iss")
    text = open(path).read()
    defs = {"SourcePath": os.path.join(repo, "packaging", "windows") + "\\"}
    if re.search(r'#define\s+AppVersion\s+"[0-9]', text):
        fail("kryfo.iss has a version of its own")
    if "pubspec.yaml" not in text:
        fail("kryfo.iss does not read mobile\\pubspec.yaml")
    defs["AppVersion"] = pubspec_version(repo)
    if not re.fullmatch(r"\d+\.\d+\.\d+", defs["AppVersion"]):
        fail("no version in pubspec.yaml: %r" % defs["AppVersion"])
    # the pubspec reader's own names are ispp calls, not paths
    head = re.sub(r"#ifndef AppVersion.*?\n#endif", "", text, count=1, flags=re.S)
    for m in re.finditer(r"^\s*#define\s+(\w+)\s+(.+?)\s*$", head, re.M):
        if m.group(1) not in defs:
            defs[m.group(1)] = iss_eval(m.group(2), defs)

    def resolve(s):
        s = re.sub(r"\{#(\w+)\}", lambda g: defs[g.group(1)], s)
        return os.path.normpath(s.replace("\\", "/"))

    section = None
    setup = {}
    sources = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if re.fullmatch(r"\[\w+\]", line):
            section = line
            continue
        if section == "[Setup]" and "=" in line:
            k, v = line.split("=", 1)
            setup[k.strip()] = v.strip()
        elif section == "[Files]":
            fields = dict((k.strip(), v.strip().strip('"'))
                          for k, v in (f.split(":", 1) for f in line.split(";") if ":" in f))
            sources.append(fields)

    if setup.get("PrivilegesRequired") != "lowest":
        fail("installer is not per-user")
    if "PrivilegesRequiredOverridesAllowed" in setup:
        fail("installer offers to elevate")
    if not setup.get("DefaultDirName", "").startswith("{localappdata}\\Programs\\"):
        fail("not installed under {localappdata}\\Programs")
    for key in ["LicenseFile", "SetupIconFile"]:
        if not os.path.isfile(resolve(setup[key])):
            fail("%s missing: %s" % (key, setup[key]))
    for src in sources:
        hits = glob.glob(resolve(src["Source"]))
        if "Excludes" in src:
            ex = src["Excludes"].split(",")
            hits = [h for h in hits if os.path.basename(h) not in ex]
        if not hits and "skipifsourcedoesntexist" not in src.get("Flags", ""):
            fail("installer source missing: " + src["Source"])
    ok("%d installer sources resolve" % len(sources))
    dests = {(s["DestDir"], s.get("DestName", os.path.basename(resolve(s["Source"]))))
             for s in sources}
    for want in [("{app}", "kryfo.exe"), ("{app}", "halo.dll"),
                 ("{app}", "kryfo_signal.dll"), ("{app}\\tor", "tor.exe")]:
        if want not in dests:
            fail("installer does not put %s in %s" % (want[1], want[0]))
    code = text.split("[Code]", 1)[-1]
    if "{localappdata}\\Kryfo" not in code or "MsgBox" not in code \
            or "UninstallSilent" not in code:
        fail("uninstall does not ask before removing user data")
    # signing only when asked for, and never with a key in the repo
    if re.search(r"^SignTool=", text.split("#ifdef Sign", 1)[0], re.M):
        fail("SignTool outside #ifdef Sign")
    print("defs " + " ".join("%s=%s" % (k, defs[k]) for k in ["AppVersion", "TorExeSha256"]))


if __name__ == "__main__":
    if sys.argv[1] == "flatpak":
        flatpak(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "iss":
        iss(sys.argv[2])
    sys.exit(1 if failed else 0)
