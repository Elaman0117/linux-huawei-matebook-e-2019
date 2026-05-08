#!/bin/bash
# ============================================================================
# generate-config.sh — Generate kernel .config for HUAWEI MateBook E 2019
# ============================================================================
# This script generates a proper kernel configuration by:
#   1. Starting from qcom_defconfig (or defconfig) as base
#   2. Applying MateBook E 2019-specific config fragment
#   3. Running olddefconfig to resolve dependencies
#
# Usage:
#   ./scripts/generate-config.sh [kernel-source-dir]
#
# If kernel-source-dir is not provided, looks for linux-src/ in current dir.
# ============================================================================

set -euo pipefail

KERNEL_SRC="${1:-linux-src}"
ARCH="arm64"
CONFIG_FRAG="${KERNEL_SRC}/.config-fragment"

echo "=== Generating kernel config for HUAWEI MateBook E 2019 ==="
echo "Kernel source: $KERNEL_SRC"

if [ ! -d "$KERNEL_SRC" ]; then
  echo "ERROR: Kernel source directory not found: $KERNEL_SRC"
  exit 1
fi

cd "$KERNEL_SRC"

# Step 1: Start from base defconfig
if [ -f "arch/${ARCH}/configs/qcom_defconfig" ]; then
  echo "Using qcom_defconfig as base"
  make ARCH="$ARCH" qcom_defconfig
elif [ -f "arch/${ARCH}/configs/defconfig" ]; then
  echo "Using defconfig as base"
  make ARCH="$ARCH" defconfig
else
  echo "ERROR: No defconfig found"
  exit 1
fi

# Step 2: Create config fragment for MateBook E 2019
cat > "$CONFIG_FRAG" << 'EOF'
# HUAWEI MateBook E 2019 (SDM850/SDM845) specific options

# Platform
CONFIG_ARCH_QCOM=y
CONFIG_SOC_QCOM=y

# Type-C / USB PD
CONFIG_TYPEC=y
CONFIG_TYPEC_UCSI=y
CONFIG_UCSI_ACK_ECI=y

# Huawei Planck EC Driver
CONFIG_HUAWEI_PLANCK_EC=y

# QSEECOM (sensor support)
CONFIG_QCOM_QSEECOM=y
CONFIG_QCOM_QSEECOM_UEFI=y

# HID / Input
CONFIG_HID=y
CONFIG_HID_MULTITOUCH=y
CONFIG_I2C_HID=y
CONFIG_I2C_HID_OF=y
CONFIG_INPUT_TOUCHSCREEN=y
CONFIG_TOUCHSCREEN_GOODIX=y

# WiFi (ath10k)
CONFIG_ATH10K=y
CONFIG_ATH10K_PCI=y
CONFIG_ATH10K_SNOC=y

# Bluetooth
CONFIG_BT=y
CONFIG_BT_HCIUART=y
CONFIG_BT_HCIUART_QCA=y

# GPU (freedreno/msm)
CONFIG_DRM_MSM=y
CONFIG_DRM_PANEL_EDP=y

# Audio (qcom/sdm845)
CONFIG_SND_SOC=y
CONFIG_SND_SOC_QCOM=y
CONFIG_SND_SOC_SDM845=y

# UFS Storage
CONFIG_SCSI_UFS_QCOM=y

# Display
CONFIG_DRM_PANEL=y

# Camera
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_V4L_PLATFORM_DRIVERS=y
CONFIG_VIDEO_QCOM_CAMSS=y

# Power / Battery
CONFIG_CHARGER_QCOM_SMBB=y
CONFIG_POWER_SUPPLY=y
CONFIG_BATTERY_QCOM_BATTMGR=y

# Firmware
CONFIG_FW_LOADER=y
CONFIG_EXTRA_FIRMWARE_DIR="/lib/firmware"

# initramfs
CONFIG_BLK_DEV_INITRD=y

# Module Support
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MODVERSIONS=y

# Module Signing
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_ALL=n
CONFIG_MODULE_SIG_FORCE=n
EOF

# Step 3: Merge fragment into .config
echo "Merging config fragment..."
scripts/kconfig/merge_config.sh -m .config "$CONFIG_FRAG"

# Step 4: Resolve dependencies
echo "Resolving config dependencies..."
make ARCH="$ARCH" olddefconfig

# Step 5: Verify critical options
echo ""
echo "=== Critical config verification ==="
CRITICAL_OPTS=(
  "CONFIG_ARCH_QCOM"
  "CONFIG_DRM_MSM"
  "CONFIG_TYPEC_UCSI"
  "CONFIG_SCSI_UFS_QCOM"
  "CONFIG_ATH10K"
  "CONFIG_BT_HCIUART_QCA"
  "CONFIG_MODULES"
)

ALL_OK=true
for opt in "${CRITICAL_OPTS[@]}"; do
  val=$(grep "^${opt}=" .config 2>/dev/null || echo "NOT SET")
  if [[ "$val" == *"=y" ]]; then
    echo "  [OK] $opt"
  else
    echo "  [!!] $opt = $val"
    ALL_OK=false
  fi
done

if [ "$ALL_OK" = true ]; then
  echo ""
  echo "All critical options are set correctly!"
else
  echo ""
  echo "WARNING: Some critical options are not set as expected."
  echo "This may indicate a dependency issue or config change."
fi

echo ""
echo "Config saved to: $KERNEL_SRC/.config"
echo "Done!"
