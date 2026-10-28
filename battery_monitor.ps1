# battery_monitor.ps1
# Logs battery drain, CPU/RAM/GPU usage, and running averages at whatever
# interval you choose. At startup it asks:
#   1) whether to log data to a CSV file
#   2) how to handle the display: turn it off / keep it always on (no sleep) / leave normal
#   3) how often to check (e.g. 1m, 30s, 1h, 1d)
#
# Run it with:  powershell -ExecutionPolicy Bypass -File battery_monitor.ps1

function Ask-YesNo($prompt) {
    while ($true) {
        $ans = Read-Host "$prompt (y/n)"
        if ($ans -match '^(y|yes)$') { return $true }
        if ($ans -match '^(n|no)$') { return $false }
        Write-Host "Please answer y or n."
    }
}

function Parse-Interval($text) {
    $text = $text.Trim().ToLower()
    if ($text -match '^(\d+)(s|m|h|d)$') {
        $num = [int]$Matches[1]
        switch ($Matches[2]) {
            's' { return $num }
            'm' { return $num * 60 }
            'h' { return $num * 3600 }
            'd' { return $num * 86400 }
        }
    }
    return $null
}

function Ask-Interval {
    while ($true) {
        $ans = Read-Host "How often to check? e.g. 30s, 1m, 5m, 1h, 1d (default 1m)"
        if ($ans -eq "") { return 60 }
        $secs = Parse-Interval $ans
        if ($null -ne $secs) { return $secs }
        Write-Host "Use a number followed by s, m, h or d (e.g. 5m, 30s)."
    }
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class PowerHelper {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

$ES_CONTINUOUS = [uint32]2147483648
$ES_SYSTEM_REQUIRED = [uint32]1
$ES_DISPLAY_REQUIRED = [uint32]2

function Turn-DisplayOff {
    $HWND_BROADCAST = [IntPtr]0xFFFF
    $WM_SYSCOMMAND = 0x0112
    $SC_MONITORPOWER = [IntPtr]0xF170
    [PowerHelper]::SendMessage($HWND_BROADCAST, $WM_SYSCOMMAND, $SC_MONITORPOWER, [IntPtr]2) | Out-Null
}

function Keep-AlwaysOn {
    # Must be called repeatedly (each loop tick) - the flag resets otherwise
    [PowerHelper]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED) | Out-Null
}

function Release-AlwaysOn {
    [PowerHelper]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
}

function Get-BatteryInfo {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($null -eq $battery) { return $null }
    $percent = $battery.EstimatedChargeRemaining
    # BatteryStatus: 2 = AC power / charging, others = on battery
    $plugged = $battery.BatteryStatus -eq 2
    return @{ Percent = $percent; Plugged = $plugged }
}

function Get-CpuUsage {
    try {
        $counter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop
        return [math]::Round($counter.CounterSamples[0].CookedValue, 2)
    } catch {
        return $null
    }
}

function Get-RamUsage {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $usedPercent = 100 - (($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
        return [math]::Round($usedPercent, 2)
    } catch {
        return $null
    }
}

function Get-GpuUsage {
    # Sums all GPU engine utilization counters (3D, copy, video decode, etc.)
    # Works on Windows 10/11 with WDDM 2.0+ drivers; returns $null if unsupported.
    try {
        $counters = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
        $total = ($counters.CounterSamples | Measure-Object -Property CookedValue -Sum).Sum
        if ($total -gt 100) { $total = 100 }
        return [math]::Round($total, 2)
    } catch {
        return $null
    }
}

Write-Host "=== Battery & System Monitor ==="
$doLog = Ask-YesNo "Log data to a file?"

Write-Host "`nDisplay option:"
Write-Host "  1) Turn display off now"
Write-Host "  2) Keep display always on / prevent sleep while monitoring"
Write-Host "  3) Leave display as normal (no change)"
$displayChoice = $null
while ($displayChoice -notin @("1","2","3")) {
    $displayChoice = Read-Host "Choose 1, 2 or 3"
}

$intervalSeconds = Ask-Interval

$logPath = Join-Path (Get-Location) "battery_log.csv"
if ($doLog) {
    if (-not (Test-Path $logPath)) {
        try {
            "timestamp,battery_percent,plugged,drain_since_last(%),elapsed_since_last(s),avg_drain_rate(%/hr),cpu_percent,avg_cpu_percent,ram_percent,avg_ram_percent,gpu_percent,avg_gpu_percent" |
                Out-File -FilePath $logPath -Encoding utf8 -ErrorAction Stop
        } catch {
            Write-Host "Could not create log file. Check the file isn't open elsewhere and you have write access to this folder."
            $doLog = $false
        }
    }
    if ($doLog) { Write-Host "Logging to: $logPath" }
}

if ($displayChoice -eq "1") {
    Turn-DisplayOff
}

$batt = Get-BatteryInfo
if ($null -eq $batt) {
    Write-Host "No battery detected on this system. Exiting."
    exit
}

$startPercent = $batt.Percent
$startTime = Get-Date
$lastPercent = $batt.Percent
$lastTime = $startTime

$cpuSum = 0.0; $cpuCount = 0
$ramSum = 0.0; $ramCount = 0
$gpuSum = 0.0; $gpuCount = 0
$gpuWarned = $false

Write-Host "Starting battery level: $startPercent%"
Write-Host "Checking every $intervalSeconds seconds. Press Ctrl+C to stop."
Write-Host ""

try {
    while ($true) {
        if ($displayChoice -eq "2") {
            Keep-AlwaysOn
        }

        Start-Sleep -Seconds $intervalSeconds
        $batt = Get-BatteryInfo
        if ($null -eq $batt) {
            Write-Host "Battery info unavailable this reading, skipping."
            continue
        }

        $percent = $batt.Percent
        $plugged = $batt.Plugged
        $now = Get-Date

        $elapsedSinceLast = ($now - $lastTime).TotalSeconds
        $drainSinceLast = $lastPercent - $percent

        $totalElapsedHours = ($now - $startTime).TotalHours
        $totalDrain = $startPercent - $percent
        if ($totalElapsedHours -gt 0) {
            $avgRate = $totalDrain / $totalElapsedHours
        } else {
            $avgRate = 0
        }

        $cpu = Get-CpuUsage
        $ram = Get-RamUsage
        $gpu = Get-GpuUsage

        if ($null -ne $cpu) { $cpuSum += $cpu; $cpuCount++ }
        if ($null -ne $ram) { $ramSum += $ram; $ramCount++ }
        if ($null -ne $gpu) { $gpuSum += $gpu; $gpuCount++ }
        elseif (-not $gpuWarned) {
            Write-Host "(GPU usage counters not available on this system - will show N/A)"
            $gpuWarned = $true
        }

        $avgCpu = if ($cpuCount -gt 0) { [math]::Round($cpuSum / $cpuCount, 2) } else { $null }
        $avgRam = if ($ramCount -gt 0) { [math]::Round($ramSum / $ramCount, 2) } else { $null }
        $avgGpu = if ($gpuCount -gt 0) { [math]::Round($gpuSum / $gpuCount, 2) } else { $null }

        $ts = $now.ToString("yyyy-MM-dd HH:mm:ss")
        $status = if ($plugged) { "Plugged" } else { "On battery" }

        $cpuText = if ($null -ne $cpu) { "$cpu%" } else { "N/A" }
        $ramText = if ($null -ne $ram) { "$ram%" } else { "N/A" }
        $gpuText = if ($null -ne $gpu) { "$gpu%" } else { "N/A" }
        $avgCpuText = if ($null -ne $avgCpu) { "$avgCpu%" } else { "N/A" }
        $avgRamText = if ($null -ne $avgRam) { "$avgRam%" } else { "N/A" }
        $avgGpuText = if ($null -ne $avgGpu) { "$avgGpu%" } else { "N/A" }

        Write-Host ("[{0}] Batt {1}% ({2}) | drain: {3:N2}% | avg drain: {4:N2}%/hr | CPU {5} (avg {6}) | RAM {7} (avg {8}) | GPU {9} (avg {10})" -f `
            $ts, $percent, $status, $drainSinceLast, $avgRate, $cpuText, $avgCpuText, $ramText, $avgRamText, $gpuText, $avgGpuText)

        if ($doLog) {
            try {
                "$ts,$percent,$plugged,$([math]::Round($drainSinceLast,2)),$([math]::Round($elapsedSinceLast,1)),$([math]::Round($avgRate,2)),$cpuText,$avgCpuText,$ramText,$avgRamText,$gpuText,$avgGpuText" |
                    Out-File -FilePath $logPath -Append -Encoding utf8 -ErrorAction Stop
            } catch {
                Write-Host "Could not write to log file this tick (it may be open in Excel/Notepad). Skipping this entry."
            }
        }

        $lastPercent = $percent
        $lastTime = $now
    }
}
finally {
    if ($displayChoice -eq "2") {
        Release-AlwaysOn
    }
    Write-Host "`nStopped monitoring."
}