import 'package:flutter_tts/flutter_tts.dart';

abstract class IKoreanVoiceService {
  Future<void> initialize();
  Future<void> speak(String text, {double? overrideRate});
  void setSpeedTier(double rate);
  double get currentRate;
}

class NativeKoreanTtsService implements IKoreanVoiceService {
  final FlutterTts _tts = FlutterTts();
  double _currentRate = 0.35; // Default: 🎧 初學慢速 0.35x

  static const double rateSlowest = 0.24;  // 🐢 特慢 0.24x
  static const double rateDefault = 0.35;  // 🎧 初學慢速 0.35x
  static const double rateStandard = 0.45; // ▶️ 標準 0.45x

  @override
  double get currentRate => _currentRate;

  @override
  Future<void> initialize() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(_currentRate);
  }

  @override
  void setSpeedTier(double rate) {
    _currentRate = rate;
    _tts.setSpeechRate(rate);
  }

  @override
  Future<void> speak(String text, {double? overrideRate}) async {
    final clean = text.split('[').first.split('(').first.trim();
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(overrideRate ?? _currentRate);
    await _tts.speak(clean.isEmpty ? text : clean);
  }
}
