#!/bin/bash
# ============================================================================
# package-arch.sh — Create an Arch Linux .pkg.tar.zst package manually
# ============================================================================
# This script creates a proper Arch Linux ARM package from a staged kernel
# installation directory. It generates .PKGINFO, .MTREE, .BUILDINFO and
# packs everything into a .pkg.tar.zst file.
#
# Usage:
#   ./scripts/package-arch.sh \
#     --staging-dir /tmp/kernel-staging \
#     --pkgname linux-huawei-matebook-e-2019 \
#     --pkgver 7.1rc1 \
#     --pkgrel 1 \
#     --kernel-ver 7.1.0-rc1-huawei-matebook-e-2019 \
#     --output-dir /tmp
# ============================================================================

set -euo pipefail

# Default values
STAGING_DIR=""
PKGNAME="linux-huawei-matebook-e-2019"
PKGVER=""
PKGREL="1"
KERNEL_VER=""
OUTPUT_DIR="."

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --staging-dir) STAGING_DIR="$2"; shift 2 ;;
    --pkgname) PKGNAME="$2"; shift 2 ;;
    --pkgver) PKGVER="$2"; shift 2 ;;
    --pkgrel) PKGREL="$2"; shift 2 ;;
    --kernel-ver) KERNEL_VER="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "  --staging-dir DIR   Directory with staged kernel installation"
      echo "  --pkgname NAME      Package name (default: linux-huawei-matebook-e-2019)"
      echo "  --pkgver VERSION    Package version"
      echo "  --pkgrel NUM        Package release number (default: 1)"
      echo "  --kernel-ver VER    Full kernel version string"
      echo "  --output-dir DIR    Output directory for the package file"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate required arguments
if [ -z "$STAGING_DIR" ]; then echo "ERROR: --staging-dir is required"; exit 1; fi
if [ -z "$PKGVER" ]; then echo "ERROR: --pkgver is required"; exit 1; fi
if [ -z "$KERNEL_VER" ]; then echo "ERROR: --kernel-ver is required"; exit 1; fi

echo "=== Creating Arch Linux Package ==="
echo "Package: $PKGNAME $PKGVER-$PKGREL"
echo "Kernel:  $KERNEL_VER"
echo "Staging: $STAGING_DIR"

# Prepare package directory
PKGDIR=$(mktemp -d)
trap "rm -rf '$PKGDIR'" EXIT

cp -a "$STAGING_DIR/." "$PKGDIR/"

# Create /boot/vmlinuz symlink
if [ -f "$PKGDIR/boot/vmlinuz-$KERNEL_VER" ]; then
  ln -sf "vmlinuz-$KERNEL_VER" "$PKGDIR/boot/vmlinuz-$PKGNAME"
fi

# Create mkinitcpio preset
mkdir -p "$PKGDIR/etc/mkinitcpio.d"
cat > "$PKGDIR/etc/mkinitcpio.d/$PKGNAME.preset" << PRESET
# mkinitcpio preset file for '$PKGNAME'
ALL_kver="$KERNEL_VER"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-$PKGNAME.img"
default_options="-S autodetect"

fallback_image="/boot/initramfs-$PKGNAME-fallback.img"
fallback_options="-S autodetect"
PRESET

# Create .INSTALL script
cat > "$PKGDIR/.INSTALL" << INSTALL
post_install() {
  echo "Updating initramfs for $PKGNAME..."
  if command -v mkinitcpio &>/dev/null; then
    mkinitcpio -p $PKGNAME
  fi
  echo ""
  echo "IMPORTANT: Update your bootloader configuration."
  echo "  vmlinuz:  /boot/vmlinuz-$PKGNAME"
  echo "  initramfs: /boot/initramfs-$PKGNAME.img"
  echo "  dtb:      /boot/dtbs/$KERNEL_VER/qcom/sdm850-huawei-matebook-e-2019.dtb"
}

post_upgrade() {
  post_install
}

pre_remove() {
  rm -f /boot/initramfs-$PKGNAME.img
  rm -f /boot/initramfs-$PKGNAME-fallback.img
}
INSTALL

# Create .PKGINFO
TOTAL_SIZE=$(du -sb "$PKGDIR" | cut -f1)
cat > "$PKGDIR/.PKGINFO" << PKGINFO
pkgname = $PKGNAME
pkgver = $PKGVER-$PKGREL
pkgdesc = Linux kernel for HUAWEI MateBook E 2019 (SDM850/SDM845) based on SDM845 mainline
url = https://gitlab.com/sdm845-mainline/linux
builddate = $(date +%s)
packager = Arch Linux ARM Kernel Builder
size = $TOTAL_SIZE
arch = aarch64
license = GPL-2.0-only
depends = coreutils kmod initramfs
optdepends = uboot-tools: for U-Boot bootloader
provides = linux=$PKGVER
conflicts = linux-aarch64
backup = etc/mkinitcpio.d/$PKGNAME.preset
PKGINFO

# Create .BUILDINFO
cat > "$PKGDIR/.BUILDINFO" << BUILDINFO
format = 2
pkgname = $PKGNAME
pkgbase = $PKGNAME
pkgver = $PKGVER-$PKGREL
pkgarch = aarch64
pkgbuild_sha256sum = unknown
packager = Arch Linux ARM Kernel Builder
builddate = $(date +%s)
builddir = /tmp/kernel-build
buildenv = custom
options = !strip
BUILDINFO

# Generate .MTREE
echo "Generating .MTREE..."
cd "$PKGDIR"

# Use bsdtar for MTREE generation if available
if command -v bsdtar &>/dev/null; then
  bsdtar -czf .MTREE --format=mtree \
    --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256' \
    . 2>/dev/null || echo "Warning: bsdtar MTREE generation failed, creating basic MTREE"
fi

# Fallback: create basic .MTREE if bsdtar failed
if [ ! -f .MTREE ] || [ ! -s .MTREE ]; then
  {
    echo "#mtree"
    find . -not -name '.MTREE' | sort | while read -r f; do
      if [ -f "$f" ]; then
        mode=$(stat -c '%a' "$f" 2>/dev/null || echo '644')
        size=$(stat -c '%s' "$f" 2>/dev/null || echo '0')
        md5=$(md5sum "$f" 2>/dev/null | cut -d' ' -f1 || echo '0')
        echo "./${f#./} type=file mode=$mode size=$size md5digest=$md5"
      elif [ -d "$f" ]; then
        mode=$(stat -c '%a' "$f" 2>/dev/null || echo '755')
        echo "./${f#./} type=dir mode=$mode"
      fi
    done
  } | gzip > .MTREE
fi

# Create the final .pkg.tar.zst package
PACKAGE_FILE="${PKGNAME}-${PKGVER}-${PKGREL}-aarch64.pkg.tar.zst"
echo "Creating package: $PACKAGE_FILE"

cd "$PKGDIR"
bsdtar -cf - . | zstd -T0 -18 -o "$OUTPUT_DIR/$PACKAGE_FILE"

echo ""
echo "=== Package created successfully ==="
ls -lh "$OUTPUT_DIR/$PACKAGE_FILE"
echo "Done!"
