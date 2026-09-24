import 'package:flutter/material.dart';
import '../../models/cube_color.dart';
import '../../models/cube_state.dart';

class Cube2DNet extends StatelessWidget {
  final CubeState state;
  final Function(int index)? onFacetTap;

  const Cube2DNet({Key? key, required this.state, this.onFacetTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double blockSize = 24.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: blockSize * 3 + 6),
              _buildFace(0, blockSize),
              SizedBox(width: blockSize * 6 + 12),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFace(4, blockSize),
              const SizedBox(width: 3),
              _buildFace(2, blockSize),
              const SizedBox(width: 3),
              _buildFace(1, blockSize),
              const SizedBox(width: 3),
              _buildFace(5, blockSize),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: blockSize * 3 + 6),
              _buildFace(3, blockSize),
              SizedBox(width: blockSize * 6 + 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFace(int faceIndex, double blockSize) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (row) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (col) {
              int facetIdx = faceIndex * 9 + row * 3 + col;
              CubeColor color = state.facelets[facetIdx];
              return GestureDetector(
                onTap: onFacetTap != null ? () => onFacetTap!(facetIdx) : null,
                child: Container(
                  width: blockSize,
                  height: blockSize,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color.displayColor,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.black54, width: 0.8),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
