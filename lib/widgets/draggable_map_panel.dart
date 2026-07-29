import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loadr/widgets/map_sheet_sizes.dart';

class DraggableMapPanel extends StatefulWidget {
  final Widget child;
  final double collapsedPeekHeight;
  final double maxHeightFactor;

  const DraggableMapPanel({
    super.key,
    required this.child,
    this.collapsedPeekHeight = 96,
    this.maxHeightFactor = kMapPanelMaxHeightFactor,
  });

  @override
  State<DraggableMapPanel> createState() => _DraggableMapPanelState();
}

class _DraggableMapPanelState extends State<DraggableMapPanel> {
  final _panelKey = GlobalKey();
  double _panelHeight = 0;
  double _dragOffset = 0;

  double _maxOffset([double? panelHeight]) {
    return math.max(
      0,
      (panelHeight ?? _panelHeight) - widget.collapsedPeekHeight,
    );
  }

  void _measurePanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _panelKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox) return;
      final nextHeight = renderObject.size.height;
      final nextMaxOffset = _maxOffset(nextHeight);
      if ((nextHeight - _panelHeight).abs() < 0.5 &&
          _dragOffset <= nextMaxOffset) {
        return;
      }
      setState(() {
        _panelHeight = nextHeight;
        _dragOffset = _dragOffset.clamp(0.0, nextMaxOffset);
      });
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final nextMaxOffset = _maxOffset();
    if (nextMaxOffset <= 0) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(
        0.0,
        nextMaxOffset,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final nextMaxOffset = _maxOffset();
    if (nextMaxOffset <= 0) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 500) return;
    setState(() {
      _dragOffset = velocity > 0 ? nextMaxOffset : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    _measurePanel();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height * widget.maxHeightFactor,
          ),
          child: Stack(
            children: [
              KeyedSubtree(
                key: _panelKey,
                child: widget.child,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 36,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
