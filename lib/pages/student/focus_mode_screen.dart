import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'student_theme.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  Timer? _timer;
  int _totalSeconds = 25 * 60;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  String _activeMode = 'pomodoro';

  final List<String> _quotes = [
    'Học không phải là con đường duy nhất, nhưng học là con đường nhanh nhất để đi đến thành công.',
    'Bắt đầu từ nơi bạn đứng. Sử dụng những gì bạn có. Làm những gì bạn có thể.',
    'Đừng để ngày hôm nay trôi qua mà không học được điều gì mới.',
    'Thành công là tổng hợp của những nỗ lực nhỏ bé, lặp đi lặp lại ngày này qua ngày khác.',
    'Tập trung là chìa khóa mở ra mọi cánh cửa của tri thức.',
  ];
  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = _quotes[0];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _pauseTimer();
        _showFinishedNotification();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() {
      _secondsRemaining = _totalSeconds;
    });
  }

  void _setMode(String mode) {
    _pauseTimer();
    setState(() {
      _activeMode = mode;
      if (mode == 'pomodoro') {
        _totalSeconds = 25 * 60;
      } else if (mode == 'short') {
        _totalSeconds = 5 * 60;
      } else if (mode == 'long') {
        _totalSeconds = 15 * 60;
      }
      _secondsRemaining = _totalSeconds;
      _currentQuote = _quotes[DateTime.now().millisecond % _quotes.length];
    });
  }

  void _showFinishedNotification() {
    final colors = StudentThemeScope.colorsOf(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Row(
          children: [
            Icon(LucideIcons.sparkles, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Hoan thanh phien!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          _activeMode == 'pomodoro'
              ? 'Tuyệt vời ! Bạn đã hoàn thành 25 phút tập trung. Hãy nghỉ ngơi một chút trước khi tiếp tục học.'
              : 'Đã hết thời gian nghỉ. Hãy quay lại học tập để duy trì sự tập trung.',
          style: TextStyle(fontSize: 11, color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_activeMode == 'pomodoro') {
                _setMode('short');
              } else {
                _setMode('pomodoro');
              }
            },
            child: const Text(
              'Tiếp tục học',
              style: TextStyle(
                color: Colors.indigoAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsRemaining / _totalSeconds;
    final colors = StudentThemeScope.colorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text(
          'Che do tap trung',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(
                  'pomodoro',
                  'Pomodoro (25m)',
                  Colors.pinkAccent,
                ),
                const SizedBox(width: 8),
                _buildModeButton('short', 'Nghỉ ngắn (5m)', Colors.tealAccent),
                const SizedBox(width: 8),
                _buildModeButton('long', 'Nghỉ dài (15m)', Colors.blueAccent),
              ],
            ),
            const SizedBox(height: 48),
            CircularPercentIndicator(
              radius: 110,
              lineWidth: 12,
              percent: progress,
              center: Text(
                _formatTime(_secondsRemaining),
                style: GoogleFonts.firaCode(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: _activeMode == 'pomodoro'
                  ? Colors.pinkAccent
                  : _activeMode == 'short'
                  ? Colors.tealAccent
                  : Colors.blueAccent,
              backgroundColor: colors.overlay(0.08),
              animation: false,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.quote,
                    color: Colors.indigoAccent,
                    size: 16,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentQuote,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: colors.textMuted,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _resetTimer,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      LucideIcons.rotateCcw,
                      color: colors.text,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: _isRunning ? _pauseTimer : _startTimer,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _activeMode == 'pomodoro'
                          ? Colors.pinkAccent
                          : _activeMode == 'short'
                          ? Colors.tealAccent
                          : Colors.blueAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_activeMode == 'pomodoro'
                                      ? Colors.pinkAccent
                                      : _activeMode == 'short'
                                      ? Colors.tealAccent
                                      : Colors.blueAccent)
                                  .withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? LucideIcons.pause : LucideIcons.play,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, Color color) {
    final isSelected = _activeMode == mode;
    final colors = StudentThemeScope.colorsOf(context);
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : colors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : colors.textSubtle,
          ),
        ),
      ),
    );
  }
}
