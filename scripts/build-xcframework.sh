#!/bin/bash
#
# Builds distributable XCFrameworks for every public product of the package.
#
#   ./scripts/build-xcframework.sh [output-dir]
#
# Produces PaspoIDWire.xcframework, PaspoID.xcframework and PaspoIDUI.xcframework with device
# and simulator slices, plus a zip and its SwiftPM checksum for attaching to a release.
#
# SwiftPM archives a library product as `<product>.framework` without the Swift module inside,
# so each slice is post-processed: the bundle is renamed from the `-Dynamic` product name to
# the module name and the generated `.swiftmodule` is copied into `Modules/`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-$PACKAGE_ROOT/build/xcframeworks}"
WORK_DIR="$PACKAGE_ROOT/build/work"
DERIVED_DATA="$PACKAGE_ROOT/build/DerivedData"
MODULES=(PaspoIDWire PaspoID PaspoIDUI)

rm -rf "$WORK_DIR" "$OUTPUT_DIR" "$DERIVED_DATA"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

# $1 module, $2 destination, $3 slice name (matches the build products directory suffix)
build_slice() {
  local module="$1" destination="$2" slice="$3"
  local archive="$WORK_DIR/$module-$slice.xcarchive"

  xcodebuild archive \
    -scheme "$module-Dynamic" \
    -destination "$destination" \
    -archivePath "$archive" \
    -derivedDataPath "$DERIVED_DATA" \
    -configuration Release \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    >"$WORK_DIR/$module-$slice.log" 2>&1 ||
    { echo "Archive failed, see $WORK_DIR/$module-$slice.log"; exit 1; }

  local built="$archive/Products/usr/local/lib/$module-Dynamic.framework"
  local framework="$WORK_DIR/$slice/$module.framework"
  mkdir -p "$(dirname "$framework")"
  rm -rf "$framework"
  cp -R "$built" "$framework"

  # The bundle is named after the product; consumers expect the module name.
  mv "$framework/$module-Dynamic" "$framework/$module"
  rm -rf "$framework/_CodeSignature"
  plutil -replace CFBundleExecutable -string "$module" "$framework/Info.plist"
  plutil -replace CFBundleName -string "$module" "$framework/Info.plist"

  local swiftmodule
  swiftmodule="$(find "$DERIVED_DATA" -type d -name "$module.swiftmodule" -path "*BuildProductsPath*$slice*" | head -1)"
  [ -n "$swiftmodule" ] || { echo "No $module.swiftmodule for $slice"; exit 1; }
  mkdir -p "$framework/Modules"
  cp -R "$swiftmodule" "$framework/Modules/"
}

for module in "${MODULES[@]}"; do
  echo "==> Building $module"
  build_slice "$module" "generic/platform=iOS" "iphoneos"
  build_slice "$module" "generic/platform=iOS Simulator" "iphonesimulator"

  echo "==> Assembling $module.xcframework"
  xcodebuild -create-xcframework \
    -framework "$WORK_DIR/iphoneos/$module.framework" \
    -framework "$WORK_DIR/iphonesimulator/$module.framework" \
    -output "$OUTPUT_DIR/$module.xcframework" >/dev/null
done

echo "==> Packaging"
(cd "$OUTPUT_DIR" && zip -qry PaspoID-xcframeworks.zip ./*.xcframework)
echo -n "checksum: "
swift package --package-path "$PACKAGE_ROOT" compute-checksum "$OUTPUT_DIR/PaspoID-xcframeworks.zip"

echo "Done: $OUTPUT_DIR"
