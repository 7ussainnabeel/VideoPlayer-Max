#!/usr/bin/env bash
set -euo pipefail

# Builds Flutter mobile artifacts for this repo.
# Usage:
#   ./deployment/build_mobile_artifacts.sh            # interactive choice menu
#   ./deployment/build_mobile_artifacts.sh apk        # builds apk only
#   ./deployment/build_mobile_artifacts.sh ipa        # builds ipa only
#   ./deployment/build_mobile_artifacts.sh all        # builds both apk and ipa
#   ./deployment/build_mobile_artifacts.sh both       # builds both apk and ipa
#
# After APK build, if ADB devices are connected, the script will prompt you
# to pick a device and install the generated APK.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$REPO_ROOT"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
TARGET="${1:-}"

if [[ ! -d "$FRONTEND_DIR" ]]; then
  echo "Error: Flutter project directory not found at: $FRONTEND_DIR"
  exit 1
fi

# Add common macOS Homebrew/Flutter paths if flutter is not in PATH
if ! command -v flutter >/dev/null 2>&1; then
  for path in "/opt/homebrew/Caskroom/flutter/3.44.2/flutter/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
    if [[ -d "$path" && -x "$path/flutter" ]]; then
      export PATH="$path:$PATH"
      break
    fi
  done
fi

# Add Android SDK platform-tools to PATH if not present
if ! command -v adb >/dev/null 2>&1; then
  ANDROID_SDK_PLATFORM_TOOLS="$HOME/Library/Android/sdk/platform-tools"
  if [[ -d "$ANDROID_SDK_PLATFORM_TOOLS" ]]; then
    export PATH="$PATH:$ANDROID_SDK_PLATFORM_TOOLS"
  fi
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not installed or not in PATH."
  exit 1
fi

mkdir -p "$ARTIFACTS_DIR"

choose_target_interactively() {
  while true; do
    echo "Choose what to build:"
    echo "  1) APK only"
    echo "  2) IPA only"
    echo "  3) Both (IPA + APK)"
    echo "  4) Cancel"
    printf "Enter choice [1-4]: "
    read -r choice

    case "$choice" in
      1)
        TARGET="apk"
        return
        ;;
      2)
        TARGET="ipa"
        return
        ;;
      3)
        TARGET="both"
        return
        ;;
      4)
        echo "Cancelled."
        exit 0
        ;;
      *)
        echo "Invalid choice: $choice"
        ;;
    esac
  done
}

prompt_install_apk_on_device() {
  local apk_path="$1"

  if ! command -v adb >/dev/null 2>&1; then
    echo "ADB not found in PATH. Skipping APK install."
    return
  fi

  local devices=()
  local device_id
  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] && devices+=("$device_id")
  done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')

  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No connected ADB devices detected. Skipping APK install."
    return
  fi

  if [[ ! -t 0 ]]; then
    echo "Non-interactive shell detected. Skipping APK install prompt."
    return
  fi

  echo
  echo "Connected ADB devices:"
  local i
  for i in "${!devices[@]}"; do
    echo "  $((i + 1))) ${devices[$i]}"
  done
  echo "  s) Skip install"

  while true; do
    printf "Select device to install APK [1-%d or s]: " "${#devices[@]}"
    local choice
    read -r choice

    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
      echo "Skipping APK install."
      return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#devices[@]} )); then
      local serial="${devices[$((choice - 1))]}"
      echo "Installing APK on $serial ..."
      adb -s "$serial" install -r "$apk_path"
      echo "APK installed on $serial"
      return
    fi

    echo "Invalid selection."
  done
}

prompt_open_ipa_in_impactor() {
  local ipa_path="$1"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    return
  fi

  local impactor_app_name=""
  local impactor_app_target=""
  if [[ -d "/Applications/Impactor.app" ]]; then
    impactor_app_name="Impactor"
    impactor_app_target="/Applications/Impactor.app"
  fi

  if [[ -z "$impactor_app_name" ]]; then
    echo "Impactor app not found at /Applications/Impactor.app. Skipping IPA handoff."
    echo "Install Impactor from: https://github.com/CLARATION/Impactor/releases"
    return
  fi

  if [[ ! -t 0 ]]; then
    echo "Non-interactive shell detected. Skipping Impactor prompt."
    return
  fi

  while true; do
    printf "Open IPA in %s now? [y/n]: " "$impactor_app_name"
    local choice
    read -r choice

    case "$choice" in
      y|Y)
        open -a "$impactor_app_target"

        if ! command -v osascript >/dev/null 2>&1; then
          echo "osascript not available. Please use '$impactor_app_name' -> Import ipa/.tipa and select: $ipa_path"
          return
        fi

        local automation_result
        automation_result="$(osascript - "$impactor_app_name" "$ipa_path" <<'APPLESCRIPT'
on run argv
  set appName to item 1 of argv
  set ipaPath to item 2 of argv

  tell application appName to activate
  delay 1

  tell application "System Events"
    if not (exists process appName) then
      return "PROCESS_NOT_FOUND"
    end if

    tell process appName
      set frontmost to true
      try
        if exists window 1 and exists button "Import ipa/.tipa" of window 1 then
          click button "Import ipa/.tipa" of window 1
        else
          keystroke "o" using {command down}
        end if
      on error
        keystroke "o" using {command down}
      end try
    end tell

    delay 0.6
    keystroke ipaPath
    key code 36
  end tell

  return "OK"
end run
APPLESCRIPT
)"

        case "$automation_result" in
          OK)
            echo "Triggered Import ipa/.tipa in $impactor_app_name and selected: $ipa_path"
            echo "Complete signing/install prompts in Impactor."
            ;;
          PROCESS_NOT_FOUND)
            echo "Could not automate $impactor_app_name window."
            echo "Please click Import ipa/.tipa manually and select: $ipa_path"
            ;;
          *)
            echo "Impactor automation returned: $automation_result"
            echo "If macOS Accessibility is blocked, enable Terminal under:"
            echo "  System Settings -> Privacy & Security -> Accessibility"
            echo "Then use Import ipa/.tipa and select: $ipa_path"
            ;;
        esac
        return
        ;;
      n|N)
        echo "Skipping Impactor handoff."
        return
        ;;
      *)
        echo "Invalid selection. Enter y or n."
        ;;
    esac
  done
}

build_apk() {
  echo "[1/2] Building Android APK (release)..."
  (
    cd "$FRONTEND_DIR"
    flutter build apk --release
  )

  local apk_src="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
  local apk_dest="$ARTIFACTS_DIR/app-release.apk"

  if [[ ! -f "$apk_src" ]]; then
    echo "Error: APK not found at $apk_src"
    exit 1
  fi

  cp "$apk_src" "$apk_dest"
  echo "APK ready: $apk_dest"
  prompt_install_apk_on_device "$apk_dest"
}

build_ipa() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping IPA build: iOS build is only supported on macOS."
    return 0
  fi

  echo "[2/2] Building iOS app (release, no codesign)..."
  (
    cd "$FRONTEND_DIR"
    flutter build ios --release --no-codesign
  )

  local app_dir="$FRONTEND_DIR/build/ios/iphoneos/Runner.app"
  local ipa_dest="$ARTIFACTS_DIR/Frontend.ipa"

  if [[ ! -d "$app_dir" ]]; then
    echo "Error: Runner.app not found at $app_dir"
    exit 1
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  mkdir -p "$temp_dir/Payload"
  cp -R "$app_dir" "$temp_dir/Payload/"

  rm -f "$ipa_dest"
  (
    cd "$temp_dir"
    zip -rq "$ipa_dest" Payload
  )

  rm -rf "$temp_dir"
  echo "IPA ready: $ipa_dest"
  prompt_open_ipa_in_impactor "$ipa_dest"
}

if [[ -z "$TARGET" ]]; then
  choose_target_interactively
fi

case "$TARGET" in
  apk)
    build_apk
    ;;
  ipa)
    build_ipa
    ;;
  all|both|apk+ipa|ipa+apk)
    build_apk
    build_ipa
    ;;
  *)
    echo "Invalid target: $TARGET"
    echo "Usage: $0 [apk|ipa|all|both|apk+ipa|ipa+apk]"
    exit 1
    ;;
esac

echo "Done. Artifacts are in: $ARTIFACTS_DIR"
ls -lh "$ARTIFACTS_DIR"
