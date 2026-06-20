import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import '../theme/ui_styles.dart';

class CompassRoom {
  final int id;
  final String name;
  final IconData icon;
  final String description;
  final bool isCrossFloor;
  final int? targetFloorId;

  const CompassRoom({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isCrossFloor = false,
    this.targetFloorId,
  });
}

class CompassNavigator extends StatefulWidget {
  final List<CompassRoom> rooms;
  final int? currentRoomId;
  final bool previewActive;
  final void Function(int roomId)? onRoomSelected;
  final void Function(int roomId)? onRoomPreview;
  final VoidCallback? onPreviewClear;
  final double width;
  final double height;
  final int? externalPreviewRoomId;
  final VoidCallback? onExternalPreviewHandled;

  const CompassNavigator({
    super.key,
    required this.rooms,
    this.currentRoomId,
    this.previewActive = false,
    this.onRoomSelected,
    this.onRoomPreview,
    this.onPreviewClear,
    this.width = 300,
    this.height = 72,
    this.externalPreviewRoomId,
    this.onExternalPreviewHandled,
  });

  @override
  State<CompassNavigator> createState() => _CompassNavigatorState();
}

class _CompassNavigatorState extends State<CompassNavigator> {
  late final PageController _pageController;
  double _currentPage = 0.0;
  int _centerIndex = 0;
  bool _isDragging = false;
  int? _lastHandledPreviewId;

  void _onControllerTick() {
    final next = _pageController.page ?? _currentPage;
    if (!mounted) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    final inBuildPhase = phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks;

    if (!inBuildPhase) {
      setState(() => _currentPage = next);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentPage = _pageController.page ?? next);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    final idx = widget.currentRoomId == null
        ? 0
        : widget.rooms.indexWhere((r) => r.id == widget.currentRoomId);
    _centerIndex = (idx < 0 ? 0 : idx).clamp(
      0,
      math.max(0, widget.rooms.length - 1),
    );
    _currentPage = _centerIndex.toDouble();

    _pageController = PageController(
      initialPage: _centerIndex,
      viewportFraction: 0.25,
    )..addListener(_onControllerTick);
  }

  int _indexOfRoomId(int? id) {
    if (id == null) return -1;
    return widget.rooms.indexWhere((r) => r.id == id);
  }

  Future<void> _animateToIndex(
    int idx, {
    Duration d = const Duration(milliseconds: 200),
  }) async {
    if (!_pageController.hasClients) return;
    _centerIndex = idx;
    await _pageController.animateToPage(
      _centerIndex,
      duration: d,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleExternalPreviewIfAny() {
    final req = widget.externalPreviewRoomId;
    if (req == null || req == _lastHandledPreviewId) return;

    _lastHandledPreviewId = req;
    final idx = widget.rooms.indexWhere((r) => r.id == req);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (idx >= 0) {
        await _animateToIndex(idx);
        widget.onRoomPreview?.call(widget.rooms[idx].id);
      }
      widget.onExternalPreviewHandled?.call();
    });
  }

  @override
  void didUpdateWidget(covariant CompassNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentRoomId != widget.currentRoomId ||
        oldWidget.rooms.length != widget.rooms.length) {
      final idx = _indexOfRoomId(widget.currentRoomId);
      final int newCenter = (idx < 0 ? 0 : idx).clamp(
        0,
        math.max(0, widget.rooms.length - 1),
      );
      if (widget.rooms.isNotEmpty && newCenter != _centerIndex) {
        _centerIndex = newCenter;
        _currentPage = _centerIndex.toDouble();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_centerIndex);
          }
        });
      }
    }

    if (oldWidget.externalPreviewRoomId != widget.externalPreviewRoomId ||
        oldWidget.rooms.length != widget.rooms.length) {
      _handleExternalPreviewIfAny();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onControllerTick);
    _pageController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_pageController.hasClients) return;
    final pos = _pageController.position;
    final target = (pos.pixels - details.delta.dx).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    pos.jumpTo(target);
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    _isDragging = false;

    final targetIndex = (_pageController.page ?? _centerIndex.toDouble())
        .round()
        .clamp(0, widget.rooms.length - 1);
    if (targetIndex != _centerIndex) {
      _centerIndex = targetIndex;
      await _pageController.animateToPage(
        _centerIndex,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onRoomPreview?.call(widget.rooms[_centerIndex].id);
  }

  double _verticalOffsetFor(int index) {
    final d = (_currentPage - index).abs().clamp(0.0, 2.0);
    return math.sin((1.0 - (d / 2.0)) * math.pi / 2) * 6.0;
  }

  Future<void> previewRoomById(int roomId) async {
    final idx = widget.rooms.indexWhere((r) => r.id == roomId);
    if (idx < 0) return;
    if (!mounted) return;

    if (_pageController.hasClients) {
      _centerIndex = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !_pageController.hasClients) return;
        await _pageController.animateToPage(
          _centerIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );

        widget.onRoomPreview?.call(widget.rooms[_centerIndex].id);
      });
    } else {
      _centerIndex = idx;
      widget.onRoomPreview?.call(widget.rooms[_centerIndex].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rooms.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CompassArcPainter(
                color: AppStyles.compassArc,
                strokeWidth: 1.5,
              ),
            ),
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              padEnds: true,
              itemCount: widget.rooms.length,
              itemBuilder: (context, index) {
                final room = widget.rooms[index];
                final isCenter = index == _centerIndex;
                final y = _verticalOffsetFor(index);

                return GestureDetector(
                  child: Transform.translate(
                    offset: Offset(0, -y),
                    child: Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: _CompassDot(
                        icon: room.icon,
                        isActive: isCenter,
                        isCrossFloor: room.isCrossFloor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassDot extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool isCrossFloor;

  const _CompassDot({
    required this.icon,
    required this.isActive,
    this.isCrossFloor = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppStyles.compassDotBg;
    final border = AppStyles.compassDotBorder;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppStyles.accentActive : border,
              width: isActive ? 2 : 1,
            ),
            boxShadow: [AppStyles.shadow],
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? AppStyles.accentActive : Colors.grey.shade700,
          ),
        ),
        if (isCrossFloor)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromRGBO(0, 0, 0, 0.45),
                    Color.fromRGBO(0, 0, 0, 0.30),
                  ],
                ),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.65),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.stairs,
                  size: 11,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompassArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CompassArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final start = Offset(8, size.height * 0.65);
    final end = Offset(size.width - 8, size.height * 0.65);
    final control = Offset(size.width / 2, size.height * 0.35);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CompassArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
