import 'cube_color.dart';

class CubeState {
  final List<CubeColor> facelets;

  CubeState(this.facelets) {
    assert(facelets.length == 54, 'Cube state must contain exactly 54 facelets');
  }

  factory CubeState.solved() {
    return CubeState(List.generate(54, (i) {
      if (i < 9) return CubeColor.white;
      if (i < 18) return CubeColor.red;
      if (i < 27) return CubeColor.green;
      if (i < 36) return CubeColor.yellow;
      if (i < 45) return CubeColor.orange;
      return CubeColor.blue;
    }));
  }

  factory CubeState.fromSingmaster(String s) {
    if (s.length != 54) {
      throw ArgumentError('Singmaster string must be 54 chars');
    }
    return CubeState(s.split('').map((c) => CubeColor.fromNotation(c)).toList());
  }

  String toSingmaster() {
    return facelets.map((c) => c.notation).join();
  }

  CubeState copyWithFacet(int index, CubeColor color) {
    final newList = List<CubeColor>.from(facelets);
    newList[index] = color;
    return CubeState(newList);
  }

  Map<CubeColor, int> getColorCounts() {
    final counts = <CubeColor, int>{};
    for (var c in CubeColor.values) {
      counts[c] = 0;
    }
    for (var c in facelets) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return counts;
  }
}
