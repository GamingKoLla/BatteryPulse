# BatteryPulse ⚡

**A lightweight Windows battery-drain and system-usage monitor built with PowerShell.**

Track battery percentage over time while keeping an eye on CPU, RAM, and GPU usage. Choose your sampling interval, optionally save readings to CSV, and use the logs to understand what your system is doing during a battery test.

> BatteryPulse reports the battery percentage exposed by Windows. It is a monitoring utility, not a laboratory battery-capacity or battery-health diagnostic tool.

<p align="center">
  <strong>Battery tracking · System usage · CSV logging · Configurable intervals</strong>
</p>

## ✨ Features

- **Battery monitoring** — shows the current reported battery percentage and whether the device is plugged in or running on battery.
- **Drain tracking** — calculates the percentage-point change since the previous reading and an average drain rate per hour since monitoring started.
- **CPU, RAM, and GPU usage** — records current readings and session averages where Windows exposes the required performance counters.
- **CSV export** — optionally saves timestamped readings to `battery_log.csv` for review in Excel or another spreadsheet application.
- **Flexible sampling** — choose intervals such as `30s`, `1m`, `5m`, `1h`, or `1d`.
- **Display and sleep options** — turn the display off at the start, request that the system and display stay awake while monitoring, or leave power behavior unchanged.
- **No third-party modules** — uses Windows PowerShell and built-in Windows/CIM performance counters.
- **Simple launch** — start it using the included batch file or run the PowerShell script directly.

## 🖥️ Requirements

- Windows 10 or Windows 11.
- Windows PowerShell with permission to run the script.
- A battery-backed device for battery readings. Desktop PCs without a detectable battery will exit with a message.
- GPU usage readings depend on supported Windows GPU performance counters and drivers. If unavailable, GPU usage is shown as `N/A`.

## 🚀 Quick start

1. Download or clone this repository.
2. Extract the files if you downloaded a ZIP archive.
3. Open the `BatteryPulse` folder.
4. Double-click `run_battery_monitor.bat`.
5. Answer the prompts to choose CSV logging, display behavior, and the sampling interval.
6. Leave the window open while the test runs. Press **Ctrl+C** in the PowerShell window to stop monitoring.

### Run from PowerShell

Open PowerShell in the project folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\battery_monitor.ps1
```

The included launcher uses `-ExecutionPolicy Bypass` for this process only; it does not permanently change your system's PowerShell execution policy. Review scripts before running them, as you should with any downloaded code.

## 📊 CSV output

If you enable logging, BatteryPulse writes `battery_log.csv` in the working directory. The file includes these columns:

| Column | Meaning |
|---|---|
| `timestamp` | Time of the reading |
| `battery_percent` | Battery percentage reported by Windows |
| `plugged` | Whether Windows reports AC power / charging status |
| `drain_since_last(%)` | Previous percentage minus current percentage; a negative value means the reported level increased |
| `elapsed_since_last(s)` | Seconds since the previous valid reading |
| `avg_drain_rate(%/hr)` | Average percentage-point change per hour since the session began |
| `cpu_percent` | Current CPU usage, when available |
| `avg_cpu_percent` | Average CPU usage across successful readings in the session |
| `ram_percent` | Current percentage of physical memory in use |
| `avg_ram_percent` | Average memory usage across successful readings in the session |
| `gpu_percent` | GPU-engine utilization estimate, when supported |
| `avg_gpu_percent` | Average reported GPU utilization across successful readings |

**Tip:** For a more useful comparison, run tests under similar screen brightness, power mode, workload, network conditions, and starting battery level. Record what you were doing during each test.

## ⚙️ Display options

At startup, choose one of these options:

1. **Turn display off now** — sends Windows a request to turn off the display. This does not guarantee that every monitor or device will behave identically.
2. **Keep display always on / prevent sleep** — requests that Windows keep the system and display awake during monitoring. The script releases this request when it stops normally or is interrupted through its handled exit path.
3. **Leave display as normal** — does not intentionally change display or sleep behavior.

## 🔍 How drain rate is calculated

BatteryPulse uses the battery percentage reported by Windows and calculates the difference over elapsed time. Its average drain rate is:

`(starting battery percentage − current battery percentage) ÷ elapsed hours`

This is a **percentage-point rate**, not a measurement of battery energy in watt-hours. Battery percentages are rounded estimates supplied by the system, so short tests may show zero change or uneven readings.

## ⚠️ Notes and limitations

- This tool does not directly measure battery capacity, battery wear, voltage, current, or power consumption in watts.
- It does not currently generate a graphical dashboard or HTML report; readings appear in the terminal and can optionally be saved to CSV.
- CPU, RAM, and GPU averages cover successful samples collected during the current run.
- Windows performance-counter availability varies by device, driver, and configuration.
- The battery's reported plugged/charging status may vary by hardware and driver. Check the output against your device's actual power state.
- The monitor is designed to run until you stop it. Choose a reasonable interval for your test.

## 🧰 Project files

```text
BatteryPulse/
├── battery_monitor.ps1       # Monitoring and CSV logging logic
├── run_battery_monitor.bat   # Windows launcher
└── README.md                 # Documentation
```

## 🤝 Contributing

Bug reports, ideas, and pull requests are welcome. If reporting an issue, include your Windows version, PowerShell version, device type, selected interval, and any relevant error message. Remove personal information from logs before sharing them.

## 🗺️ Possible future improvements

These are ideas, not features currently included:

- Battery-health and capacity reporting using supported Windows battery interfaces.
- A graphical interface with live charts.
- Test-session summaries and HTML reports.
- Configurable CSV output paths and additional export formats.

## 👨‍💻 Author & Organization

**Coded by Rawishan**  
**Organization:** ArcEdgeNetwork — [arcedge.lk](https://arcedge.lk)

BatteryPulse is developed by Rawishan under ArcEdgeNetwork, also known as ArcEdge.lk. Built as a lightweight Windows utility for observing battery drain alongside system resource usage.

- **Developer:** Rawishan
- **Organization:** ArcEdgeNetwork
- **Website:** [https://arcedge.lk](https://arcedge.lk)

---

If BatteryPulse is useful to you, consider giving the repository a ⭐ and sharing feedback or improvements.
