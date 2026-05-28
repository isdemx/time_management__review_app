#!/bin/sh
set -eu

if [ "${CODE_SIGNING_ALLOWED:-}" = "NO" ] || [ "${CODE_SIGNING_REQUIRED:-}" = "NO" ] || [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ ! -d "$FRAMEWORKS_DIR" ]; then
  exit 0
fi

platform_for_binary() {
  xcrun vtool -show-build "$1" 2>/dev/null | awk '/platform / { print $2; exit }'
}

replace_objective_c_simulator_binary() {
  binary="$1"

  if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
    return
  fi

  platform="$(platform_for_binary "$binary")"
  if [ "$platform" = "IOS" ]; then
    return
  fi

  search_dir="${SRCROOT}/../.dart_tool/hooks_runner/shared/objective_c/build"
  if [ ! -d "$search_dir" ]; then
    echo "error: objective_c.framework was built for $platform, and no native-assets cache was found at $search_dir"
    exit 1
  fi

  for candidate in "$search_dir"/*/objective_c.dylib; do
    [ -f "$candidate" ] || continue
    candidate_platform="$(platform_for_binary "$candidate")"
    if [ "$candidate_platform" = "IOS" ]; then
      echo "Replacing objective_c.framework $platform binary with iOS native asset"
      cp "$candidate" "$binary"
      return
    fi
  done

  echo "error: objective_c.framework was built for $platform, but no iOS objective_c native asset was found"
  exit 1
}

for framework in "$FRAMEWORKS_DIR"/*.framework; do
  [ -e "$framework" ] || continue

  binary="$framework/$(basename "$framework" .framework)"
  if [ -f "$binary" ] && file "$binary" | grep -q "Mach-O"; then
    if [ "$(basename "$framework")" = "objective_c.framework" ]; then
      replace_objective_c_simulator_binary "$binary"
    fi

    binary_archs=$(lipo -archs "$binary" 2>/dev/null || true)
    for arch in $binary_archs; do
      case " ${ARCHS:-} " in
        *" $arch "*) ;;
        *)
          tmp_binary="${binary}.thin"
          echo "Stripping $arch from $(basename "$framework")"
          if lipo -remove "$arch" -output "$tmp_binary" "$binary"; then
            mv "$tmp_binary" "$binary"
          else
            rm -f "$tmp_binary"
            echo "warning: Failed to strip $arch from $(basename "$framework"); continuing with existing binary"
          fi
          ;;
      esac
    done

    if [ "$(basename "$framework")" = "objective_c.framework" ] && [ "${PLATFORM_NAME:-}" = "iphoneos" ]; then
      platform="$(platform_for_binary "$binary")"
      if [ "$platform" != "IOS" ]; then
        echo "error: objective_c.framework still references unsupported platform $platform"
        exit 1
      fi
    fi
  fi

  echo "Re-signing $(basename "$framework") with ${EXPANDED_CODE_SIGN_IDENTITY_NAME:-$EXPANDED_CODE_SIGN_IDENTITY}"
  /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none --preserve-metadata=identifier,entitlements "$framework"
done
