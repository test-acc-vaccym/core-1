#!/usr/bin/env bash

aosp_pre_build() {
  log_header "${FUNCNAME[0]}"

  patch_updater
  patch_launcher
  patch_disable_apex
  patch_device_config
}

patch_updater() {
  log_header "${FUNCNAME[0]}"

  cd "${AOSP_BUILD_DIR}/packages/apps/Updater/res/values"
  sed --in-place --expression "s@s3bucket@${RELEASE_URL}/@g" config.xml

  # selinux changes required to support updater in 11.0
  if ! grep -q "vendor/rattlesnakeos/vendor/sepolicy/common/sepolicy.mk" "${AOSP_BUILD_DIR}/build/core/config.mk"; then
    sed -i '/product-graph dump-products/a #add selinux policies last\n$(eval include vendor/rattlesnakeos/vendor/sepolicy/common/sepolicy.mk)' "${AOSP_BUILD_DIR}/build/core/config.mk"
  fi
}

patch_launcher() {
  log_header "${FUNCNAME[0]}"

  # disable QuickSearchBox widget on home screen
  sed -i "s/QSB_ON_FIRST_SCREEN = true;/QSB_ON_FIRST_SCREEN = false;/" "${AOSP_BUILD_DIR}/packages/apps/Launcher3/src/com/android/launcher3/config/FeatureFlags.java"
}

# currently don't have a need for apex updates (https://source.android.com/devices/tech/ota/apex)
patch_disable_apex() {
  log_header "${FUNCNAME[0]}"

  sed -i 's@$(call inherit-product, $(SRC_TARGET_DIR)/product/updatable_apex.mk)@@' "${AOSP_BUILD_DIR}/build/make/target/product/mainline_system.mk"
}

_patch_product_makefile() {
  local codename="${1}"
  local product_model="${2}"
  local product_makefile="${3}"
  sed -i "s@PRODUCT_MODEL := AOSP on ${codename}@PRODUCT_MODEL := ${product_model}@" "${product_makefile}" || true
  if ! grep -q "vendor/rattlesnakeos/vendor/config/main.mk" "${product_makefile}"; then
    sed -i '/vendor\/google_devices\/crosshatch\/proprietary\/device-vendor.mk)/a \$(call inherit-product, vendor\/rattlesnakeos\/vendor\/config\/main.mk)' "${product_makefile}" || true
  fi
  if ! grep -q "^PRODUCT_RESTRICT_VENDOR_FILES" "${product_makefile}"; then
    echo "PRODUCT_RESTRICT_VENDOR_FILES := false" >> "${product_makefile}" || true
  fi
}

patch_device_config() {
  log_header "${FUNCNAME[0]}"

  _patch_product_makefile "${DEVICE}" "${DEVICE_FRIENDLY}" "${AOSP_BUILD_DIR}/device/google/${DEVICE_FAMILY}/aosp_${DEVICE}.mk"
}