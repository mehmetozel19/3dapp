import 'package:flutter/material.dart';

// TODO list a few of the rooms under the floor numbers

class FloorSelector extends StatefulWidget {
  const FloorSelector({
    super.key,
    this.floors = 5,
    this.boxHeight = 52,
    this.spacing = 0,
    this.initialFloor = 0,
    this.onFloorChanged,
    this.selectedColor = Colors.blueAccent,
    this.unselectedColor,
    this.width,
    this.maxWidth = 300,
    this.floorRooms,
  });

  final int floors;
  final double boxHeight;
  final double spacing;
  final int initialFloor;
  final Function(int)? onFloorChanged;
  final Color selectedColor;
  final Color? unselectedColor;
  final double? width;
  final double maxWidth;
  final List<List<String>>? floorRooms;

  @override
  State<FloorSelector> createState() => _FloorSelectorState();
}

class _FloorSelectorState extends State<FloorSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _selectorPosition = 0;
  late int selectedFloor;
  int? hoveredFloor;

  double get totalHeight => widget.floors * widget.boxHeight;

  @override
  void initState() {
    super.initState();
    selectedFloor = widget.initialFloor;
    hoveredFloor = selectedFloor;
    _selectorPosition = selectedFloor * widget.boxHeight;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
  }

  void moveSelectorToFloor(int floor) {
    double target = floor * widget.boxHeight;
    _animation =
        Tween<double>(begin: _selectorPosition, end: target).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        )..addListener(() {
          setState(() {
            _selectorPosition = _animation.value;
            _updateHoveredFloor();
          });
        });
    _animationController.forward(from: 0);
    setState(() {
      selectedFloor = floor;
      widget.onFloorChanged?.call(selectedFloor);
    });
  }

  int floorFromPosition(double position) {
    return (position / widget.boxHeight).round().clamp(0, widget.floors - 1);
  }

  void _updateHoveredFloor() {
    int newHoveredFloor = floorFromPosition(_selectorPosition);
    if (newHoveredFloor != hoveredFloor) {
      setState(() {
        hoveredFloor = newHoveredFloor;
      });
    }
  }

  bool isHoveringOverFloor(int floorIndex) {
    return hoveredFloor == floorIndex;
  }

  bool isAdjacentToHoveredOrSelected(int index) {
    int targetFloor = hoveredFloor ?? selectedFloor;
    return (index == targetFloor - 1) || (index == targetFloor + 1);
  }

  BorderRadius _getBorderRadius(int index) {
    final double radius = 20;

    bool isSelected = selectedFloor == index;
    bool isHovering = isHoveringOverFloor(index);
    bool isTopFloor = index == widget.floors - 1;
    bool isBottomFloor = index == 0;
    int targetFloor = hoveredFloor ?? selectedFloor;
    bool isAboveTarget = index == targetFloor + 1;
    bool isBelowTarget = index == targetFloor - 1;
    bool isBeingHovered = hoveredFloor != null;

    if (isSelected && !isBeingHovered) {
      if (isTopFloor && isBottomFloor) {
        return BorderRadius.circular(radius);
      } else if (isTopFloor) {
        return BorderRadius.vertical(top: Radius.circular(radius));
      } else if (isBottomFloor) {
        return BorderRadius.vertical(bottom: Radius.circular(radius));
      }
      return BorderRadius.zero;
    }

    if (isHovering) {
      return BorderRadius.circular(radius);
    }

    // Handle adjacent cards to hovered/selected target
    if (isAboveTarget && isBeingHovered) {
      if (isTopFloor) {
        return BorderRadius.circular(radius);
      } else {
        return BorderRadius.vertical(bottom: Radius.circular(radius));
      }
    }

    if (isBelowTarget && isBeingHovered) {
      if (isBottomFloor) {
        return BorderRadius.circular(radius);
      } else {
        return BorderRadius.vertical(top: Radius.circular(radius));
      }
    }

    if (isTopFloor && isBottomFloor) {
      // Single floor
      return BorderRadius.circular(radius);
    } else if (isTopFloor) {
      return BorderRadius.vertical(top: Radius.circular(radius));
    } else if (isBottomFloor) {
      return BorderRadius.vertical(bottom: Radius.circular(radius));
    }

    return BorderRadius.zero;
  }

  double _getCardPosition(int index) {
    double spacing = 8.0;
    int targetFloor = hoveredFloor ?? selectedFloor;
    double basePosition = index * widget.boxHeight;

    if (index > targetFloor) {
      // Cards above the target get pushed up by spacing, *2 unless it's the bottommost card
      if (targetFloor != 0) {
        basePosition += spacing * 2;
      } else {
        basePosition += spacing;
      }
    } else if (index == targetFloor) {
      // Target card gets spacing below it unless it's the bottommost card
      if (index != 0) {
        basePosition += spacing;
      }
    }

    return basePosition;
  }

  double _getCardWidth(int index, double baseWidth) {
    int targetFloor = hoveredFloor ?? selectedFloor;
    bool isTargetCard = index == targetFloor;

    return isTargetCard ? baseWidth : baseWidth * 0.9;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedWidth =
        widget.width ?? (screenWidth * 0.5).clamp(200.0, widget.maxWidth);

    // Calculate total height including spacing
    double dynamicTotalHeight = totalHeight + 16.0;

    return SizedBox(
      height: dynamicTotalHeight,
      width: calculatedWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(widget.floors, (index) {
            double bottomPos = _getCardPosition(index);
            bool isSelected = selectedFloor == index;
            bool isHovering = isHoveringOverFloor(index);
            bool isTargetCard = isSelected || isHovering;
            double cardWidth = _getCardWidth(index, calculatedWidth);

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              bottom: bottomPos,
              child: GestureDetector(
                onTap: () => moveSelectorToFloor(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: cardWidth,
                  height: widget.boxHeight,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.grey.shade50,
                    borderRadius: _getBorderRadius(index),
                    border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    boxShadow: isTargetCard
                        ? [
                            const BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.1),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor $index',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (widget.floorRooms != null &&
                                  index < widget.floorRooms!.length &&
                                  widget.floorRooms![index].isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.floorRooms![index]
                                      .take(3)
                                      .join(', '), // Show up to 3
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: widget.selectedColor,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Draggable selector
          Positioned.fill(
            child: GestureDetector(
              onPanStart: (details) {
                RenderBox box = context.findRenderObject() as RenderBox;
                Offset localOffset = box.globalToLocal(details.globalPosition);

                // Calculate the position from bottom and adjust for spacing
                double fromBottom = dynamicTotalHeight - localOffset.dy;
                double adjustedPosition =
                    fromBottom - widget.boxHeight / 2 - 8.0;

                setState(() {
                  _selectorPosition = adjustedPosition.clamp(
                    0,
                    totalHeight - widget.boxHeight,
                  );
                  _updateHoveredFloor();
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _selectorPosition -= details.delta.dy;
                  _selectorPosition = _selectorPosition.clamp(
                    0,
                    totalHeight - widget.boxHeight,
                  );
                  _updateHoveredFloor();
                });
              },
              onPanEnd: (_) {
                int snappedFloor = floorFromPosition(_selectorPosition);
                moveSelectorToFloor(snappedFloor);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Visual selector indicator
          Positioned(
            bottom: _selectorPosition + 8.0, // for spacing
            child: IgnorePointer(
              child: Container(
                width: calculatedWidth,
                height: widget.boxHeight,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.transparent, width: 0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
