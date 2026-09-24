import 'package:flutter/material.dart';
import '../../core/native_bridge/rubik_ffi_bridge.dart';

/// A one line, on-device proof that the Flutter <-> C++ FFI link is alive.
///
/// Previously the native pipeline handle was never created, which made every
/// scanner/validator call a silent no-op. This widget performs a small self
/// test at build time so that failure is loud instead of invisible.
class NativeEngineStatusBanner extends StatefulWidget {
  const NativeEngineStatusBanner({Key? key}) : super(key: key);

  @override
  State<NativeEngineStatusBanner> createState() =>
      _NativeEngineStatusBannerState();
}

class _NativeEngineStatusBannerState extends State<NativeEngineStatusBanner> {
  late final List<_EngineCheck> _checks;
  late final bool _allPassed;

  @override
  void initState() {
    super.initState();
    _checks = _runSelfTest();
    _allPassed = _checks.every((c) => c.passed);
  }

  static const String _solvedFacelets =
      'UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB';

  List<_EngineCheck> _runSelfTest() {
    final engine = RubikFfiBridge.instance;
    final checks = <_EngineCheck>[];

    checks.add(_EngineCheck(
      label: '原生库 librubik_core.so',
      passed: engine.isLoaded,
      detail: engine.isLoaded
          ? '已加载，FFI 符号全部解析成功'
          : (engine.loadError ?? '加载失败，原因未知'),
    ));

    checks.add(_EngineCheck(
      label: '管线句柄 init_cube_pipeline',
      passed: engine.isPipelineInitialized,
      detail: engine.isPipelineInitialized
          ? '已创建上下文，扫描 / 校验 / 跳步接口均可用'
          : (engine.pipelineError ?? '未初始化，相关接口会静默失效'),
    ));

    if (!engine.isLoaded) {
      checks.add(const _EngineCheck(
        label: '状态校验 validate()',
        passed: false,
        detail: '已跳过：原生库未加载',
      ));
      checks.add(const _EngineCheck(
        label: '求解内核 solve()',
        passed: false,
        detail: '已跳过：原生库未加载',
      ));
      return checks;
    }

    final validationError = engine.validate(_solvedFacelets);
    checks.add(_EngineCheck(
      label: '状态校验 validate()',
      passed: validationError == null,
      detail: validationError ?? '已还原状态通过颜色计数与 4 项守恒校验',
    ));

    final solution = engine.solveKociemba(_solvedFacelets);
    checks.add(_EngineCheck(
      label: '求解内核 solve()',
      passed: solution == 'SOLVED',
      detail: solution == 'SOLVED' ? '正确识别为已还原状态' : solution,
    ));

    return checks;
  }

  void _showDetails() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('原生引擎自检', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _checks
                .map((c) => Padding(
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
                    ))
                .toList(),
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
    final color = _allPassed ? const Color(0xFF00E676) : Colors.redAccent;
    return InkWell(
      onTap: _showDetails,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _allPassed ? Icons.memory_rounded : Icons.memory_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              _allPassed ? '原生引擎就绪' : '原生引擎异常',
              style: TextStyle(color: color, fontSize: 12),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline_rounded,
                size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _EngineCheck {
  const _EngineCheck({
    required this.label,
    required this.passed,
    required this.detail,
  });

  final String label;
  final bool passed;
  final String detail;
}
