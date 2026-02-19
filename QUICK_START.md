# Quick Start Guide - Bash Fan Controller

## Installation (One Command)

```bash
cd corsair-ai300-fan-controller-bash
sudo ./install_fan_controller_bash.sh
```

That's it! The installer will:
- ✓ Detect your OS (Arch or Fedora/Bazzite)
- ✓ Install lm-sensors with the correct package manager
- ✓ Configure sensors automatically
- ✓ Install the fan controller
- ✓ Enable auto-start on boot

## Start It Now

```bash
sudo systemctl start fan-controller-bash.service
```

## Check if It's Working

```bash
sudo journalctl -u fan-controller-bash.service -f
```

You should see output like:
```
Temperature: 45°C -> Setting fan speed to 30%
Temperature: 62°C -> Setting fan speed to 50%
Temperature: 71°C -> Setting fan speed to 75%
```

## Customize Thresholds

Edit the top of the script:
```bash
sudo nano /usr/local/bin/temp_fan_controller.sh
```

Change these values:
```bash
TEMP_LOW=50         # Your preferred low threshold
TEMP_MEDIUM=65      # Your preferred medium threshold
TEMP_HIGH=75        # Your preferred high threshold
TEMP_CRITICAL=85    # Your preferred critical threshold
```

Then restart:
```bash
sudo systemctl restart fan-controller-bash.service
```

## Bazzite Users

On Bazzite, after the first run:
1. The installer will install lm-sensors
2. **You must reboot**
3. Run the installer again after reboot

This is normal for immutable systems.

## Test Without Installing

Want to test first?
```bash
sudo ./temp_fan_controller.sh
```

Press Ctrl+C when done. It will reset fans to automatic mode.

---

For full documentation, see README_BASH.md
