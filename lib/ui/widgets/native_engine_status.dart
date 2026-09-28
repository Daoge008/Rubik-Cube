import 'package:flutter/material.dart';

import '../../core/native_bridge/native_selftest.dart';

/// A one line, on-device proof that the Flutter <-> C++ FFI link is alive.
///
/// The check is deliberately more than a "can I open the library" smoke test:
/// it solves a set of fixed scrambled states and compares the answers with the
/// ones measured on the host, so a broken pruning table or an arm64 specific
/// miscompile shows up here rather than in a wrong solution handed to a user.
///
/// Every result is also written to logcat, which means a device run can be
/// verified with `adb logcat` without anyone looking at the screen.
class NativeEngineStatusBanner extends StatefulWidget {
  const NativeEngineStatusBanner({Key? key}) : super(key: key);

  @override
  State<NativeEngineStatusBanner> createState() =>
      _NativeEngineStatusBannerState();
}

class _NativeEngineStatusBannerState extends State<NativeEngineStatusBanner> {
  NativeSelfTestResult? _result;
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    // After the first frame: the cold start builds both pruning tables inside
    // a synchronous FFI call, so running it during build would stall the very
    // first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final result = await runNativeSelfTest(
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );

    // Mirrored to logcat on purpose: `adb logcat -s flutter` is enough to
    // confirm or refute a device build.
    final summary = result.allPassed
        ? 'ALL PASSED'
        : 'FAILURES: ${result.failureCount}';
    debugPrint('=== rubik native self test ===');
    debugPrint(result.log.trimRight());
    debugPrint('=== $summary ===');

    if (!mounted) return;
    setState(() => _result = result);
  }

  void _showDetails() {
    final result = _result;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('原生引擎自检', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...(result?.checks ?? const <SelfTestCheck>[]).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          c.passed
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          size: 18,
                          color: c.passed
                              ? const Color(0xFF00E676)
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.detail,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
              if (result != null) ...[
                const Divider(color: Colors.white12),
                Text(
                  '冷启动（含建表） '
                  '${(result.coldStartMicros / 1000).toStringAsFixed(0)} ms\n'
                  'Kociemba 平均 '
                  '${(result.kociembaMicros / 1000 / kDeviceVectors.length).toStringAsFixed(0)} ms\n'
                  'CFOP 平均 '
                  '${(result.cfopMicros / 1000 / kDeviceVectors.length).toStringAsFixed(0)} ms',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final running = result == null;

    final Color color;
    final IconData icon;
    final String label;
    if (running) {
      color = Colors.white54;
      icon = Icons.memory_rounded;
      label = _total == 0 ? '原生引擎自检中…' : '原生引擎自检中… $_done/$_total';
    } else if (result.allPassed) {
      color = const Color(0xFF00E676);
      icon = Icons.memory_rounded;
      label = '原生引擎就绪';
    } else {
      color = Colors.redAccent;
      icon = Icons.memory_outlined;
      label = '原生引擎异常（${result.failureCount} 项）';
    }

    return InkWell(
      onTap: running ? null : _showDetails,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (running)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            if (!running) ...[
              const SizedBox(width: 6),
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.white38),
            ],
          ],
        ),
      ),
    );
  }
}
