# Put one folder at the front of the Windows user PATH. Called by
# setup-machine.sh. Input comes from the environment, because a path with
# spaces does not survive as an argument from Git Bash:
#   LODESTAR_PATH_ENTRY  the folder
#   LODESTAR_PATH_MODE   check (default): exit 0 when the folder is there, 1 when not
#                        add: write it first in the list
#   LODESTAR_PATH_KEY    registry key that holds Path; default HKCU:\Environment.
#                        The self-test sets its own key, so it never writes the real PATH.
$ErrorActionPreference = 'Stop'
$add = $env:LODESTAR_PATH_ENTRY
if (-not $add) { exit 2 }
$key = if ($env:LODESTAR_PATH_KEY) { $env:LODESTAR_PATH_KEY } else { 'HKCU:\Environment' }
$item = Get-Item -LiteralPath $key
# Read the value as stored, not expanded: an entry such as %USERPROFILE%\bin
# must be written back unchanged.
$raw = [string]$item.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
$entries = @($raw -split ';' | Where-Object { $_ })
function Test-Same($entry) {
  [Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\') -ieq $add.TrimEnd('\')
}
if ($env:LODESTAR_PATH_MODE -ne 'add') {
  if (@($entries | Where-Object { Test-Same $_ }).Count -gt 0) { exit 0 }
  exit 1
}
$rest = @($entries | Where-Object { -not (Test-Same $_) })
# @($add): a string plus an array would be joined into one broken entry.
$new = (@($add) + $rest) -join ';'
$kind = if ($null -ne $item.GetValue('Path', $null)) { $item.GetValueKind('Path') } else { 'ExpandString' }
Set-ItemProperty -LiteralPath $key -Name Path -Value $new -Type $kind
# A direct registry write is silent. Clearing a variable that does not exist
# sends the "environment changed" notice, so programs started later see the PATH.
if (-not $env:LODESTAR_PATH_KEY) { [Environment]::SetEnvironmentVariable('LODESTAR_PATH_REFRESH', $null, 'User') }
exit 0
