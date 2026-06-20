import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show File;
import 'package:file_picker/file_picker.dart';
import '../../../models/houses_store.dart';
import '../../../features/panorama/theme/ui_styles.dart';
import '../../../models/editor_models.dart';
import 'room_editor_page.dart';
import '../../../models/panorama_data.dart';

class HouseCreatorScreen extends StatefulWidget {
  final PanoramaData? initialHouse;
  final int? houseIndex;

  const HouseCreatorScreen({super.key, this.initialHouse, this.houseIndex});

  @override
  State<HouseCreatorScreen> createState() => _HouseCreatorScreenState();
}

const double kControlHeight = 40.0;
const double kControlFontSize = 14.0;

class _HouseCreatorScreenState extends State<HouseCreatorScreen> {
  final List<FloorEditor> _floors = (() {
    final floor = FloorEditor();
    floor.rooms.add(EditableRoom());
    return [floor];
  })();
  final TextEditingController _titleCtrl = TextEditingController(
    text: 'My House',
  );
  final TextEditingController _addressCtrl = TextEditingController(text: '');
  final TextEditingController _areaCtrl = TextEditingController(text: '');
  String _houseThumbPath = '';
  GlobalKey<SliverAnimatedListState> _floorsKey =
      GlobalKey<SliverAnimatedListState>();
  final List<bool> _floorExpanded = [false];

  late String _initialDigest;
  bool get _hasChanges => _computeDigest() != _initialDigest;

  late _HouseSnapshot _snapshot;

  bool _saving = false;

  PanoramaData? _draftHouse;
  int? _createdHouseIndex;

  // --- NEW: tracking for reorder change indicators ---
  bool _showReorderIndicators = false;
  final Map<FloorEditor, int> _originalFloorOrder = {};

  void _captureOriginalFloorOrder() {
    _originalFloorOrder
      ..clear()
      ..addEntries(_floors.asMap().entries.map(
        (e) => MapEntry(e.value, e.key),
      ));
  }
  // ---------------------------------------------------

  void _addFloor() {
    final index = _floors.length;
    final newFloor = FloorEditor();
    newFloor.rooms.add(EditableRoom());
    _floors.add(newFloor);
    _floorExpanded.insert(index, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floorsKey.currentState?.insertItem(
        index,
        duration: const Duration(milliseconds: 300),
      );
      setState(() {});
    });
    // Ensure original order tracking includes newly added floor even after indicators shown.
    if (_showReorderIndicators) {
      _originalFloorOrder[newFloor] = index;
    } else {
      _captureOriginalFloorOrder();
    }
  }

  void _removeFloor(int floorIdx) {
    if (_floors.length == 1) return;
    final removed = _floors.removeAt(floorIdx);
    if (floorIdx >= 0 && floorIdx < _floorExpanded.length) {
      _floorExpanded.removeAt(floorIdx);
    }

    if (_floors.length == 1) {
      setState(() {
        _floorExpanded
          ..clear()
          ..addAll(List<bool>.filled(_floors.length, false));
        _floorsKey = GlobalKey<SliverAnimatedListState>();
      });
    } else {
      _floorsKey.currentState?.removeItem(
        floorIdx,
        (context, animation) => _buildAnimatedFloorTile(
          context,
          removed,
          floorIdx,
          animation,
          interactive: false,
        ),
        duration: const Duration(milliseconds: 300),
      );
      setState(() {
        _floorExpanded
          ..clear()
          ..addAll(List<bool>.filled(_floors.length, false));
      });
    }
  }

  void _addRoom(int floorIdx) {
    _floors[floorIdx].rooms.add(EditableRoom());
    if (floorIdx >= 0 && floorIdx < _floorExpanded.length) {
      _floorExpanded[floorIdx] = true;
    }
    setState(() {});
    _syncStore();
  }

  void _deleteRoom(int floorIdx, int roomIdx) {
    final floor = _floors[floorIdx];

    // NEW: prevent deleting the last room on a floor
    if (floor.rooms.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one room on each floor')),
      );
      return;
    }

    if (floor.rooms.isEmpty) return;
    floor.rooms.removeAt(roomIdx);
    for (final r in floor.rooms) {
      r.connectedRoomIds = r.connectedRoomIds
          .where((id) => id != roomIdx)
          .map((id) => id > roomIdx ? id - 1 : id)
          .toList();
    }
    floor.hotspots.removeWhere(
      (h) => h.fromRoomId == roomIdx || h.toRoomId == roomIdx,
    );
    for (final h in floor.hotspots) {
      if (h.fromRoomId > roomIdx) h.fromRoomId -= 1;
      if (h.toRoomId > roomIdx) h.toRoomId -= 1;
    }
    setState(() {});
    _syncStore();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialHouse != null) {
      _loadFromPanoramaData(widget.initialHouse!);
    } else {
      final loaded = _loadFromPanoramaStoreIfAny();
      if (!loaded) {
        PanoramaData().replaceFromEditors(_floors);
      }
    }
    _initialDigest = _computeDigest();
    _snapshot = _HouseSnapshot.capture(
      _titleCtrl.text,
      _addressCtrl.text,
      _areaCtrl.text,
      _houseThumbPath,
      _floors,
    );
    _captureOriginalFloorOrder(); // capture initial order
  }

  void _loadFromPanoramaData(PanoramaData data) {
    _titleCtrl.text = data.houseName;
    _addressCtrl.text = data.houseAddress;
    _areaCtrl.text = data.houseArea;
    _houseThumbPath = data.houseThumbnail;

    final floorKeys = data.floorRooms.keys.toList()..sort();
    final rebuilt = <FloorEditor>[];

    for (final fIdx in floorKeys) {
      final roomsData = data.floorRooms[fIdx] ?? const <RoomData>[];
      final hotspotsData = data.floorHotspots[fIdx] ?? const <HotspotData>[];

      final floor = FloorEditor();

      for (final rd in roomsData) {
        final r = EditableRoom();
        r.name = rd.name;
        r.imagePath = rd.imagePath;
        r.iconName = _iconNameFromIcon(rd.icon, fallback: 'circle_outlined');
        r.description = rd.description; // NEW
        r.connectedRoomIds = List<int>.from(rd.connectedRoomIds);
        // Optionally sync controllers if needed
        try {
          r.nameCtrl.text = r.name;
          r.imageCtrl.text = r.imagePath;
          r.descCtrl.text = r.description; // NEW
        } catch (_) {}
        floor.rooms.add(r);
      }

      for (final hd in hotspotsData) {
        floor.hotspots.add(
          EditableHotspot(
            fromRoomId: hd.fromRoomId,
            toRoomId: hd.toRoomId,
            latitude: hd.latitude,
            longitude: hd.longitude,
            text: hd.text,
            iconName: _iconNameFromIcon(hd.icon, fallback: 'arrow_forward'),
            changeFloor: hd.targetFloorId != null,
            targetFloorId: hd.targetFloorId,
          ),
        );
      }

      rebuilt.add(floor);
    }

    setState(() {
      _floors
        ..clear()
        ..addAll(rebuilt);
      _floorExpanded
        ..clear()
        ..addAll(List<bool>.filled(_floors.length, false));
    });
  }

  String _computeDigest() {
    final data = {
      'title': _titleCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'area': _areaCtrl.text.trim(),
      'thumb': _houseThumbPath,
      'floorsCount': _floors.length,
      'rooms': _floors
          .map(
            (f) => f.rooms
                .map((r) => '${r.name}|${r.iconName}|${r.imagePath}')
                .toList(),
          )
          .toList(),
    };
    return data.toString();
  }

  Future<void> _onExitPressed() async {
    if (_hasChanges && !_validateFields()) {
      return;
    }
    if (!_hasChanges) {
      Navigator.of(context).pop();
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
    switch (action) {
      case 'save':
        await _onSavePressed(exitAfter: true);
        break;
      case 'discard':
        setState(() {
          _snapshot.restoreInto(
            _titleCtrl,
            _addressCtrl,
            _areaCtrl,
            (v) => _houseThumbPath = v,
            _floors,
          );
          _floorExpanded
            ..clear()
            ..addAll(List<bool>.filled(_floors.length, false));

          _floorsKey = GlobalKey<SliverAnimatedListState>();
        });
        // NEW: push restored data into the store/draft so added/deleted rooms are reverted globally
        _syncStore();
        if (!mounted) return;
        Navigator.of(context).pop();
        break;
      default:
        break;
    }
  }

  Future<void> _onSavePressed({bool exitAfter = false}) async {
    if (_saving) return;
    if (_hasChanges && !_validateFields()) return;
    setState(() => _saving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _syncStore();
      final store = HousesStore.instance;
      if (widget.houseIndex == null) {
        if (_createdHouseIndex == null) {
          if (_draftHouse == null) {
            _draftHouse = PanoramaData()
              ..replaceFromEditors(
                _floors,
                name: _titleCtrl.text,
                address: _addressCtrl.text,
                area: _areaCtrl.text,
                thumbnail: _houseThumbPath,
              );
          }
          store.addHouse(_draftHouse!);
          _createdHouseIndex = store.houses.length - 1;
          store.selectedIndex = _createdHouseIndex!;
        } else {
          store.notifyListeners();
        }
      }
      _initialDigest = _computeDigest();
      _snapshot = _HouseSnapshot.capture(
        _titleCtrl.text,
        _addressCtrl.text,
        _areaCtrl.text,
        _houseThumbPath,
        _floors,
      );

      // --- CLEAR INDICATORS AFTER SAVE ---
      _showReorderIndicators = false;
      _captureOriginalFloorOrder();
      // -----------------------------------

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('House saved')));
      if (exitAfter) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _loadFromPanoramaStoreIfAny() {
    final store = PanoramaData();
    if (store.floorRooms.isEmpty) return false;

    final floorKeys = store.floorRooms.keys.toList()..sort();
    final rebuilt = <FloorEditor>[];

    for (final fIdx in floorKeys) {
      final roomsData = store.floorRooms[fIdx] ?? const <RoomData>[];
      final hotspotsData = store.floorHotspots[fIdx] ?? const <HotspotData>[];

      final floor = FloorEditor();

      for (final rd in roomsData) {
        final r = EditableRoom();
        r.name = rd.name;
        r.imagePath = rd.imagePath;
        r.iconName = _iconNameFromIcon(rd.icon, fallback: 'circle_outlined');
        r.connectedRoomIds = List<int>.from(rd.connectedRoomIds);
        floor.rooms.add(r);
      }

      for (final hd in hotspotsData) {
        floor.hotspots.add(
          EditableHotspot(
            fromRoomId: hd.fromRoomId,
            toRoomId: hd.toRoomId,
            latitude: hd.latitude,
            longitude: hd.longitude,
            text: hd.text,
            iconName: _iconNameFromIcon(hd.icon, fallback: 'arrow_forward'),
            changeFloor: hd.targetFloorId != null,
            targetFloorId: hd.targetFloorId,
          ),
        );
      }

      rebuilt.add(floor);
    }

    setState(() {
      _floors
        ..clear()
        ..addAll(rebuilt);
      _floorExpanded
        ..clear()
        ..addAll(List<bool>.filled(_floors.length, false));
    });

    return true;
  }

  String _iconNameFromIcon(
    IconData icon, {
    String fallback = 'circle_outlined',
  }) {
    for (final entry in kIconCatalog.entries) {
      final v = entry.value;
      if (v.codePoint == icon.codePoint && v.fontFamily == icon.fontFamily) {
        return entry.key;
      }
    }
    return fallback;
  }

  void _syncStore() {
    final store = HousesStore.instance;

    if (widget.houseIndex != null &&
        widget.houseIndex! >= 0 &&
        widget.houseIndex! < store.houses.length) {
      final existing = store.houses[widget.houseIndex!];
      existing.replaceFromEditors(
        _floors,
        name: _titleCtrl.text,
        address: _addressCtrl.text,
        area: _areaCtrl.text,
        thumbnail: _houseThumbPath,
      );
      store.selectedIndex = widget.houseIndex!;
      store.notifyListeners();
      return;
    }

    if (_draftHouse == null) {
      _draftHouse = PanoramaData();
    }
    _draftHouse!.replaceFromEditors(
      _floors,
      name: _titleCtrl.text,
      address: _addressCtrl.text,
      area: _areaCtrl.text,
      thumbnail: _houseThumbPath,
    );

    if (_createdHouseIndex != null) {
      store.notifyListeners();
    }
  }

  bool _validateFields() {
    final name = _titleCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final area = _areaCtrl.text.trim();
    if (name.isEmpty || address.isEmpty || area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields: name, address, and area.',
          ),
        ),
      );
      return false;
    }
    if (double.tryParse(area) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area must be a valid number.')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.light();
    final themed = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
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
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: AppStyles.textPrimary),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppStyles.accentActive, width: 1.2),
        ),
        labelStyle: TextStyle(color: AppStyles.textSecondary),
        hintStyle: TextStyle(color: AppStyles.textSecondary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppStyles.surface,
        selectedColor: AppStyles.controlBgActive,
        side: BorderSide(color: AppStyles.border, width: AppStyles.borderWidth),
        labelStyle: TextStyle(color: AppStyles.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
          backgroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
          backgroundColor: Colors.white,
          elevation: 0,
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('House Creator')),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: _ThumbnailBox(
                  path: _houseThumbPath,
                  onPick: (p) => setState(() => _houseThumbPath = p),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(color: AppStyles.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'House title *',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      style: TextStyle(color: AppStyles.textPrimary),
                      decoration: const InputDecoration(labelText: 'Address *'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _areaCtrl,
                      style: TextStyle(color: AppStyles.textPrimary),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Area (m²) *',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) => child,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;

                    // Before first reorder capture original order
                    if (!_showReorderIndicators) {
                      _captureOriginalFloorOrder();
                    }

                    final floor = _floors.removeAt(oldIndex);
                    _floors.insert(newIndex, floor);
                    final expanded = _floorExpanded.removeAt(oldIndex);
                    _floorExpanded.insert(newIndex, expanded);

                    // Enable indicators
                    _showReorderIndicators = true;
                  });
                  _syncStore();
                },
                children: [
                  for (int index = 0; index < _floors.length; index++)
                    Container(
                      key: ValueKey('floor-$index'),
                      child: _buildFloorTile(context, _floors[index], index),
                    ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 72)),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WhiteButton.icon(
                icon: Icons.add,
                label: 'Add Floor',
                onPressed: _addFloor,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _WhiteButton.icon(
                    icon: Icons.delete_outline,
                    label: 'Delete house',
                    onPressed: () async {
                      final ok = await confirmDeleteDialog(
                        context,
                        title: 'Delete house',
                        message:
                            'This will remove all floors, rooms, and connections.',
                        confirmLabel: 'Delete',
                        confirmIcon: Icons.delete_outline,
                      );
                      if (!ok) return;
                      final store = HousesStore.instance;
                      if (widget.houseIndex != null &&
                          widget.houseIndex! >= 0 &&
                          widget.houseIndex! < store.houses.length) {
                        store.deleteHouse(widget.houseIndex!);
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          _floors.clear();
                          final floor = FloorEditor();
                          floor.rooms.add(EditableRoom());
                          _floors.add(floor);
                          _floorExpanded
                            ..clear()
                            ..addAll(List<bool>.filled(_floors.length, false));
                          _floorsKey = GlobalKey<SliverAnimatedListState>();
                          _houseThumbPath = '';
                          _titleCtrl.text = 'My House';
                          _addressCtrl.text = '';
                          _areaCtrl.text = '';
                        });
                        _syncStore();
                      }
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
                      onPressed: () => _onSavePressed(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRoomEditor(int fIdx, int rIdx) async {
    // Ensure PanoramaData reflects the latest _floors before opening editor
    _syncStore();

    final store = HousesStore.instance;
    PanoramaData panoramaDataToUse;
    if (widget.houseIndex != null) {
      panoramaDataToUse = store.houses[widget.houseIndex!];
    } else if (_draftHouse != null) {
      panoramaDataToUse = _draftHouse!;
    } else {
      // Fresh in-memory data for a new (unsaved) house
      panoramaDataToUse = PanoramaData()..replaceFromEditors(_floors);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomEditorPage(
          floor: _floors[fIdx],
          roomIndex: rIdx,
          floorIndex: fIdx,
          panoramaData: panoramaDataToUse,
          allFloorsEditors: _floors,
        ),
      ),
    );
    setState(() {});
    _syncStore(); // keep store up to date after returning as well
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

  Widget _buildRoomCard(int fIdx, int rIdx, EditableRoom room) {
    final floor = _floors[fIdx];
    final connCount = floor.hotspots.where((h) => h.fromRoomId == rIdx).length;

    // NEW: can delete only if more than 1 room on this floor
    final bool canDeleteRoom = floor.rooms.length > 1;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(0.0, 8.0, 8.0, 0.0),
      leading: _RoomIcon(iconName: room.iconName),
      title: Text(
        room.name.isEmpty ? 'Pano $rIdx' : room.name,
        style: TextStyle(
          color: AppStyles.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '$connCount connection${connCount == 1 ? '' : 's'}',
        style: TextStyle(color: AppStyles.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: canDeleteRoom
                ? 'Delete pano'
                : 'Keep at least one room on this floor',
            icon: Icon(
              Icons.delete_outline,
              color: canDeleteRoom
                  ? Colors.redAccent
                  : const Color.fromRGBO(0, 0, 0, 0.3),
            ),
            onPressed: canDeleteRoom
                ? () async {
                    final ok = await confirmDeleteDialog(
                      context,
                      title: 'Delete pano',
                      message:
                          'This will remove this room and its connections.',
                    );
                    if (ok) _deleteRoom(fIdx, rIdx);
                  }
                : null,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: () => _openRoomEditor(fIdx, rIdx),
    );
  }

  Widget _buildAnimatedFloorTile(
    BuildContext context,
    FloorEditor floor,
    int fIdx,
    Animation<double> animation, {
    bool interactive = true,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: _buildFloorTile(context, floor, fIdx, interactive: interactive),
      ),
    );
  }

  // --- helper: compact, monochrome indicator placed left of the card ---
  Widget _buildReorderIndicator(FloorEditor floor, int currentIndex) {
    // Compute original index and delta
    final int? orig = _originalFloorOrder[floor];
    if (!_showReorderIndicators || orig == null) {
      // Unchanged or indicators disabled => small circle
      return const Icon(Icons.minimize, size: 16, color: Colors.black54);
    }

    final int delta = orig - currentIndex; // positive => moved up
    if (delta == 0) {
      return const Icon(Icons.minimize, size: 16, color: Colors.black54);
    }

    final bool movedUp = delta > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          movedUp ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          color: Colors.black54,
        ),
        const SizedBox(width: 2),
        Text(
          '${delta.abs()}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700, // increased weight
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildFloorTile(
    BuildContext context,
    FloorEditor floor,
    int fIdx, {
    bool interactive = true,
  }) {
    final canDeleteFloor = interactive && _floors.length > 1;
    final isExpanded = (fIdx >= 0 && fIdx < _floorExpanded.length)
        ? _floorExpanded[fIdx]
        : false;

    // Build the card content (unchanged except we removed the in-title indicator)
    final card = Container(
      // move horizontal spacing to the row padding; keep only vertical margin here
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppStyles.surface,
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        border: Border.all(
          color: AppStyles.border,
          width: AppStyles.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: fIdx,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 20.0, 0.0, 20.0),
              child: Icon(Icons.drag_handle, color: AppStyles.textSecondary),
            ),
          ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: AppStyles.border,
                splashFactory: NoSplash.splashFactory,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                listTileTheme: const ListTileThemeData(
                  tileColor: Colors.transparent,
                  selectedTileColor: Colors.transparent,
                ),
              ),
              child: ExpansionTile(
                key: ValueKey('floor-$fIdx-${isExpanded ? 'open' : 'closed'}'),
                initiallyExpanded: isExpanded,
                onExpansionChanged: interactive
                    ? (open) => setState(() {
                          if (fIdx >= 0 && fIdx < _floorExpanded.length) {
                            _floorExpanded[fIdx] = open;
                          }
                        })
                    : null,
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.transparent),
                ),
                collapsedShape: const RoundedRectangleBorder(
                  side: BorderSide(color: Colors.transparent),
                ),
                title: Row(
                  children: [
                    Text(
                      'Floor $fIdx',
                      style: TextStyle(
                        color: AppStyles.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // indicator moved outside the card (left gutter)
                  ],
                ),
                subtitle: Text(
                  '${floor.rooms.length} panoramas • ${floor.hotspots.length} connections',
                  style: TextStyle(color: AppStyles.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Add pano',
                      icon: Icon(
                        Icons.meeting_room,
                        color: AppStyles.textSecondary,
                      ),
                      onPressed: interactive ? () => _addRoom(fIdx) : null,
                    ),
                    IconButton(
                      tooltip: canDeleteFloor
                          ? 'Delete Floor'
                          : 'Keep at least one floor',
                      icon: Icon(
                        Icons.delete_outline,
                        color: canDeleteFloor
                            ? Colors.redAccent
                            : const Color.fromRGBO(0, 0, 0, 0.3),
                      ),
                      onPressed: canDeleteFloor
                          ? () async {
                              final ok = await confirmDeleteDialog(
                                context,
                                title: 'Delete floor',
                                message:
                                    'This will remove Floor $fIdx and all its rooms and connections.',
                              );
                              if (ok) _removeFloor(fIdx);
                            }
                          : null,
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 24.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panoramas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textPrimary,
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: floor.rooms.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'No rooms yet. Add one with the button above.',
                                    style: TextStyle(
                                      color: AppStyles.textSecondary,
                                    ),
                                  ),
                                )
                              : Column(
                                  key: ValueKey(floor.rooms.length),
                                  children: [
                                    ...List.generate(floor.rooms.length, (rIdx) {
                                      final room = floor.rooms[rIdx];
                                      return TweenAnimationBuilder<double>(
                                        key: ValueKey(room),
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOut,
                                        tween: Tween(begin: 0, end: 1),
                                        builder: (context, t, child) => Opacity(
                                          opacity: t,
                                          child: Transform.translate(
                                            offset: Offset(0, (1 - t) * 8),
                                            child: child,
                                          ),
                                        ),
                                        child: _buildRoomCard(fIdx, rIdx, room),
                                      );
                                    }),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Row: left gutter indicator + card
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left gutter indicator, outside the card, vertically centered
            SizedBox(
              width: 34,
              child: Center(child: _buildReorderIndicator(floor, fIdx)),
            ),
            const SizedBox(width: 6), // increased spacing between indicator and card
            // Card
            Expanded(child: card),
          ],
        ),
      ),
    );
  }
}

class _RoomIcon extends StatelessWidget {
  final String iconName;
  const _RoomIcon({required this.iconName});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade200,
        child: Icon(
          kIconCatalog[iconName] ?? Icons.circle_outlined,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _ThumbnailBox extends StatelessWidget {
  final String path;
  final ValueChanged<String> onPick;
  const _ThumbnailBox({required this.path, required this.onPick});

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppStyles.surface,
            borderRadius: BorderRadius.circular(12),
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
                              'Upload Thumbnail',
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
                    color: const Color.fromRGBO(255, 255, 255, 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.image_search,
                          size: 16,
                          color: AppStyles.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Change image',
                          style: TextStyle(color: AppStyles.textPrimary),
                        ),
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

  const _WhiteButton.icon({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_WhiteButton> createState() => _WhiteButtonState();
}

class _WhiteButtonState extends State<_WhiteButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;
    final border = Border.all(
      color: AppStyles.border,
      width: AppStyles.borderWidth,
    );
    final radius = BorderRadius.circular(12);

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed ? bg.withOpacity(0.95) : bg,
            borderRadius: radius,
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: AppStyles.textPrimary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(color: AppStyles.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseSnapshot {
  final String title;
  final String address;
  final String area;
  final String thumb;
  final List<FloorEditor> floors;

  _HouseSnapshot({
    required this.title,
    required this.address,
    required this.area,
    required this.thumb,
    required this.floors,
  });

  static _HouseSnapshot capture(
    String title,
    String address,
    String area,
    String thumb,
    List<FloorEditor> floors,
  ) {
    final copiedFloors = floors.map((f) => f.deepCopy()).toList();
    return _HouseSnapshot(
      title: title,
      address: address,
      area: area,
      thumb: thumb,
      floors: copiedFloors,
    );
  }

  void restoreInto(
    TextEditingController titleCtrl,
    TextEditingController addressCtrl,
    TextEditingController areaCtrl,
    ValueChanged<String> setThumb,
    List<FloorEditor> targetFloors,
  ) {
    titleCtrl.text = title;
    addressCtrl.text = address;
    areaCtrl.text = area;
    setThumb(thumb);
    targetFloors
      ..clear()
      ..addAll(floors.map((f) => f.deepCopy()).toList());
  }
}

extension DeepCopyFloorEditor on FloorEditor {
  FloorEditor deepCopy() {
    final copy = FloorEditor();
    copy.rooms.addAll(rooms.map((r) => r.deepCopy()));
    copy.hotspots.addAll(hotspots.map((h) => h.deepCopy()));
    return copy;
  }
}

extension DeepCopyEditableRoom on EditableRoom {
  EditableRoom deepCopy() {
    final copy = EditableRoom();
    copy.name = name;
    copy.iconName = iconName;
    copy.imagePath = imagePath;
    copy.description = description; // NEW
    copy.connectedRoomIds = List<int>.from(connectedRoomIds);
    return copy;
  }
}

extension DeepCopyEditableHotspot on EditableHotspot {
  EditableHotspot deepCopy() {
    return EditableHotspot(
      fromRoomId: fromRoomId,
      toRoomId: toRoomId,
      latitude: latitude,
      longitude: longitude,
      text: text,
      iconName: iconName,
      pairId: pairId,
      isPaired: isPaired,
      changeFloor: changeFloor,
      targetFloorId: targetFloorId,
    );
  }
}
