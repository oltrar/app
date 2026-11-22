# LoopMate setup

## iOS standalone (macOS + Xcode)

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/ios
brew install xcodegen
xcodegen generate
open LoopMate.xcodeproj
# In Xcode select your Development Team, an iPhone, then Run.
```

## iOS cross-app gestures (Xcode UI testing)

```bash
cd apps/ios
# Edit Tests/presets.json: activePreset, bundleId, repeatCount, steps
xcodegen generate
open LoopMate.xcodeproj
# Select an attached iPhone, then run:
# Product → Test (Cmd+U), or run AutomationUITests/testRunActivePresetAcrossApps.
# Stop the test in Xcode to stop automation.
```

## Android (JDK 17 + Android SDK + Gradle 8.10.2)

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/android
gradle assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
# Device: Settings → Accessibility → LoopMate actions → Enable
```

iOS cross-app gesture presets require an Xcode test session; the standalone iOS app cannot control other apps. Android uses Accessibility directly. Presets are stored on Android in-app and on iOS in `Tests/presets.json`.
