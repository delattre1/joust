[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Line,

    [Parameter(Mandatory = $false)]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [string]$CliPath,

    [Parameter(Mandatory = $false)]
    [string]$AgentApiBase,

    [switch]$Local
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repositoryRoot
try {
    $script:cliMode = $null
    $script:cliExecutable = $null
    $script:wslExecutable = $null

    function Resolve-PlowAgents {
        param([string]$RequestedPath)

        $candidate = if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
            Get-Command plow-agents -ErrorAction SilentlyContinue
        } else {
            Get-Command $RequestedPath -ErrorAction SilentlyContinue
        }

        if ($null -ne $candidate) {
            $script:cliMode = "native"
            $script:cliExecutable = $candidate.Source
            return
        }

        if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
            throw "The plow-agents CLI path does not exist or is not executable: $RequestedPath"
        }

        $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
        if ($null -ne $wsl) {
            $probe = & $wsl.Source -e sh -lc "command -v plow-agents" 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($probe -join ""))) {
                $script:cliMode = "wsl"
                $script:wslExecutable = $wsl.Source
                return
            }
        }

        throw "plow-agents was not found. Install the current official CLI or pass -CliPath."
    }

    function ConvertTo-ShellWord {
        param([Parameter(Mandatory = $true)][string]$Value)

        return "'" + ($Value -replace "'", "'\\''") + "'"
    }

    function Invoke-PlowAgents {
        param(
            [Parameter(Mandatory = $true)][string[]]$Arguments,
            [switch]$Capture
        )

        if ($script:cliMode -eq "native") {
            if ($Capture) {
                $output = @(& $script:cliExecutable @Arguments 2>&1)
            } else {
                & $script:cliExecutable @Arguments
                $output = @()
            }
        } else {
            $command = "plow-agents " + (($Arguments | ForEach-Object {
                ConvertTo-ShellWord $_
            }) -join " ")
            if ($Capture) {
                $output = @(& $script:wslExecutable --cd $repositoryRoot -e sh -lc $command 2>&1)
            } else {
                & $script:wslExecutable --cd $repositoryRoot -e sh -lc $command
                $output = @()
            }
        }

        $exitCode = $LASTEXITCODE
        if ($Capture) {
            # Keep the captured digest parseable while still surfacing Docker
            # and CLI output to the operator.
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -ne 0) {
            throw "plow-agents failed with exit code ${exitCode}: $($Arguments -join ' ')"
        }
        if ($Capture) {
            return ($output -join [Environment]::NewLine)
        }
    }

    function Add-LineArgument {
        param([System.Collections.Generic.List[string]]$Arguments)

        if (-not [string]::IsNullOrWhiteSpace($Line)) {
            $Arguments.Add("--line")
            $Arguments.Add($Line)
        }
    }

    Resolve-PlowAgents $CliPath

    # Fail before a local deploy can mint a line-scoped agent that Compose will
    # immediately reject for lack of the variant's stable Index identity.
    if ($Local -and [string]::IsNullOrWhiteSpace($env:AGENT_ID)) {
        throw "Set AGENT_ID to the stable Agent Index id before using -Local."
    }

    $help = Invoke-PlowAgents @("--help") -Capture
    if ($help -notmatch "deploy" -or $help -notmatch "image" -or $help -notmatch "agents") {
        throw "The installed plow-agents CLI is older than the one-click deploy contract. Update it from https://github.com/plow-pbc/plow-agents."
    }

    if ($Local) {
        if (-not [string]::IsNullOrWhiteSpace($Image)) {
            throw "-Image is only valid for a hosted deploy; omit it with -Local."
        }
        if (-not [string]::IsNullOrWhiteSpace($env:PLOW_CREDENTIALS) -or
            -not [string]::IsNullOrWhiteSpace($env:PLOW_CREDENTIALS_PATH)) {
            throw "The official deploy --local path writes ./plow-credentials. Use the existing credential path with docker compose up, or unset PLOW_CREDENTIALS/PLOW_CREDENTIALS_PATH for a fresh local deploy."
        }
        if (-not [string]::IsNullOrWhiteSpace($AgentApiBase)) {
            $arguments = [System.Collections.Generic.List[string]]::new()
            $arguments.Add("deploy")
            $arguments.Add("--local")
            Add-LineArgument $arguments
            $arguments.Add("--agent-api-base")
            $arguments.Add($AgentApiBase)
            Invoke-PlowAgents $arguments.ToArray()
        } else {
            $arguments = [System.Collections.Generic.List[string]]::new()
            $arguments.Add("deploy")
            $arguments.Add("--local")
            Add-LineArgument $arguments
            Invoke-PlowAgents $arguments.ToArray()
        }
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($AgentApiBase)) {
        throw "-AgentApiBase is only valid with -Local."
    }
    if ([string]::IsNullOrWhiteSpace($Image)) {
        throw "-Image is required for a hosted deploy (for example ghcr.io/account/joust:v1)."
    }

    # The upstream CLI performs the credential scan and builds linux/amd64.
    Invoke-PlowAgents @("image", "build", $Image)
    $pushOutput = Invoke-PlowAgents @("image", "push", $Image) -Capture
    $digestMatch = [regex]::Match($pushOutput, "(?m)(?<reference>[^\s\r\n]+@sha256:[0-9a-f]{64})")
    if (-not $digestMatch.Success) {
        throw "The official image push did not return an immutable digest reference."
    }

    $deployArguments = [System.Collections.Generic.List[string]]::new()
    $deployArguments.Add("deploy")
    $deployArguments.Add($digestMatch.Groups["reference"].Value)
    Add-LineArgument $deployArguments
    Invoke-PlowAgents $deployArguments.ToArray()
} finally {
    Pop-Location
}
