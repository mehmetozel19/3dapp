import 'dart:io' show File;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import '../theme/ui_styles.dart';

class PickerMarker {
  final double latitude;
  final double longitude;
  final String label;
  final IconData icon;
  const PickerMarker({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.icon,
  });
}

class PanoHotspotPicker extends StatefulWidget {
  final String imagePath;
  final double? initialLatitude;
  final double? initialLongitude;

  final List<PickerMarker> markers;

  final IconData selectedIcon;
  final String selectedLabel;

  const PanoHotspotPicker({
    super.key,
    required this.imagePath,
    this.initialLatitude,
    this.initialLongitude,
    required this.markers,
    required this.selectedIcon,
    required this.selectedLabel,
  });

  @override
  State<PanoHotspotPicker> createState() => _PanoHotspotPickerState();
}

class _PanoHotspotPickerState extends State<PanoHotspotPicker>
    with SingleTickerProviderStateMixin {
  final PanoramaController _controller = PanoramaController();
  double? _lat;
  double? _lon;

  late final AnimationController _markerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _markerScale = CurvedAnimation(
    parent: _markerCtrl,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _markerFade = CurvedAnimation(
    parent: _markerCtrl,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLatitude;
    _lon = widget.initialLongitude;

    if (_lat != null && _lon != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markerCtrl.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _markerCtrl.dispose();
    super.dispose();
  }

  void _setPick(double lon, double lat) {
    setState(() {
      _lon = lon;
      _lat = lat;
    });
    _markerCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _lat != null && _lon != null;

    final base = Theme.of(context);
    final themed = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: base.textTheme.apply(
        bodyColor: AppStyles.textPrimary,
        displayColor: AppStyles.textPrimary,
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: PanoramaViewer(
                panoramaController: _controller,
                animSpeed: 0,
                sensorControl: SensorControl.none,
                onTap: (double lon, double lat, double _) {
                  _setPick(lon, lat);
                  return null;
                },
                hotspots: [
                  // Show existing hotspots
                  ...widget.markers.map(
                    (m) => Hotspot(
                      latitude: m.latitude,
                      longitude: m.longitude,
                      width: 90,
                      height: 116,
                      widget: IgnorePointer(
                        ignoring: true,
                        child: Opacity(
                          opacity: 0.8,
                          child: _pickerHotspotWidget(
                            icon: m.icon,
                            label: m.label,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Current selection
                  if (canUse)
                    Hotspot(
                      latitude: _lat!,
                      longitude: _lon!,
                      width: 90,
                      height: 116,
                      widget: IgnorePointer(
                        ignoring: true,
                        child: FadeTransition(
                          opacity: _markerFade,
                          child: ScaleTransition(
                            scale: _markerScale,
                            child: _pickerHotspotWidget(
                              icon: widget.selectedIcon,
                              label: widget.selectedLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 100,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) {
                  final fade = CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOut,
                  );
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(fade);
                  return FadeTransition(
                    opacity: fade,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: canUse
                    ? Column(
                        key: const ValueKey('use_here_btn'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Use here'),
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(<String, double>{'lat': _lat!, 'lon': _lon!}),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: const StadiumBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Exit'),
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: const StadiumBorder(),
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.black87,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: _HintBar(lat: _lat, lon: _lon),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerHotspotWidget({required IconData icon, required String label}) {
    final bg = AppStyles.hotspotBg;
    final border = AppStyles.hotspotBorder;
    final iconColor = AppStyles.hotspotIcon;
    final labelBg = AppStyles.hotspotLabelBg;
    final labelText = AppStyles.hotspotLabelText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: AppStyles.borderWidth),
            boxShadow: [AppStyles.shadow],
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: iconColor),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppStyles.border,
              width: AppStyles.borderWidth,
            ),
            boxShadow: [AppStyles.shadow],
          ),
          child: Text(
            label.isEmpty ? 'Room' : label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: TextStyle(
              color: labelText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HintBar extends StatelessWidget {
  final double? lat;
  final double? lon;
  const _HintBar({this.lat, this.lon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.touch_app, size: 18, color: Colors.grey.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap anywhere to set hotspot.',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                lat != null && lon != null
                    ? 'lat: ${lat!.toStringAsFixed(1)}  lon: ${lon!.toStringAsFixed(1)}'
                    : 'lat: —  lon: —',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
