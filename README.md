# LoopMate

## Android

Requires Flutter SDK and Android SDK.

~~~bash
cd apps/android
bash tool/bootstrap.sh
flutter run
flutter build apk --release
~~~

Enable LoopMate in Android Settings → Accessibility before starting automation.

## iOS

Requires macOS, Flutter SDK, and Xcode.

~~~bash
cd apps/ios
bash tool/bootstrap.sh
open -a Simulator
flutter run
flutter build ios --release
~~~

iOS is preview-only; third-party iOS apps cannot inject gestures into other apps.
