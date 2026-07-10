import 'package:flutter/material.dart';
import 'presets.dart';

const double kControlHeight = 40.0;
const double kControlFontSize = 14.0;

String _slugify(String label) {
  final t = label.trim().toLowerCase();
  final buf = StringBuffer();
  for (final ch in t.runes) {
    final c = String.fromCharCode(ch);
    if (RegExp(r'[a-z0-9]').hasMatch(c)) {
      buf.write(c);
    } else {
      buf.write('_');
    }
  }

  final s = buf.toString().replaceAll(RegExp(r'_+'), '_');
  return s.replaceAll(RegExp(r'^_+|_+$'), '');
}

const Map<String, IconData> _kBaseIcons = {
  'circle_outlined': Icons.circle_outlined,
  'arrow_forward': Icons.arrow_forward,
  'arrow_back': Icons.arrow_back,
  'north': Icons.north,
  'south': Icons.south,
  'east': Icons.east,
  'west': Icons.west,
};

Map<String, IconData> _buildIconCatalog() {
  final map = <String, IconData>{};

  map.addAll(_kBaseIcons);

  for (final p in kRoomPresetCatalog) {
    final key = _slugify(p.label);

    map.putIfAbsent(key, () => p.icon);
  }

  map.putIfAbsent('kitchen', () => Icons.kitchen);
  map.putIfAbsent('bathroom', () => Icons.bathroom);
  map.putIfAbsent('bedroom', () => Icons.hotel);
  map.putIfAbsent('storage', () => Icons.storage);
  map.putIfAbsent('stairs', () => Icons.stairs);
  map.putIfAbsent('deck', () => Icons.deck);
  map.putIfAbsent('door_front_door', () => Icons.door_front_door);
  map.putIfAbsent('countertops', () => Icons.countertops);

  return Map.unmodifiable(map);
}

final Map<String, IconData> kIconCatalog = _buildIconCatalog();

class FloorEditor {
  List<EditableRoom> rooms = [];
  List<EditableHotspot> hotspots = [];
}

class EditableRoom {
  String name;
  String imagePath;
  String iconName;
  String description;
  int presetId;
  bool isBatchUpload;

  List<int> connectedRoomIds;

  final TextEditingController _nameCtrl;
  final TextEditingController _imageCtrl;
  final TextEditingController _descCtrl;

  EditableRoom({
    this.name = '',
    this.imagePath = '',
    this.iconName = 'circle_outlined',
    this.description = '',
    this.presetId = -1,
    this.isBatchUpload = false,
    List<int>? connectedRoomIds,
  })  : connectedRoomIds = connectedRoomIds ?? [],
        _nameCtrl = TextEditingController(text: name),
        _imageCtrl = TextEditingController(text: imagePath),
        _descCtrl = TextEditingController(text: description);

  TextEditingController get nameCtrl => _nameCtrl;
  TextEditingController get imageCtrl => _imageCtrl;
  TextEditingController get descCtrl => _descCtrl;
}

class EditableHotspot {
  int fromRoomId;
  int toRoomId;
  double latitude;
  double longitude;
  String text;
  String iconName;
  String pairId;
  bool isPaired;

  bool changeFloor;
  int? targetFloorId;

  late final TextEditingController latCtrl;
  late final TextEditingController lonCtrl;
  late final TextEditingController textCtrl;

  EditableHotspot({
    required this.fromRoomId,
    required this.toRoomId,
    required this.latitude,
    required this.longitude,
    required this.text,
    required this.iconName,
    String? pairId,
    this.isPaired = true,
    this.changeFloor = false,
    this.targetFloorId,
  }) : pairId = pairId ?? '' {
    latCtrl = TextEditingController(text: latitude.toStringAsFixed(1));
    lonCtrl = TextEditingController(text: longitude.toStringAsFixed(1));
    textCtrl = TextEditingController(text: text);
  }
}
