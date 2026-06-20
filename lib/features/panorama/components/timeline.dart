import 'package:flutter/material.dart';
import '../theme/ui_styles.dart';

class Timeline extends StatefulWidget {
  const Timeline({
    super.key,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.timelineHeight = 80,
    this.connectedItems = const [],
    this.items = const [],
  });

  final int initialIndex;
  final Function(int)? onIndexChanged;
  final double timelineHeight;
  final List<int> connectedItems;
  final List<TimelineItem> items;

  @override
  State<Timeline> createState() => _TimelineState();
}

class TimelineItem {
  final IconData icon;
  final String text;

  const TimelineItem({required this.icon, required this.text});
}

class _TimelineState extends State<Timeline> {
  late int _currentIndex;
  int? _previewIndex;
  bool _isInitialBuild = true;

  final ScrollController _scrollCtrl = ScrollController();
  late List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _itemKeys = List<GlobalKey>.generate(
      widget.items.length,
      (_) => GlobalKey(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isInitialBuild = false;
      });
      _scrollActiveIntoView(animated: false);
    });
  }

  @override
  void didUpdateWidget(Timeline oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate keys if count changes and scroll
    if (oldWidget.items.length != widget.items.length) {
      _itemKeys = List<GlobalKey>.generate(
        widget.items.length,
        (_) => GlobalKey(),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollActiveIntoView(),
      );
    }

    if (oldWidget.initialIndex != widget.initialIndex) {
      _currentIndex = widget.initialIndex;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollActiveIntoView(),
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollActiveIntoView({bool animated = true}) {
    final idx = _previewIndex ?? _currentIndex;
    if (idx < 0 || idx >= _itemKeys.length) return;

    final ctx = _itemKeys[idx].currentContext;
    if (ctx == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: animated ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: 0.5, // center
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _selectIndex(int index) {
    setState(() {
      _currentIndex = index;
      widget.onIndexChanged?.call(_currentIndex);
    });
    _scrollActiveIntoView();
  }

  void updateIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    _scrollActiveIntoView();
  }

  void setPreview(int? previewIndex) {
    setState(() {
      _previewIndex = previewIndex;
    });
    _scrollActiveIntoView();
  }

  void clearPreview() {
    setState(() {
      _previewIndex = null;
    });
    _scrollActiveIntoView();
  }

  double _getItemOpacity(int index) {
    if (index == _currentIndex) return 1.0;
    if (widget.connectedItems.contains(index)) return 1.0;
    return 0.2;
  }

  bool _isClickable(int index) {
    return index == _currentIndex || widget.connectedItems.contains(index);
  }

  bool _isPreviewItem(int index) {
    return _previewIndex != null && index == _previewIndex;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final bool isActive = i == _currentIndex;
            final bool isPreview = _isPreviewItem(i);
            final bool isClickable = _isClickable(i);
            final opacity = _getItemOpacity(i);
            final item = widget.items[i];

            return Container(
              key: _itemKeys[i],
              margin: const EdgeInsets.symmetric(horizontal: 6.0),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _isInitialBuild && isActive ? 1 : 0,
                  end: (isActive || isPreview) ? 1 : 0,
                ),
                duration: _isInitialBuild
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  final expandedWidth = 100.0 * t;
                  return AnimatedOpacity(
                    opacity: opacity,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onTap: isClickable ? () => _selectIndex(i) : null,
                      child: MouseRegion(
                        cursor: isClickable
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                        child: Container(
                          width: 32 + expandedWidth,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppStyles.surface
                                : isPreview
                                ? AppStyles.surface
                                : AppStyles.surfaceMuted,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppStyles.border,
                              width: AppStyles.borderWidth,
                            ),
                            boxShadow: isActive ? [AppStyles.shadow] : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isActive
                                      ? Colors.grey.shade700
                                      : isPreview
                                      ? Colors.grey.shade700
                                      : AppStyles.textSecondary,
                                  size: 14,
                                ),
                                if (t > 0.1) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(-10 * (1 - t), 0),
                                      child: Opacity(
                                        opacity: Curves.easeOutQuart.transform(
                                          (t - 0.2).clamp(0.0, 1.0),
                                        ),
                                        child: Text(
                                          item.text,
                                          style: TextStyle(
                                            color: isActive
                                                ? AppStyles.textPrimary
                                                : isPreview
                                                ? AppStyles.textPrimary
                                                : AppStyles.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}
