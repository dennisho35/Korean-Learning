import 'dart:convert';
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
  bool _isDarkMode = false;
  bool _showRomaji = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _tts.initialize();
    final jsonStr = await rootBundle.loadString('assets/data/curriculum.json');
    setState(() {
      _curriculum = jsonDecode(jsonStr) as Map<String, dynamic>;
    });
  }

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
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B365D),
          foregroundColor: Colors.white,
          title: const Text('韓語一步通 Korean Step-by-Step'),
          actions: [
            TextButton(
              onPressed: () => setState(() => _showRomaji = !_showRomaji),
              child: Text(
                _showRomaji ? '拼音:顯示' : '拼音:隱藏',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(40),
            child: Container(
              color: const Color(0xFF162D4F),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('語速：', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  _speedBtn('🐢 特慢 0.24x', 0.24),
                  const SizedBox(width: 6),
                  _speedBtn('🎧 初學 0.35x', 0.35),
                  const SizedBox(width: 6),
                  _speedBtn('▶️ 標準 0.45x', 0.45),
                ],
              ),
            ),
          ),
        ),
        body: _curriculum == null
            ? const Center(child: CircularProgressIndicator())
            : _buildCurrentTab(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (idx) => setState(() => _currentTab = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.font_download), label: '韓文字母'),
            NavigationDestination(icon: Icon(Icons.pin), label: '數字與量詞'),
            NavigationDestination(icon: Icon(Icons.chat), label: '日常會話'),
            NavigationDestination(icon: Icon(Icons.quiz), label: '測驗與複習'),
          ],
        ),
      ),
    );
  }

  Widget _speedBtn(String label, double rate) {
    final active = (_tts.currentRate - rate).abs() < 0.02;
    return GestureDetector(
      onTap: () => setState(() => _tts.setSpeedTier(rate)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD64045) : Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCurrentTab() {
    final jamoList = (_curriculum!['jamo'] as List).cast<Map<String, dynamic>>();
    if (_currentTab == 0) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: jamoList.length,
        itemBuilder: (ctx, i) {
          final item = JamoItem.fromJson(jamoList[i]);
          return Card(
            child: ListTile(
              leading: Text(item.jamo, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              title: Text('${item.name}  ${_showRomaji ? "[${item.romaji}]" : ""}'),
              subtitle: Text('${item.approxZh}\n例詞：${item.exampleWord}'),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _tts.speak(item.exampleWord.split('(').first),
              ),
            ),
          );
        },
      );
    }
    return const Center(child: Text('完整資料已載入於 assets/data/curriculum.json'));
  }
}
