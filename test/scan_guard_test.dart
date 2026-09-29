import 'package:flutter_test/flutter_test.dart';
import 'package:rubik_cube_solver/core/vision/scanner_service.dart';
import 'package:rubik_cube_solver/core/native_bridge/rubik_ffi_bridge.dart';

void main() {
  group('Scan Guard and Assembly Tests', () {
    test('ScannerService starts with 0 faces and null scannedState', () {
      final scanner = ScannerService();
      scanner.startScanning();

      expect(scanner.scannedFacesCount, 0);
      expect(scanner.scannedState, isNull);
      expect(scanner.isComplete, isFalse);
      expect(scanner.assemblyState, ScanAssemblyState.scanning);
    });

    test('ScannerService syncFromNative resets scannedState if faces < 6', () {
      final scanner = ScannerService();
      scanner.syncFromNative();

      // With engine not ready or faces < 6, scannedState must remain null
      if (scanner.scannedFacesCount < 6) {
        expect(scanner.scannedState, isNull);
        expect(scanner.isComplete, isFalse);
      }
    });
  });
}
