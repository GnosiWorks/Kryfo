# run by kryfo.iss while it compiles: a tor.exe other than the pinned one
# stops the build
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Sha256
)
$ErrorActionPreference = 'Stop'
$got = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
if ($got -ne $Sha256.ToLowerInvariant()) {
  [Console]::Error.WriteLine("tor.exe sha256 $got, pinned $Sha256")
  exit 1
}
exit 0
