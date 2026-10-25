class JamoItem {
  final String id;
  final int order;
  final String category;
  final String row;
  final String jamo;
  final String name;
  final String romaji;
  final String approxZh;
  final int strokes;
  final String mnemonic;
  final String pronunciationTip;
  final String exampleWord;
  final String exampleSentence;
  final List<String> directions;
  final String confusable;

  JamoItem({
    required this.id,
    required this.order,
    required this.category,
    required this.row,
    required this.jamo,
    required this.name,
    required this.romaji,
    required this.approxZh,
    required this.strokes,
    required this.mnemonic,
    required this.pronunciationTip,
    required this.exampleWord,
    required this.exampleSentence,
    required this.directions,
    required this.confusable,
  });

  factory JamoItem.fromJson(Map<String, dynamic> json) {
    return JamoItem(
      id: json['id'] as String,
      order: json['order'] as int,
      category: json['category'] as String,
      row: json['row'] as String,
      jamo: json['jamo'] as String,
      name: json['name'] as String,
      romaji: json['romaji'] as String,
      approxZh: json['approxZh'] as String,
      strokes: json['strokes'] as int,
      mnemonic: json['mnemonic'] as String,
      pronunciationTip: json['pronunciationTip'] as String,
      exampleWord: json['exampleWord'] as String,
      exampleSentence: json['exampleSentence'] as String,
      directions: List<String>.from(json['directions'] ?? []),
      confusable: json['confusable'] as String? ?? '',
    );
  }
}

/// Real Unicode Hangul Syllable Block Combiner (0xAC00 Formula)
class HangulCombiner {
  static const List<String> choseong = [
    'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];
  static const List<String> jungseong = [
    'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ'
  ];
  static const List<String> jongseong = [
    '','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ','ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ','ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ'
  ];

  static String combine(int choIdx, int jungIdx, int jongIdx) {
    final int code = ((choIdx * 21) + jungIdx) * 28 + jongIdx + 0xAC00;
    return String.fromCharCode(code);
  }
}
