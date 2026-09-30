import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/challenge_record_service.dart';
import '../../core/sound_service.dart';
import '../../models/cube_state.dart';
import '../widgets/cube_3d.dart';

enum ChallengeStatus {
  inspecting, // Randomly scrambled, auto-rotating to show all faces
  running,    // Timer is ticking, player is solving
  completed,  // Solved! Victory dialog shown
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final GlobalKey<InteractiveCube3DState> _cubeKey = GlobalKey<InteractiveCube3DState>();

  ChallengeStatus _status = ChallengeStatus.inspecting;
  late CubeState _cubeState;
  String _currentScramble = '';
  int _moveCount = 0;

  // Stopwatch & high frequency timer
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickerTimer;
  int _elapsedMilliseconds = 0;

  // Personal Best
  int? _personalBestMs;

  @override
  void initState() {
    super.initState();
    _loadPB();
    _startNewInspection();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadPB() async {
    final pb = await ChallengeRecordService.instance.getPersonalBestTimeMs();
    if (mounted) {
      setState(() => _personalBestMs = pb);
    }
  }

  void _startNewInspection() {
    _tickerTimer?.cancel();
    _stopwatch.reset();
    _elapsedMilliseconds = 0;
    _moveCount = 0;

    final res = CubeState.generateScramble(moveCount: 22);
    setState(() {
      _cubeState = res.state;
      _currentScramble = res.scramble;
      _status = ChallengeStatus.inspecting;
    });

    _cubeKey.currentState?.resetCamera();
  }

  void _onStartChallenge() {
    if (_status != ChallengeStatus.inspecting) return;

    HapticFeedback.heavyImpact();
    CubeSoundService.instance.playTurn();

    setState(() {
      _status = ChallengeStatus.running;
      _moveCount = 0;
      _elapsedMilliseconds = 0;
    });

    // Reset camera to comfortable solving perspective
    _cubeKey.currentState?.resetCamera(yaw: 0.65, pitch: -0.45);

    _stopwatch.reset();
    _stopwatch.start();

    // 16ms timer (~60fps centisecond update)
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted && _status == ChallengeStatus.running) {
        setState(() {
          _elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
        });
      }
    });
  }

  Future<void> _onMoveApplied(String move) async {
    if (_status != ChallengeStatus.running) return;

    setState(() {
      _cubeState = _cubeState.applyMove(move);
      _moveCount++;
    });

    if (_cubeState.isSolved) {
      _stopwatch.stop();
      _tickerTimer?.cancel();
      _elapsedMilliseconds = _stopwatch.elapsedMilliseconds;

      final tps = _elapsedMilliseconds > 0
          ? (_moveCount / (_elapsedMilliseconds / 1000.0))
          : 0.0;

      final record = ChallengeRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timeMs: _elapsedMilliseconds,
        moves: _moveCount,
        tps: double.parse(tps.toStringAsFixed(2)),
        date: DateTime.now(),
        scramble: _currentScramble,
      );

      final isNewPB = await ChallengeRecordService.instance.saveRecord(record);
      await _loadPB();

      if (mounted) {
        setState(() {
          _status = ChallengeStatus.completed;
        });
        HapticFeedback.vibrate();
        CubeSoundService.instance.playComplete();
        _showVictoryDialog(record, isNewPB);
      }
    }
  }

  String _formatMs(int ms) {
    final totalSec = ms / 1000.0;
    final minutes = totalSec ~/ 60;
    final seconds = (totalSec % 60).floor();
    final centis = ((ms % 1000) / 10).floor();
    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
    }
    return '${seconds.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
  }

  void _showVictoryDialog(ChallengeRecord record, bool isNewPB) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isNewPB ? const Color(0xFFFFD600) : const Color(0xFF00E676),
              width: 1.5,
            ),
          ),
          title: Column(
            children: [
              Icon(
                isNewPB ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                color: isNewPB ? const Color(0xFFFFD600) : const Color(0xFF00E676),
                size: 56,
              ),
              const SizedBox(height: 8),
              Text(
                isNewPB ? '🎉 新纪录达成！' : '🎉 挑战成功！',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              if (isNewPB) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '🏆 NEW PERSONAL BEST',
                    style: TextStyle(color: Color(0xFFFFD600), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatMs(record.timeMs),
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('总步数', '${record.moves} 步'),
                    Container(width: 1, height: 28, color: Colors.white12),
                    _statItem('平均转速', '${record.tps} TPS'),
                  ],
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showHistorySheet();
              },
              child: const Text('排行榜', style: TextStyle(color: Color(0xFF40C4FF))),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('返回'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startNewInspection();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('再来一局', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showHistorySheet() async {
    final list = await ChallengeRecordService.instance.getHistory(limit: 15);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.leaderboard_rounded, color: Color(0xFFFFD600), size: 22),
                        SizedBox(width: 8),
                        Text(
                          '个人复原挑战榜',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text('暂无挑战成绩，快去挑战一局吧！', style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, idx) {
                        final item = list[idx];
                        final isTop = idx == 0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isTop
                                  ? const Color(0xFFFFD600).withValues(alpha: 0.2)
                                  : Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: isTop ? const Color(0xFFFFD600) : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                item.formattedTime,
                                style: TextStyle(
                                  color: isTop ? const Color(0xFFFFD600) : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isTop) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('PB', style: TextStyle(color: Color(0xFFFFD600), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${item.moves}步 · ${item.tps} TPS · ${item.date.month}月${item.date.day}日',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveTPS = _elapsedMilliseconds > 0
        ? (_moveCount / (_elapsedMilliseconds / 1000.0)).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: AppBar(
        title: const Text('⚡ 极速复原挑战'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_rounded, color: Color(0xFFFFD600)),
            tooltip: '历史排行榜',
            onPressed: _showHistorySheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Status & Timer Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  if (_status == ChallengeStatus.inspecting) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F51B5).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF8C9EFF), width: 1.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_red_eye_rounded, color: Color(0xFF8C9EFF), size: 16),
                          SizedBox(width: 6),
                          Text(
                            '观察阶段 · 360° 自动全貌展示中',
                            style: TextStyle(color: Color(0xFF8C9EFF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '00.00',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E676), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFF00E676)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '步数: $_moveCount 步 · 转速: $liveTPS TPS',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatMs(_elapsedMilliseconds),
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],

                  if (_personalBestMs != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '个人最佳纪录 (PB): ${_formatMs(_personalBestMs!)}',
                      style: const TextStyle(color: Color(0xFFFFD600), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),

            // 3D Cube Stage
            Expanded(
              child: Center(
                child: InteractiveCube3D(
                  key: _cubeKey,
                  state: _cubeState,
                  size: 300,
                  interactive: _status == ChallengeStatus.running,
                  allowFaceTurns: _status == ChallengeStatus.running,
                  autoRotate: _status == ChallengeStatus.inspecting,
                  autoRotateSpeed: 0.55,
                  onMoveApplied: _onMoveApplied,
                ),
              ),
            ),

            // Gesture guidance tip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status == ChallengeStatus.inspecting
                    ? '准备好后点击下方开始，挑战模块不提供求解'
                    : '👆 单指转动魔方 · ✌️ 双指调整视角',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _status == ChallengeStatus.inspecting
                  ? Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle_rounded),
                          label: const Text('换个打乱'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _startNewInspection,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, size: 28),
                            label: const Text(
                              '开始挑战',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            onPressed: _onStartChallenge,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('放弃并重新开始'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _startNewInspection,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
