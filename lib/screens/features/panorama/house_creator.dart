import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../models/houses_store.dart';
import '../../../features/panorama/theme/ui_styles.dart';
import '../../../models/editor_models.dart';
import 'room_editor_page.dart';
import '../../../models/panorama_data.dart';

class AIClassifier {

  Interpreter? _interpreter;


  final List<String> labels = [
    'backyard',
    'bathroom',
    'bedroom',
    'frontyard',
    'kitchen',
    'livingRoom'
  ];



  // -----------------------------
  // MODEL YÜKLE
  // -----------------------------
  Future<void> loadModel() async {

    if (_interpreter != null) return;


    try {

      _interpreter =
      await Interpreter.fromAsset(
          'assets/room_model.tflite'
      );


      debugPrint("MODEL YÜKLENDİ");


      debugPrint(
          "INPUT SHAPE : "
              "${_interpreter!
              .getInputTensor(0)
              .shape}"
      );


      debugPrint(
          "INPUT TYPE : "
              "${_interpreter!
              .getInputTensor(0)
              .type}"
      );


      debugPrint(
          "OUTPUT SHAPE : "
              "${_interpreter!
              .getOutputTensor(0)
              .shape}"
      );


      debugPrint(
          "OUTPUT TYPE : "
              "${_interpreter!
              .getOutputTensor(0)
              .type}"
      );



    } catch(e){

      debugPrint(
          "Model yükleme hatası: $e"
      );

    }

  }





  // -----------------------------
  // RESİM SINIFLANDIR
  // -----------------------------
  Future<String> classifyImage(
      String imagePath
      ) async {


    await loadModel();


    if(_interpreter == null){

      return "Model yok";

    }



    // -------------------------
    // RESİM OKUMA
    // -------------------------

    final bytes =
    File(imagePath)
        .readAsBytesSync();


    img.Image? image =
    img.decodeImage(bytes);



    if(image == null){

      return "Resim okunamadı";

    }



    // Python:
    // cv2.resize(img_rgb,(224,224))

    final resized =
    img.copyResize(
      image,
      width:224,
      height:224,
      interpolation:
      img.Interpolation.linear,
    );




    // -------------------------
    // INPUT TENSOR
    // Python:
    // float32
    // 0-255
    // [1,224,224,3]
    // -------------------------


    final input =
    List.generate(
      1,
          (_) =>
          List.generate(
            224,
                (y)=>
                List.generate(
                  224,
                      (x){


                    final pixel =
                    resized.getPixel(x,y);



                    return [

                      pixel.r.toDouble(),

                      pixel.g.toDouble(),

                      pixel.b.toDouble(),


                    ];


                  },
                ),
          ),
    );





    // -------------------------
    // OUTPUT
    // -------------------------


    final output =
    List.generate(
      1,
          (_) =>
          List.filled(
              labels.length,
              0.0
          ),
    );




    // MODEL ÇALIŞTIR

    _interpreter!.run(
        input,
        output
    );





    final result =
    List<double>.from(
        output[0]
    );



    debugPrint("------------------");


    for(int i=0;i<labels.length;i++){

      debugPrint(
          "${labels[i]} : "
              "${result[i]}"
      );

    }



    // -------------------------
    // MAX BUL
    // -------------------------

    int index=0;


    for(int i=1;i<result.length;i++){

      if(result[i]>result[index]){

        index=i;

      }

    }



    double confidence =
        result[index]*100;



    debugPrint(
        "TAHMİN : "
            "${labels[index]}"
            "  %"
            "${confidence.toStringAsFixed(2)}"
    );



    return labels[index];

  }





  void dispose(){

    _interpreter?.close();

  }


}

class HouseCreatorScreen extends StatefulWidget {
  final PanoramaData? initialHouse;
  final int? houseIndex;

  const HouseCreatorScreen({super.key, this.initialHouse, this.houseIndex});

  @override
  State<HouseCreatorScreen> createState() => _HouseCreatorScreenState();
}

const double kControlHeight = 40.0;
const double kControlFontSize = 16.0;

class _HouseCreatorScreenState extends State<HouseCreatorScreen> {
  final AIClassifier _aiClassifier = AIClassifier();

  static const String _kBatchConnectionPairId = 'batch_auto';
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
  final List<bool> _floorExpanded = [false];

  late String _initialDigest;
  bool get _hasChanges => _computeDigest() != _initialDigest;

  late _HouseSnapshot _snapshot;

  bool _saving = false;

  PanoramaData? _draftHouse;
  int? _createdHouseIndex;

  bool _showReorderIndicators = false;
  final Map<FloorEditor, int> _originalFloorOrder = {};

  final Map<FloorEditor, Map<EditableRoom, int>> _originalRoomOrder = {};

  void _captureOriginalFloorOrder() {
    _originalFloorOrder
      ..clear()
      ..addEntries(_floors.asMap().entries.map(
            (e) => MapEntry(e.value, e.key),
      ));
  }

  void _captureOriginalRoomOrder(FloorEditor floor) {
    if (_originalRoomOrder.containsKey(floor)) return;
    _originalRoomOrder[floor] = {
      for (final e in floor.rooms.asMap().entries) e.value: e.key,
    };
  }

  void _addFloor() {
    final index = _floors.length;
    final newFloor = FloorEditor();
    newFloor.rooms.add(EditableRoom());

    setState(() {
      _floors.add(newFloor);
      _floorExpanded.insert(index, false);

      if (_showReorderIndicators) {
        _originalFloorOrder[newFloor] = index;
      } else {
        _captureOriginalFloorOrder();
      }
    });
  }

  void _removeFloor(int floorIdx) {
    if (_floors.length == 1) return;

    final floorToRemove = _floors[floorIdx];

    setState(() {
      _floors.removeAt(floorIdx);
      if (floorIdx >= 0 && floorIdx < _floorExpanded.length) {
        _floorExpanded.removeAt(floorIdx);
      }

      _floorExpanded
        ..clear()
        ..addAll(List<bool>.filled(_floors.length, false));

      _showReorderIndicators = false;
      _captureOriginalFloorOrder();
      _originalRoomOrder.remove(floorToRemove);
    });
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
    _aiClassifier.loadModel();

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
    _captureOriginalFloorOrder();
  }

  @override
  void dispose() {
    _aiClassifier.dispose();
    super.dispose();
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
        r.description = rd.description;
        r.connectedRoomIds = List<int>.from(rd.connectedRoomIds);
        r.presetId = rd.presetId;

        try {
          r.nameCtrl.text = r.name;
          r.imageCtrl.text = r.imagePath;
          r.descCtrl.text = r.description;
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
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
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
        });

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

      _showReorderIndicators = false;
      _captureOriginalFloorOrder();

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
      scaffoldBackgroundColor: AppStyles.surfaceMuted,
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
          backgroundColor: WidgetStatePropertyAll(AppStyles.surface),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            ),
          ),
        ),
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
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppStyles.surface,
        selectedColor: AppStyles.controlBgActive,
        side: BorderSide(color: AppStyles.border, width: AppStyles.borderWidth),
        labelStyle: TextStyle(color: AppStyles.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
          backgroundColor: AppStyles.surface,
          elevation: 0,
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppStyles.textPrimary,
          backgroundColor: AppStyles.surface,
          elevation: 0,
          side: BorderSide(
            color: AppStyles.border,
            width: AppStyles.borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: AppStyles.surfaceMuted,
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
                      style: TextStyle(
                        color: AppStyles.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'House title *',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      style: TextStyle(color: AppStyles.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _areaCtrl,
                      style: TextStyle(color: AppStyles.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Area (m²) *',
                        prefixIcon: Icon(Icons.aspect_ratio),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) => child,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;

                      if (!_showReorderIndicators) {
                        _captureOriginalFloorOrder();
                      }

                      final floor = _floors.removeAt(oldIndex);
                      _floors.insert(newIndex, floor);
                      final expanded = _floorExpanded.removeAt(oldIndex);
                      _floorExpanded.insert(newIndex, expanded);

                      _showReorderIndicators = true;
                    });
                    _syncStore();
                  },
                  children: [
                    for (int index = 0; index < _floors.length; index++)
                      Container(
                        key: ObjectKey(_floors[index]),
                        child: _buildFloorTile(context, _floors[index], index),
                      ),
                  ],
                ),
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
                      isPrimary: true,
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
    _syncStore();

    final store = HousesStore.instance;
    PanoramaData panoramaDataToUse;
    if (widget.houseIndex != null) {
      panoramaDataToUse = store.houses[widget.houseIndex!];
    } else if (_draftHouse != null) {
      panoramaDataToUse = _draftHouse!;
    } else {
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
    _syncStore();
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
        backgroundColor: AppStyles.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyles.cardRadius),
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
    final bool canDeleteRoom = floor.rooms.length > 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        onTap: () => _openRoomEditor(fIdx, rIdx),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppStyles.surface,
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            border: Border.all(
              color: AppStyles.border,
              width: AppStyles.borderWidth,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: ReorderableDragStartListener(
                  index: rIdx,
                  child: SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoomReorderIndicator(floor, room, rIdx),
                        const SizedBox(height: 4),
                        Icon(
                          Icons.drag_handle,
                          color: AppStyles.accentInactive,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _PanoPreviewBox(
                imagePath: room.imagePath,
                iconName: room.iconName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name.isEmpty ? 'Pano $rIdx' : room.name,
                            style: TextStyle(
                              color: AppStyles.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.isBatchUpload)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppStyles.surfaceAccent,
                              borderRadius: BorderRadius.circular(
                                AppStyles.pillRadius,
                              ),
                              border: Border.all(
                                color: AppStyles.border,
                                width: AppStyles.borderWidth,
                              ),
                            ),
                            child: Text(
                              'Batch',
                              style: TextStyle(
                                color: AppStyles.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$connCount connection${connCount == 1 ? '' : 's'}',
                      style: TextStyle(color: AppStyles.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppStyles.surfaceAccent,
                  borderRadius: BorderRadius.circular(AppStyles.pillRadius),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: canDeleteRoom
                        ? AppStyles.textSecondary
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderIndicator(FloorEditor floor, int currentIndex) {
    final int? orig = _originalFloorOrder[floor];
    if (!_showReorderIndicators || orig == null) {
      return const Icon(Icons.minimize, size: 18, color: Colors.black54);
    }

    final int delta = orig - currentIndex;
    if (delta == 0) {
      return const Icon(Icons.minimize, size: 18, color: Colors.black54);
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
        Text(
          '${delta.abs()}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomReorderIndicator(
      FloorEditor floor, EditableRoom room, int currentIndex) {
    final origMap = _originalRoomOrder[floor];
    if (!_showReorderIndicators || origMap == null) {
      return const Icon(Icons.minimize, size: 16, color: Colors.black54);
    }
    final int? orig = origMap[room];
    if (orig == null) {
      return const Icon(Icons.minimize, size: 16, color: Colors.black54);
    }
    final int delta = orig - currentIndex;
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
            fontWeight: FontWeight.w700,
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

    final card = Container(
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
            child: SizedBox(
              width: 40,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 0.0, 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildReorderIndicator(floor, fIdx),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.drag_handle,
                      color: AppStyles.accentInactive,
                    ),
                  ],
                ),
              ),
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
                key: ObjectKey(floor),
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
                  ],
                ),
                subtitle: Text(
                  '${floor.rooms.length} panoramas • ${floor.hotspots.length} connections',
                  style: TextStyle(color: AppStyles.textSecondary),
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: AppStyles.surfaceAccent,
                    borderRadius: BorderRadius.circular(AppStyles.pillRadius),
                  ),
                  child: Row(
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
                              ? AppStyles.textSecondary
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
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(1.0, 8.0, 24.0, 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _WhiteButton.icon(
                              icon: Icons.upload_file,
                              label: 'Batch upload panoramas',
                              onPressed: () async {
                                final result =
                                await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: true,
                                );
                                final files =
                                    result?.files ?? const <PlatformFile>[];
                                if (files.isEmpty) return;

                                files.sort((a, b) {
                                  final an = (a.name).toLowerCase();
                                  final bn = (b.name).toLowerCase();
                                  return an.compareTo(bn);
                                });

                                setState(() {
                                  if (floor.rooms.length == 1 &&
                                      _isDefaultRoom(floor.rooms.first)) {
                                    floor.rooms.removeAt(0);
                                    floor.hotspots.clear();
                                  }
                                });

                                final startIndex = floor.rooms.length;

                                for (var f in files) {
                                  final path = f.path;
                                  if (path == null || path.isEmpty) continue;

                                  final room = EditableRoom();
                                  room.isBatchUpload = true;
                                  room.imagePath = path;
                                  room.imageCtrl.text = path;

                                  String predictedName = 'backyard';
                                  try {
                                    predictedName = await _aiClassifier.classifyImage(path);
                                  } catch (e) {
                                    debugPrint("AI Tahmin hatası: $e");
                                  }

                                  room.name = predictedName;
                                  room.nameCtrl.text = predictedName;

                                  setState(() {
                                    floor.rooms.add(room);
                                  });
                                }

                                setState(() {
                                  final lastNew = floor.rooms.length - 1;
                                  final firstNew = startIndex;

                                  if (firstNew > 0) {
                                    final prev = firstNew - 1;
                                    _ensureBidirectionalConnection(
                                      floor,
                                      prev,
                                      firstNew,
                                    );
                                  }

                                  for (var r = firstNew; r < lastNew; r++) {
                                    _ensureBidirectionalConnection(
                                      floor,
                                      r,
                                      r + 1,
                                      pairId: _kBatchConnectionPairId,
                                    );
                                  }

                                  if (fIdx >= 0 &&
                                      fIdx < _floorExpanded.length) {
                                    _floorExpanded[fIdx] = true;
                                  }
                                });
                                _syncStore();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Panoramas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppStyles.textPrimary,
                          ),
                        ),
                        floor.rooms.isEmpty
                            ? Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No rooms yet. Add one with the button above.',
                            style: TextStyle(
                              color: AppStyles.textSecondary,
                            ),
                          ),
                        )
                            : ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) =>
                          child,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;

                              _captureOriginalRoomOrder(floor);
                              _showReorderIndicators = true;

                              final moved =
                              floor.rooms.removeAt(oldIndex);
                              floor.rooms.insert(newIndex, moved);

                              _remapRoomIndicesForFloor(
                                  floor, oldIndex, newIndex);
                              _remapConnectedRoomIdsForFloor(
                                  floor, oldIndex, newIndex);

                              _rebuildBatchConnections(floor);
                            });
                            _syncStore();
                          },
                          children: [
                            for (int rIdx = 0;
                            rIdx < floor.rooms.length;
                            rIdx++)
                              Container(
                                key: ObjectKey(floor.rooms[rIdx]),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 6),
                                child: _buildRoomCard(
                                    fIdx, rIdx, floor.rooms[rIdx]),
                              ),
                          ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: card,
    );
  }

  bool _hasHotspot(FloorEditor floor, int from, int to) {
    return floor.hotspots.any(
          (h) => !h.changeFloor && h.fromRoomId == from && h.toRoomId == to,
    );
  }

  bool _isDefaultRoom(EditableRoom room) {
    return room.imagePath.isEmpty &&
        (room.name.isEmpty || room.name.startsWith('Pano ')) &&
        room.iconName == 'circle_outlined' &&
        room.description.isEmpty &&
        room.presetId == -1 &&
        room.connectedRoomIds.isEmpty;
  }

  void _ensureConnection(
      FloorEditor floor,
      int from,
      int to, {
        double latitude = 0.0,
        double longitude = 25.0,
        String text = '',
        String iconName = 'arrow_forward',
        String? pairId,
      }) {
    if (_hasHotspot(floor, from, to)) return;
    floor.hotspots.add(
      EditableHotspot(
        fromRoomId: from,
        toRoomId: to,
        latitude: latitude,
        longitude: longitude,
        text: text,
        iconName: iconName,
        pairId: pairId,
      ),
    );
  }

  void _ensureBidirectionalConnection(
      FloorEditor floor,
      int a,
      int b, {
        String? pairId,
      }) {
    _ensureConnection(
      floor,
      a,
      b,
      longitude: 25.0,
      iconName: 'arrow_forward',
      pairId: pairId,
    );
    _ensureConnection(
      floor,
      b,
      a,
      longitude: -25.0,
      iconName: 'arrow_back',
      pairId: pairId,
    );

    if (!floor.rooms[a].connectedRoomIds.contains(b)) {
      floor.rooms[a].connectedRoomIds.add(b);
    }
    if (!floor.rooms[b].connectedRoomIds.contains(a)) {
      floor.rooms[b].connectedRoomIds.add(a);
    }
  }

  void _rebuildBatchConnections(FloorEditor floor) {
    floor.hotspots.removeWhere(
          (h) => h.pairId == _kBatchConnectionPairId,
    );

    final batchIndices = <int>[];
    for (var i = 0; i < floor.rooms.length; i++) {
      if (floor.rooms[i].isBatchUpload) {
        batchIndices.add(i);
      }
    }

    if (batchIndices.length > 1) {
      for (var i = 0; i < batchIndices.length - 1; i++) {
        _ensureBidirectionalConnection(
          floor,
          batchIndices[i],
          batchIndices[i + 1],
          pairId: _kBatchConnectionPairId,
        );
      }
    }

    _rebuildConnectedRoomIdsFromHotspots(floor);
  }

  void _rebuildConnectedRoomIdsFromHotspots(FloorEditor floor) {
    for (final room in floor.rooms) {
      room.connectedRoomIds = [];
    }

    for (var rIdx = 0; rIdx < floor.rooms.length; rIdx++) {
      final conns = floor.hotspots
          .where((h) => h.fromRoomId == rIdx && !(h.changeFloor == true))
          .map((h) => h.toRoomId)
          .where((to) => to >= 0 && to < floor.rooms.length)
          .toSet()
          .toList()
        ..sort();
      floor.rooms[rIdx].connectedRoomIds = conns;
    }
  }

  void _remapRoomIndicesForFloor(
      FloorEditor floor, int oldIndex, int newIndex) {
    for (final h in floor.hotspots) {
      if (h.fromRoomId == oldIndex) {
        h.fromRoomId = newIndex;
      } else if (oldIndex < newIndex) {
        if (h.fromRoomId > oldIndex && h.fromRoomId <= newIndex) {
          h.fromRoomId -= 1;
        }
      } else if (oldIndex > newIndex) {
        if (h.fromRoomId >= newIndex && h.fromRoomId < oldIndex) {
          h.fromRoomId += 1;
        }
      }

      if (h.toRoomId == oldIndex) {
        h.toRoomId = newIndex;
      } else if (oldIndex < newIndex) {
        if (h.toRoomId > oldIndex && h.toRoomId <= newIndex) {
          h.toRoomId -= 1;
        }
      } else if (oldIndex > newIndex) {
        if (h.toRoomId >= newIndex && h.toRoomId < oldIndex) {
          h.toRoomId += 1;
        }
      }
    }
  }

  void _remapConnectedRoomIdsForFloor(
      FloorEditor floor, int oldIndex, int newIndex) {
    for (final r in floor.rooms) {
      r.connectedRoomIds = r.connectedRoomIds.map((id) {
        if (id == oldIndex) return newIndex;
        if (oldIndex < newIndex) {
          if (id > oldIndex && id <= newIndex) return id - 1;
        } else if (oldIndex > newIndex) {
          if (id >= newIndex && id < oldIndex) return id + 1;
        }
        return id;
      }).toList();
    }
  }
}

class _PanoPreviewBox extends StatelessWidget {
  final String imagePath;
  final String iconName;
  const _PanoPreviewBox({
    required this.imagePath,
    required this.iconName,
  });

  bool get _hasImage => imagePath.isNotEmpty && File(imagePath).existsSync();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hasImage
          ? () => showDialog(
        context: context,
        builder: (_) => _ImagePreviewDialog(imagePath: imagePath),
      )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            children: [
              Positioned.fill(
                child: _hasImage
                    ? Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: AppStyles.accentInactive.withOpacity(0.2),
                  child: Icon(
                    Icons.panorama,
                    color: AppStyles.textSecondary,
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    kIconCatalog[iconName] ?? Icons.circle_outlined,
                    color: AppStyles.textPrimary,
                    size: 14,
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

class _ImagePreviewDialog extends StatelessWidget {
  final String imagePath;
  const _ImagePreviewDialog({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppStyles.cardRadius),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.9),
                  borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  border: Border.all(
                    color: AppStyles.border,
                    width: AppStyles.borderWidth,
                  ),
                ),
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: AppStyles.textPrimary,
                ),
              ),
            ),
          ),
        ],
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
          if (p != null) {
            onPick(p);
          }
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
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                    border: Border.all(
                      color: AppStyles.border,
                      width: AppStyles.borderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
    copy.description = description;
    copy.isBatchUpload = isBatchUpload;
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