@echo off
chcp 65001 >nul
echo Building Korean Step-by-Step Android Release APK...
call flutter create . --project-name korean_step_by_step --org com.stepbystep
call flutter pub get
call flutter build apk --release
echo Done: build\app\outputs\flutter-apk\app-release.apk
pause
