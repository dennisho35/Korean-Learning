#!/usr/bin/env bash
set -e
echo "======================================================"
echo "韓語一步通 Korean Step-by-Step — Android APK & iOS 建置腳本"
echo "======================================================"
flutter --version
flutter create . --project-name korean_step_by_step --org com.stepbystep
flutter pub get
flutter test
echo "[1/2] 正在建置 Android Release APK..."
flutter build apk --release
echo "✅ APK 建置完成：build/app/outputs/flutter-apk/app-release.apk"
echo "[2/2] 正在建置 Google Play Android App Bundle (AAB)..."
flutter build appbundle --release
echo "✅ AAB 建置完成：build/app/outputs/bundle/release/app-release.aab"
