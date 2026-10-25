import 'package:flutter/material.dart';

/// A9. 韓文字母觸控手寫描紅畫布（自我練習模式）
class HangulHandwritingCanvas extends StatefulWidget {
  final String targetJamo;
  final int expectedStrokes;
  final bool showTracingGuide;
  final ValueChanged<int> onPracticeSubmitted;

  const HangulHandwritingCanvas({
    super.key,
    required this.targetJamo,
    required this.expectedStrokes,
    this.showTracingGuide = true,
    required this.onPracticeSubmitted,
  });

  @override
  State<HangulHandwritingCanvas> createState() => _HangulHandwritingCanvasState();
}

class _HangulHandwritingCanvasState extends State<HangulHandwritingCanvas> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;

  void _clear() => setState(() => _strokes.clear());
  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('自我練習模式 — 目前筆畫：${_strokes.length} / ${widget.expectedStrokes}'),
        const SizedBox(height: 8),
        GestureDetector(
          onPanStart: (d) {
            setState(() {
              _currentStroke = [d.localPosition];
              _strokes.add(_currentStroke!);
            });
          },
          onPanUpdate: (d) {
            setState(() => _currentStroke?.add(d.localPosition));
          },
          onPanEnd: (_) => _currentStroke = null,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF1B365D), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: _HangulPainter(
                strokes: _strokes,
                targetJamo: widget.targetJamo,
                showTracing: widget.showTracingGuide,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(onPressed: _undo, child: const Text('復原一筆')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _clear, child: const Text('清除重寫')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => widget.onPracticeSubmitted(_strokes.length),
              child: const Text('提交完成'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HangulPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final String targetJamo;
  final bool showTracing;

  _HangulPainter({
    required this.strokes,
    required this.targetJamo,
    required this.showTracing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showTracing) {
      final tp = TextPainter(
        text: TextSpan(
          text: targetJamo,
          style: TextStyle(
            fontSize: 170,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B365D).withOpacity(0.14),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
    }

    final paint = Paint()
      ..color = const Color(0xFF1B365D)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HangulPainter oldDelegate) => true;
}
