# run by kryfo.iss while it compiles: a tor.exe other than the pinned one
# stops the build
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Sha256
)
$ErrorActionPreference = 'Stop'
# .net, not Get-FileHash: started from iscc on a runner, windows powershell gets
# powershell 7's module path and cannot load modules, so no cmdlet from one here
$sha = [System.Security.Cryptography.SHA256]::Create()
$fs = [System.IO.File]::OpenRead([System.IO.Path]::GetFullPath($Path))
try { $got = -join ($sha.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) } finally { $fs.Dispose() }
if ($got -ne $Sha256.ToLowerInvariant()) {
  [Console]::Error.WriteLine("tor.exe sha256 $got, pinned $Sha256")
  exit 1
}
exit 0
