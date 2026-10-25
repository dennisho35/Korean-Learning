# 韓語一步通 Korean Step-by-Step (Flutter Android & iOS 跨平台完整專案)

## 一、專案結構
- `assets/data/curriculum.json`：完整校對之韓語教材資料庫（40 個韓文字母、音節方塊組字資料、收音與 7 大音變規則、固有與漢字雙系統數字 12 單元、19 類情境量詞、20 課日常會話、26 道跨 13 題型測驗題庫）。
- `lib/models/curriculum_models.dart`：資料模型與韓文音節方塊 Unicode 動態合成演算法 (`(초성*21 + 중성)*28 + 종성 + 0xAC00`)。
- `lib/services/tts_service.dart`：韓語語音服務介面與原生 TTS 實作（支援 `0.24x` 特慢、`0.35x` 初學慢速預設、`0.45x` 標準三段語速）。
- `lib/services/storage_service.dart`：本機離線學習進度、手寫練習次數與 SRS 錯題本儲存。
- `lib/widgets/handwriting_canvas.dart`：手機觸控韓文字母手寫描紅與自由書寫畫布（自我練習模式）。
- `test/curriculum_test.dart`：單元測試與教材資料完整性驗證。
- `build_apk.sh`：一鍵建置 Android APK 與 AAB 腳本。

## 二、Android APK / AAB 建置與安裝指南
1. 確保電腦已安裝 **Flutter SDK (>=3.19)** 與 **Android Studio / Android SDK (API 34)**。
2. 解壓縮本專案並進入目錄：
   ```bash
   cd korean_step_by_step_flutter
   ./build_apk.sh
   ```
3. 產生的可安裝 APK 路徑為：
   `build/app/outputs/flutter-apk/app-release.apk`
4. 透過 USB 安裝至 Android 手機：
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

## 三、iOS IPA 建置指南
1. 於 macOS 環境安裝 **Xcode 15+** 與 **CocoaPods**。
2. 執行：
   ```bash
   flutter build ipa --release
   ```
3. 使用 Xcode Organizer 或 Transporter 上傳至 App Store Connect / TestFlight。
