# LoopMate — setup

## iOS (macOS + Xcode)

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/ios
brew install xcodegen
xcodegen generate
open LoopMate.xcodeproj
# Select your team in Xcode → LoopMate target → Signing & Capabilities.
# Choose an iPhone or simulator and press Run.
```

## Android (JDK 17 + Android SDK + Gradle 8.10.2)

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/android
gradle assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
# On device: Settings → Accessibility → LoopMate actions → Enable
```
