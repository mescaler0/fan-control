#!/bin/bash

# Automatic Fan Controller based on Temperature Thresholds
# Monitors system temperatures and adjusts fan speeds accordingly


# Monitor temps without script
#watch -n 1 sensors

# Or more detailed
#watch -n 1 'sensors; echo "---"; cat /sys/class/hwmon/hwmon*/temp*_input'

# On Arch:
#sudo pacman -S stress
#stress --cpu 8 --timeout 60s

# On Bazzite:
#rpm-ostree install stress-ng
#stress-ng --cpu 8 --timeout 60s


# Configuration - Edit these values to customize behavior
TEMP_LOW=50         # Below 50°C - minimum fan speed
TEMP_MEDIUM=65      # 50-65°C - medium fan speed
TEMP_HIGH=75        # 65-75°C - high fan speed
TEMP_CRITICAL=85    # Above 85°C - maximum fan speed

FAN_SPEED_LOW=30        # 30% fan speed (PWM value: 77/255)
FAN_SPEED_MEDIUM=50     # 50% fan speed (PWM value: 128/255)
FAN_SPEED_HIGH=75       # 75% fan speed (PWM value: 191/255)
FAN_SPEED_CRITICAL=100  # 100% fan speed (PWM value: 255/255)

CHECK_INTERVAL=5    # Check every 5 seconds

# Arrays to store sensor and fan paths
declare -a TEMP_SENSORS
declare -a FAN_PWMS
declare -a FAN_ENABLES

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Convert percentage to PWM value (0-255)
percent_to_pwm() {
    local percent=$1
    echo $(( percent * 255 / 100 ))
}

# Detect temperature sensors
detect_temp_sensors() {
    local hwmon_base="/sys/class/hwmon"
    local count=0
    
    if [[ ! -d "$hwmon_base" ]]; then
        log "ERROR: $hwmon_base not found. Is lm-sensors installed?"
        return 1
    fi
    
    log "Detecting temperature sensors..."
    
    for hwmon_dir in "$hwmon_base"/hwmon*; do
        if [[ -f "$hwmon_dir/name" ]]; then
            local device_name=$(cat "$hwmon_dir/name")
            
            # Find all temperature input files
            for temp_input in "$hwmon_dir"/temp*_input; do
                if [[ -f "$temp_input" ]]; then
                    TEMP_SENSORS+=("$temp_input")
                    local sensor_label=""
                    local label_file="${temp_input%_input}_label"
                    if [[ -f "$label_file" ]]; then
                        sensor_label=" ($(cat "$label_file"))"
                    fi
                    log "  Found: $device_name - $(basename "$temp_input")$sensor_label"
                    ((count++))
                fi
            done
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log "WARNING: No temperature sensors found!"
        return 1
    fi
    
    log "Detected $count temperature sensor(s)"
    return 0
}

# Detect fan PWM controls
detect_fan_controls() {
    local hwmon_base="/sys/class/hwmon"
    local count=0
    
    log "Detecting fan PWM controls..."
    
    for hwmon_dir in "$hwmon_base"/hwmon*; do
        if [[ -f "$hwmon_dir/name" ]]; then
            local device_name=$(cat "$hwmon_dir/name")
            
            # Find all PWM files
            for pwm_file in "$hwmon_dir"/pwm[0-9]*; do
                # Skip if it's a pwm*_enable file
                if [[ "$pwm_file" == *"_enable" ]] || [[ "$pwm_file" == *"_mode" ]]; then
                    continue
                fi
                
                if [[ -f "$pwm_file" && -w "$pwm_file" ]]; then
                    local pwm_enable="${pwm_file}_enable"
                    
                    # Check if enable file exists and is writable
                    if [[ -f "$pwm_enable" && -w "$pwm_enable" ]]; then
                        FAN_PWMS+=("$pwm_file")
                        FAN_ENABLES+=("$pwm_enable")
                        log "  Found: $device_name - $(basename "$pwm_file")"
                        ((count++))
                    fi
                fi
            done
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log "WARNING: No PWM fan controls found!"
        log "Your system may not support software fan control via sysfs."
        return 1
    fi
    
    log "Detected $count fan control(s)"
    return 0
}

# Get maximum temperature from all sensors
get_max_temperature() {
    local max_temp=0
    local temp
    
    for sensor in "${TEMP_SENSORS[@]}"; do
        if [[ -f "$sensor" ]]; then
            # Temperature is in millidegrees Celsius
            temp=$(cat "$sensor" 2>/dev/null)
            if [[ $? -eq 0 && -n "$temp" ]]; then
                # Convert to degrees Celsius
                temp=$((temp / 1000))
                if [[ $temp -gt $max_temp ]]; then
                    max_temp=$temp
                fi
            fi
        fi
    done
    
    echo "$max_temp"
}

# Determine appropriate fan speed based on temperature
determine_fan_speed() {
    local temp=$1
    
    if [[ $temp -ge $TEMP_CRITICAL ]]; then
        echo "$FAN_SPEED_CRITICAL"
    elif [[ $temp -ge $TEMP_HIGH ]]; then
        echo "$FAN_SPEED_HIGH"
    elif [[ $temp -ge $TEMP_MEDIUM ]]; then
        echo "$FAN_SPEED_MEDIUM"
    else
        echo "$FAN_SPEED_LOW"
    fi
}

# Set fan speed (percentage)
set_fan_speed() {
    local speed_percent=$1
    local pwm_value=$(percent_to_pwm "$speed_percent")
    local success=0
    
    for i in "${!FAN_PWMS[@]}"; do
        local pwm_file="${FAN_PWMS[$i]}"
        local enable_file="${FAN_ENABLES[$i]}"
        
        # Set to manual mode (1 = manual/PWM mode)
        if echo "1" > "$enable_file" 2>/dev/null; then
            # Set PWM value
            if echo "$pwm_value" > "$pwm_file" 2>/dev/null; then
                success=1
            else
                log "ERROR: Could not write to $pwm_file"
            fi
        else
            log "ERROR: Could not write to $enable_file"
        fi
    done
    
    return $((1 - success))
}

# Reset fans to automatic mode
reset_fans() {
    log "Resetting fans to automatic mode..."
    
    for enable_file in "${FAN_ENABLES[@]}"; do
        # 2 = automatic mode (may vary by hardware)
        echo "2" > "$enable_file" 2>/dev/null || echo "0" > "$enable_file" 2>/dev/null
    done
}

# Cleanup function
cleanup() {
    log ""
    log "Shutting down fan controller..."
    reset_fans
    log "Fan control returned to automatic mode"
    exit 0
}

# Main function
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root (sudo)"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    # Set up signal handlers
    trap cleanup SIGINT SIGTERM
    
    log "=== Starting Automatic Fan Controller ==="
    log "Temperature thresholds:"
    log "  Low:      < ${TEMP_LOW}°C    -> ${FAN_SPEED_LOW}% fan speed"
    log "  Medium:   ${TEMP_LOW}-${TEMP_MEDIUM}°C  -> ${FAN_SPEED_MEDIUM}% fan speed"
    log "  High:     ${TEMP_MEDIUM}-${TEMP_HIGH}°C  -> ${FAN_SPEED_HIGH}% fan speed"
    log "  Critical: > ${TEMP_CRITICAL}°C    -> ${FAN_SPEED_CRITICAL}% fan speed"
    log "Check interval: ${CHECK_INTERVAL} seconds"
    log ""
    
    # Detect sensors and fan controls
    if ! detect_temp_sensors; then
        log "ERROR: Could not detect temperature sensors. Exiting."
        exit 1
    fi
    
    log ""
    
    if ! detect_fan_controls; then
        log "ERROR: Could not detect fan controls. Exiting."
        exit 1
    fi
    
    log ""
    log "Starting monitoring loop..."
    log ""
    
    local current_speed=""
    
    # Main control loop
    while true; do
        local max_temp=$(get_max_temperature)
        local target_speed=$(determine_fan_speed "$max_temp")
        
        # Only update if speed needs to change
        if [[ "$target_speed" != "$current_speed" ]]; then
            log "Temperature: ${max_temp}°C -> Setting fan speed to ${target_speed}%"
            
            if set_fan_speed "$target_speed"; then
                current_speed="$target_speed"
            else
                log "Failed to set fan speed!"
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main
