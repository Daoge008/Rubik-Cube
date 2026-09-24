import 'package:flutter/material.dart';
import 'core/native_bridge/rubik_ffi_bridge.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The native pipeline must be initialized before any handle based FFI call
  // is made; otherwise every scanner/validator call is a silent no-op.
  final engine = RubikFfiBridge.instance;
  if (!engine.initPipeline()) {
    debugPrint('Native pipeline unavailable: ${engine.pipelineError}');
  } else {
    debugPrint('Native pipeline ready: librubik_core.so loaded.');
  }

  runApp(const RubikCubeApp());
}

class RubikCubeApp extends StatelessWidget {
  const RubikCubeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rubik AR Solver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12121E),
        primaryColor: const Color(0xFF00E676),
      ),
      home: const HomeScreen(),
    );
  }
}
