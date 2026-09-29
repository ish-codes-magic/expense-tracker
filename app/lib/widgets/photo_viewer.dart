import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import 'nocturne_widgets.dart';

/// Opens a receipt photo full screen; pinch or double-tap to zoom in on small
/// print.
void showReceiptPhoto(BuildContext context, String path) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => _PhotoViewer(path: path),
  ));
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.path});

  final String path;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final _zoom = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final point = _doubleTap?.localPosition ?? Offset.zero;
    _zoom.value = _zoom.value.isIdentity()
        ? (Matrix4.identity()
          ..translateByDouble(-point.dx * 1.5, -point.dy * 1.5, 0, 1)
          ..scaleByDouble(2.5, 2.5, 1, 1))
        : Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Noc.bg,
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTapDown: (details) => _doubleTap = details,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _zoom,
              maxScale: 6,
              child: Center(child: Image.file(File(widget.path))),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CircleIconButton(icon: Ph.x, tooltip: 'Close', onPressed: () => Navigator.pop(context)),
          ),
        ),
      ]),
    );
  }
}
