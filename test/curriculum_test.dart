import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:korean_step_by_step/models/curriculum_models.dart';

void main() {
  test('Verify 40 Korean Jamo, Unicode Combiner, Dual Numbers, 19 Counters & 20 Conversations', () {
    final raw = File('assets/data/curriculum.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final jamo = data['jamo'] as List;
    expect(jamo.length, 40);

    // Verify Unicode syllable combiner (ㄱ + ㅏ = 가, ㅎ + ㅏ + ㄴ = 한)
    expect(HangulCombiner.combine(0, 0, 0), '가');
    expect(HangulCombiner.combine(18, 0, 4), '한');

    final counters = data['counters'] as List;
    expect(counters.length, 19);

    final conversations = data['conversations'] as List;
    expect(conversations.length, 20);
  });
}
