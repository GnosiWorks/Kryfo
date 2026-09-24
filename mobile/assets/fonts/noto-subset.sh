#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# the noto fallbacks behind kryfo's own fonts, cut down to the scripts they
# are there for. fraunces, instrument sans and jetbrains mono draw latin; these
# only ever draw what those lack: cyrillic, and arabic with persian. and one
# that stands in for instrument sans in vietnamese, which stacks accents
# instrument sans does not have.
#
# sources: google/fonts at the commit below, checked by sha256. tools:
# fonttools 4.66.0. same inputs, same commands, same bytes out.
#
#   ./noto-subset.sh <dir with the downloaded noto files>
set -euo pipefail
SRC=${1:?dir with the noto source files}
OUT=$(cd "$(dirname "$0")" && pwd)
# fonttools stamps "now" into each font's header unless told otherwise.
# the source commit's date instead (2026-09-24T09:58:38Z), so a rerun is the same bytes.
export SOURCE_DATE_EPOCH=1790243918
# google/fonts 23e54b51ddffbc7713c583748e3bd86f62b1fa4a
declare -A SUM=(
  ["NotoSerif[wdth,wght].ttf"]=4d8e6761424656867019081a1a01336f3cb086982682698714054fc33f782713
  ["NotoSerif-Italic[wdth,wght].ttf"]=e87acbc6c0efd0d9a20d6a8cbbda2b266c14be3a3a6f5af8ec9d7b2460570ad1
  ["NotoSans[wdth,wght].ttf"]=bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d
  ["NotoNaskhArabic[wght].ttf"]=67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f
  ["NotoSansArabic[wdth,wght].ttf"]=63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e
)
for f in "${!SUM[@]}"; do
  echo "${SUM[$f]}  $SRC/$f" | sha256sum -c --quiet -
done

# cyrillic and its supplement, and the numero sign
CYR=U+0400-052F,U+2116
# arabic, with the persian letters and digits in it, the rial sign, and the
# zero-width non-joiner persian writes words with. not the zero-width joiner:
# emoji sequences use it, and a fallback that claims it could split them.
ARAB=U+0600-06FF,U+FDFC,U+200C
# latin with every vietnamese letter (precomposed, and the combining marks),
# general punctuation, the dong and euro signs
VIET=U+0020-007E,U+00A0-017F,U+01A0-01A1,U+01AF-01B0,U+0300-0303,U+0306,U+0309,U+0323,U+1EA0-1EF9,U+2000-206F,U+20AB-20AC

cut() { # in out unicodes axis-limits...
  local in=$1 out=$2 uni=$3; shift 3
  local tmp; tmp=$(mktemp --suffix=.ttf)
  fonttools varLib.instancer "$in" "$@" -o "$tmp" -q
  pyftsubset "$tmp" --unicodes="$uni" --layout-features='*' --no-hinting \
    --name-IDs='*' --name-languages=0x409 --drop-tables+=DSIG \
    --output-file="$OUT/$out"
  rm -f "$tmp"
  echo "$out $(stat -c%s "$OUT/$out")"
}

cut "$SRC/NotoSerif[wdth,wght].ttf"        NotoSerif-Cyrillic.ttf        "$CYR"  wdth=100 wght=300:700
cut "$SRC/NotoSerif-Italic[wdth,wght].ttf" NotoSerif-Cyrillic-Italic.ttf "$CYR"  wdth=100 wght=300:700
cut "$SRC/NotoSans[wdth,wght].ttf"         NotoSans-Cyrillic.ttf         "$CYR"  wdth=100 wght=400:700
cut "$SRC/NotoNaskhArabic[wght].ttf"       NotoNaskhArabic-Kryfo.ttf     "$ARAB" wght=400:700
cut "$SRC/NotoSansArabic[wdth,wght].ttf"   NotoSansArabic-Kryfo.ttf      "$ARAB" wdth=100 wght=400:700
cut "$SRC/NotoSans[wdth,wght].ttf"         NotoSans-Vietnamese.ttf       "$VIET" wdth=100 wght=400:700
