#!/bin/zsh
# Captures the App Store screenshots on the iPhone 17 Pro Max simulator (6.9", 1320x2868).
# Each scenario is a deterministic app state from ScreenshotScenario (Debug builds only).
#
#   scripts/screenshots.sh [output-dir]      default: screenshots/nl-NL
#
# Upload them afterwards with scripts/upload_screenshots.py.
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.squashanalyzer.app"
OUT="${1:-screenshots/nl-NL}"
DERIVED="build/DerivedData-screenshots"
SCENARIOS=(setup coach-match coach-zone referee history dashboard)

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name and d.get("isAvailable"):
            print(d["udid"]); sys.exit(0)
sys.exit(f"no available simulator named {name!r}")
' "$DEVICE_NAME")

echo "▸ Building Debug for $DEVICE_NAME ($UDID)"
xcodebuild -project SquashAnalyzer.xcodeproj -scheme SquashAnalyzer -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/SquashAnalyzer.app"

echo "▸ Booting simulator"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# Fresh install so the seeded sample data is the only data
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState discharging --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName ""

# Warm-up launch: lets first-boot system banners (e.g. Apple Intelligence) disappear
xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot setup >/dev/null
sleep 8

mkdir -p "$OUT"
i=1
for scenario in "${SCENARIOS[@]}"; do
  file="$OUT/$(printf '%02d' $i)-$scenario.png"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$scenario" >/dev/null
  sleep 3
  xcrun simctl io "$UDID" screenshot "$file" >/dev/null 2>&1
  echo "  ✓ $file"
  i=$((i + 1))
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear
sips -g pixelWidth -g pixelHeight "$OUT/01-setup.png" | tail -2 | tr -s ' ' | paste -sd' ' -
echo "▸ Done: ${#SCENARIOS[@]} screenshots in $OUT"
