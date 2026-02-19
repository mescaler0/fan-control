#!/bin/bash

# Installation script for Automatic Fan Controller (Bash version)
# Works on Arch Linux and Bazzite/Fedora

set -e

echo "=== Corsair AI 300 Fan Controller Installation (Bash Version) ==="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then 
    echo "ERROR: Please run as root (sudo ./install_fan_controller_bash.sh)"
    exit 1
fi

# Detect distribution
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_NAME="$NAME"
    echo "Detected OS: $OS_NAME"
else
    echo "ERROR: Cannot detect OS"
    exit 1
fi

echo

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check and install lm-sensors based on distribution
install_lm_sensors() {
    if command_exists sensors; then
        echo "✓ lm-sensors is already installed"
        return 0
    fi
    
    echo "Installing lm-sensors..."
    
    case "$OS_ID" in
        arch|archlinux|endeavouros|manjaro)
            echo "  Using pacman..."
            pacman -S --noconfirm lm_sensors
            ;;
        
        fedora|bazzite*)
            echo "  Detected Fedora/Bazzite"
            
            # Check if it's an immutable system (Bazzite)
            if [[ -f /run/ostree-booted ]] || command_exists rpm-ostree; then
                echo "  Detected immutable OS (using rpm-ostree)..."
                rpm-ostree install lm_sensors
                
                echo ""
                echo "════════════════════════════════════════════════════════════"
                echo "  IMPORTANT: Bazzite/Fedora Atomic detected!"
                echo "  You need to REBOOT for lm_sensors to be available."
                echo "  After rebooting, run this script again to complete setup."
                echo "════════════════════════════════════════════════════════════"
                echo ""
                read -p "Press ENTER to acknowledge..."
                exit 0
            else
                # Regular Fedora
                echo "  Using dnf..."
                dnf install -y lm_sensors
            fi
            ;;
        
        ubuntu|debian|pop)
            echo "  Using apt..."
            apt-get update
            apt-get install -y lm-sensors
            ;;
        
        opensuse*|sles)
            echo "  Using zypper..."
            zypper install -y sensors
            ;;
        
        *)
            echo "ERROR: Unsupported distribution: $OS_ID"
            echo "Please install lm-sensors manually and run this script again"
            exit 1
            ;;
    esac
    
    echo "✓ lm-sensors installed successfully"
}

# Configure sensors
configure_sensors() {
    echo
    echo "Configuring sensors..."
    
    # Check if sensors are already configured
    if sensors &>/dev/null && [[ $(sensors 2>/dev/null | wc -l) -gt 5 ]]; then
        echo "✓ Sensors appear to be already configured"
        return 0
    fi
    
    # Run sensors-detect automatically
    echo "Running sensors-detect with automatic configuration..."
    
    if command_exists sensors-detect; then
        # Auto-detect and auto-answer YES to all questions
        yes "" | sensors-detect --auto 2>/dev/null || sensors-detect --auto
        echo "✓ Sensors configured"
    else
        echo "WARNING: sensors-detect not found, skipping auto-configuration"
    fi
    
    # Load kernel modules
    if [[ -f /etc/sysconfig/lm_sensors ]]; then
        echo "Loading sensor modules..."
        /usr/bin/sensors-detect --auto 2>/dev/null || true
        systemctl restart lm_sensors.service 2>/dev/null || true
    fi
}

# Test if sensors work
test_sensors() {
    echo
    echo "Testing sensors..."
    
    if command_exists sensors; then
        echo "Available sensors:"
        sensors 2>/dev/null | head -20 || echo "  (No sensor output available yet)"
    fi
    
    echo
    echo "Checking for hwmon devices..."
    if [[ -d /sys/class/hwmon ]]; then
        local count=$(find /sys/class/hwmon -name "temp*_input" 2>/dev/null | wc -l)
        echo "  Found $count temperature sensors in /sys/class/hwmon"
        
        local pwm_count=$(find /sys/class/hwmon -name "pwm[0-9]" -not -name "*_enable" -not -name "*_mode" 2>/dev/null | wc -l)
        echo "  Found $pwm_count PWM fan controls in /sys/class/hwmon"
    else
        echo "  WARNING: /sys/class/hwmon not found!"
    fi
}

# Main installation
main() {
    # Install lm-sensors
    install_lm_sensors
    
    # Configure sensors
    configure_sensors
    
    # Test sensors
    test_sensors
    
    echo
    echo "Installing fan controller script..."
    
    # Copy bash script to system location
    if [[ ! -f temp_fan_controller.sh ]]; then
        echo "ERROR: temp_fan_controller.sh not found in current directory"
        exit 1
    fi
    
    cp temp_fan_controller.sh /usr/local/bin/
    chmod +x /usr/local/bin/temp_fan_controller.sh
    echo "✓ Script installed to /usr/local/bin/temp_fan_controller.sh"
    
    # Copy systemd service file
    if [[ ! -f fan-controller-bash.service ]]; then
        echo "ERROR: fan-controller-bash.service not found in current directory"
        exit 1
    fi
    
    cp fan-controller-bash.service /etc/systemd/system/
    echo "✓ Service file installed to /etc/systemd/system/fan-controller-bash.service"
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable the service
    echo
    echo "Enabling fan controller service..."
    systemctl enable fan-controller-bash.service
    echo "✓ Service enabled (will start on boot)"
    
    echo
    echo "════════════════════════════════════════════════════════════"
    echo "  Installation Complete!"
    echo "════════════════════════════════════════════════════════════"
    echo
    echo "Next steps:"
    echo
    echo "1. Start the service now:"
    echo "   sudo systemctl start fan-controller-bash.service"
    echo
    echo "2. Check if it's working:"
    echo "   sudo systemctl status fan-controller-bash.service"
    echo
    echo "3. View real-time logs:"
    echo "   sudo journalctl -u fan-controller-bash.service -f"
    echo
    echo "4. Test manually before enabling (optional):"
    echo "   sudo /usr/local/bin/temp_fan_controller.sh"
    echo "   (Press Ctrl+C to stop)"
    echo
    echo "Configuration:"
    echo "  Edit thresholds in: /usr/local/bin/temp_fan_controller.sh"
    echo "  After editing, restart: sudo systemctl restart fan-controller-bash.service"
    echo
    echo "Troubleshooting:"
    echo "  View detected sensors: sensors"
    echo "  Check hwmon devices: ls -la /sys/class/hwmon/*/temp*_input"
    echo "  Check PWM controls: ls -la /sys/class/hwmon/*/pwm*"
    echo
}

# Run main installation
main
