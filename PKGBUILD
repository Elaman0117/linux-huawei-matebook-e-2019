# ============================================================================
# PKGBUILD — Reference build script for local builds on Arch Linux ARM
# ============================================================================
# NOTE: This PKGBUILD is for LOCAL builds on an Arch Linux ARM system.
# The GitHub Actions CI uses its own build process (build-kernel.yml).
# This file serves as documentation and for developers who want to
# build locally using makepkg.
#
# Only stable SDM845 tags are used (no -rc tags).
# ============================================================================

# Maintainer: Your Name <your@email.com>
pkgbase=linux-huawei-matebook-e-2019
pkgname=("${pkgbase}")
_desc="HUAWEI MateBook E 2019 (SDM850/SDM845)"
pkgver=6.18.2
pkgrel=1
arch=('aarch64')
url="https://gitlab.com/sdm845-mainline/linux"
license=('GPL-2.0-only')
makedepends=(
  'bc'
  'bison'
  'dtc'
  'flex'
  'git'
  'kmod'
  'libelf'
  'openssl'
  'python'
  'uboot-tools'
  'xmlto'
)
options=('!strip')
source=(
  "linux-src::git+https://gitlab.com/sdm845-mainline/linux.git#tag=sdm845-6.18.2-r0"
  'config'
  'linux.preset'
)
sha256sums=(
  'SKIP'  # Kernel source - verified by git tag
  'SKIP'  # Config file
  'SKIP'  # Preset file
)

# New-Wheat patches (applied in prepare())
_new_wheat_repo="https://github.com/New-Wheat/Linux-for-HUAWEI-MateBook-E-2019.git"
_new_wheat_patches=(
  "2-8-usb-typec-ucsi-add-recipient-arg-to-update_altmodes-callback.patch"
  "huawei_planck_devicetree.patch"
  "huawei_planck_ec.patch"
  "huawei_planck_qseecom.patch"
  "camera_sensors_and_actuator.patch"
)

_kernelname=${pkgbase#linux}
_localversion="-huawei-matebook-e-2019"

prepare() {
  cd "${srcdir}/linux-src"

  # Clone New-Wheat patches
  if [ ! -d "${srcdir}/new-wheat" ]; then
    git clone --depth 1 "${_new_wheat_repo}" "${srcdir}/new-wheat"
  fi

  local PATCH_DIR="${srcdir}/new-wheat/patches"

  # Apply patches in order
  for patch_file in "${_new_wheat_patches[@]}"; do
    msg2 "Applying ${patch_file}..."
    if [ ! -f "${PATCH_DIR}/${patch_file}" ]; then
      error "Patch not found: ${PATCH_DIR}/${patch_file}"
      return 1
    fi

    # Try git am first, fall back to patch
    if ! git am --whitespace=nowarn "${PATCH_DIR}/${patch_file}" 2>/dev/null; then
      git am --abort 2>/dev/null || true
      patch -p1 --no-backup-if-mismatch -i "${PATCH_DIR}/${patch_file}"
    fi
  done

  # Apply config
  msg2 "Applying kernel config..."
  cp "${srcdir}/config" .config
  make ARCH=arm64 olddefconfig
}

build() {
  cd "${srcdir}/linux-src"
  make ARCH=arm64 -j"$(nproc)" \
    LOCALVERSION="${_localversion}" \
    Image Image.gz modules \
    qcom/sdm850-huawei-matebook-e-2019.dtb
}

_package() {
  pkgdesc="The ${_desc} kernel and modules based on SDM845 mainline"
  depends=('coreutils' 'kmod' 'mkinitcpio>=0.7')
  optdepends=(
    'linux-firmware: firmware images needed for some devices'
    'wireless-regdb: to set the correct wireless channels of your country'
    'uboot-tools: for U-Boot bootloader'
  )
  provides=("linux=${pkgver}" 'KSMBD-MODULE' 'WIREGUARD-MODULE')
  conflicts=('linux' 'linux-aarch64')
  backup=("etc/mkinitcpio.d/${pkgbase}.preset")
  install="${pkgbase}.install"

  cd "${srcdir}/linux-src"
  local _kernver="$(make ARCH=arm64 kernelrelease)"

  # Install modules (Arch Linux ARM convention: /usr/lib/modules)
  make ARCH=arm64 \
    INSTALL_MOD_PATH="${pkgdir}/usr" \
    INSTALL_MOD_STRIP=1 \
    modules_install

  # Install boot images (match linux-aarch64 layout)
  install -Dm644 arch/arm64/boot/Image "${pkgdir}/boot/Image"
  install -Dm644 arch/arm64/boot/Image.gz "${pkgdir}/boot/Image.gz"

  # Install device tree blob
  install -Dm644 arch/arm64/boot/dts/qcom/sdm850-huawei-matebook-e-2019.dtb \
    "${pkgdir}/boot/dtbs/qcom/sdm850-huawei-matebook-e-2019.dtb" 2>/dev/null || true

  # Trigger mkinitcpio hook on install/upgrade (matches linux-aarch64)
  install -d "${pkgdir}/usr/lib/initcpio/"
  echo "dummy file to trigger mkinitcpio to run" > "${pkgdir}/usr/lib/initcpio/${_kernver}"

  # Install mkinitcpio preset
  install -Dm644 "${srcdir}/linux.preset" "${pkgdir}/etc/mkinitcpio.d/${pkgbase}.preset"
  sed -i -e "s|%PKGBASE%|${pkgbase}|g" -e "s|%KERNVER%|${_kernver}|g" \
    "${pkgdir}/etc/mkinitcpio.d/${pkgbase}.preset"

  # Remove build and source symlinks (should not ship in the runtime kernel package)
  rm -f "${pkgdir}/usr/lib/modules/${_kernver}/build"
  rm -f "${pkgdir}/usr/lib/modules/${_kernver}/source"
}
