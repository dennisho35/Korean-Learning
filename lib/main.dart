import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/curriculum_models.dart';
import 'services/tts_service.dart';
import 'services/storage_service.dart';
import 'widgets/handwriting_canvas.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KoreanStepByStepApp());
}

class KoreanStepByStepApp extends StatefulWidget {
  const KoreanStepByStepApp({super.key});

  @override
  State<KoreanStepByStepApp> createState() => _KoreanStepByStepAppState();
}

class _KoreanStepByStepAppState extends State<KoreanStepByStepApp> {
  final IKoreanVoiceService _tts = NativeKoreanTtsService();
  final StudyStorageService _storage = StudyStorageService();
  Map<String, dynamic>? _curriculum;

  // Persistent State (100% Real User Progress, Zero Fake Stats)
  int _dailyGoalMinutes = 10;
  String _reminderTime = '20:00';
  bool _isDarkMode = false;
  bool _showRomaji = true;
  double _fontScale = 1.0;

  // Navigation & Sub-tabs
  int _currentTab = 0; // 0:Home, 1:Hangul, 2:Numbers, 3:Conversation, 4:Quiz/Stats
  String _hangulSubTab = 'basic_consonant';
  String _numCounterMode = 'units'; // 'units' | 'compare' | 'counters'
  String _selectedNumCatFilter = 'ALL';
  Map<String, dynamic>? _selectedSingleNumItem;
  int _currentConvIndex = 0;
  String _quizSubTab = 'test'; // 'test' | 'mistakes' | 'favorites' | 'stats'

  // Real Tracking Data
  Map<String, String> _jamoStatus = {}; // id -> 'unlearned' | 'learned' | 'review'
  Map<String, int> _handwritingCounts = {}; // id -> count
  int _combinerCount = 0;
  List<String> _completedRules = [];
  List<String> _completedNumberUnits = [];
  List<String> _completedLessons = [];
  List<Map<String, dynamic>> _favorites = [];
  Map<String, Map<String, dynamic>> _mistakeBook = {};
  int _totalQuizzesTaken = 0;
  int _totalQuestionsAnswered = 0;
  int _totalCorrectAnswers = 0;
  int _totalStudySeconds = 0;
  int _todayStudySeconds = 0;
  int _streakDays = 0;
  String? _lastStudyDate;

  // A5 Combiner State
  static const List<String> _choseongList = [
    'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];
  static const List<String> _choseongRom = [
    'g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h'
  ];
  static const List<String> _jungseongList = [
    'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ'
  ];
  static const List<String> _jungseongRom = [
    'a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u','wo','we','wi','yu','eu','ui','i'
  ];
  static const List<String> _jongseongList = [
    '(無)','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ','ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ','ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];
  static const List<String> _jongseongRom = [
    '','k','k','k','n','n','n','t','l','k','m','l','l','l','p','l','m','p','p','t','t','ng','t','t','k','t','p','t'
  ];
  static const List<String> _jongseongRep = [
    '無收音','[ㄱ]','[ㄱ]','[ㄱ](讀左)','[ㄴ]','[ㄴ](讀左)','[ㄴ](讀左)','[ㄷ]','[ㄹ]','[ㄱ](讀右)','[ㅁ](讀右)','[ㄹ](讀左)','[ㄹ](讀左)','[ㄹ](讀左)','[ㅂ](讀右)','[ㄹ](讀左)','[ㅁ]','[ㅂ]','[ㅂ](讀左)','[ㄷ]','[ㄷ]','[ㅇ]','[ㄷ]','[ㄷ]','[ㄱ]','[ㄷ]','[ㅂ]','[ㄷ]'
  ];
  int _combChoIdx = 0;
  int _combJungIdx = 0;
  int _combJongIdx = 0;

  // A10 Trainer State
  int _trainerJamoIndex = 0;
  List<Map<String, dynamic>> _trainerOptions = [];
  String _trainerFeedback = '請點擊播放題目發音，再選出對應的韓文字母';

  // B4 Context Number Converter State
  int _converterInputNum = 2;
  String _converterContext = 'dual';
  final TextEditingController _numInputController = TextEditingController(text: '2');
  Map<String, dynamic>? _numListenTarget;
  List<Map<String, dynamic>> _numListenOptions = [];
  String _numListenFeedback = '';

  // D2 Conversation Practice State
  String _convPracticeFeedback = '';

  // E2 Quiz State
  String _quizFilterModule = 'ALL';
  List<Map<String, dynamic>> _activeQuizQuestions = [];
  Map<int, int> _activeQuizAnswers = {};
  bool _activeQuizSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _tts.initialize();
    final jsonStr = await rootBundle.loadString('assets/data/curriculum.json');
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final saved = await _storage.loadState();

    setState(() {
      _curriculum = decoded;
      _dailyGoalMinutes = (saved['dailyGoalMinutes'] as int?) ?? 10;
      _reminderTime = (saved['reminderTime'] as String?) ?? '20:00';
      _isDarkMode = (saved['isDarkMode'] as bool?) ?? false;
      _showRomaji = (saved['showRomaji'] as bool?) ?? true;
      _fontScale = ((saved['fontScale'] as num?) ?? 1.0).toDouble();

      final savedRate = ((saved['speechRate'] as num?) ?? 0.35).toDouble();
      _tts.setSpeedTier(savedRate);

      if (saved['jamoStatus'] is Map) {
        _jamoStatus = Map<String, String>.from(saved['jamoStatus'] as Map);
      }
      if (saved['handwritingCounts'] is Map) {
        _handwritingCounts = (saved['handwritingCounts'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        );
      }
      _combinerCount = (saved['combinerCount'] as int?) ?? 0;
      if (saved['completedRules'] is List) {
        _completedRules = List<String>.from(saved['completedRules'] as List);
      }
      if (saved['completedNumberUnits'] is List) {
        _completedNumberUnits = List<String>.from(saved['completedNumberUnits'] as List);
      }
      if (saved['completedLessons'] is List) {
        _completedLessons = List<String>.from(saved['completedLessons'] as List);
      }
      if (saved['favorites'] is List) {
        _favorites = (saved['favorites'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (saved['mistakeBook'] is Map) {
        _mistakeBook = (saved['mistakeBook'] as Map).map(
          (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
        );
      }
      _totalQuizzesTaken = (saved['totalQuizzesTaken'] as int?) ?? 0;
      _totalQuestionsAnswered = (saved['totalQuestionsAnswered'] as int?) ?? 0;
      _totalCorrectAnswers = (saved['totalCorrectAnswers'] as int?) ?? 0;
      _totalStudySeconds = (saved['totalStudySeconds'] as int?) ?? 0;
      _todayStudySeconds = (saved['todayStudySeconds'] as int?) ?? 0;
      _streakDays = (saved['streakDays'] as int?) ?? 0;
      _lastStudyDate = saved['lastStudyDate'] as String?;

      _initTrainerRound();
      _startNewQuizSession('ALL', notify: false);
    });
  }

  Future<void> _saveAppState() async {
    await _storage.saveState({
      'dailyGoalMinutes': _dailyGoalMinutes,
      'reminderTime': _reminderTime,
      'isDarkMode': _isDarkMode,
      'showRomaji': _showRomaji,
      'fontScale': _fontScale,
      'speechRate': _tts.currentRate,
      'jamoStatus': _jamoStatus,
      'handwritingCounts': _handwritingCounts,
      'combinerCount': _combinerCount,
      'completedRules': _completedRules,
      'completedNumberUnits': _completedNumberUnits,
      'completedLessons': _completedLessons,
      'favorites': _favorites,
      'mistakeBook': _mistakeBook,
      'totalQuizzesTaken': _totalQuizzesTaken,
      'totalQuestionsAnswered': _totalQuestionsAnswered,
      'totalCorrectAnswers': _totalCorrectAnswers,
      'totalStudySeconds': _totalStudySeconds,
      'todayStudySeconds': _todayStudySeconds,
      'streakDays': _streakDays,
      'lastStudyDate': _lastStudyDate,
    });
  }

  void _recordStudySeconds(int sec) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    setState(() {
      if (_lastStudyDate != todayStr) {
        _todayStudySeconds = 0;
        _streakDays += 1;
        _lastStudyDate = todayStr;
      }
      _todayStudySeconds += sec;
      _totalStudySeconds += sec;
    });
    _saveAppState();
  }

  void _speak(String text, {double? rate}) {
    _recordStudySeconds(4);
    _tts.speak(text, overrideRate: rate);
  }

  List<Map<String, dynamic>> get _jamoList =>
      (_curriculum?['jamo'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _tripletsList =>
      (_curriculum?['consonantTriplets'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _structuresList =>
      (_curriculum?['syllableStructures'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _coreSyllableSets =>
      (_curriculum?['coreSyllableSets'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _batchimRules =>
      (_curriculum?['batchimRules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _phonologicalRules =>
      (_curriculum?['phonologicalRules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _numSystemComparison =>
      (_curriculum?['numberSystemComparison'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _numbersCategories =>
      (_curriculum?['numbersCategories'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _countersList =>
      (_curriculum?['counters'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _conversationsList =>
      (_curriculum?['conversations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _quizQuestionsList =>
      (_curriculum?['quizQuestions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '韓語一步通 Korean Step-by-Step',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B365D)),
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_fontScale),
          ),
          child: child!,
        );
      },
      home: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1B365D),
            foregroundColor: Colors.white,
            title: const Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0xFFD64045),
                  child: Text('한', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '韓語一步通 Korean Step-by-Step',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _showRomaji = !_showRomaji);
                  _saveAppState();
                },
                child: Text(
                  _showRomaji ? '拼音:顯示' : '拼音:隱藏',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                tooltip: '切換深淺色主題',
                onPressed: () {
                  setState(() => _isDarkMode = !_isDarkMode);
                  _saveAppState();
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                tooltip: '系統設定與進度重置',
                onPressed: () => _openSettingsSheet(ctx),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: Container(
                color: const Color(0xFF162D4F),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔊 全域語速：', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      _speedBtn('🐢 特慢 0.24x', 0.24),
                      const SizedBox(width: 6),
                      _speedBtn('🎧 初學 0.35x(預設)', 0.35),
                      const SizedBox(width: 6),
                      _speedBtn('▶️ 標準 0.45x', 0.45),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _curriculum == null
              ? const Center(child: CircularProgressIndicator())
              : _buildCurrentTab(ctx),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTab,
            onDestinationSelected: (idx) => setState(() => _currentTab = idx),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首頁任務'),
              NavigationDestination(icon: Icon(Icons.font_download_outlined), selectedIcon: Icon(Icons.font_download), label: '韓文字母'),
              NavigationDestination(icon: Icon(Icons.pin_outlined), selectedIcon: Icon(Icons.pin), label: '數字與量詞'),
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '日常會話'),
              NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: '測驗與統計'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedBtn(String label, double rate) {
    final active = (_tts.currentRate - rate).abs() < 0.02;
    return GestureDetector(
      onTap: () {
        setState(() => _tts.setSpeedTier(rate));
        _saveAppState();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD64045) : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCurrentTab(BuildContext context) {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab(context);
      case 1:
        return _buildHangulTab(context);
      case 2:
        return _buildNumbersAndCountersTab(context);
      case 3:
        return _buildConversationTab(context);
      case 4:
        return _buildQuizAndStatsTab(context);
      default:
        return _buildHomeTab(context);
    }
  }

  // ===========================================================================
  // TAB 0: 首頁與每日任務 (Home & Daily Plan)
  // ===========================================================================
  Widget _buildHomeTab(BuildContext context) {
    final learnedJamo = _jamoStatus.values.where((v) => v == 'learned').length;
    final reviewJamo = _jamoStatus.values.where((v) => v == 'review').length;
    final totalJamo = _jamoList.length;
    final todayMin = (_todayStudySeconds / 60.0);
    final progress = (_todayStudySeconds / (_dailyGoalMinutes * 60)).clamp(0.0, 1.0);
    final acc = _totalQuestionsAnswered == 0
        ? 0
        : ((_totalCorrectAnswers / _totalQuestionsAnswered) * 100).round();

    final nextJamo = _jamoList.firstWhere(
      (j) => _jamoStatus[j['id']] != 'learned',
      orElse: () => _jamoList.first,
    );
    final nextConv = _conversationsList.firstWhere(
      (c) => !_completedLessons.contains(c['id']),
      orElse: () => _conversationsList.first,
    );

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Hero Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B365D), Color(0xFF284B7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🎯 每日學習計劃 ｜ 連續學習：$_streakDays 天',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '歡迎來到「韓語一步通 Korean Step-by-Step」！',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '零基礎繁體中文韓語教學：涵蓋韓文 40 音、音節方塊組字器、收音與 7 大音變、固有與漢字雙軌數字、19 類量詞與 20 課韓國旅遊會話。所有統計 100% 由本機真實紀錄計算！',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('每日目標時間設定：', style: TextStyle(color: Colors.white, fontSize: 12)),
                        Text('$_dailyGoalMinutes 分鐘 / 日',
                            style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [5, 10, 15, 30].map((m) {
                        final selected = _dailyGoalMinutes == m;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selected ? const Color(0xFFD64045) : Colors.white12,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              onPressed: () {
                                setState(() => _dailyGoalMinutes = m);
                                _saveAppState();
                              },
                              child: Text('$m分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('今日已學習時間：', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${todayMin.toStringAsFixed(1)} / $_dailyGoalMinutes 分鐘 (${(progress * 100).round()}%)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: Colors.greenAccent,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 Core Module Entry Cards
        const Text('四大核心學習模組（點擊立即進入）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            _moduleCard(
              badge: '가나',
              stat: '已掌握 $learnedJamo / $totalJamo',
              title: '1. 韓文字母與拼讀',
              desc: '40音、手寫描紅、動態組字、收音與7大音變',
              color: Colors.blue,
              onTap: () => setState(() => _currentTab = 1),
            ),
            _moduleCard(
              badge: '하나',
              stat: '12單元 + 19量詞',
              title: '2. 數字與量詞',
              desc: '固有與漢字雙系統、情境數字轉換器',
              color: Colors.orange,
              onTap: () => setState(() => _currentTab = 2),
            ),
            _moduleCard(
              badge: '💬',
              stat: '已完成 ${_completedLessons.length} / ${_conversationsList.length} 課',
              title: '3. 日常會話 (20課)',
              desc: '點餐續小菜、購物退稅、交通儲值、演唱會領票',
              color: Colors.teal,
              onTap: () => setState(() => _currentTab = 3),
            ),
            _moduleCard(
              badge: '🎯',
              stat: '正確率 $acc%',
              title: '4. 測驗與統計',
              desc: '13大互動題型、SRS錯題本、收藏夾與真實報表',
              color: Colors.redAccent,
              onTap: () => setState(() => _currentTab = 4),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Daily Recommended Tasks
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📋 今日智慧推薦學習任務（依每日 $_dailyGoalMinutes 分鐘目標規劃）',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1B365D),
                    child: Text(nextJamo['jamo'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('韓文字母：學習「${nextJamo['jamo']} — ${nextJamo['name']}」並手寫練習',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${nextJamo['row']} ｜ ${nextJamo['exampleWord']}', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      setState(() => _currentTab = 1);
                      _openJamoDetailModal(context, nextJamo);
                    },
                    child: const Text('開始練習'),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.chat, color: Colors.white, size: 18),
                  ),
                  title: Text('旅遊會話：${nextConv['title']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(nextConv['situation'].toString(), style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      final idx = _conversationsList.indexOf(nextConv);
                      setState(() {
                        _currentConvIndex = idx >= 0 ? idx : 0;
                        _currentTab = 3;
                      });
                    },
                    child: const Text('進入會話'),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFD64045),
                    child: Icon(Icons.quiz, color: Colors.white, size: 18),
                  ),
                  title: Text(
                    _mistakeBook.isNotEmpty
                        ? 'SRS 錯題重溫：您有 ${_mistakeBook.length} 道錯題待複習'
                        : '綜合互動測驗：檢驗韓文字母、收音音變與雙軌數字',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('需重溫字母：$reviewJamo 字 ｜ 間隔重複記憶強化', style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _quizSubTab = _mistakeBook.isNotEmpty ? 'mistakes' : 'test';
                        _currentTab = 4;
                      });
                    },
                    child: Text(_mistakeBook.isNotEmpty ? '複習錯題' : '開始測驗'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Voice Check Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔊 韓語語音合成 (TTS) 與手寫練習誠實標示',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                const Text(
                  '• 語音：整合 Android / iOS 原生系統 TTS（首爾標準語 ko-KR），支援頂部 0.24x 特慢、0.35x 初學慢速、0.45x 標準三段語速切換。\n'
                  '• 手寫：採用「自我練習模式（含筆畫數檢核與描紅底字對照）」，所有進度儲存在本機並支援離線學習。',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B365D),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('點擊測試韓語發音 (안녕하세요! 한국어를 배워 봅시다)'),
                    onPressed: () => _speak('안녕하세요! 한국어를 한 걸음씩 배워 봅시다.'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _moduleCard({
    required String badge,
    required String stat,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  ),
                  Flexible(
                    child: Text(stat,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: 模組 A — 韓文字母及拼讀學習中心 (8 Sub-Tabs + Modal Handwriting)
  // ===========================================================================
  Widget _buildHangulTab(BuildContext context) {
    final subTabs = [
      {'id': 'basic_consonant', 'label': 'A1. 基本子音 (14)'},
      {'id': 'double_consonant', 'label': 'A2. 雙子音與三音比較 (5)'},
      {'id': 'basic_vowel', 'label': 'A3. 基本母音 (10)'},
      {'id': 'compound_vowel', 'label': 'A4. 複合母音 (11)'},
      {'id': 'combiner', 'label': '🧩 A5. 音節方塊組字器'},
      {'id': 'batchim', 'label': '⚓ A6. 收音 (받침) 專項'},
      {'id': 'rules', 'label': '⚡ A7. 7大音變規則'},
      {'id': 'trainer', 'label': '🎙️ A10. 發音與聽辨訓練'},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: subTabs.map((t) {
                final selected = _hangulSubTab == t['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : null)),
                    selected: selected,
                    selectedColor: const Color(0xFF1B365D),
                    onSelected: (_) => setState(() => _hangulSubTab = t['id']!),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _buildHangulSubContent(context),
        ),
      ],
    );
  }

  Widget _buildHangulSubContent(BuildContext context) {
    if (_hangulSubTab == 'combiner') return _buildSyllableCombinerView();
    if (_hangulSubTab == 'batchim') return _buildBatchimView();
    if (_hangulSubTab == 'rules') return _buildPhonologicalRulesView();
    if (_hangulSubTab == 'trainer') return _buildHangulTrainerView();

    final items = _jamoList.where((j) => j['category'] == _hangulSubTab).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '💡 點擊任一字母卡片開啟「筆順說明、3段語速播放與觸控手寫描紅畫布」；點右上角喇叭直接發音。（註：中文近似音與羅馬拼音僅作初學輔助）',
            style: TextStyle(fontSize: 12),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (ctx, i) {
            final item = items[i];
            final id = item['id'].toString();
            final status = _jamoStatus[id] ?? 'unlearned';
            final practiceCnt = _handwritingCounts[id] ?? 0;
            final dotColor = status == 'learned'
                ? Colors.green
                : (status == 'review' ? Colors.amber : Colors.grey);
            final speakTarget = (item['syllableForm'] ?? item['exampleWord'].toString().split('(').first).toString().trim();

            return InkWell(
              onTap: () => _openJamoDetailModal(context, item),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 5, backgroundColor: dotColor),
                              const SizedBox(width: 4),
                              if (practiceCnt > 0)
                                Text('已寫$practiceCnt次', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          InkWell(
                            onTap: () => _speak(speakTarget),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.volume_up, size: 20, color: Color(0xFF1B365D)),
                            ),
                          ),
                        ],
                      ),
                      Text(item['jamo'].toString(), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
                      Text(item['name'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (_showRomaji)
                        Text('[ ${item['romaji']} ]',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFD64045), fontWeight: FontWeight.bold)),
                      Text(
                        item['exampleWord'].toString().split('／').first,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (_hangulSubTab == 'double_consonant') ...[
          const SizedBox(height: 18),
          const Text(
            '🔍 A2 重點：韓語子音「平音 vs 緊音 vs 送氣音」三對立比較（點擊發音）',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._tripletsList.map((tr) {
            final plain = tr['plain'] as Map<String, dynamic>;
            final tense = tr['tense'] as Map<String, dynamic>;
            final asp = tr['aspirated'] as Map<String, dynamic>?;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr['group'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _speak(plain['syllable'].toString()),
                            child: Text('${plain['jamo']} (${plain['syllable']})\n平音 ${plain['romaji']} 🔊',
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _speak(tense['syllable'].toString()),
                            child: Text('${tense['jamo']} (${tense['syllable']})\n緊音 ${tense['romaji']} 🔊',
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFFD64045))),
                          ),
                        ),
                        if (asp != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _speak(asp['syllable'].toString()),
                              child: Text('${asp['jamo']} (${asp['syllable']})\n送氣 ${asp['romaji']} 🔊',
                                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('📌 單字對比：${tr['minimalPairs']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        TextButton.icon(
                          icon: const Icon(Icons.volume_up, size: 16),
                          label: const Text('連聽', style: TextStyle(fontSize: 12)),
                          onPressed: () => _speak(
                            tr['minimalPairs'].toString().replaceAll(RegExp(r'\([^)]*\)'), '').replaceAll('vs', ', '),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // Modal: Single Jamo Detail + 3-Speed TTS + Stroke Guide + Touch Handwriting Canvas
  void _openJamoDetailModal(BuildContext context, Map<String, dynamic> initialItem) {
    int modalIdx = _jamoList.indexWhere((j) => j['id'] == initialItem['id']);
    if (modalIdx < 0) modalIdx = 0;
    bool traceMode = true;
    String feedbackMsg = '請用手指在上方畫布書寫韓文字母，完成後點擊「提交完成」。';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final item = _jamoList[modalIdx];
            final id = item['id'].toString();
            final status = _jamoStatus[id] ?? 'unlearned';
            final practiceCnt = _handwritingCounts[id] ?? 0;
            final speakTarget = (item['syllableForm'] ?? item['exampleWord'].toString().split('(').first).toString().trim();
            final directions = List<String>.from(item['directions'] ?? []);

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 0.96,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(label: Text(item['row'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    // Top Character & 3-Speed Audio Box
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(item['jamo'].toString(),
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('名稱：${item['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('羅馬拼音：${item['romaji']}',
                                        style: const TextStyle(color: Color(0xFFD64045), fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(96, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () => _speak(speakTarget, rate: 0.24),
                                  child: const Text('🐢 特慢 0.24x', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B365D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(96, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () => _speak(speakTarget, rate: 0.35),
                                  child: const Text('🎧 慢速 0.35x', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(height: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD64045),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(96, 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  onPressed: () => _speak(speakTarget, rate: 0.45),
                                  child: const Text('▶️ 標準 0.45x', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Study Status Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('學習狀態標記：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('未學', style: TextStyle(fontSize: 12)),
                              selected: status == 'unlearned',
                              onSelected: (_) {
                                setState(() => _jamoStatus[id] = 'unlearned');
                                setModalState(() {});
                                _saveAppState();
                              },
                            ),
                            ChoiceChip(
                              label: const Text('✅ 已掌握', style: TextStyle(fontSize: 12)),
                              selected: status == 'learned',
                              selectedColor: Colors.green.shade200,
                              onSelected: (_) {
                                setState(() => _jamoStatus[id] = 'learned');
                                _recordStudySeconds(10);
                                setModalState(() {});
                              },
                            ),
                            ChoiceChip(
                              label: const Text('📌 重點重溫', style: TextStyle(fontSize: 12)),
                              selected: status == 'review',
                              selectedColor: Colors.amber.shade200,
                              onSelected: (_) {
                                setState(() => _jamoStatus[id] = 'review');
                                _recordStudySeconds(10);
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Explanation Cards
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🗣️ 近似中文發音提示（僅作初學參考，不能完全代表韓語發音）：',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD64045))),
                          const SizedBox(height: 4),
                          Text(item['approxZh'].toString(), style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 字形記憶技巧與發音要訣：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(item['mnemonic'].toString(), style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(item['pronunciationTip'].toString(), style: const TextStyle(fontSize: 12)),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('代表詞：${item['exampleWord']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.volume_up, size: 16),
                                label: const Text('讀單字'),
                                onPressed: () => _speak(item['exampleWord'].toString().split('(').first.split('／').first.trim()),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('例句：${item['exampleSentence']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.teal)),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.record_voice_over, size: 16),
                                label: const Text('讀例句'),
                                onPressed: () => _speak(item['exampleSentence'].toString().split('(').first.trim()),
                              ),
                            ],
                          ),
                          if ((item['confusable'] ?? '').toString().isNotEmpty)
                            Text('🔍 ${item['confusable']}',
                                style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Stroke Order Directions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✍️ 標準筆順與書寫方向（共 ${item['strokes']} 筆）：',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          ...directions.asMap().entries.map(
                                (e) => Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 12)),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // A9 Touch Handwriting Canvas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('A9. 韓文字母觸控手寫練習畫布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('已累計完成練習：$practiceCnt 次', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('描紅', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: false, label: Text('自由寫', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {traceMode},
                          onSelectionChanged: (s) => setModalState(() => traceMode = s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: HangulHandwritingCanvas(
                        key: ValueKey('${id}_$traceMode'),
                        targetJamo: item['jamo'].toString(),
                        expectedStrokes: (item['strokes'] as num).toInt(),
                        showTracingGuide: traceMode,
                        onPracticeSubmitted: (recordedStrokes) {
                          if (recordedStrokes == 0) {
                            setModalState(() => feedbackMsg = '⚠️ 尚未偵測到任何筆畫！請先在畫布上書寫後再提交。');
                            return;
                          }
                          setState(() {
                            _handwritingCounts[id] = (_handwritingCounts[id] ?? 0) + 1;
                            if (_jamoStatus[id] == null || _jamoStatus[id] == 'unlearned') {
                              _jamoStatus[id] = 'learned';
                            }
                          });
                          _recordStudySeconds(20);
                          _speak(speakTarget);
                          final expected = (item['strokes'] as num).toInt();
                          setModalState(() {
                            if (recordedStrokes == expected) {
                              feedbackMsg = '🎉 練習完成！筆畫數與標準一致（$recordedStrokes/$expected 筆），已自動標記為「已掌握」！';
                            } else {
                              feedbackMsg = '💡 已記錄練習次數！您寫了 $recordedStrokes 筆，標準筆順建議為 $expected 筆。';
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(feedbackMsg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),

                    // Prev / Next Navigation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('上一個字母'),
                          onPressed: () {
                            setModalState(() {
                              modalIdx = (modalIdx - 1 + _jamoList.length) % _jamoList.length;
                              feedbackMsg = '請用手指在上方畫布書寫韓文字母，完成後點擊「提交完成」。';
                            });
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('下一個字母'),
                          onPressed: () {
                            setModalState(() {
                              modalIdx = (modalIdx + 1) % _jamoList.length;
                              feedbackMsg = '請用手指在上方畫布書寫韓文字母，完成後點擊「提交完成」。';
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // A5: Interactive Unicode Hangul Syllable Combiner View
  Widget _buildSyllableCombinerView() {
    final code = ((_combChoIdx * 21) + _combJungIdx) * 28 + _combJongIdx + 0xAC00;
    final sylChar = String.fromCharCode(code);
    final rom = '${_choseongRom[_combChoIdx]}${_jungseongRom[_combJungIdx]}${_jongseongRom[_combJongIdx]}';
    final cho = _choseongList[_combChoIdx];
    final jung = _jungseongList[_combJungIdx];
    final jong = _jongseongList[_combJongIdx];
    final repSound = _jongseongRep[_combJongIdx];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('🧩 A5-1. 互動韓文音節方塊動態組字器',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    Chip(label: Text('已組字 $_combinerCount 次', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
                const Text('點選下方「1.初聲子音 ＋ 2.中聲母音 ＋ 3.終聲收音」，即時合成音節方塊並播放發音：',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1B365D), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B365D),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(sylChar, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '公式：$cho + $jung ${_combJongIdx > 0 ? "+ $jong" : "(無收音)"} = $sylChar',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (_showRomaji)
                              Text('羅馬拼音：${rom.isEmpty ? "a" : rom}',
                                  style: const TextStyle(color: Color(0xFFD64045), fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('收音代表音：$repSound', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => _speak(sylChar, rate: 0.24),
                                  child: const Text('🐢 特慢', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B365D),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.volume_up, size: 16),
                                  label: Text('發音 ($sylChar)', style: const TextStyle(fontSize: 12)),
                                  onPressed: () => _speak(sylChar),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('步驟 1：選擇初聲子音（초성 19個）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_choseongList.length, (idx) {
                    final sel = _combChoIdx == idx;
                    return InkWell(
                      onTap: () => _updateCombiner(cho: idx),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFF1B365D) : Colors.transparent,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_choseongList[idx],
                            style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : null)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('步驟 2：選擇中聲母音（중성 21個）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_jungseongList.length, (idx) {
                    final sel = _combJungIdx == idx;
                    return InkWell(
                      onTap: () => _updateCombiner(jung: idx),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? Colors.teal.shade700 : Colors.transparent,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_jungseongList[idx],
                            style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : null)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('步驟 3：選擇終聲收音（받침 27個 + 無收音）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_jongseongList.length, (idx) {
                    final sel = _combJongIdx == idx;
                    return InkWell(
                      onTap: () => _updateCombiner(jong: idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFD64045) : Colors.transparent,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_jongseongList[idx],
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : null)),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('📐 A5-2. 韓文音節方塊四大結構說明', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ..._structuresList.map((st) {
          final exList = List<String>.from(st['examples'] ?? []);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st['type'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('公式：${st['formula']}', style: const TextStyle(fontSize: 12, color: Color(0xFFD64045), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(st['desc'].toString(), style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: exList.map((ex) {
                      return ActionChip(
                        label: Text('$ex 🔊', style: const TextStyle(fontSize: 12)),
                        onPressed: () => _speak(ex.substring(0, 1)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        ..._coreSyllableSets.map((set) {
          final items = (set['items'] as List).cast<Map<String, dynamic>>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(set['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((it) {
                  return InkWell(
                    onTap: () => _speak(it['syl'].toString()),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(it['syl'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(it['comp'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (_showRomaji)
                            Text(it['romaji'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFFD64045), fontWeight: FontWeight.bold)),
                          Text(it['word'].toString(), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _updateCombiner({int? cho, int? jung, int? jong}) {
    setState(() {
      if (cho != null) _combChoIdx = cho;
      if (jung != null) _combJungIdx = jung;
      if (jong != null) _combJongIdx = jong;
      _combinerCount += 1;
    });
    final code = ((_combChoIdx * 21) + _combJungIdx) * 28 + _combJongIdx + 0xAC00;
    _speak(String.fromCharCode(code));
  }

  // A6: Batchim View
  Widget _buildBatchimView() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '⚓ A6. 收音（받침 Batchim）專項：韓文 27 種收音在字尾獨立發音時，全部歸併為 [ㄱ, ㄴ, ㄷ, ㄹ, ㅁ, ㅂ, ㅇ] 七大代表音！塞音收音一律「唯閉不破」。',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        ..._batchimRules.map((b) {
          final exList = (b['examples'] as List).cast<Map<String, dynamic>>();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('代表音：${b['repSound']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                      Chip(label: Text('字形：${b['writtenJamo']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  Text('👅 發音部位：${b['articulation']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 4),
                  Text(b['desc'].toString(), style: const TextStyle(fontSize: 12, height: 1.4)),
                  const Divider(),
                  ...exList.map((ex) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${ex['word']}  →  實際讀音：${ex['actual']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${_showRomaji ? "(${ex['romaji']}) " : ""}${ex['zh']}', style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.volume_up, color: Color(0xFF1B365D)),
                        onPressed: () => _speak(ex['word'].toString().split('/').first.trim()),
                      ),
                    );
                  }),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('⚠️ 常見發音錯誤：${b['commonError']}', style: const TextStyle(fontSize: 11, color: Color(0xFFD64045))),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // A7: 7 Phonological Rules View
  Widget _buildPhonologicalRulesView() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _phonologicalRules.map((rule) {
        final id = rule['id'].toString();
        final isDone = _completedRules.contains(id);
        final exList = (rule['examples'] as List).cast<Map<String, dynamic>>();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(rule['title'].toString(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                    ),
                    FilterChip(
                      label: Text(isDone ? '✅ 已掌握' : '標記已學', style: const TextStyle(fontSize: 11)),
                      selected: isDone,
                      onSelected: (_) {
                        setState(() {
                          if (isDone) {
                            _completedRules.remove(id);
                          } else {
                            _completedRules.add(id);
                          }
                        });
                        _recordStudySeconds(15);
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('📐 音變公式：${rule['formula']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Text(rule['explanation'].toString(), style: const TextStyle(fontSize: 12, height: 1.4)),
                const Divider(),
                ...exList.map((ex) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('字形：${ex['written']}  →  實際發音：${ex['actual']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${_showRomaji ? "${ex['romaji']} ｜ " : ""}${ex['zh']}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Text('🐢'),
                          onPressed: () => _speak(ex['written'].toString().split('/').first.trim(), rate: 0.24),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF1B365D)),
                          onPressed: () => _speak(ex['written'].toString().split('/').first.trim()),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('⚠️ 容易出錯的地方：${rule['pitfall']}', style: const TextStyle(fontSize: 11, color: Color(0xFFD64045))),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // A10: Pronunciation & Listening Trainer View
  void _initTrainerRound() {
    if (_jamoList.isEmpty) return;
    final rand = Random();
    _trainerJamoIndex = rand.nextInt(_jamoList.length);
    final target = _jamoList[_trainerJamoIndex];
    final pool = _jamoList.where((j) => j['id'] != target['id']).toList()..shuffle(rand);
    _trainerOptions = [target, ...pool.take(3)]..shuffle(rand);
    _trainerFeedback = '請點擊播放題目發音，再選出對應的韓文字母';
  }

  Widget _buildHangulTrainerView() {
    if (_jamoList.isEmpty) return const SizedBox.shrink();
    final target = _jamoList[_trainerJamoIndex];
    final speakTarget = (target['syllableForm'] ?? target['exampleWord'].toString().split('(').first).toString().trim();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🎙️ A10. 字母三速跟讀與聽音辨字訓練',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('下一題'),
                      onPressed: () {
                        setState(() => _initTrainerRound());
                        final nextT = _jamoList[_trainerJamoIndex];
                        final sp = (nextT['syllableForm'] ?? nextT['exampleWord'].toString().split('(').first).toString().trim();
                        _speak(sp);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B365D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('🔊 點擊播放題目韓語發音'),
                  onPressed: () => _speak(speakTarget),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => _speak(speakTarget, rate: 0.24), child: const Text('🐢 特慢 0.24x')),
                    OutlinedButton(onPressed: () => _speak(speakTarget, rate: 0.35), child: const Text('🎧 慢速 0.35x')),
                    OutlinedButton(onPressed: () => _speak(speakTarget, rate: 0.45), child: const Text('▶️ 標準 0.45x')),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: _trainerOptions.map((opt) {
                    return OutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (opt['id'] == target['id']) {
                            _trainerFeedback = '🎉 答對了！正確答案就是「${target['jamo']} (${target['name']})」！';
                            _speak(speakTarget);
                          } else {
                            _trainerFeedback = '❌ 再聽一次看看！提示：${target['pronunciationTip']}';
                          }
                        });
                      },
                      child: Text(
                        '${opt['jamo']} (${opt['exampleWord'].toString().split('(').first.trim()})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(_trainerFeedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B365D))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: 模組 B & C — 韓語雙軌數字與 19 類量詞 (Numbers & Counters)
  // ===========================================================================
  Map<String, String> _convertIntToSinoKorean(int n) {
    if (n < 0) return {'kr': '-', 'rom': '-'};
    if (n == 0) return {'kr': '영 (공)', 'rom': 'yeong (gong)'};
    const digitsKr = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
    const digitsRom = ['', 'il', 'i', 'sam', 'sa', 'o', 'yuk', 'chil', 'pal', 'gu'];

    Map<String, String> under10000(int val) {
      String kr = '';
      List<String> rom = [];
      final cheon = val ~/ 1000;
      final baek = (val % 1000) ~/ 100;
      final sip = (val % 100) ~/ 10;
      final il = val % 10;
      if (cheon > 0) {
        kr += '${cheon == 1 ? "" : digitsKr[cheon]}천';
        rom.add('${cheon == 1 ? "" : digitsRom[cheon]}cheon');
      }
      if (baek > 0) {
        kr += '${baek == 1 ? "" : digitsKr[baek]}백';
        rom.add('${baek == 1 ? "" : digitsRom[baek]}baek');
      }
      if (sip > 0) {
        kr += '${sip == 1 ? "" : digitsKr[sip]}십';
        rom.add('${sip == 1 ? "" : digitsRom[sip]}sip');
      }
      if (il > 0) {
        kr += digitsKr[il];
        rom.add(digitsRom[il]);
      }
      return {'kr': kr, 'rom': rom.join('-')};
    }

    final eok = n ~/ 100000000;
    final man = (n % 100000000) ~/ 10000;
    final rem = n % 10000;
    List<String> krParts = [];
    List<String> romParts = [];
    if (eok > 0) {
      final ep = under10000(eok);
      krParts.add('${ep['kr']}억');
      romParts.add('${ep['rom']}-eok');
    }
    if (man > 0) {
      if (man == 1) {
        krParts.add('만');
        romParts.add('man');
      } else {
        final mp = under10000(man);
        krParts.add('${mp['kr']}만');
        romParts.add('${mp['rom']}-man');
      }
    }
    if (rem > 0) {
      final rp = under10000(rem);
      krParts.add(rp['kr']!);
      romParts.add(rp['rom']!);
    }
    return {'kr': krParts.join(' '), 'rom': romParts.join(' ')};
  }

  Map<String, String> _convertIntToNativeKorean(int n, {bool beforeCounter = false}) {
    if (n <= 0) return {'kr': '영/공 (0用漢字數詞)', 'rom': 'yeong/gong'};
    if (n >= 100) {
      final s = _convertIntToSinoKorean(n);
      return {'kr': '${s['kr']} (100以上用漢字數詞)', 'rom': s['rom']!};
    }
    const tensKr = ['', '열', '스물', '서른', '마흔', '쉰', '예순', '일흔', '여든', '아흔'];
    const tensRom = ['', 'yeol', 'seumul', 'seoreun', 'maheun', 'swin', 'yesun', 'ilheun', 'yeodeun', 'aheun'];
    const unitsKr = ['', '하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉'];
    const unitsModKr = ['', '한', '두', '세', '네', '다섯', '여섯', '일곱', '여덟', '아홉'];
    const unitsRom = ['', 'hana', 'dul', 'set', 'net', 'daseot', 'yeoseot', 'ilgop', 'yeodeol', 'ahop'];
    const unitsModRom = ['', 'han', 'du', 'se', 'ne', 'daseot', 'yeoseot', 'ilgop', 'yeodeol', 'ahop'];

    if (beforeCounter && n == 20) return {'kr': '스무', 'rom': 'seumu'};
    final t = n ~/ 10;
    final u = n % 10;
    final tk = tensKr[t];
    final tr = tensRom[t];
    final uk = beforeCounter ? unitsModKr[u] : unitsKr[u];
    final ur = beforeCounter ? unitsModRom[u] : unitsRom[u];
    return {
      'kr': '$tk$uk',
      'rom': (tr.isNotEmpty && ur.isNotEmpty) ? '$tr-$ur' : '$tr$ur',
    };
  }

  void _startNumberListeningChallenge() {
    final samples = [
      {'label': '₩4,500 (사천오백 원)', 'kr': '사천오백 원입니다', 'zh': '4,500 韓元（漢字數詞）'},
      {'label': '₩35,000 (삼만 오천 원)', 'kr': '삼만 오천 원입니다', 'zh': '35,000 韓元（漢字數詞）'},
      {'label': '2杯 (두 잔)', 'kr': '아메리카노 두 잔 주세요', 'zh': '兩杯美式咖啡（固有數詞縮略形）'},
      {'label': '3點10分 (세 시 십 분)', 'kr': '지금 세 시 십 분이에요', 'zh': '三點十分（時固有、分漢字）'},
      {'label': '4個人 (네 명)', 'kr': '저희 네 명이에요', 'zh': '四個人（固有數詞縮略形）'},
      {'label': '6月15日 (유월 십오일)', 'kr': '유월 십오일이에요', 'zh': '6月15日（注意 6月讀 유월）'},
    ];
    final rand = Random();
    final target = samples[rand.nextInt(samples.length)];
    final others = samples.where((s) => s['label'] != target['label']).toList()..shuffle(rand);
    setState(() {
      _numListenTarget = target;
      _numListenOptions = [target, ...others.take(3)]..shuffle(rand);
      _numListenFeedback = '請聽韓語語音並選出正確答案';
    });
    _speak(target['kr']!);
  }

  Widget _buildNumbersAndCountersTab(BuildContext context) {
    final val = _converterInputNum.clamp(0, 999999999);
    final sino = _convertIntToSinoKorean(val);
    final nativeBase = _convertIntToNativeKorean(val, beforeCounter: false);
    final nativeMod = _convertIntToNativeKorean(val, beforeCounter: true);

    String phraseKr = '';
    String sysLabel = '';
    if (_converterContext == 'gae') {
      phraseKr = '${nativeMod['kr']!.split('(').first.trim()} 개';
      sysLabel = '固有數詞縮略形 ＋ 개 (個)';
    } else if (_converterContext == 'myeong') {
      phraseKr = '${nativeMod['kr']!.split('(').first.trim()} 명';
      sysLabel = '固有數詞縮略形 ＋ 명 (人)';
    } else if (_converterContext == 'jan') {
      phraseKr = '${nativeMod['kr']!.split('(').first.trim()} 잔';
      sysLabel = '固有數詞縮略形 ＋ 잔 (杯)';
    } else if (_converterContext == 'hour') {
      final hVal = ((val <= 0 ? 1 : val) - 1) % 12 + 1;
      phraseKr = '${_convertIntToNativeKorean(hVal, beforeCounter: true)['kr']} 시';
      sysLabel = '固有數詞縮略形 ＋ 시 ($hVal點鐘)';
    } else if (_converterContext == 'minute') {
      phraseKr = '${sino['kr']} 분';
      sysLabel = '漢字韓語數詞 ＋ 분 (分鐘)';
    } else if (_converterContext == 'age') {
      phraseKr = '${nativeMod['kr']!.split('(').first.trim()} 살 (正式：${sino['kr']} 세)';
      sysLabel = '口語：固有＋살 ／ 正式：漢字＋세';
    } else if (_converterContext == 'money') {
      phraseKr = '${sino['kr']} 원';
      sysLabel = '漢字韓語數詞 ＋ 원 (韓元)';
    } else if (_converterContext == 'month') {
      final mVal = ((val <= 0 ? 1 : val) - 1) % 12 + 1;
      phraseKr = mVal == 6 ? '유월 (6月)' : (mVal == 10 ? '시월 (10月)' : '${_convertIntToSinoKorean(mVal)['kr']}월 ($mVal月)');
      sysLabel = '漢字韓語數詞 ＋ 월 (注意 6月 유월、10月 시월)';
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Mode Switcher
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('🔢 B1-B4. 完整數字列表 (12單元)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _numCounterMode == 'units',
                onSelected: (_) => setState(() => _numCounterMode = 'units'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('⚖️ B3. 兩套數字情境比較表', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _numCounterMode == 'compare',
                onSelected: (_) => setState(() => _numCounterMode = 'compare'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('🍺 C. 19大類量詞與例句', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _numCounterMode == 'counters',
                onSelected: (_) => setState(() => _numCounterMode = 'counters'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // B4 Interactive Context-Aware Converter
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('🧮 B4. 情境式韓語雙系統數字即時轉換器',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD64045),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.headphones, size: 15),
                      label: const Text('聽力挑戰', style: TextStyle(fontSize: 11)),
                      onPressed: _startNumberListeningChallenge,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _numInputController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '輸入數字',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          setState(() => _converterInputNum = int.tryParse(v) ?? 0);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _converterContext,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '選擇使用情境',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'dual', child: Text('🔍 固有 vs 漢字雙對照', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'gae', child: Text('🍎 數量 (〜個 개)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'myeong', child: Text('👥 人數 (〜名 명)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'jan', child: Text('☕ 飲品 (〜杯 잔)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'hour', child: Text('🕒 時間 (〜點 시)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'minute', child: Text('⏱️ 時間 (〜分 분)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'age', child: Text('🎂 年齡 (〜살 vs 〜세)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'money', child: Text('💴 金額 (〜韓元 원)', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'month', child: Text('📅 月份 (〜月 월)', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) => setState(() => _converterContext = v ?? 'dual'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_converterContext == 'dual')
                  Column(
                    children: [
                      ListTile(
                        dense: true,
                        tileColor: Colors.blue.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text('① 固有數詞：${nativeBase['kr']} ${val >= 1 && val <= 99 ? "(接量詞：${nativeMod['kr']})" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: _showRomaji ? Text(nativeBase['rom']!, style: const TextStyle(fontSize: 11)) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF1B365D)),
                          onPressed: () => _speak(nativeBase['kr']!.split('(').first.trim()),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        dense: true,
                        tileColor: Colors.amber.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text('② 漢字數詞：${sino['kr']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: _showRomaji ? Text(sino['rom']!, style: const TextStyle(fontSize: 11)) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up, color: Colors.amber),
                          onPressed: () => _speak(sino['kr']!.split('(').first.trim()),
                        ),
                      ),
                    ],
                  )
                else
                  ListTile(
                    dense: true,
                    tileColor: Colors.teal.withOpacity(0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    title: Text('$sysLabel  →  $phraseKr',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.volume_up, size: 16),
                      label: const Text('發音'),
                      onPressed: () => _speak(phraseKr.split('(').first.trim()),
                    ),
                  ),
                if (_numListenTarget != null) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🎧 隨機價格／時間聽音挑戰：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextButton.icon(
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text('重播題目'),
                        onPressed: () => _speak(_numListenTarget!['kr'].toString()),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _numListenOptions.map((opt) {
                      return OutlinedButton(
                        onPressed: () {
                          setState(() {
                            if (opt['label'] == _numListenTarget!['label']) {
                              _numListenFeedback = '🎉 答對了！正是「${_numListenTarget!['kr']}」（${_numListenTarget!['zh']}）';
                            } else {
                              _numListenFeedback = '❌ 再聽一次！正確答案為：${_numListenTarget!['label']}';
                            }
                          });
                        },
                        child: Text('${opt['label']} — ${opt['zh']}', style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(_numListenFeedback, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD64045))),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Main Number / Comparison / Counter Views
        if (_numCounterMode == 'units') ..._buildNumberUnitsWidgets(),
        if (_numCounterMode == 'compare') _buildNumberComparisonWidget(),
        if (_numCounterMode == 'counters') ..._buildCountersWidgets(),
      ],
    );
  }

  List<Widget> _buildNumberUnitsWidgets() {
    final visibleCats = _selectedNumCatFilter == 'ALL'
        ? _numbersCategories
        : _numbersCategories.where((c) => c['id'] == _selectedNumCatFilter).toList();

    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('全部顯示 (${_numbersCategories.length}單元)', style: const TextStyle(fontSize: 11)),
                selected: _selectedNumCatFilter == 'ALL',
                onSelected: (_) => setState(() => _selectedNumCatFilter = 'ALL'),
              ),
            ),
            ..._numbersCategories.map((c) {
              final id = c['id'].toString();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c['title'].toString().split('（').first, style: const TextStyle(fontSize: 11)),
                  selected: _selectedNumCatFilter == id,
                  onSelected: (_) => setState(() => _selectedNumCatFilter = id),
                ),
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 8),
      if (_selectedSingleNumItem != null)
        Card(
          color: Colors.blue.shade50,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1B365D), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '【${_selectedSingleNumItem!['num']}】 ${_selectedSingleNumItem!['korean']}  ${_selectedSingleNumItem!['actualPron']}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Text('🐢'),
                          onPressed: () => _speak(
                            _selectedSingleNumItem!['korean'].toString().split('/').first.split('(').first.trim(),
                            rate: 0.24,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Color(0xFF1B365D)),
                          onPressed: () => _speak(
                            _selectedSingleNumItem!['korean'].toString().split('/').first.split('(').first.trim(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_showRomaji)
                  Text('羅馬拼音：${_selectedSingleNumItem!['romaji']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFD64045), fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('💡 說明：${_selectedSingleNumItem!['note']}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '🗣️ 例句：${_selectedSingleNumItem!['exampleKr']}（${_selectedSingleNumItem!['exampleZh']}）',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.record_voice_over, size: 15),
                      label: const Text('讀例句', style: TextStyle(fontSize: 11)),
                      onPressed: () => _speak(_selectedSingleNumItem!['exampleKr'].toString()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ...visibleCats.map((cat) {
        final catId = cat['id'].toString();
        final items = (cat['items'] as List).cast<Map<String, dynamic>>();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat['title'].toString(),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                Text(cat['description'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (_, idx) {
                    final item = items[idx];
                    final isIrr = item['irregular'] == true;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSingleNumItem = item;
                          if (!_completedNumberUnits.contains(catId)) {
                            _completedNumberUnits.add(catId);
                          }
                        });
                        _speak(item['korean'].toString().split('/').first.split('(').first.trim());
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isIrr ? Colors.red.withOpacity(0.06) : Colors.grey.withOpacity(0.06),
                          border: Border.all(
                            color: isIrr ? Colors.redAccent.shade100 : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    item['num'].toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isIrr ? const Color(0xFFD64045) : const Color(0xFF1B365D),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.volume_up, size: 13, color: Colors.grey),
                              ],
                            ),
                            Text(item['korean'].toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(item['actualPron'].toString(),
                                style: TextStyle(fontSize: 10, color: isIrr ? const Color(0xFFD64045) : Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (_showRomaji)
                              Text(item['romaji'].toString(),
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildNumberComparisonWidget() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚖️ B3. 固有韓語數詞 vs 漢字韓語數詞 使用情境完整比較',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ..._numSystemComparison.map((row) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row['situation'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('採用系統：${row['system']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD64045))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('範例：${row['example']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B365D))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 18, color: Color(0xFF1B365D)),
                          onPressed: () => _speak(row['example'].toString().split('(').first.trim()),
                        ),
                      ],
                    ),
                    Text('💡 ${row['note']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCountersWidgets() {
    return _countersList.map((cnt) {
      final table = (cnt['countTable'] as List).cast<Map<String, dynamic>>();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${cnt['name']}  [${cnt['korean']} · ${cnt['romaji']}]',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.volume_up, size: 15),
                    label: const Text('讀例句', style: TextStyle(fontSize: 11)),
                    onPressed: () => _speak(cnt['exampleKr'].toString()),
                  ),
                ],
              ),
              Text('搭配系統：${cnt['numberSystem']} ｜ 適用：${cnt['appliesTo']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 6),
              Text('📌 規則：${cnt['ruleNote']}', style: const TextStyle(fontSize: 12)),
              Text('⚠️ 提醒：${cnt['commonMistake']}', style: const TextStyle(fontSize: 12, color: Color(0xFFD64045))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: table.map((r) {
                  return InkWell(
                    onTap: () => _speak(r['k'].toString().split('(').first.split('/').first.trim()),
                    child: Container(
                      width: 98,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: r['irr'] == true ? Colors.red.withOpacity(0.06) : Colors.grey.withOpacity(0.08),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['n']} 🔊', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(r['k'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(r['actual'].toString(), style: const TextStyle(fontSize: 10, color: Color(0xFFD64045))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(),
              Text('🗣️ 情境 (${cnt['scenario']})：${cnt['exampleKr']} ${cnt['exampleActual']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
              Text('中文：${cnt['exampleZh']}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ===========================================================================
  // TAB 3: 模組 D — 日常生活會話 20 課 (Daily Conversations)
  // ===========================================================================
  Widget _buildConversationTab(BuildContext context) {
    if (_conversationsList.isEmpty) return const SizedBox.shrink();
    final conv = _conversationsList[_currentConvIndex];
    final convId = conv['id'].toString();
    final isCompleted = _completedLessons.contains(convId);
    final lines = (conv['lines'] as List).cast<Map<String, dynamic>>();
    final vocab = (conv['vocab'] as List).cast<Map<String, dynamic>>();
    final pq = conv['practiceQuestion'] as Map<String, dynamic>;
    final pqOptions = List<String>.from(pq['options'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Topic Dropdown Selector
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: DropdownButton<int>(
              value: _currentConvIndex,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: List.generate(_conversationsList.length, (idx) {
                final c = _conversationsList[idx];
                final done = _completedLessons.contains(c['id']);
                return DropdownMenuItem(
                  value: idx,
                  child: Text('${c['title']} ${done ? "✅" : ""}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                );
              }),
              onChanged: (v) {
                setState(() {
                  _currentConvIndex = v ?? 0;
                  _convPracticeFeedback = '';
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Lesson Header Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(conv['category'].toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: const Color(0xFF1B365D),
                    ),
                    const SizedBox(width: 6),
                    Chip(label: Text(conv['level'].toString(), style: const TextStyle(fontSize: 11))),
                  ],
                ),
                Text(conv['title'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('📍 使用情境：${conv['situation']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B365D),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('整課連續播放', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        final allKr = lines.map((l) => l['kr'].toString()).join(' ');
                        _speak(allKr);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: Icon(isCompleted ? Icons.check_circle : Icons.check_box_outline_blank,
                          color: isCompleted ? Colors.green : null),
                      label: Text(isCompleted ? '已完成本課' : '標記完成', style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          if (isCompleted) {
                            _completedLessons.remove(convId);
                          } else {
                            _completedLessons.add(convId);
                            _recordStudySeconds(45);
                          }
                        });
                        _saveAppState();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Dialogue Lines
        const Text('🗣️ 多輪情境對話（點擊可依三段語速播放或收藏句子）',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        ...lines.map((line) {
          final lineId = line['id'].toString();
          final isFav = _favorites.any((f) => f['id'] == lineId);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(line['speaker'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        visualDensity: VisualDensity.compact,
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _speak(line['kr'].toString(), rate: 0.24),
                            child: const Text('🐢特慢', style: TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () => _speak(line['kr'].toString(), rate: 0.35),
                            child: const Text('🎧慢速', style: TextStyle(fontSize: 11)),
                          ),
                          TextButton(
                            onPressed: () => _speak(line['kr'].toString(), rate: 0.45),
                            child: const Text('▶️標準', style: TextStyle(fontSize: 11)),
                          ),
                          IconButton(
                            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : null),
                            onPressed: () => _toggleFavorite(
                              id: lineId,
                              kr: line['kr'].toString(),
                              actual: line['actual'].toString(),
                              romaji: line['romaji'].toString(),
                              zh: line['zh'].toString(),
                              source: conv['title'].toString(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(line['kr'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('實際連音/音變：${line['actual']}',
                      style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600)),
                  if (_showRomaji)
                    Text('Romaji: ${line['romaji']}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD64045), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('中文：${line['zh']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 4),
                  Text('💡 要點：${line['note']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        }),

        // Vocabulary Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📘 重要詞彙解釋（點擊發音或收藏）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                ...vocab.asMap().entries.map((entry) {
                  final v = entry.value;
                  final vId = '${convId}_v${entry.key}';
                  final isFav = _favorites.any((f) => f['id'] == vId);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${v['kr']}  ${v['actual']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${_showRomaji ? "${v['romaji']} ｜ " : ""}${v['zh']}', style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 18, color: Color(0xFF1B365D)),
                          onPressed: () => _speak(v['kr'].toString().split('/').first.trim()),
                        ),
                        IconButton(
                          icon: Icon(isFav ? Icons.star : Icons.star_border, size: 18, color: isFav ? Colors.amber : null),
                          onPressed: () => _toggleFavorite(
                            id: vId,
                            kr: v['kr'].toString(),
                            actual: v['actual'].toString(),
                            romaji: v['romaji'].toString(),
                            zh: v['zh'].toString(),
                            source: conv['title'].toString(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Grammar & Formal vs Informal Notes
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📐 基本文法與常見錯誤提醒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(conv['grammarNote'].toString(), style: const TextStyle(fontSize: 12, height: 1.4)),
                const Divider(),
                const Text('🎩 正式敬語 vs 非正式朋友半語（반말）',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD64045))),
                const SizedBox(height: 4),
                Text(conv['formalVsInformal'].toString(), style: const TextStyle(fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // D2 Practice Question
        Card(
          color: Colors.amber.withOpacity(0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯 D2. 隨堂情境互動練習', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                Text(pq['prompt'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...pqOptions.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                        onPressed: () {
                          final correctIdx = (pq['correctIndex'] as num).toInt();
                          setState(() {
                            if (entry.key == correctIdx) {
                              _convPracticeFeedback = '🎉 答對了！${pq['explanation']}';
                              if (!_completedLessons.contains(convId)) {
                                _completedLessons.add(convId);
                                _recordStudySeconds(30);
                              }
                            } else {
                              _convPracticeFeedback = '❌ 再想一下！提示：${pq['explanation']}';
                            }
                          });
                        },
                        child: Text(entry.value, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  );
                }),
                if (_convPracticeFeedback.isNotEmpty)
                  Text(_convPracticeFeedback, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Prev / Next Lesson Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('上一課'),
              onPressed: () {
                setState(() {
                  _currentConvIndex = (_currentConvIndex - 1 + _conversationsList.length) % _conversationsList.length;
                  _convPracticeFeedback = '';
                });
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B365D),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('下一課'),
              onPressed: () {
                setState(() {
                  _currentConvIndex = (_currentConvIndex + 1) % _conversationsList.length;
                  _convPracticeFeedback = '';
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  void _toggleFavorite({
    required String id,
    required String kr,
    required String actual,
    required String romaji,
    required String zh,
    required String source,
  }) {
    setState(() {
      final idx = _favorites.indexWhere((f) => f['id'] == id);
      if (idx >= 0) {
        _favorites.removeAt(idx);
      } else {
        _favorites.add({
          'id': id,
          'kr': kr,
          'actual': actual,
          'romaji': romaji,
          'zh': zh,
          'source': source,
        });
      }
    });
    _saveAppState();
  }

  // ===========================================================================
  // TAB 4: 模組 E — 測驗 (13大題型)、SRS錯題本、收藏夾與真實統計
  // ===========================================================================
  void _startNewQuizSession(String moduleFilter, {bool notify = true}) {
    _quizFilterModule = moduleFilter;
    var pool = _quizQuestionsList;
    if (moduleFilter != 'ALL') {
      pool = pool.where((q) => q['module'] == moduleFilter).toList();
    }
    _activeQuizQuestions = List<Map<String, dynamic>>.from(pool);
    _activeQuizAnswers = {};
    _activeQuizSubmitted = false;
    if (notify) setState(() {});
  }

  void _submitQuizSession(BuildContext context) {
    if (_activeQuizQuestions.isEmpty) return;
    if (_activeQuizAnswers.length < _activeQuizQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('還有 ${_activeQuizQuestions.length - _activeQuizAnswers.length} 題尚未作答，請完成後再交卷！')),
      );
      return;
    }

    int correctCount = 0;
    final nowIso = DateTime.now().toIso8601String().substring(0, 10);

    setState(() {
      _activeQuizSubmitted = true;
      for (int i = 0; i < _activeQuizQuestions.length; i++) {
        final q = _activeQuizQuestions[i];
        final qId = q['id'].toString();
        final chosen = _activeQuizAnswers[i];
        final correctIdx = (q['correctIndex'] as num).toInt();

        if (chosen == correctIdx) {
          correctCount++;
          if (_mistakeBook.containsKey(qId)) {
            final rec = _mistakeBook[qId]!;
            final consec = ((rec['consecutiveCorrect'] as int?) ?? 0) + 1;
            final interval = consec == 1 ? 1 : (consec == 2 ? 3 : (consec == 3 ? 7 : ((rec['intervalDays'] as int?) ?? 7) * 2));
            final nextDate = DateTime.now().add(Duration(days: interval)).toIso8601String().substring(0, 10);
            rec['consecutiveCorrect'] = consec;
            rec['intervalDays'] = interval;
            rec['nextReviewIso'] = nextDate;
          }
        } else {
          if (!_mistakeBook.containsKey(qId)) {
            _mistakeBook[qId] = {
              'questionId': qId,
              'wrongCount': 1,
              'consecutiveCorrect': 0,
              'intervalDays': 1,
              'nextReviewIso': nowIso,
            };
          } else {
            final rec = _mistakeBook[qId]!;
            rec['wrongCount'] = ((rec['wrongCount'] as int?) ?? 1) + 1;
            rec['consecutiveCorrect'] = 0;
            rec['intervalDays'] = 1;
            rec['nextReviewIso'] = nowIso;
          }
        }
      }
      _totalQuizzesTaken += 1;
      _totalQuestionsAnswered += _activeQuizQuestions.length;
      _totalCorrectAnswers += correctCount;
    });
    _recordStudySeconds(_activeQuizQuestions.length * 10);
  }

  Widget _buildQuizAndStatsTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('📝 E2. 綜合測驗 (13題型)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _quizSubTab == 'test',
                  onSelected: (_) => setState(() => _quizSubTab = 'test'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text('🔄 E3. 錯題本與 SRS (${_mistakeBook.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _quizSubTab == 'mistakes',
                  onSelected: (_) => setState(() => _quizSubTab = 'mistakes'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text('⭐ 收藏夾 (${_favorites.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _quizSubTab == 'favorites',
                  onSelected: (_) => setState(() => _quizSubTab = 'favorites'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('📊 E4. 真實統計報表', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  selected: _quizSubTab == 'stats',
                  onSelected: (_) => setState(() => _quizSubTab = 'stats'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _buildQuizSubContent(context),
        ),
      ],
    );
  }

  Widget _buildQuizSubContent(BuildContext context) {
    if (_quizSubTab == 'mistakes') return _buildMistakeBookView();
    if (_quizSubTab == 'favorites') return _buildFavoritesView();
    if (_quizSubTab == 'stats') return _buildRealStatsView();

    if (_activeQuizQuestions.isEmpty && _quizQuestionsList.isNotEmpty) {
      _startNewQuizSession('ALL', notify: false);
    }

    int correctCount = 0;
    if (_activeQuizSubmitted) {
      for (int i = 0; i < _activeQuizQuestions.length; i++) {
        if (_activeQuizAnswers[i] == (_activeQuizQuestions[i]['correctIndex'] as num).toInt()) {
          correctCount++;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', '韓文字母', '數字教學', '量詞單位', '日常會話'].map((m) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  backgroundColor: _quizFilterModule == m ? const Color(0xFFD64045) : null,
                  label: Text(
                    m == 'ALL' ? '全部題型 (${_quizQuestionsList.length}題)' : m,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _quizFilterModule == m ? Colors.white : null),
                  ),
                  onPressed: () => _startNewQuizSession(m),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (_activeQuizSubmitted)
          Card(
            color: Colors.green.shade50,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '📊 測驗成績：答對 $correctCount / ${_activeQuizQuestions.length} 題（${((correctCount / _activeQuizQuestions.length) * 100).round()}%）\n答錯題目已自動排入 SRS 錯題本！',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _startNewQuizSession(_quizFilterModule),
                    child: const Text('重新測驗'),
                  ),
                ],
              ),
            ),
          ),
        ..._activeQuizQuestions.asMap().entries.map((entry) {
          final qIdx = entry.key;
          final q = entry.value;
          final options = List<String>.from(q['options'] ?? []);
          final chosen = _activeQuizAnswers[qIdx];
          final correctIdx = (q['correctIndex'] as num).toInt();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text('第 ${qIdx + 1} 題 · ${q['typeName']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B365D))),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: const Text('題目音訊', style: TextStyle(fontSize: 11)),
                        onPressed: () => _speak(q['targetAudio'].toString()),
                      ),
                    ],
                  ),
                  Text(q['prompt'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...options.asMap().entries.map((optEntry) {
                    final oIdx = optEntry.key;
                    final optText = optEntry.value;
                    Color? btnColor;
                    if (!_activeQuizSubmitted && chosen == oIdx) {
                      btnColor = Colors.blue.withOpacity(0.18);
                    } else if (_activeQuizSubmitted) {
                      if (oIdx == correctIdx) {
                        btnColor = Colors.green.withOpacity(0.22);
                      } else if (chosen == oIdx && oIdx != correctIdx) {
                        btnColor = Colors.red.withOpacity(0.22);
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: btnColor,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onPressed: () {
                            if (!_activeQuizSubmitted) {
                              setState(() => _activeQuizAnswers[qIdx] = oIdx);
                            }
                          },
                          child: Text(optText, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    );
                  }),
                  if (_activeQuizSubmitted)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: chosen == correctIdx ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chosen == correctIdx ? '✅ 答對了！' : '❌ 答錯了！正確答案：${options[correctIdx]}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text('💡 詳解：${q['explanation']}', style: const TextStyle(fontSize: 11)),
                          Text('📚 建議重溫：${q['reviewCourse']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
        if (!_activeQuizSubmitted)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD64045),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _submitQuizSession(context),
              child: const Text('✅ 提交測驗並查看詳解與成績', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
      ],
    );
  }

  Widget _buildMistakeBookView() {
    if (_mistakeBook.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('🎉 目前 SRS 錯題本是空的！\n在綜合測驗中答錯的題目會自動記錄於此並安排間隔重複複習。',
              textAlign: TextAlign.center),
        ),
      );
    }
    final entries = _mistakeBook.values.toList()
      ..sort((a, b) => ((b['wrongCount'] as int?) ?? 0).compareTo((a['wrongCount'] as int?) ?? 0));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: entries.map((rec) {
        final qId = rec['questionId'].toString();
        final q = _quizQuestionsList.firstWhere((item) => item['id'] == qId, orElse: () => {});
        if (q.isEmpty) return const SizedBox.shrink();
        final options = List<String>.from(q['options'] ?? []);
        final correctIdx = (q['correctIndex'] as num).toInt();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('累計答錯 ${rec['wrongCount']} 次 ｜ SRS間隔：${rec['intervalDays']}天',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD64045))),
                    TextButton(
                      onPressed: () {
                        setState(() => _mistakeBook.remove(qId));
                        _saveAppState();
                      },
                      child: const Text('✅ 移出錯題本', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                Text(q['prompt'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('正確答案：${options[correctIdx]}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('詳解：${q['explanation']}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFavoritesView() {
    if (_favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('⭐ 尚未收藏任何韓語單字或句子。\n您可在「日常會話」點擊星號加入收藏！', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _favorites.map((fav) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('${fav['kr']}  ${fav['actual']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${_showRomaji ? "${fav['romaji']}\n" : ""}${fav['zh']}（${fav['source']}）',
                style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF1B365D)),
                  onPressed: () => _speak(fav['kr'].toString()),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {
                    setState(() => _favorites.removeWhere((f) => f['id'] == fav['id']));
                    _saveAppState();
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRealStatsView() {
    final basicJamoTotal = _jamoList.where((j) => j['category'] == 'basic_consonant' || j['category'] == 'basic_vowel').length;
    final basicJamoLearned = _jamoList
        .where((j) => (j['category'] == 'basic_consonant' || j['category'] == 'basic_vowel') && _jamoStatus[j['id']] == 'learned')
        .length;
    final compVowelTotal = _jamoList.where((j) => j['category'] == 'compound_vowel').length;
    final compVowelLearned = _jamoList.where((j) => j['category'] == 'compound_vowel' && _jamoStatus[j['id']] == 'learned').length;
    final doubleConLearned = _jamoList.where((j) => j['category'] == 'double_consonant' && _jamoStatus[j['id']] == 'learned').length;
    final totalHandwriting = _handwritingCounts.values.fold<int>(0, (a, b) => a + b);
    final acc = _totalQuestionsAnswered == 0 ? 0.0 : (_totalCorrectAnswers / _totalQuestionsAnswered) * 100.0;
    final totalMin = (_totalStudySeconds / 60.0).toStringAsFixed(1);

    final statsCards = [
      {'val': '$basicJamoLearned / $basicJamoTotal', 'label': '基本子音與母音掌握'},
      {'val': '$compVowelLearned / $compVowelTotal (雙子音 $doubleConLearned/5)', 'label': '複合母音與雙子音'},
      {'val': '$_combinerCount 次', 'label': '音節方塊動態組字'},
      {'val': '${_completedRules.length} / 7 則', 'label': '收音與音變課程進度'},
      {'val': '${_completedNumberUnits.length} / 12 單元', 'label': '數字與量詞探索進度'},
      {'val': '${_completedLessons.length} / 20 課', 'label': '已完成會話課程數'},
      {'val': '${acc.toStringAsFixed(1)}%', 'label': '測驗平均正確率'},
      {'val': '$totalHandwriting 次', 'label': '手寫畫布練習次數'},
      {'val': '$totalMin 分鐘', 'label': '累計真實學習時間'},
      {'val': '$_streakDays 天', 'label': '連續學習日數'},
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '📊 E4 真實統計數據承諾：以下所有指標 100% 由您在本機的實際學習狀態、手寫次數、組字操作與測驗紀錄動態計算，絕無任何虛構預設數據。',
            style: TextStyle(fontSize: 12),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: statsCards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
          ),
          itemBuilder: (_, idx) {
            final st = statsCards[idx];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(st['val']!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B365D)),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(st['label']!, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // SETTINGS & RESET SHEET
  // ===========================================================================
  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚙️ 系統設定、無障礙字體縮放與進度管理',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('無障礙文字縮放比例：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      {'label': '標準 (100%)', 'val': 1.0},
                      {'label': '適中 (112%)', 'val': 1.12},
                      {'label': '大字 (122%)', 'val': 1.22},
                    ].map((opt) {
                      final v = (opt['val'] as num).toDouble();
                      final sel = (_fontScale - v).abs() < 0.02;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(opt['label'].toString(), style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            onSelected: (_) {
                              setState(() => _fontScale = v);
                              setSheetState(() {});
                              _saveAppState();
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '🔒 隱私與離線承諾：所有學習進度、手寫練習紀錄、錯題本與生字收藏皆儲存在本機 SharedPreferences，支援離線學習。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('🗑️ 重置所有本機學習紀錄'),
                      onPressed: () {
                        setState(() {
                          _jamoStatus.clear();
                          _handwritingCounts.clear();
                          _combinerCount = 0;
                          _completedRules.clear();
                          _completedNumberUnits.clear();
                          _completedLessons.clear();
                          _favorites.clear();
                          _mistakeBook.clear();
                          _totalQuizzesTaken = 0;
                          _totalQuestionsAnswered = 0;
                          _totalCorrectAnswers = 0;
                          _totalStudySeconds = 0;
                          _todayStudySeconds = 0;
                          _streakDays = 0;
                        });
                        _saveAppState();
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
