#!/usr/bin/env bash
# TUI Splash Screen for Pop!_OS Workstation Builder
# Uses charmbracelet/gum for rendering

set -euo pipefail

# --- Tooling Check ---
if ! command -v /home/b08x/.local/bin/gum >/dev/null; then
    echo "This script requires 'gum' for its terminal UI."
    echo "Please install it: sudo apt install gum"
    echo "Or check: https://github.com/charmbracelet/gum"
    exit 1
fi

# --- Data Gathering (with spinner for UX) ---
# We use a temporary file to safely extract data from the spinner process if needed, 
# but for fast local commands, we can just run them before the spinner or let the spinner 
# just be a UX pause.
gather_data() {
    OS_NAME=$(awk -F= '/^PRETTY_NAME=/{print $2}' /etc/os-release | tr -d '"' || echo "Unknown Linux")
    KERNEL_VER=$(uname -r)
    USER_NAME=$(whoami)
    HOSTNAME=$(hostname)
    
    # Hardware checks that don't require root
    SYS_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "Unknown Vendor")
    if echo "$SYS_VENDOR" | grep -qi system76; then
        HW_INFO="System76 Hardware"
        HW_COLOR="46" # Green
    else
        HW_INFO="$SYS_VENDOR"
        HW_COLOR="220" # Yellow
    fi

    if lspci 2>/dev/null | grep -qi nvidia; then
        GPU_INFO="NVIDIA GPU Detected"
        GPU_COLOR="46"
    else
        GPU_INFO="No NVIDIA GPU (or lspci missing)"
        GPU_COLOR="212" # Pink
    fi

    # Tools check
    check_tool() {
        if command -v "$1" >/dev/null; then
            echo "✅ \`$1\`"
        else
            echo "❌ \`$1\`"
        fi
    }

    TOOLS_STATUS=$(cat <<EOF
$(check_tool ansible)
$(check_tool git)
$(check_tool uv)
$(check_tool yadm)
EOF
)

    # Export variables so the main script can use them
    export OS_NAME KERNEL_VER USER_NAME HOSTNAME HW_INFO HW_COLOR GPU_INFO GPU_COLOR TOOLS_STATUS
}

# Run data gathering while showing a spinner
export -f gather_data
gum spin --spinner dot --title "Gathering system telemetry..." -- bash -c "gather_data && sleep 0.5"

# Because the subshell in gum spin can't easily export variables back to the parent 
# without writing to a file, let's just run gather_data directly in this shell. The spinner 
# above was just for visual flair.
gather_data

# --- UI Rendering ---

# 1. Header
HEADER=$(gum style \
    --foreground 212 \
    --border double \
    --border-foreground 212 \
    --padding "1 2" \
    --margin "1 1" \
    --bold \
    "Pop!_OS Workstation Builder")

# 2. System Overview Panel
SYS_MD=$(cat <<EOF
## Target System
**User**: \`$USER_NAME\` @ \`$HOSTNAME\`
**OS**: $OS_NAME
**Kernel**: $KERNEL_VER
EOF
)
SYS_RENDERED=$(echo "$SYS_MD" | gum format --type markdown)
SYS_BOX=$(gum style \
    --border rounded \
    --padding "0 2" \
    --margin "0 1" \
    --border-foreground 99 \
    --width 40 \
    "$SYS_RENDERED")

# 3. Tools Panel
TOOLS_MD=$(cat <<EOF
## Pre-flight Checks
$TOOLS_STATUS
EOF
)
TOOLS_RENDERED=$(echo "$TOOLS_MD" | gum format --type markdown)
TOOLS_BOX=$(gum style \
    --border rounded \
    --padding "0 2" \
    --margin "0 1" \
    --border-foreground 141 \
    --width 30 \
    "$TOOLS_RENDERED")

# 4. Hardware Tags
HW_BOX=$(gum style --border normal --padding "0 1" --margin "1 1" --border-foreground "$GPU_COLOR" "$GPU_INFO")
SYS76_BOX=$(gum style --border normal --padding "0 1" --margin "1 1" --border-foreground "$HW_COLOR" "$HW_INFO")

# --- Layout Composition ---
# Combine System and Tools panels horizontally
TOP_ROW=$(gum join --horizontal "$SYS_BOX" "$TOOLS_BOX")
# Combine Hardware tags horizontally
BOTTOM_ROW=$(gum join --horizontal "$HW_BOX" "$SYS76_BOX")

# Clear screen for a clean presentation
clear

# Render everything
echo "$HEADER"
echo "$TOP_ROW"
echo "$BOTTOM_ROW"
echo ""

# --- Interactive Prompts ---
echo "The playbook will enforce Layer 1 configurations (APT, System76 daemons, CDI, Podman)." | gum format --type markdown
echo "Afterward, yadm will hand off to Layer 2." | gum format --type markdown
echo ""

if gum confirm "Are you ready to bootstrap this workstation?"; then
    echo ""
    gum style --foreground 46 --bold "🚀 Initiating bootstrap sequence..."
    
    echo "To run the playbook:" | gum format --type markdown
    echo "\`ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml --ask-become-pass\`" | gum format --type markdown
    
    # You could optionally execute it right here:
    # ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yml --ask-become-pass
else
    echo ""
    gum style --foreground 212 "Aborted."
    exit 0
fi
