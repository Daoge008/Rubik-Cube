import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import 'solver_screen.dart';

class ScanScreen extends StatefulWidget {
  final SolveMode mode;
  const ScanScreen({Key? key, required this.mode}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  int _scannedFaces = 0;

  void _onFaceConfirmed() {
    setState(() {
      _scannedFaces = (_scannedFaces + 1).clamp(0, 6);
    });
    if (_scannedFaces == 6) {
      _startSolve();
    }
  }

  void _startSolve() {
    final demo = CubeState.fromSingmaster(
        "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SolverScreen(initialState: demo, mode: widget.mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('连续扫描 ($_scannedFaces/6 面)'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              '在镜头前自由旋转魔方\nYOLO 自动锁定各面并提取色彩',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
              ),
              onPressed: _onFaceConfirmed,
              child: Text('模拟扫描并记录第 ${_scannedFaces + 1} 面'),
            ),
          ],
        ),
      ),
    );
  }
}
