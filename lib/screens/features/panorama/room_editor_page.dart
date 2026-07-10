import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import '../../../features/panorama/components/pano_hotspot_picker.dart';
import '../../../features/panorama/theme/ui_styles.dart';
import '../../../models/editor_models.dart';
import '../../../models/panorama_data.dart';
import '../../../models/presets.dart';
import 'dart:convert' as convert;
import 'dart:math' as math;

const double kControlHeight = 40.0;
const double kControlFontSize = 16.0;

class RoomEditorPage extends StatefulWidget {
  final FloorEditor floor;
  final int roomIndex;
  final int floorIndex;
  final PanoramaData panoramaData;
  final List<FloorEditor> allFloorsEditors;

  const RoomEditorPage({
    super.key,
    required this.floor,
    required this.roomIndex,
    required this.floorIndex,
    required this.panoramaData,
    required this.allFloorsEditors,
  });

  @override
  State<RoomEditorPage> createState() => _RoomEditorPageState();
}

class _RoomEditorPageState extends State<RoomEditorPage> {
  EditableRoom get room => widget.floor.rooms[widget.roomIndex];
  bool _saving = false;

  late String _initialDigest;
  bool get _hasChanges => _computeDigest() != _initialDigest;

  late _RoomSnapshot _snapshot;

  bool _showNoRoomsWarning = false;

  static const String _kPresetCustom = 'Custom';
  String _presetValue = _kPresetCustom;

  late Set<String> _originalCrossFloorPairIds;

  @override
  void initState() {
    super.initState();
    _initialDigest = _computeDigest();
    _snapshot = _RoomSnapshot.capture(widget.floor, widget.roomIndex);
    _originalCrossFloorPairIds = _collectCrossFloorPairIdsForRoom();

    final existingRooms =
        widget.panoramaData.floorRooms[widget.floorIndex] ?? const <RoomData>[];
    for (int i = 0; i < widget.floor.rooms.length; i++) {
      final er = widget.floor.rooms[i];

      if (er.presetId == kPresetNone) {
        if (i >= 0 && i < existingRooms.length) {
          er.presetId = existingRooms[i].presetId;
        }

        if (er.presetId == kPresetNone && er.name.trim().isNotEmpty) {
          final byLabel = getPresetByLabel(er.name);
          if (byLabel != null) {
            er.presetId = byLabel.id;
          }
        }
      }
    }

    if (room.presetId != kPresetNone) {
      final p = getPresetById(room.presetId);
      if (p != null && p.id != kPresetNone) {
        _presetValue = p.label;
      } else {
        _presetValue = _kPresetCustom;
        room.presetId = kPresetNone;
      }
    } else {
      final byLabel = getPresetByLabel(room.name);
      if (byLabel != null) {
        room.presetId = byLabel.id;
        _presetValue = byLabel.label;
      } else {
        _presetValue = _kPresetCustom;
      }
    }
  }

  String _iconKeyForIcon(IconData icon) {
    for (final e in kIconCatalog.entries) {
      if (e.value.codePoint == icon.codePoint &&
          e.value.fontFamily == icon.fontFamily) {
        return e.key;
      }
    }
    return 'circle_outlined';
  }

  Set<String> _collectCrossFloorPairIdsForRoom() {
    final result = <String>{};
    for (int f = 0; f < widget.allFloorsEditors.length; f++) {
      final floor = widget.allFloorsEditors[f];
      for (final h in floor.hotspots) {
        if (!h.changeFloor || h.pairId.isEmpty) continue;
        final isOutgoingFromThisRoom =
            (f == widget.floorIndex && h.fromRoomId == widget.roomIndex);
        final isIncomingToThisRoom = (h.targetFloorId == widget.floorIndex &&
            h.toRoomId == widget.roomIndex);
        if (isOutgoingFromThisRoom || isIncomingToThisRoom) {
          result.add(h.pairId);
        }
      }
    }
    return result;
  }

  String _computeDigest() {
    double _r3(double v) => double.parse(v.toStringAsFixed(3));
    final conns = widget.floor.hotspots
        .where((h) => h.fromRoomId == widget.roomIndex)
        .map(
          (h) => {
            'to': h.toRoomId,
            'lat': _r3(h.latitude),
            'lon': _r3(h.longitude),
            'text': (h.text).trim(),
            'icon': h.iconName,
            'paired': h.isPaired,
            'chgFloor': h.changeFloor,
            'tfloor': h.targetFloorId ?? -1,
          },
        )
        .toList()
      ..sort((a, b) {
        final t = (a['to'] as int).compareTo(b['to'] as int);
        if (t != 0) return t;
        return (a['text'] as String).compareTo(b['text'] as String);
      });

    final data = {
      'name': room.name.trim(),
      'icon': room.iconName,
      'imagePath': room.imagePath,
      'desc': room.description,
      'conns': conns,
    };
    return convert.jsonEncode(data);
  }

  bool _validateBeforeSave() {
    final issues = widget.floor.hotspots
        .where((h) => h.fromRoomId == widget.roomIndex)
        .where((h) => h.text.trim().isEmpty)
        .toList();
    if (issues.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in a label for all connections before saving.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _onSavePressed({bool exitAfter = false}) async {
    if (_saving) return;
    if (!_validateBeforeSave()) return;

    setState(() => _saving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 700));

      widget.panoramaData
          .replaceFloorFromEditor(widget.floorIndex, widget.floor);
      _initialDigest = _computeDigest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panorama saved')),
      );
      if (exitAfter && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onExitPressed() async {
    if (_saving) return;

    if (!_hasChanges) {
      Navigator.of(context).pop(true);
      return;
    }

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        title: Text(
          'Exit editor',
          style: TextStyle(
            color: AppStyles.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Do you want to save changes before exiting?',
          style: TextStyle(color: AppStyles.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              const Spacer(),
              _WhiteButton.icon(
                icon: Icons.logout,
                label: 'Discard & exit',
                onPressed: () => Navigator.of(ctx).pop('discard'),
              ),
              const SizedBox(width: 8),
              _WhiteButton.icon(
                icon: Icons.check,
                label: 'Save & exit',
                onPressed: () => Navigator.of(ctx).pop('save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              _WhiteButton.icon(
                icon: Icons.close,
                label: 'Cancel',
                onPressed: () => Navigator.of(ctx).pop('cancel'),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (action) {
      case 'save':
        await _onSavePressed(exitAfter: true);
        break;
      case 'discard':
        _cleanupNewCrossFloorTwins();
        _snapshot.restoreInto(widget.floor, widget.roomIndex);
        Navigator.of(context).pop(true);
        break;
      default:
        break;
    }
  }

  Future<bool> confirmDeleteDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData confirmIcon = Icons.delete_outline,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppStyles.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppStyles.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              _WhiteButton.icon(
                icon: Icons.close,
                label: cancelLabel,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const Spacer(),
              _WhiteButton.icon(
                icon: confirmIcon,
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _cleanupNewCrossFloorTwins() {
    for (int f = 0; f < widget.allFloorsEditors.length; f++) {
      final floor = widget.allFloorsEditors[f];
      floor.hotspots.removeWhere((h) {
        if (!h.changeFloor || h.pairId.isEmpty) return false;
        final involvesThisRoom =
            (f == widget.floorIndex && h.fromRoomId == widget.roomIndex) ||
                (h.targetFloorId == widget.floorIndex &&
                    h.toRoomId == widget.roomIndex);
        if (!involvesThisRoom) return false;

        return !_originalCrossFloorPairIds.contains(h.pairId);
      });
    }
  }

  void _syncPresetFromFields() {}

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    final themed = base.copyWith(
      scaffoldBackgroundColor: AppStyles.surfaceMuted, 
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        toolbarHeight: 44,
        centerTitle: true,
        titleSpacing: 8,
        titleTextStyle: TextStyle(
          color: AppStyles.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        toolbarTextStyle: TextStyle(
          color: AppStyles.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: AppStyles.textPrimary, size: 20),
        actionsIconTheme: IconThemeData(color: AppStyles.textPrimary, size: 20),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppStyles.textPrimary,
        displayColor: AppStyles.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppStyles.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          borderSide: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          borderSide: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          borderSide: BorderSide(
            color: AppStyles.textPrimary, 
            width: 1.5,
          ),
        ),
        labelStyle: TextStyle(color: AppStyles.textSecondary),
        floatingLabelStyle: TextStyle(
          color: AppStyles.textPrimary, 
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: AppStyles.textSecondary.withOpacity(0.5)),
        prefixIconColor: AppStyles.textSecondary,
      ),
    );

    final connections = widget.floor.hotspots
        .where((h) => h.fromRoomId == widget.roomIndex)
        .toList();
    final connectedRoomIds =
        connections.where((h) => !h.changeFloor).map((h) => h.toRoomId).toSet();
    final availableRoomIds = List.generate(widget.floor.rooms.length, (i) => i)
        .where((i) => i != widget.roomIndex && !connectedRoomIds.contains(i))
        .toList();

    final panoramaData = widget.panoramaData;
    final allFloorsCount = panoramaData.floorRooms.length;
    debugPrint('All floors count: $allFloorsCount');
    final otherFloorIds = List.generate(allFloorsCount, (i) => i)
        .where((i) => i != widget.floorIndex)
        .toList();
    final hasOtherFloors = otherFloorIds.isNotEmpty;

    final hasImage =
        room.imagePath.isNotEmpty && File(room.imagePath).existsSync();

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: AppStyles.surfaceMuted,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(room.name.isEmpty ? 'Edit pano' : room.name),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _SectionHeader('Basics'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.surface,
                borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                border: Border.all(
                  color: AppStyles.border,
                  width: AppStyles.borderWidth,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Preset: ',
                          style: TextStyle(color: AppStyles.textPrimary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WhiteDropdown<String>(
                          value: _presetValue,
                          items: _presetItems(),
                          onChanged: (v) {
                            if (v == null) return;
                            if (v == _kPresetCustom) {
                              setState(() {
                                _presetValue = v;
                                room.presetId = kPresetNone;
                              });
                              return;
                            }
                            final preset = getPresetByLabel(v);
                            if (preset != null) {
                              _applyPreset(preset);
                              setState(() => _presetValue = preset.label);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: room.nameCtrl,
                    style: TextStyle(
                      color: AppStyles.textPrimary,
                      fontSize: kControlFontSize,
                      fontWeight: FontWeight.bold, 
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    onChanged: (v) => setState(() {
                      room.name = v;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Icon: ',
                          style: TextStyle(color: AppStyles.textPrimary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WhiteDropdown<String>(
                          value: room.iconName.isEmpty
                              ? 'circle_outlined'
                              : room.iconName,
                          items: _iconItems(),
                          onChanged: (v) => setState(() {
                            room.iconName = v ?? 'circle_outlined';
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppStyles.accentInactive.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          kIconCatalog[room.iconName] ?? Icons.circle_outlined,
                          color: AppStyles.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: TextField(
                      controller: room.descCtrl,
                      minLines: 1,
                      maxLines: 10,
                      style: TextStyle(
                        color: AppStyles.textPrimary,
                        fontSize: kControlFontSize,
                        height: 1.25,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      onChanged: (v) => setState(() {
                        room.description = v;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader('Panorama'),
            _PanoramaUploadBox(
              path: room.imagePath,
              onPick: (p) {
                setState(() {
                  room.imagePath = p;
                  room.imageCtrl.text = p;
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionHeader('Connections', padding: EdgeInsets.zero),
                _WhiteButton.icon(
                  icon: Icons.add_link,
                  label: 'Add connection',
                  onPressed: () {
                    final connections = widget.floor.hotspots
                        .where((h) => h.fromRoomId == widget.roomIndex)
                        .toList();
                    final connectedSameFloor = connections
                        .where((h) => !h.changeFloor)
                        .map((h) => h.toRoomId)
                        .toSet();
                    final sameFloorCandidates = List.generate(
                      widget.floor.rooms.length,
                      (i) => i,
                    ).where((i) => i != widget.roomIndex);
                    final uniqueSameFloorAvailable = sameFloorCandidates
                        .where((i) => !connectedSameFloor.contains(i))
                        .toList();

                    final allFloorsCount =
                        widget.panoramaData.floorRooms.length;
                    final otherFloorIds =
                        List.generate(allFloorsCount, (i) => i)
                            .where((i) => i != widget.floorIndex)
                            .toList();

                    final usedCrossTargets = connections
                        .where((h) => h.changeFloor)
                        .map((h) => '${h.targetFloorId}:${h.toRoomId}')
                        .toSet();

                    final List<MapEntry<int, int>> availableCrossTargets = [];
                    for (final fi in otherFloorIds) {
                      final rooms = widget.panoramaData.floorRooms[fi] ??
                          const <RoomData>[];
                      for (int ri = 0; ri < rooms.length; ri++) {
                        final key = '$fi:$ri';
                        if (!usedCrossTargets.contains(key)) {
                          availableCrossTargets.add(MapEntry(fi, ri));
                        }
                      }
                    }

                    final bool noneSame = uniqueSameFloorAvailable.isEmpty;
                    final bool noneCross = availableCrossTargets.isEmpty;

                    if (noneSame && noneCross) {
                      setState(() => _showNoRoomsWarning = true);
                      return;
                    }

                    setState(() {
                      _showNoRoomsWarning = false;
                      final pid = _newPairId();

                      if (!noneSame) {
                        final to = uniqueSameFloorAvailable.first;
                        final r = widget.floor.rooms[to];
                        final label = r.name.trim().isNotEmpty
                            ? r.name.trim()
                            : 'Pano $to';

                        final h = EditableHotspot(
                          fromRoomId: widget.roomIndex,
                          toRoomId: to,
                          latitude: 0,
                          longitude: 0,
                          text: label,
                          iconName: 'arrow_forward',
                          pairId: pid,
                          isPaired: true,
                          changeFloor: false,
                          targetFloorId: null,
                        );

                        widget.floor.hotspots.insert(0, h);
                        _updateTwinFromSource(
                          widget.floor,
                          h,
                          allEditors: widget.allFloorsEditors,
                          sourceFloorIndex: widget.floorIndex,
                        );
                        return;
                      }

                      final target = availableCrossTargets.first;
                      final tf = target.key;
                      final tr = target.value;
                      final rooms = widget.panoramaData.floorRooms[tf] ??
                          const <RoomData>[];
                      final name =
                          (rooms.isNotEmpty && rooms[tr].name.isNotEmpty)
                              ? rooms[tr].name
                              : 'Pano $tr';

                      final h = EditableHotspot(
                        fromRoomId: widget.roomIndex,
                        toRoomId: tr,
                        latitude: 0,
                        longitude: 0,
                        text: name,
                        iconName: 'arrow_forward',
                        pairId: pid,
                        isPaired: true,
                        changeFloor: true,
                        targetFloorId: tf,
                      );

                      widget.floor.hotspots.insert(0, h);
                      _updateTwinFromSource(
                        widget.floor,
                        h,
                        allEditors: widget.allFloorsEditors,
                        sourceFloorIndex: widget.floorIndex,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_showNoRoomsWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All rooms are already connected. Add another room to create more connections.',
                          style: TextStyle(
                              color: Colors.orange.shade800, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (connections.isNotEmpty && !hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyles.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Connections won't work without an image. Please upload a panorama.",
                          style: TextStyle(
                            color: AppStyles.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  if (connections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No connections yet.',
                        style: TextStyle(color: AppStyles.textSecondary),
                      ),
                    ),
                  ...connections.map(
                    (h) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.surface,
                        borderRadius:
                            BorderRadius.circular(AppStyles.cardRadius),
                        border: Border.all(
                          color: AppStyles.border,
                          width: AppStyles.borderWidth,
                        ),
                      ),
                      child: _FlatConnectionRow(
                        floor: widget.floor,
                        hotspot: h,
                        floorIndex: widget.floorIndex,
                        panoramaData: panoramaData,
                        allFloorsEditors: widget.allFloorsEditors,
                        onChanged: () => setState(() {}),
                        onPickInPano: () async {
                          final imgPath = room.imagePath;
                          if (imgPath.isEmpty || !File(imgPath).existsSync()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload a panorama image first'),
                              ),
                            );
                            return;
                          }

                          final existing = widget.floor.hotspots
                              .where(
                            (x) =>
                                x.fromRoomId == widget.roomIndex &&
                                x != h &&
                                !(x.latitude == 0 && x.longitude == 0) &&
                                !x.changeFloor,
                          )
                              .map((x) {
                            final toRoom = widget.floor.rooms[x.toRoomId];
                            final icon = kIconCatalog[toRoom.iconName] ??
                                Icons.circle_outlined;
                            final label = x.text.isNotEmpty
                                ? x.text
                                : (toRoom.name.isNotEmpty
                                    ? toRoom.name
                                    : 'Pano ${x.toRoomId}');
                            return PickerMarker(
                              latitude: x.latitude,
                              longitude: x.longitude,
                              label: label,
                              icon: icon,
                            );
                          }).toList();

                          IconData selectedIcon = Icons.place;
                          String selectedLabel;
                          if (!h.changeFloor) {
                            final toRoom = widget.floor.rooms[h.toRoomId];
                            selectedIcon =
                                kIconCatalog[toRoom.iconName] ?? Icons.place;
                            selectedLabel = h.text.isNotEmpty
                                ? h.text
                                : (toRoom.name.isNotEmpty
                                    ? toRoom.name
                                    : 'Pano ${h.toRoomId}');
                          } else {
                            final rooms = panoramaData.floorRooms[
                                    h.targetFloorId ?? widget.floorIndex] ??
                                const <RoomData>[];
                            if (rooms.isNotEmpty) {
                              final idx = h.toRoomId.clamp(0, rooms.length - 1);
                              selectedIcon = rooms[idx].icon;
                              final name = rooms[idx].name;
                              selectedLabel = h.text.isNotEmpty
                                  ? h.text
                                  : (name.isNotEmpty
                                      ? name
                                      : 'Pano ${h.toRoomId}');
                            } else {
                              selectedLabel = h.text.isNotEmpty
                                  ? h.text
                                  : 'Pano ${h.toRoomId}';
                            }
                          }

                          final result =
                              await Navigator.push<Map<String, double>>(
                            context,
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => PanoHotspotPicker(
                                imagePath: imgPath,
                                initialLatitude: h.latitude,
                                initialLongitude: h.longitude,
                                markers: existing,
                                selectedIcon: selectedIcon,
                                selectedLabel: selectedLabel,
                              ),
                            ),
                          );
                          if (result != null &&
                              result.containsKey('lat') &&
                              result.containsKey('lon')) {
                            setState(() {
                              h.latitude = result['lat']!;
                              h.longitude = result['lon']!;
                              h.latCtrl.text = h.latitude.toStringAsFixed(1);
                              h.lonCtrl.text = h.longitude.toStringAsFixed(1);
                              _updateTwinFromSource(
                                widget.floor,
                                h,
                                allEditors: widget.allFloorsEditors,
                                sourceFloorIndex: widget.floorIndex,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              _WhiteButton.icon(
                icon: Icons.delete_outline,
                label: 'Delete pano',
                onPressed: () async {
                  if (_saving) return;
                  final ok = await confirmDeleteDialog(
                    context,
                    title: 'Delete pano',
                    message: 'This will remove this room and its connections.',
                  );
                  if (!ok) return;
                  final floor = widget.floor;
                  final idx = widget.roomIndex;
                  floor.rooms.removeAt(idx);
                  floor.hotspots.removeWhere(
                    (h) => h.fromRoomId == idx || h.toRoomId == idx,
                  );
                  for (final h in floor.hotspots) {
                    if (h.fromRoomId > idx) h.fromRoomId -= 1;
                    if (h.toRoomId > idx) h.toRoomId -= 1;
                  }

                  widget.panoramaData.replaceFloorFromEditor(
                    widget.floorIndex,
                    floor,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop(true);
                },
              ),
              const Spacer(),
              _WhiteButton.icon(
                icon: Icons.exit_to_app,
                label: 'Exit',
                onPressed: _onExitPressed,
              ),
              const SizedBox(width: 8),
              if (_saving)
                const SizedBox(
                  width: 40,
                  height: kControlHeight,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                _WhiteButton.icon(
                  icon: Icons.check,
                  label: 'Save',
                  isPrimary: true, 
                  onPressed: () => _onSavePressed(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _iconItems() {
    final keys = (kIconCatalog.keys.toList()..sort());
    return keys
        .map((n) => DropdownMenuItem<String>(value: n, child: Text(n)))
        .toList();
  }

  List<DropdownMenuItem<String>> _presetItems() {
    return [
      const DropdownMenuItem<String>(
        value: _kPresetCustom,
        child: Text(_kPresetCustom),
      ),
      ...kRoomPresetCatalog.map(
        (p) => DropdownMenuItem<String>(
          value: p.label,
          child: Text(p.label),
        ),
      ),
    ];
  }

  void _applyPreset(dynamic preset) {
    final iconKey = _iconKeyForIcon(preset.icon);
    setState(() {
      room.presetId = preset.id;
      _presetValue = preset.label;

      room.name = preset.label;
      room.iconName = iconKey;

      room.nameCtrl.text = room.name;
      room.nameCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: room.nameCtrl.text.length),
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  const _SectionHeader(this.title, {this.padding = const EdgeInsets.only(bottom: 8)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          color: AppStyles.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _FlatConnectionRow extends StatelessWidget {
  final FloorEditor floor;
  final EditableHotspot hotspot;
  final VoidCallback onChanged;
  final VoidCallback onPickInPano;
  final int floorIndex;
  final PanoramaData panoramaData;
  final List<FloorEditor> allFloorsEditors;

  const _FlatConnectionRow({
    required this.floor,
    required this.hotspot,
    required this.onChanged,
    required this.onPickInPano,
    required this.floorIndex,
    required this.panoramaData,
    required this.allFloorsEditors,
  });

  @override
  Widget build(BuildContext context) {
    final floorKeys = panoramaData.floorRooms.keys.toList()..sort();
    final otherFloorIds = floorKeys.where((k) => k != floorIndex).toList();
    final hasOtherFloors = otherFloorIds.isNotEmpty;

    final int fromId = hotspot.fromRoomId;
    final List<int> sameFloorCandidates =
        List.generate(floor.rooms.length, (i) => i)
            .where((i) => i != fromId)
            .toList();

    final Set<int> usedSameFloorTargets = floor.hotspots
        .where((h) => h.fromRoomId == fromId && h != hotspot && !h.changeFloor)
        .map((h) => h.toRoomId)
        .toSet();

    final List<int> uniqueSameFloorAvailable = sameFloorCandidates
        .where((i) => !usedSameFloorTargets.contains(i))
        .toList();

    final bool canToggleChangeFloorOff = uniqueSameFloorAvailable.isNotEmpty;

    final usedCrossTargets = floor.hotspots
        .where((h) => h.fromRoomId == fromId && h.changeFloor)
        .map((h) => '${h.targetFloorId}:${h.toRoomId}')
        .toSet();

    final List<MapEntry<int, int>> availableCrossTargets = [];
    for (final fi in otherFloorIds) {
      final rooms = panoramaData.floorRooms[fi] ?? const <RoomData>[];
      for (int ri = 0; ri < rooms.length; ri++) {
        final key = '$fi:$ri';
        if (!usedCrossTargets.contains(key)) {
          availableCrossTargets.add(MapEntry(fi, ri));
        }
      }
    }
    final bool hasCrossFloorTargetsAvailable = availableCrossTargets.isNotEmpty;

    final excludeCurrent = floor.rooms.length > 1;
    final currentId = hotspot.fromRoomId;
    final availableRoomIds = List.generate(
      floor.rooms.length,
      (i) => i,
    ).where((i) => !excludeCurrent || i != currentId).toList();

    final connectedRoomIds = floor.hotspots
        .where(
          (h) =>
              h.fromRoomId == hotspot.fromRoomId &&
              h != hotspot &&
              !h.changeFloor,
        )
        .map((h) => h.toRoomId)
        .toSet();

    final filteredRoomIds = availableRoomIds
        .where((i) => !connectedRoomIds.contains(i) || i == hotspot.toRoomId)
        .toList();

    String labelFor(int i) {
      final r = floor.rooms[i];
      return (r.name.isNotEmpty) ? r.name : 'Pano $i';
    }

    String toRoomName;
    if (!hotspot.changeFloor) {
      toRoomName = (hotspot.toRoomId >= 0 &&
              hotspot.toRoomId < floor.rooms.length &&
              floor.rooms[hotspot.toRoomId].name.isNotEmpty)
          ? floor.rooms[hotspot.toRoomId].name
          : 'Pano ${hotspot.toRoomId}';
    } else {
      if (hotspot.targetFloorId == null ||
          !otherFloorIds.contains(hotspot.targetFloorId)) {
        hotspot.targetFloorId =
            otherFloorIds.isNotEmpty ? otherFloorIds.first : null;
      }
      final targetFloor = hotspot.targetFloorId ?? floorIndex;
      final rooms = panoramaData.floorRooms[targetFloor] ?? const <RoomData>[];

      if (rooms.isEmpty) {
        hotspot.toRoomId = 0;
      } else if (hotspot.toRoomId < 0 || hotspot.toRoomId >= rooms.length) {
        hotspot.toRoomId = 0;
      }
      if (rooms.isNotEmpty &&
          hotspot.toRoomId >= 0 &&
          hotspot.toRoomId < rooms.length) {
        final nm = rooms[hotspot.toRoomId].name;
        toRoomName = nm.isNotEmpty ? nm : 'Pano ${hotspot.toRoomId}';
      } else {
        toRoomName = 'Pano ${hotspot.toRoomId}';
      }
    }

    List<DropdownMenuItem<int>> toItems;
    int toValue;
    if (hotspot.changeFloor) {
      toItems = [
        DropdownMenuItem<int>(
          value: -1,
          child: Text('Cross-floor → $toRoomName'),
        ),
      ];
      toValue = -1;
    } else {
      final excludeCurrent = floor.rooms.length > 1;
      final currentId = hotspot.fromRoomId;
      final availableRoomIds = List.generate(floor.rooms.length, (i) => i)
          .where((i) => !excludeCurrent || i != currentId)
          .toList();

      final connectedRoomIds = floor.hotspots
          .where((h) =>
              h.fromRoomId == hotspot.fromRoomId &&
              h != hotspot &&
              !h.changeFloor)
          .map((h) => h.toRoomId)
          .toSet();

      final filteredRoomIds = availableRoomIds
          .where((i) => !connectedRoomIds.contains(i) || i == hotspot.toRoomId)
          .toList();

      int selectedToId = hotspot.toRoomId;
      if (!filteredRoomIds.contains(selectedToId)) {
        selectedToId = filteredRoomIds.isNotEmpty
            ? filteredRoomIds.first
            : floor.rooms.isEmpty
                ? 0
                : hotspot.toRoomId.clamp(0, floor.rooms.length - 1);
        hotspot.toRoomId = selectedToId;
      }

      toItems = filteredRoomIds
          .map((i) => DropdownMenuItem<int>(value: i, child: Text(labelFor(i))))
          .toList();

      if (toItems.isEmpty) {
        toItems = [
          DropdownMenuItem<int>(
            value: selectedToId,
            child: Text(labelFor(selectedToId)),
          ),
        ];
      }
      toValue = selectedToId;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              const Text('To', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Expanded(
                child: _WhiteDropdown<int>(
                  value: toValue,
                  items: toItems,
                  onChanged: hotspot.changeFloor
                      ? null
                      : (v) {
                          final oldTo = hotspot.toRoomId;
                          hotspot.toRoomId = v ?? hotspot.toRoomId;
                          if (!hotspot.changeFloor) {
                            _retargetTwinForToChange(
                              floor,
                              hotspot,
                              oldTo,
                              hotspot.fromRoomId,
                            );
                          }
                          onChanged();
                        },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppStyles.surfaceAccent,
                  borderRadius: BorderRadius.circular(AppStyles.pillRadius),
                ),
                child: IconButton(
                  tooltip: 'Remove',
                  icon: Icon(
                    Icons.delete_outline,
                    color: AppStyles.textSecondary,
                  ),
                  onPressed: () async {
                    final ok = await confirmDeleteDialog(
                      context,
                      title: 'Remove connection',
                      message: 'This will remove this connection.',
                      confirmLabel: 'Remove',
                      confirmIcon: Icons.link_off,
                    );
                    if (!ok) return;
                    _removeTwin(
                      floor,
                      hotspot,
                      allEditors: allFloorsEditors,
                      sourceFloorIndex: floorIndex,
                    );
                    floor.hotspots.remove(hotspot);
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: hotspot.textCtrl,
            style: TextStyle(
              color: AppStyles.textPrimary,
              fontSize: kControlFontSize,
            ),
            decoration: const InputDecoration(
              labelText: 'Label *',
              prefixIcon: Icon(Icons.label_outline),
            ),
            onChanged: (v) {
              hotspot.text = v;
              _updateTwinFromSource(
                floor,
                hotspot,
                allEditors: allFloorsEditors,
                sourceFloorIndex: floorIndex,
              );
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: hotspot.latCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: AppStyles.textPrimary,
                    fontSize: kControlFontSize,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Lat',
                    prefixIcon: Icon(Icons.explore_outlined),
                  ),
                  onChanged: (v) {
                    hotspot.latitude = double.tryParse(v) ?? hotspot.latitude;
                    _updateTwinFromSource(
                      floor,
                      hotspot,
                      allEditors: allFloorsEditors,
                      sourceFloorIndex: floorIndex,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: hotspot.lonCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: AppStyles.textPrimary,
                    fontSize: kControlFontSize,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Lon',
                    prefixIcon: Icon(Icons.explore_outlined),
                  ),
                  onChanged: (v) {
                    hotspot.longitude = double.tryParse(v) ?? hotspot.longitude;
                    _updateTwinFromSource(
                      floor,
                      hotspot,
                      allEditors: allFloorsEditors,
                      sourceFloorIndex: floorIndex,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _WhiteButton.icon(
                icon: Icons.my_location,
                label: 'Pick',
                onPressed: onPickInPano,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(
                    hotspot.isPaired
                        ? 'Pairing position with $toRoomName'
                        : 'Free positioning',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: hotspot.isPaired,
                  onSelected: (selected) {
                    _setPairingMode(
                      floor,
                      hotspot,
                      selected,
                      allEditors: allFloorsEditors,
                      sourceFloorIndex: floorIndex,
                    );
                    onChanged();
                  },
                  selectedColor: AppStyles.controlBgActive,
                  backgroundColor: AppStyles.surface,
                  labelStyle: TextStyle(
                    color: AppStyles.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                ),
                ChoiceChip(
                  label: const Text(
                    'Change floor',
                    style: TextStyle(fontSize: 12),
                  ),
                  selected: hotspot.changeFloor,
                  onSelected: (hasOtherFloors || hotspot.changeFloor)
                      ? (selected) {
                          if (selected) {
                            if (!hasCrossFloorTargetsAvailable) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'All rooms are already connected. Add another room to create more connections.',
                                  ),
                                ),
                              );
                              return;
                            }
                            hotspot.changeFloor = true;

                            final pick = availableCrossTargets.first;
                            hotspot.targetFloorId = pick.key;
                            hotspot.toRoomId = pick.value;

                            _updateTwinFromSource(
                              floor,
                              hotspot,
                              allEditors: allFloorsEditors,
                              sourceFloorIndex: floorIndex,
                            );
                            onChanged();
                            return;
                          }

                          if (!canToggleChangeFloorOff) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'All rooms on this floor are already connected. You cannot create another same-floor connection.',
                                ),
                              ),
                            );
                            return;
                          }

                          final int newTo = uniqueSameFloorAvailable.first;

                          _removeTwin(
                            floor,
                            hotspot,
                            allEditors: allFloorsEditors,
                            sourceFloorIndex: floorIndex,
                          );
                          hotspot.changeFloor = false;
                          hotspot.targetFloorId = null;
                          hotspot.toRoomId = newTo;

                          _updateTwinFromSource(
                            floor,
                            hotspot,
                            allEditors: allFloorsEditors,
                            sourceFloorIndex: floorIndex,
                          );
                          onChanged();
                        }
                      : null,
                  selectedColor: AppStyles.controlBgActive,
                  backgroundColor: AppStyles.surface,
                  labelStyle: TextStyle(
                    color: AppStyles.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: hotspot.changeFloor
                ? Column(
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Floor'),
                          const SizedBox(width: 8),
                          _WhiteDropdown<int>(
                            value: (hotspot.targetFloorId != null &&
                                    otherFloorIds
                                        .contains(hotspot.targetFloorId))
                                ? hotspot.targetFloorId!
                                : otherFloorIds.first,
                            items: otherFloorIds
                                .map(
                                  (fi) => DropdownMenuItem<int>(
                                    value: fi,
                                    child: Text('Floor $fi'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              hotspot.targetFloorId = v;
                              final tRooms = panoramaData.floorRooms[v] ??
                                  const <RoomData>[];
                              hotspot.toRoomId = tRooms.isEmpty ? 0 : 0;
                              onChanged();
                            },
                            width: 150,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final tfId = (hotspot.targetFloorId != null &&
                                        otherFloorIds
                                            .contains(hotspot.targetFloorId))
                                    ? hotspot.targetFloorId!
                                    : otherFloorIds.first;
                                final rooms = panoramaData.floorRooms[tfId] ??
                                    const <RoomData>[];
                                final items = rooms.isEmpty
                                    ? <DropdownMenuItem<int>>[
                                        const DropdownMenuItem<int>(
                                          value: 0,
                                          child: Text('No rooms'),
                                        ),
                                      ]
                                    : List<DropdownMenuItem<int>>.generate(
                                        rooms.length,
                                        (i) => DropdownMenuItem<int>(
                                          value: i,
                                          child: Text(
                                            rooms[i].name.isNotEmpty
                                                ? rooms[i].name
                                                : 'Pano $i',
                                          ),
                                        ),
                                      );

                                final value = rooms.isEmpty
                                    ? 0
                                    : hotspot.toRoomId
                                        .clamp(0, rooms.length - 1);

                                hotspot.toRoomId = value;

                                return _WhiteDropdown<int>(
                                  value: value,
                                  items: items,
                                  onChanged: (v) {
                                    if (rooms.isEmpty) return;
                                    hotspot.toRoomId =
                                        (v ?? 0).clamp(0, rooms.length - 1);
                                    onChanged();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Future<bool> confirmDeleteDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData confirmIcon = Icons.delete_outline,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: AppStyles.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppStyles.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Row(
            children: [
              _WhiteButton.icon(
                icon: Icons.close,
                label: cancelLabel,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              const Spacer(),
              _WhiteButton.icon(
                icon: confirmIcon,
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

String _labelForRoom(FloorEditor floor, int roomId) {
  if (roomId < 0 || roomId >= floor.rooms.length) return 'Pano $roomId';
  final nm = floor.rooms[roomId].name.trim();
  return nm.isNotEmpty ? nm : 'Pano $roomId';
}

String _twinLabelForSameFloor(FloorEditor floor, EditableHotspot src) {
  return _labelForRoom(floor, src.fromRoomId);
}

String _newPairId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final r = math.Random().nextInt(1 << 32);
  return 'p_${ts.toRadixString(36)}_${r.toRadixString(36)}';
}

String _ensurePairId(EditableHotspot h) {
  if (h.pairId.isEmpty) h.pairId = _newPairId();
  return h.pairId;
}

EditableHotspot? _findOrBindTwin(FloorEditor floor, EditableHotspot h) {
  if (h.changeFloor) return null;
  final pid = _ensurePairId(h);
  for (final x in floor.hotspots) {
    if (!identical(x, h) && x.pairId == pid && !x.changeFloor) return x;
  }
  final idx = floor.hotspots.indexWhere(
    (x) =>
        !x.changeFloor &&
        x.fromRoomId == h.toRoomId &&
        x.toRoomId == h.fromRoomId,
  );
  if (idx >= 0) {
    final found = floor.hotspots[idx];
    found.pairId = pid;
    return found;
  }
  return null;
}

EditableHotspot _ensureTwin(FloorEditor floor, EditableHotspot h) {
  final existing = _findOrBindTwin(floor, h);
  final desiredTwinLabel = _twinLabelForSameFloor(floor, h);

  if (existing != null) {
    existing.fromRoomId = h.toRoomId;
    existing.toRoomId = h.fromRoomId;

    if (existing.text.trim().isEmpty || existing.text.trim() == h.text.trim()) {
      existing.text = desiredTwinLabel;
      try {
        existing.textCtrl.text = existing.text;
      } catch (_) {}
    }

    existing.iconName = h.iconName;
    if (h.isPaired) _applySameFloorMirroredLon(h, existing);
    return existing;
  }

  final pid = _ensurePairId(h);
  final twin = EditableHotspot(
    fromRoomId: h.toRoomId,
    toRoomId: h.fromRoomId,
    latitude: 0,
    longitude: 0,
    text: desiredTwinLabel,
    iconName: h.iconName,
    pairId: pid,
  );
  if (h.isPaired) _applySameFloorMirroredLon(h, twin);
  try {
    twin.textCtrl.text = twin.text;
  } catch (_) {}
  floor.hotspots.add(twin);
  return twin;
}

void _updateTwinFromSource(
  FloorEditor floor,
  EditableHotspot h, {
  List<FloorEditor>? allEditors,
  int? sourceFloorIndex,
}) {
  if (h.changeFloor) {
    if (allEditors == null ||
        sourceFloorIndex == null ||
        h.targetFloorId == null) return;
    _ensureCrossFloorTwin(
      allEditors,
      sourceFloorIndex,
      h,
    );
    return;
  }
  if (!h.isPaired) return;

  final twin = _ensureTwin(floor, h);

  final desiredTwinLabel = _twinLabelForSameFloor(floor, h);
  if (twin.text.trim().isEmpty || twin.text.trim() == h.text.trim()) {
    twin.text = desiredTwinLabel;
    try {
      twin.textCtrl.text = twin.text;
    } catch (_) {}
  }

  twin.iconName = h.iconName;
  twin.fromRoomId = h.toRoomId;
  twin.toRoomId = h.fromRoomId;
  _applySameFloorMirroredLon(h, twin);
}

void _retargetTwinForToChange(
  FloorEditor floor,
  EditableHotspot src,
  int _,
  int __,
) {
  if (src.changeFloor) return;
  final twin = _ensureTwin(floor, src);
  twin.fromRoomId = src.toRoomId;
  twin.toRoomId = src.fromRoomId;

  final desired = _twinLabelForSameFloor(floor, src);
  if (twin.text.trim().isEmpty || twin.text.trim() == src.text.trim()) {
    twin.text = desired;
    try {
      twin.textCtrl.text = desired;
    } catch (_) {}
  }

  if (src.isPaired) _applySameFloorMirroredLon(src, twin);
}

double _wrapLon180(double lon) {
  while (lon > 180) lon -= 360;
  while (lon <= -180) lon += 360;
  return lon;
}

void _applySameFloorMirroredLon(EditableHotspot src, EditableHotspot dst) {
  dst.latitude = src.latitude;
  dst.longitude = _wrapLon180(src.longitude + 180.0);
  try {
    dst.latCtrl.text = dst.latitude.toStringAsFixed(1);
    dst.lonCtrl.text = dst.longitude.toStringAsFixed(1);
  } catch (_) {}
}

void _applyOppositeLatLon(EditableHotspot src, EditableHotspot dst) {
  dst.latitude = -src.latitude;
  dst.longitude = _wrapLon180(src.longitude + 180.0);
  try {
    dst.latCtrl.text = dst.latitude.toStringAsFixed(1);
    dst.lonCtrl.text = dst.longitude.toStringAsFixed(1);
  } catch (_) {}
}

void _removeTwin(
  FloorEditor floor,
  EditableHotspot h, {
  List<FloorEditor>? allEditors,
  int? sourceFloorIndex,
}) {
  if (h.changeFloor) {
    if (allEditors == null ||
        sourceFloorIndex == null ||
        h.targetFloorId == null) return;
    final targetFloor =
        (h.targetFloorId! >= 0 && h.targetFloorId! < allEditors.length)
            ? allEditors[h.targetFloorId!]
            : null;
    if (targetFloor == null) return;
    targetFloor.hotspots.removeWhere((x) =>
        x.pairId == h.pairId &&
        x.changeFloor &&
        x.targetFloorId == sourceFloorIndex &&
        x.fromRoomId == h.toRoomId &&
        x.toRoomId == h.fromRoomId);
    return;
  }
  if (h.pairId.isEmpty) {
    final idx = floor.hotspots.indexWhere(
      (x) =>
          !x.changeFloor &&
          x.fromRoomId == h.toRoomId &&
          x.toRoomId == h.fromRoomId,
    );
    if (idx >= 0) floor.hotspots.removeAt(idx);
    return;
  }
  final idx = floor.hotspots.indexWhere(
    (x) => !x.changeFloor && x.pairId == h.pairId && !identical(x, h),
  );
  if (idx >= 0) floor.hotspots.removeAt(idx);
}

class _RoomSnapshot {
  final String name;
  final String iconName;
  final String imagePath;
  final String description;
  final int presetId;
  final List<_ConnSnapshot> conns;
  final List<_IncomingSnapshot> incoming;

  _RoomSnapshot({
    required this.name,
    required this.iconName,
    required this.imagePath,
    required this.description,
    required this.presetId,
    required this.conns,
    required this.incoming,
  });

  static _RoomSnapshot capture(FloorEditor floor, int roomIndex) {
    final r = floor.rooms[roomIndex];
    final conns = floor.hotspots
        .where((h) => h.fromRoomId == roomIndex)
        .map(
          (h) => _ConnSnapshot(
            to: h.toRoomId,
            lat: h.latitude,
            lon: h.longitude,
            text: h.text,
            iconName: h.iconName,
            pairId: h.pairId,
            isPaired: h.isPaired,
            changeFloor: h.changeFloor,
            targetFloorId: h.targetFloorId,
          ),
        )
        .toList();
    final incoming = floor.hotspots
        .where((h) => h.toRoomId == roomIndex)
        .map(
          (h) => _IncomingSnapshot(
            from: h.fromRoomId,
            lat: h.latitude,
            lon: h.longitude,
            text: h.text,
            iconName: h.iconName,
            pairId: h.pairId,
            isPaired: h.isPaired,
            changeFloor: h.changeFloor,
            targetFloorId: h.targetFloorId,
          ),
        )
        .toList();
    return _RoomSnapshot(
      name: r.name,
      iconName: r.iconName,
      imagePath: r.imagePath,
      description: r.description,
      presetId: r.presetId,
      conns: conns,
      incoming: incoming,
    );
  }

  void restoreInto(FloorEditor floor, int roomIndex) {
    final r = floor.rooms[roomIndex];
    r.name = name;
    r.iconName = iconName;
    r.imagePath = imagePath;
    r.description = description;
    r.presetId = presetId;
    try {
      r.nameCtrl.text = name;
      r.imageCtrl.text = imagePath;
      r.descCtrl.text = description;
    } catch (_) {}
    floor.hotspots.removeWhere(
      (h) => h.fromRoomId == roomIndex || h.toRoomId == roomIndex,
    );
    for (final c in conns) {
      final h = EditableHotspot(
        fromRoomId: roomIndex,
        toRoomId: c.to,
        latitude: c.lat,
        longitude: c.lon,
        text: c.text,
        iconName: c.iconName,
        pairId: c.pairId,
        isPaired: c.isPaired,
        changeFloor: c.changeFloor,
        targetFloorId: c.targetFloorId,
      );
      try {
        h.latCtrl.text = c.lat.toStringAsFixed(1);
        h.lonCtrl.text = c.lon.toStringAsFixed(1);
        h.textCtrl.text = c.text;
      } catch (_) {}
      floor.hotspots.add(h);
    }
    for (final inc in incoming) {
      final h = EditableHotspot(
        fromRoomId: inc.from,
        toRoomId: roomIndex,
        latitude: inc.lat,
        longitude: inc.lon,
        text: inc.text,
        iconName: inc.iconName,
        pairId: inc.pairId,
        isPaired: inc.isPaired,
        changeFloor: inc.changeFloor,
        targetFloorId: inc.targetFloorId,
      );
      try {
        h.latCtrl.text = inc.lat.toStringAsFixed(1);
        h.lonCtrl.text = inc.lon.toStringAsFixed(1);
        h.textCtrl.text = inc.text;
      } catch (_) {}
      floor.hotspots.add(h);
    }
  }
}

class _ConnSnapshot {
  final int to;
  final double lat;
  final double lon;
  final String text;
  final String iconName;
  final String pairId;
  final bool isPaired;
  final bool changeFloor;
  final int? targetFloorId;

  _ConnSnapshot({
    required this.to,
    required this.lat,
    required this.lon,
    required this.text,
    required this.iconName,
    required this.pairId,
    required this.isPaired,
    required this.changeFloor,
    required this.targetFloorId,
  });
}

class _IncomingSnapshot {
  final int from;
  final double lat;
  final double lon;
  final String text;
  final String iconName;
  final String pairId;
  final bool isPaired;
  final bool changeFloor;
  final int? targetFloorId;

  _IncomingSnapshot({
    required this.from,
    required this.lat,
    required this.lon,
    required this.text,
    required this.iconName,
    required this.pairId,
    required this.isPaired,
    required this.changeFloor,
    required this.targetFloorId,
  });
}

class _PanoramaUploadBox extends StatelessWidget {
  final String path;
  final ValueChanged<String> onPick;
  const _PanoramaUploadBox({required this.path, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InkWell(
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          final p = result?.files.single.path;
          if (p != null) onPick(p);
        },
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        child: Container(
          decoration: BoxDecoration(
            color: AppStyles.surface,
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            border: Border.all(
              color: AppStyles.border,
              width: AppStyles.borderWidth,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: (path.isNotEmpty && File(path).existsSync())
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.panorama,
                              color: AppStyles.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload panorama image',
                              style: TextStyle(color: AppStyles.textSecondary),
                            ),
                          ],
                        ),
                      ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppStyles.surfaceMuted, 
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                    border: Border.all(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.image_search, size: 16, color: AppStyles.textPrimary),
                        const SizedBox(width: 6),
                        Text('Change image', style: TextStyle(color: AppStyles.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _WhiteButton.icon({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  State<_WhiteButton> createState() => _WhiteButtonState();
}

class _WhiteButtonState extends State<_WhiteButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    
    final bg = widget.isPrimary ? AppStyles.textPrimary : AppStyles.surface;
    
    final fg = widget.isPrimary ? AppStyles.surface : AppStyles.textPrimary;
    
    final border = Border.all(
      color: widget.isPrimary ? AppStyles.textPrimary : AppStyles.border,
      width: AppStyles.borderWidth,
    );
    final radius = BorderRadius.circular(AppStyles.cardRadius);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _pressed ? bg.withOpacity(0.95) : bg,
            borderRadius: radius,
            border: border,
            boxShadow: widget.isPrimary && _hover
                ? [
                    BoxShadow(
                      color: AppStyles.textPrimary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double? width;

  const _WhiteDropdown({
    required this.value,
    required this.items,
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final expandedItems = items
        .map(
          (it) => DropdownMenuItem<T>(
            value: it.value,
            child: SizedBox(
              width: double.infinity,
              child: Align(alignment: Alignment.centerLeft, child: it.child),
            ),
          ),
        )
        .toList();

    return DropdownButtonHideUnderline(
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: kControlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppStyles.surface,
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          border: Border.all(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        alignment: Alignment.centerLeft,
        child: DropdownButton<T>(
          value: value,
          items: expandedItems,
          onChanged: onChanged,
          isDense: true,
          isExpanded: true,
          iconEnabledColor: AppStyles.textPrimary,
          dropdownColor: AppStyles.surface,
          style: TextStyle(
            color: AppStyles.textPrimary,
            fontSize: kControlFontSize,
          ),
        ),
      ),
    );
  }
}

void _setPairingMode(
  FloorEditor floor,
  EditableHotspot h,
  bool paired, {
  List<FloorEditor>? allEditors,
  int? sourceFloorIndex,
}) {
  h.isPaired = paired;
  if (h.changeFloor) {
    _updateTwinFromSource(
      floor,
      h,
      allEditors: allEditors,
      sourceFloorIndex: sourceFloorIndex,
    );
    return;
  }
  final twin = _findOrBindTwin(floor, h);
  if (twin != null) twin.isPaired = paired;
  if (paired) {
    _updateTwinFromSource(
      floor,
      h,
      allEditors: allEditors,
      sourceFloorIndex: sourceFloorIndex,
    );
  }
}

EditableHotspot _ensureCrossFloorTwin(
  List<FloorEditor> editors,
  int sourceFloorIndex,
  EditableHotspot src,
) {
  final targetFloorIndex = src.targetFloorId;
  if (!src.changeFloor || targetFloorIndex == null) return src;
  if (targetFloorIndex < 0 || targetFloorIndex >= editors.length) return src;

  final sourceFloor = editors[sourceFloorIndex];
  final targetFloor = editors[targetFloorIndex];
  final pid = _ensurePairId(src);

  String twinLabel() => _labelForRoom(sourceFloor, src.fromRoomId);

  for (final h in targetFloor.hotspots) {
    if (h.pairId == pid &&
        h.changeFloor &&
        h.targetFloorId == sourceFloorIndex &&
        h.fromRoomId == src.toRoomId &&
        h.toRoomId == src.fromRoomId) {
      if (h.text.trim().isEmpty || h.text.trim() == src.text.trim()) {
        h.text = twinLabel();
        try {
          h.textCtrl.text = h.text;
        } catch (_) {}
      }
      h.iconName = src.iconName;
      h.isPaired = src.isPaired;
      if (src.isPaired) _applyOppositeLatLon(src, h);
      return h;
    }
  }

  final twin = EditableHotspot(
    fromRoomId: src.toRoomId,
    toRoomId: src.fromRoomId,
    latitude: src.isPaired ? -src.latitude : 0,
    longitude: src.isPaired ? _wrapLon180(src.longitude + 180) : 0,
    text: twinLabel(),
    iconName: src.iconName,
    pairId: pid,
    isPaired: src.isPaired,
    changeFloor: true,
    targetFloorId: sourceFloorIndex,
  );
  try {
    twin.textCtrl.text = twin.text;
  } catch (_) {}
  targetFloor.hotspots.add(twin);
  return twin;
}
