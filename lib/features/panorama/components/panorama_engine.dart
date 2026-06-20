import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;
import '../theme/ui_styles.dart';

class PanoramaEngine extends StatefulWidget {
  const PanoramaEngine({
    super.key,
    required this.panoImages,
    this.initialPanoId = 0,
    this.hotspots = const [],
    this.onPanoChanged,
    this.onViewChanged,
    this.onHotspotClicked,
    this.onCameraDriving,
    this.borderRadius = 16.0,
    this.animSpeed = 0,
    this.sensorControl = SensorControl.orientation,
    this.transitionDuration = const Duration(milliseconds: 1200),
  });

  final List<Image> panoImages;
  final int initialPanoId;
  final List<PanoHotspot> hotspots;
  final Function(int panoId)? onPanoChanged;
  final Function(double lon, double lat, double zoom)? onViewChanged;
  final Function(PanoHotspot hotspot)? onHotspotClicked;
  final void Function(bool active)? onCameraDriving;
  final double borderRadius;
  final double animSpeed;
  final SensorControl sensorControl;
  final Duration transitionDuration;

  @override
  State<PanoramaEngine> createState() => PanoramaEngineState();
}

class PanoramaEngineState extends State<PanoramaEngine>
    with TickerProviderStateMixin {
  late PanoramaController _panoramaController;
  late int _panoId;
  bool _isTransitioning = false;
  double _lon = 0;
  double _lat = 0;
  double _zoom = 1.0;

  Image? _fromImage;
  Image? _toImage;
  double? _savedLongitude;
  double? _savedLatitude;
  double? _savedZoom;
  double? _hotspotLon;
  double? _hotspotLat;

  AnimationController? _lookCtrl;

  bool _programmaticDriving = false;
  void _setProgrammaticDriving(bool active) {
    if (_programmaticDriving == active) return;
    _programmaticDriving = active;
    try {
      widget.onCameraDriving?.call(active);
    } catch (_) {}
  }

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _panoId = widget.initialPanoId;
    _panoramaController = PanoramaController();
  }

  @override
  void didUpdateWidget(covariant PanoramaEngine oldWidget) {
    super.didUpdateWidget(oldWidget);

    final imagesChanged =
        oldWidget.panoImages.length != widget.panoImages.length ||
            !identical(oldWidget.panoImages, widget.panoImages);
    final initialChanged = oldWidget.initialPanoId != widget.initialPanoId;

    if (!_isTransitioning && (imagesChanged || initialChanged)) {
      final len = widget.panoImages.length;
      final int desired = widget.initialPanoId.clamp(0, math.max(0, len - 1));
      if (desired != _panoId) {
        setState(() => _panoId = desired);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onPanoChanged?.call(_panoId);
        });
      }
    }
  }

  bool setCurrentPano(int panoId) {
    if (_isTransitioning || widget.panoImages.isEmpty) return false;
    final len = widget.panoImages.length;
    final id = panoId.clamp(0, len - 1);
    if (id == _panoId) return true;
    setState(() => _panoId = id);
    widget.onPanoChanged?.call(_panoId);
    return true;
  }

  @override
  void dispose() {
    _panoramaController.dispose();
    _lookCtrl?.dispose();

    _setProgrammaticDriving(false);
    super.dispose();
  }

  void _onViewChanged(double longitude, double latitude, double tilt) {
    setState(() {
      _lon = longitude;
      _lat = latitude;
      _zoom = _panoramaController.getZoom();
    });
    widget.onViewChanged?.call(_lon, _lat, _zoom);
  }

  bool navigateTo(int targetPanoId) {
    if (_isTransitioning || targetPanoId == _panoId) return false;
    cancelFocus();
    final match = widget.hotspots.firstWhere(
      (h) => h.panoId == _panoId && h.targetPanoId == targetPanoId,
      orElse: () => const PanoHotspot(
        panoId: -1,
        targetPanoId: -1,
        latitude: 0,
        longitude: 0,
      ),
    );
    if (match.panoId == -1) return false;
    _goToHotspotPano(
      match.targetPanoId,
      match.longitude,
      match.latitude,
      match,
    );
    return true;
  }

  void _goToHotspotPano(
    int nextPanoId,
    double hotspotLon,
    double hotspotLat,
    PanoHotspot hotspot,
  ) async {
    if (_isTransitioning || nextPanoId >= widget.panoImages.length) return;

    _setProgrammaticDriving(true);
    widget.onHotspotClicked?.call(hotspot);

    final currentLon = _panoramaController.getLongitude();
    final currentLat = _panoramaController.getLatitude();
    final currentZoom = _panoramaController.getZoom();

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isLoading = false;
      _isTransitioning = true;
      _fromImage = widget.panoImages[_panoId];
      _toImage = widget.panoImages[nextPanoId];
      _savedLongitude = currentLon;
      _savedLatitude = currentLat;
      _savedZoom = currentZoom;
      _hotspotLon = hotspotLon;
      _hotspotLat = hotspotLat;
    });
  }

  void _onTransitionCompleted() {
    setState(() {
      _isTransitioning = false;
      _fromImage = null;
      _toImage = null;
      _savedLongitude = null;
      _savedLatitude = null;
      _savedZoom = null;
      _hotspotLon = null;
      _hotspotLat = null;
    });

    _setProgrammaticDriving(false);
  }

  List<Hotspot> _buildHotspots() {
    return widget.hotspots.where((hotspot) => hotspot.panoId == _panoId).map((
      hotspot,
    ) {
      final hasText = (hotspot.text != null && hotspot.text!.trim().isNotEmpty);
      final extraH = hasText ? 36.0 : 0.0;

      final VoidCallback onPressed = hotspot.isCrossFloor
          ? () {
              try {
                widget.onHotspotClicked?.call(hotspot);
              } catch (_) {}
            }
          : () => _goToHotspotPano(
                hotspot.targetPanoId,
                hotspot.longitude,
                hotspot.latitude,
                hotspot,
              );

      return Hotspot(
        latitude: hotspot.latitude,
        longitude: hotspot.longitude,
        width: hotspot.width,
        height: hotspot.height + extraH,
        widget: hotspot.widget ??
            _defaultHotspotButton(
              text: hotspot.text,
              icon: hotspot.icon,
              hotspot: hotspot,
              onPressed: onPressed,
            ),
      );
    }).toList();
  }

  Widget _defaultHotspotButton({
    String? text,
    IconData? icon,
    VoidCallback? onPressed,
    PanoHotspot? hotspot,
  }) {
    final screenW = MediaQuery.of(context).size.width;
    final maxLabelWidth = math.min(screenW * 0.45, 240.0);

    BoxDecoration _glassDeco({
      BorderRadius? radius,
      bool circle = false,
    }) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(0, 0, 0, 0.28),
            Color.fromRGBO(0, 0, 0, 0.18),
          ],
        ),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.45),
          width: AppStyles.borderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.10),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : (radius ?? BorderRadius.circular(12)),
      );
    }

    Widget _glassCircle(Widget child) {
      return ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: _glassDeco(circle: true),
            child: child,
          ),
        ),
      );
    }

    Widget _glassRounded({
      required Widget child,
      BorderRadius? radius,
      EdgeInsets padding = const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 4.0,
      ),
    }) {
      final r = radius ?? BorderRadius.circular(12);
      return ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: _glassDeco(radius: r),
            child: child,
          ),
        ),
      );
    }

    final hasText = text != null && text.trim().isNotEmpty;

    final circleWithBadge = Stack(
      clipBehavior: Clip.none,
      children: [
        _glassCircle(
          IconButton(
            style: ButtonStyle(
              shape: WidgetStateProperty.all(const CircleBorder()),
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              foregroundColor: WidgetStateProperty.all(Colors.white70),
              overlayColor:
                  WidgetStateProperty.all(Colors.white.withOpacity(0.12)),
              padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
            ),
            onPressed: onPressed,
            icon: Icon(
              icon ?? Icons.open_in_browser,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ),
        if (hotspot?.isCrossFloor ?? false)
          Positioned(
            right: -4,
            bottom: -4,
            child: _glassCircle(
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.stairs,
                  size: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );

    final main = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        circleWithBadge,
        if (hasText)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxLabelWidth),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              child: _glassRounded(
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return main;
  }

  bool focusHotspotTo(
    int targetPanoId, {
    Duration duration = const Duration(milliseconds: 0),
  }) {
    if (_isTransitioning) return false;

    final match = widget.hotspots.firstWhere(
      (h) => h.panoId == _panoId && h.targetPanoId == targetPanoId,
      orElse: () => const PanoHotspot(
        panoId: -1,
        targetPanoId: -1,
        latitude: 0,
        longitude: 0,
      ),
    );
    if (match.panoId == -1) return false;

    _setProgrammaticDriving(true);
    _animateLookTo(match.longitude, match.latitude, duration: duration);
    return true;
  }

  void cancelFocus() {
    _lookCtrl?.stop();
    _lookCtrl?.dispose();
    _lookCtrl = null;
    _setProgrammaticDriving(false);
  }

  void _animateLookTo(
    double targetLon,
    double targetLat, {
    Duration duration = const Duration(milliseconds: 0),
  }) {
    cancelFocus();

    final startLon = _panoramaController.getLongitude();
    final startLat = _panoramaController.getLatitude();

    final normStartLon = _normalizeLon(startLon);
    final normTargetLon = _normalizeLon(targetLon);
    final deltaLon = _shortestDeltaDegrees(normStartLon, normTargetLon);
    final deltaLat = targetLat - startLat;

    _setProgrammaticDriving(true);

    _lookCtrl = AnimationController(vsync: this, duration: duration)
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_lookCtrl!.value);
        final lon = _normalizeLon(normStartLon + deltaLon * t);
        final lat = (startLat + deltaLat * t).clamp(-90.0, 90.0);
        try {
          _panoramaController.setView(lat, lon);
        } catch (_) {}
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
          cancelFocus();
        }
      })
      ..forward();
  }

  double _normalizeLon(double lon) {
    var l = lon;
    while (l > 180) l -= 360;
    while (l < -180) l += 360;
    return l;
  }

  double _shortestDeltaDegrees(double from, double to) {
    var d = to - from;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          PanoramaViewer(
            panoramaController: _panoramaController,
            animSpeed: widget.animSpeed,
            sensorControl: SensorControl.none,
            onViewChanged: _onViewChanged,
            hotspots: _buildHotspots(),
            child: widget.panoImages[_panoId],
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_isTransitioning && _fromImage != null && _toImage != null)
            Positioned.fill(
              child: PanoramaTransition(
                fromImage: _fromImage!,
                toImage: _toImage!,
                savedLongitude: _savedLongitude!,
                savedLatitude: _savedLatitude!,
                savedZoom: _savedZoom!,
                hotspotLon: _hotspotLon,
                hotspotLat: _hotspotLat,
                borderRadius: widget.borderRadius,
                transitionDuration: widget.transitionDuration,
                onViewChanged: _onViewChanged,
                onCompleted: () {
                  final targetPanoId = widget.hotspots
                      .firstWhere(
                        (h) =>
                            h.panoId == _panoId &&
                            h.longitude == _hotspotLon &&
                            h.latitude == _hotspotLat,
                        orElse: () => widget.hotspots.first,
                      )
                      .targetPanoId;
                  setState(() => _panoId = targetPanoId);
                  widget.onPanoChanged?.call(_panoId);
                  _onTransitionCompleted();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class PanoHotspot {
  final int panoId;
  final int targetPanoId;
  final double latitude;
  final double longitude;
  final double width;
  final double height;
  final String? text;
  final IconData? icon;
  final Widget? widget;

  final int? targetFloorId;

  const PanoHotspot({
    required this.panoId,
    required this.targetPanoId,
    required this.latitude,
    required this.longitude,
    this.width = 90,
    this.height = 80,
    this.text,
    this.icon,
    this.widget,
    this.targetFloorId,
  });

  bool get isCrossFloor => targetFloorId != null;
}

class PanoramaTransition extends StatefulWidget {
  final Image fromImage;
  final Image toImage;
  final double savedLongitude;
  final double savedLatitude;
  final double savedZoom;
  final VoidCallback onCompleted;
  final Function(double lon, double lat, double zoom)? onViewChanged;
  final double? hotspotLon;
  final double? hotspotLat;
  final double borderRadius;
  final Duration transitionDuration;

  const PanoramaTransition({
    required this.fromImage,
    required this.toImage,
    required this.savedLongitude,
    required this.savedLatitude,
    required this.savedZoom,
    required this.onCompleted,
    this.onViewChanged,
    this.hotspotLon,
    this.hotspotLat,
    this.borderRadius = 16.0,
    this.transitionDuration = const Duration(milliseconds: 1200),
    super.key,
  });

  @override
  State<PanoramaTransition> createState() => _PanoramaTransitionState();
}

class _PanoramaTransitionState extends State<PanoramaTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late Animation<Offset> _perspectiveAnim;
  late PanoramaController _transitionController;
  double _perspectiveAmplification = 1.5;

  @override
  void initState() {
    super.initState();
    _transitionController = PanoramaController();

    _ctrl =
        AnimationController(vsync: this, duration: widget.transitionDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onCompleted();
            }
          });

    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    final hotspotDirection = _calculateDirection();
    _perspectiveAnim = Tween<Offset>(
      begin: Offset.zero,
      end: hotspotDirection,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));

    _ctrl.forward();
  }

  Offset _calculateDirection() {
    if (widget.hotspotLon != null && widget.hotspotLat != null) {
      final lonDiff = widget.hotspotLon! - widget.savedLongitude;
      final latDiff = widget.hotspotLat! - widget.savedLatitude;

      double normalizedLonDiff = lonDiff;
      if (lonDiff > 180) {
        normalizedLonDiff = lonDiff - 360;
      } else if (lonDiff < -180) {
        normalizedLonDiff = lonDiff + 360;
      }

      final screenX = normalizedLonDiff / 180.0;
      final screenY = latDiff / 90.0;

      final amplifiedX = (screenX * 2.0 * _perspectiveAmplification).clamp(
        -3.15,
        3.15,
      );
      final amplifiedY = (screenY * 2.0 * _perspectiveAmplification).clamp(
        -3.15,
        3.15,
      );

      return Offset(-amplifiedX, amplifiedY);
    }

    _perspectiveAmplification = 1.0;
    return const Offset(0, -0.8);
  }

  Matrix4 _createPerspectiveMatrix(Offset perspective, double intensity) {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.002 * _perspectiveAmplification)
      ..translate(
        perspective.dx * intensity * 150 * _perspectiveAmplification,
        perspective.dy * intensity * 75 * _perspectiveAmplification,
        intensity * -75 * _perspectiveAmplification,
      );
  }

  Matrix4 _createReversePerspectiveMatrix(
    Offset perspective,
    double intensity,
  ) {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.002 * _perspectiveAmplification)
      ..translate(
        -perspective.dx * intensity * 150 * _perspectiveAmplification,
        -perspective.dy * intensity * 75 * _perspectiveAmplification,
        intensity * 75 * _perspectiveAmplification,
      );
  }

  void _onTransitionViewChanged(
    double longitude,
    double latitude,
    double tilt,
  ) {
    final zoom = _transitionController.getZoom();
    widget.onViewChanged?.call(longitude, latitude, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        final perspective = _perspectiveAnim.value;
        final progressToSecondPano = 0.1;
        final firstHalf = (t * 2.0).clamp(0.0, 1.0);
        final secondHalf = ((t - progressToSecondPano) * 2.0).clamp(0.0, 1.0);
        final showSecondPano = t >= progressToSecondPano;

        return Stack(
          children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.center,
                transform: _createPerspectiveMatrix(perspective, firstHalf),
                child: PanoramaViewer(
                  panoramaController: _transitionController,
                  sensitivity: 0,
                  animSpeed: 0,
                  sensorControl: SensorControl.none,
                  longitude: widget.savedLongitude,
                  latitude: widget.savedLatitude,
                  zoom: widget.savedZoom,
                  onViewChanged: _onTransitionViewChanged,
                  child: widget.fromImage,
                ),
              ),
            ),
            if (showSecondPano)
              Positioned.fill(
                child: Opacity(
                  opacity: secondHalf,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: _createReversePerspectiveMatrix(
                      perspective,
                      1 - secondHalf,
                    ),
                    child: PanoramaViewer(
                      panoramaController: _transitionController,
                      sensitivity: 0,
                      animSpeed: 0,
                      sensorControl: SensorControl.none,
                      longitude: widget.savedLongitude,
                      latitude: widget.savedLatitude,
                      zoom: widget.savedZoom,
                      onViewChanged: _onTransitionViewChanged,
                      child: widget.toImage,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    _ctrl.dispose();
    super.dispose();
  }
}
