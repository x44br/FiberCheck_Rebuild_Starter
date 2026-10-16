# FiberCheck Rebuild (Flutter starter)

This is a clean Flutter UI starter inspired by the strings/features found in `FiberCheck_1.3.1.apk`.

## What is included
- Modern dark dashboard with Arabic and English UI toggle
- ONU IP and protocol selection UI (Auto / Telnet / SSH)
- Optional username/password fields
- Optical metrics cards: Rx, Tx, temperature, voltage
- Diagnostic advisory, system health, WAN ping, reboot, CLI log and report sections
- Safety-conscious placeholder actions: they do not connect to a device or send reboot commands yet

## Run
1. Install Flutter SDK and Android Studio (or Flutter-capable editor).
2. Run `flutter create .` from this directory if platform folders are missing.
3. Run `flutter pub get`.
4. Run `flutter run` on an Android device.

## Important
The original APK is a compiled Flutter app. It does not contain the original Dart project in directly editable form. This starter recreates the visible structure and labels, not the original implementation. The next phase is implementing and testing the transport/diagnostic layer for an authorized Huawei ONU. Never expose or log device passwords, PPPoE credentials, GPON serials, or other subscriber secrets.
