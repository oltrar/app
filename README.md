# LoopMate

## iOS — macOS, Xcode, Flutter

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/ios
bash tool/bootstrap.sh
open -a Simulator
flutter run
# For a signed iPhone build, select a Development Team in ios/Runner.xcworkspace:
open ios/Runner.xcworkspace
flutter build ios --release
```

Open the offline demo, choose an action and interval, and press **Start**. To automate a website, enter its HTTPS URL and tap **Go**. iOS actions work **inside the app's browser only**, while foregrounded—not across other apps.

## Android — Flutter, Android SDK

```bash
git clone https://github.com/oltrar/app.git
cd app/apps/android
bash tool/bootstrap.sh
flutter run
flutter build apk --release
```

Enable **LoopMate** in Android **Settings → Accessibility**, then return to the app and press **Start**.
