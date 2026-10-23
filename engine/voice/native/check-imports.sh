#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# check-imports.sh <llvm-nm or nm> <libkryfo_voice.so>: fails when the
# library imports a network call or a way to start a process. it reads a
# model file and some memory, and has no reason for either.
set -euo pipefail
nm="$1"
so="$2"
NET='^(socket|connect|bind|listen|accept|accept4|getaddrinfo|gethostbyname|gethostbyname2|gethostbyaddr|sendto|recvfrom|sendmsg|recvmsg|send|recv|curl_.*)$'
# a forked child of the app could be granted ptrace on the keys
SPAWN='^(fork|vfork|clone|clone3|execl.*|execv.*|fexecve|posix_spawn.*|system|popen|ptrace|prctl)$'
imports="$("$nm" -D --undefined-only "$so" | awk '{print $NF}' | sed 's/@.*//')"
bad=0
net="$(grep -E "$NET" <<<"$imports" || true)"
if [[ -n "$net" ]]; then echo "error: $so imports network calls: $(tr '\n' ' ' <<<"$net")" >&2; bad=1; fi
spawn="$(grep -E "$SPAWN" <<<"$imports" || true)"
if [[ -n "$spawn" ]]; then echo "error: $so imports process calls: $(tr '\n' ' ' <<<"$spawn")" >&2; bad=1; fi
exit "$bad"
