[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Line,

    [Parameter(Mandatory = $false)]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [string]$CliPath,

    [switch]$Local
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CliPath)) {
    $command = Get-Command plow-agents -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "plow-agents was not found. Install the official CLI and select the checkout with -CliPath."
    }
    $CliPath = $command.Source
}

if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf) -and $CliPath -notmatch "^[^\\/]+$") {
    throw "The plow-agents CLI path does not exist: $CliPath"
}

function Invoke-PlowAgents {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & $CliPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "plow-agents failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
}

if ($Local) {
    # This is the official `plow-agents deploy --local` path.
    Invoke-PlowAgents @("deploy", "--local", "--line", $Line)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Image)) {
    throw "-Image is required for a cloud deploy (for example ghcr.io/account/joust:v1)."
}

# The official CLI image build and image push return an immutable
# repository@sha256 reference. Deploy only that digest; never deploy a tag.
Invoke-PlowAgents @("image", "build", $Image)
$pushOutput = (& $CliPath "image" "push" $Image 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "plow-agents image push failed with exit code $LASTEXITCODE."
}

$digestMatch = [regex]::Match($pushOutput, "(?m)(?<reference>[^\s\r\n]+@sha256:[0-9a-f]{64})")
if (-not $digestMatch.Success) {
    throw "The official image push did not return an immutable digest reference."
}

Invoke-PlowAgents @("deploy", $digestMatch.Groups["reference"].Value, "--line", $Line)
