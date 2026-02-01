import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SketchCanvas extends StatefulWidget {
  final SignatureController controller;

  const SketchCanvas({super.key, required this.controller});

  @override
  State<SketchCanvas> createState() => _SketchCanvasState();
}

class _SketchCanvasState extends State<SketchCanvas> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Transparent to overlay on paper
      child: Signature(
        controller: widget.controller,
        backgroundColor: Colors.transparent,
        height:
            300, // Fixed height area for sketching for now, or could occupy full remaining space
      ),
    );
  }
}
