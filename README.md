# Corsair AI 300 Fan Controller

A lightweight bash script for automatic temperature-based fan control arch\fedora based Linux systems with PWM fan support.


##  Features

- **Zero Dependencies** - Pure bash, no Python or other interpreters needed
- **Lightweight** - Only 2-5 MB memory footprint
- **Auto-Detection** - Automatically finds all temperature sensors and fan controls
- **Multi-OS Support** - Works on Arch Linux, Bazzite, Fedora, Ubuntu, and more
- **Smart Installer** - Detects your distro and installs dependencies automatically
- **Systemd Integration** - Runs as a service with auto-start on boot
- **Configurable** - Easy-to-edit temperature thresholds and fan speeds
- **Safe** - Resets fans to automatic mode on exit

##  Table of Contents

- [Why This Exists](#why-this-exists)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [How It Works](#how-it-works)
- [Contributing](#contributing)
- [License](#license)

##  Why This Exists

The Corsair AI Workstation 300 has a front performance button that controls fan profiles, but it only works with the Windows iCUE software. On Linux, you lose this functionality. This script provides automatic fan control based on system temperatures, giving you fine-tuned control over cooling and noise levels.

While Linux systems have built-in thermal protection and won't overheat without this script, custom fan control allows you to:

- Reduce noise during light workloads
- Increase cooling during heavy tasks
- Set your own temperature/noise balance
- React faster to temperature changes than BIOS curves

##  Requirements

- Linux kernel with hwmon support (standard on all modern distros)
- Bash 4.0 or higher (pre-installed on all modern Linux systems)
- `lm-sensors` package (automatically installed by the installer)
- PWM fan controls exposed via `/sys/class/hwmon/`
- Root/sudo access for installation and fan control

### Supported Distributions

The installer automatically detects and supports:

- Arch Linux (and derivatives: Manjaro, EndeavourOS)
- Bazzite (Fedora Atomic/immutable)
- Fedora (regular and Atomic variants)
- Ubuntu/Debian (and derivatives)
- openSUSE/SLES

##  Installation

### Quick Install

```bash
# Download and extract
tar -xzf corsair-ai300-fan-controller-bash.tar.gz
cd corsair-ai300-fan-controller-bash

# Run the installer (auto-detects your OS and installs dependencies)
sudo ./install_fan_controller_bash.sh

# Start the service
sudo systemctl start fan-controller-bash.service
```

That's it! The installer will:
1. Detect your Linux distribution
2. Install `lm-sensors` using your package manager
3. Configure sensors automatically
4. Install the fan controller script
5. Set up the systemd service
6. Enable auto-start on boot

### Bazzite/Fedora Atomic Note

On immutable systems (Bazzite), the installer will:
1. Install `lm-sensors` via `rpm-ostree`
2. Prompt you to **reboot**
3. After reboot, run the installer again to complete setup

This is normal for immutable distributions.

### Manual Installation

If you prefer to install manually:

```bash
# Install lm-sensors for your distro
# Arch:
sudo pacman -S lm_sensors

# Fedora:
sudo dnf install lm_sensors

# Ubuntu/Debian:
sudo apt install lm-sensors

# Bazzite:
rpm-ostree install lm_sensors && systemctl reboot

# Configure sensors
sudo sensors-detect --auto

# Install the script and service
sudo cp temp_fan_controller.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/temp_fan_controller.sh
sudo cp fan-controller-bash.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable fan-controller-bash.service
sudo systemctl start fan-controller-bash.service
```

##  Usage

### Start/Stop the Service

```bash
# Start
sudo systemctl start fan-controller-bash.service

# Stop
sudo systemctl stop fan-controller-bash.service

# Restart
sudo systemctl restart fan-controller-bash.service

# Check status
sudo systemctl status fan-controller-bash.service
```

### View Logs

```bash
# Follow logs in real-time
sudo journalctl -u fan-controller-bash.service -f

# View last 50 lines
sudo journalctl -u fan-controller-bash.service -n 50
```

Expected output:
```
[2026-02-19 10:30:45] === Starting Automatic Fan Controller ===
[2026-02-19 10:30:45] Detecting temperature sensors...
[2026-02-19 10:30:45]   Found: k10temp - temp1_input (Tdie)
[2026-02-19 10:30:45] Detected 1 temperature sensor(s)
[2026-02-19 10:30:45] Detecting fan PWM controls...
[2026-02-19 10:30:45]   Found: it8792 - pwm1
[2026-02-19 10:30:45] Detected 1 fan control(s)
[2026-02-19 10:30:45] Starting monitoring loop...
[2026-02-19 10:30:45] Temperature: 45°C -> Setting fan speed to 30%
[2026-02-19 10:35:22] Temperature: 68°C -> Setting fan speed to 75%
```

### Test Before Installing

Run the script manually to see what it detects:

```bash
sudo ./temp_fan_controller.sh
```

Press `Ctrl+C` to stop. The script will automatically reset fans to automatic mode.

### Enable/Disable Auto-Start

```bash
# Enable auto-start on boot
sudo systemctl enable fan-controller-bash.service

# Disable auto-start
sudo systemctl disable fan-controller-bash.service
```

##  Configuration

Edit the configuration variables at the top of the script:

```bash
sudo nano /usr/local/bin/temp_fan_controller.sh
```

### Default Configuration

```bash
# Temperature thresholds (°C)
TEMP_LOW=50         # Below 50°C - minimum fan speed
TEMP_MEDIUM=65      # 50-65°C - medium fan speed
TEMP_HIGH=75        # 65-75°C - high fan speed
TEMP_CRITICAL=85    # Above 85°C - maximum fan speed

# Fan speeds (%)
FAN_SPEED_LOW=30        # 30% fan speed
FAN_SPEED_MEDIUM=50     # 50% fan speed
FAN_SPEED_HIGH=75       # 75% fan speed
FAN_SPEED_CRITICAL=100  # 100% fan speed

# Check interval (seconds)
CHECK_INTERVAL=5    # Check every 5 seconds
```

### Temperature/Speed Curve

| Temperature | Fan Speed | Use Case |
|-------------|-----------|----------|
| < 50°C | 30% | Idle/light tasks - quiet operation |
| 50-65°C | 50% | Normal use - balanced |
| 65-75°C | 75% | Heavy workload - prioritize cooling |
| > 85°C | 100% | Critical - maximum cooling |

### Example Configurations

**Quiet Profile (prioritize silence):**
```bash
TEMP_LOW=55
TEMP_MEDIUM=70
TEMP_HIGH=80
TEMP_CRITICAL=90

FAN_SPEED_LOW=25
FAN_SPEED_MEDIUM=40
FAN_SPEED_HIGH=65
FAN_SPEED_CRITICAL=100
```

**Aggressive Profile (prioritize cooling):**
```bash
TEMP_LOW=45
TEMP_MEDIUM=60
TEMP_HIGH=70
TEMP_CRITICAL=80

FAN_SPEED_LOW=40
FAN_SPEED_MEDIUM=60
FAN_SPEED_HIGH=85
FAN_SPEED_CRITICAL=100
```

After editing, restart the service:
```bash
sudo systemctl restart fan-controller-bash.service
```

##  Troubleshooting

### Check Available Sensors

```bash
sensors
```

Expected output:
```
k10temp-pci-00c3
Adapter: PCI adapter
Tctl:         +45.0°C
Tdie:         +45.0°C
```

### No Sensors Detected

Run sensor detection:
```bash
sudo sensors-detect
# Answer YES to all questions
sudo systemctl restart lm_sensors
sensors
```

### Check Temperature Files

```bash
find /sys/class/hwmon -name "temp*_input"
```

You should see files like:
```
/sys/class/hwmon/hwmon2/temp1_input
/sys/class/hwmon/hwmon2/temp2_input
```

### Check PWM Fan Controls

```bash
find /sys/class/hwmon -name "pwm[0-9]" -not -name "*_enable"
```

You should see files like:
```
/sys/class/hwmon/hwmon3/pwm1
/sys/class/hwmon/hwmon3/pwm2
```

### No PWM Controls Found

If no PWM controls are found, your system may:
- Use BIOS-only fan control
- Require specific kernel modules
- Use a different control interface

Try loading common fan control modules:
```bash
sudo modprobe it87
sudo modprobe nct6775
```

Then check again:
```bash
find /sys/class/hwmon -name "pwm*"
```

### Service Fails to Start

Check the service logs:
```bash
sudo journalctl -u fan-controller-bash.service -n 50
```

Common issues:
- **lm-sensors not installed** → Run the installer again
- **No sensors detected** → Run `sudo sensors-detect`
- **No PWM controls** → Your hardware may not support software fan control
- **Permission denied** → Make sure the service is running as root (it should be automatically)

### Test What the Script Detects

Run manually to see detailed detection output:
```bash
sudo ./temp_fan_controller.sh
```

This shows exactly which sensors and fan controls were detected.

##  How It Works

### Detection Phase
1. Scans `/sys/class/hwmon/hwmon*/` directories
2. Finds all `temp*_input` files (temperature sensors)
3. Finds all `pwm*` files with corresponding `pwm*_enable` files
4. Validates write permissions

### Monitoring Loop
1. Reads all temperature sensors every 5 seconds
2. Determines the highest temperature
3. Calculates appropriate fan speed based on thresholds
4. Only updates PWM when speed needs to change (reduces unnecessary writes)

### Fan Control
1. Sets `pwm*_enable` to `1` (manual/PWM mode)
2. Writes PWM value (0-255) to `pwm*` file
3. PWM percentage = (value / 255) × 100

### Cleanup on Exit
1. Catches SIGINT (Ctrl+C) and SIGTERM signals
2. Resets `pwm*_enable` to `2` (automatic mode)
3. Returns fan control to system/BIOS

##  Performance Impact

| Metric | Impact |
|--------|--------|
| Memory Usage | 2-5 MB |
| CPU Usage | <0.1% (sleeps 95% of the time) |
| Disk I/O | Minimal (only sysfs reads) |
| Network | None |

This is negligible even on low-power systems.

##  Why Bash Over Python?

| Feature | Bash | Python |
|---------|------|--------|
| Memory | 2-5 MB | 10-15 MB |
| Startup | Instant | ~100ms |
| Dependencies | None (built-in) | Python 3 interpreter |
| Best For | System daemons | Development/complex logic |

For a simple monitoring daemon, bash is more appropriate and efficient.

##  Security

The systemd service includes hardening options:
- `NoNewPrivileges=true` - Prevents privilege escalation
- `PrivateTmp=true` - Isolated /tmp directory

The script:
- Only reads from `/sys/class/hwmon/`
- Only writes to PWM control files
- No network access
- No arbitrary file system access

## 🗑️ Uninstallation

```bash
# Stop and disable service
sudo systemctl stop fan-controller-bash.service
sudo systemctl disable fan-controller-bash.service

# Remove files
sudo rm /etc/systemd/system/fan-controller-bash.service
sudo rm /usr/local/bin/temp_fan_controller.sh

# Reload systemd
sudo systemctl daemon-reload

# Optionally remove lm-sensors (Arch example)
sudo pacman -Rs lm_sensors
```

##  Contributing

Contributions are welcome! Here are some ideas:

- Individual fan control (different speeds per fan)
- Hysteresis to prevent rapid speed changes
- Configuration file support
- Web interface for monitoring
- Email/notification alerts on high temps
- Support for more exotic hardware
- Better error handling

Feel free to open issues or submit pull requests!

## 📝 License

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software, either in source code form or as a compiled binary, for any purpose, commercial or non-commercial, and by any means.

See https://www.gnu.org/licenses/gpl-3.0.en.html for details.

##  Credits

Originally created for the Corsair AI Workstation 300 mini PC, but designed to work on any Linux system with standard hwmon PWM fan controls.

##  Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Run the script manually with `sudo ./temp_fan_controller.sh` to see detailed output
3. Check logs with `sudo journalctl -u fan-controller-bash.service -n 50`
4. Open an issue on GitHub with:
   - Your distro and kernel version (`uname -a`)
   - Output of `sensors`
   - Output of `ls -la /sys/class/hwmon/*/pwm*`
   - Relevant log snippets

##  Disclaimer

This software comes with no warranty. While it includes safety features (automatic reset to BIOS control on exit, thermal throttling still active), use at your own risk. Monitor your system temperatures when first using this script to ensure it's working as expected for your hardware.

---

**Made with ❤️ for the Linux community**
