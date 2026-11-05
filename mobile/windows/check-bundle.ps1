# checks a windows bundle after `flutter build windows`: the runner, the
# three natives next to it, tor in tor\, the tor.exe pin in tor-pin.txt and
# in halo.dll, aslr and dep on every pe file, cfg on kryfo.exe, and no plain
# sqlite or mingw runtime dll.
#   powershell -ExecutionPolicy Bypass -File windows\check-bundle.ps1 [-Bundle dir] [-NativeSums file]
# -NativeSums: the sha256 lines natives.sh wrote in wsl, so the dlls are the
# ones built there
param(
  [string]$Bundle = (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release'),
  [string]$NativeSums = ''
)
$ErrorActionPreference = 'Stop'
$script:fail = 0
function No([string]$why) { Write-Output "FAIL: $why"; $script:fail = 1 }
function Sha([string]$path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() }

if (-not (Test-Path -LiteralPath (Join-Path $Bundle 'kryfo.exe'))) {
  Write-Output "FAIL: no kryfo.exe in $Bundle"
  exit 1
}
$need = @('kryfo.exe', 'flutter_windows.dll', 'halo.dll', 'kryfo_signal.dll', 'sqlcipher.dll',
  'data\app.so', 'data\icudtl.dat', 'data\flutter_assets', 'tor\tor.exe', 'tor\openssl.cnf',
  'tor\licenses\tor.txt', 'tor\licenses\openssl.txt', 'tor\licenses\libevent.txt', 'tor\licenses\zlib.txt')
foreach ($n in $need) {
  if (-not (Test-Path -LiteralPath (Join-Path $Bundle $n))) { No "$n missing" }
}
# what must never ship: a plain sqlite, mingw's runtimes, the bundle's extras
foreach ($n in @('sqlite3.dll', 'libsqlite3.dll', 'libwinpthread-1.dll', 'libgcc_s_seh-1.dll',
  'libstdc++-6.dll', 'libcrypto-3-x64.dll', 'tor\tor-gencert.exe', 'tor\pluggable_transports')) {
  if (Test-Path -LiteralPath (Join-Path $Bundle $n)) { No "$n must not ship" }
}

# tor.exe is the pinned one, and halo.dll pins the same
$pin = Join-Path $PSScriptRoot '..\..\packaging\windows\tor-pin.txt'
$want = ((Get-Content -LiteralPath $pin) | Where-Object { $_ -like 'TOR_EXE_SHA256=*' }) -replace '^TOR_EXE_SHA256=', ''
$tor = Join-Path $Bundle 'tor\tor.exe'
if (Test-Path -LiteralPath $tor) {
  $got = Sha $tor
  if ($got -ne $want) { No "tor.exe sha256 $got, pinned $want" }
}
$halo = Join-Path $Bundle 'halo.dll'
if (Test-Path -LiteralPath $halo) {
  $text = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($halo))
  if (-not $text.Contains($want)) { No "halo.dll does not pin tor.exe $want" }
}
$cnf = Join-Path $Bundle 'tor\openssl.cnf'
if ((Test-Path -LiteralPath $cnf) -and ((Get-Content -Raw -LiteralPath $cnf) -match '(?m)^\s*[^#\s]')) {
  No 'tor\openssl.cnf has settings in it'
}

# the natives are the bytes built in wsl
if ($NativeSums -ne '') {
  foreach ($line in Get-Content -LiteralPath $NativeSums) {
    if ($line -notmatch '^([0-9a-f]{64})\s+\*?(.+)$') { continue }
    $name = Split-Path -Leaf $Matches[2]
    $path = Join-Path $Bundle $name
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $got = Sha $path
    if ($got -ne $Matches[1]) { No "$name sha256 $got, wsl built $($Matches[1])" }
  }
}

# pe flags: DYNAMIC_BASE 0x40, HIGH_ENTROPY_VA 0x20, NX_COMPAT 0x100, GUARD_CF 0x4000
function DllChars([string]$path) {
  $b = [System.IO.File]::ReadAllBytes($path)
  $pe = [BitConverter]::ToInt32($b, 0x3C)
  if ([BitConverter]::ToUInt32($b, $pe) -ne 0x4550) { return -1 }
  # the optional header starts 24 bytes in; DllCharacteristics is 70 into it
  return [BitConverter]::ToUInt16($b, $pe + 24 + 70)
}
$pes = Get-ChildItem -LiteralPath $Bundle -Recurse -File | Where-Object { $_.Extension -in '.exe', '.dll' }
foreach ($f in $pes) {
  $c = DllChars $f.FullName
  $rel = $f.FullName.Substring((Resolve-Path -LiteralPath $Bundle).Path.Length + 1)
  if ($c -lt 0) { No "$rel is not a pe file"; continue }
  foreach ($bit in @(@(0x40, 'DYNAMIC_BASE'), @(0x20, 'HIGH_ENTROPY_VA'), @(0x100, 'NX_COMPAT'))) {
    if (($c -band $bit[0]) -eq 0) { No "$rel lacks $($bit[1])" }
  }
  if ($rel -eq 'kryfo.exe' -and ($c -band 0x4000) -eq 0) { No 'kryfo.exe lacks GUARD_CF' }
}

if ($script:fail -eq 0) { Write-Output "bundle ok: $Bundle" }
exit $script:fail
