import 'package:flutter/material.dart';

const double kControlHeight = 40.0;
const double kControlFontSize = 14.0;

const Map<String, IconData> kIconCatalog = {
  'door_front_door': Icons.door_front_door,
  'apartment': Icons.apartment,
  'account_balance': Icons.account_balance,
  'east': Icons.east,
  'west': Icons.west,
  'north': Icons.north,
  'south': Icons.south,
  'work': Icons.work,
  'meeting_room': Icons.meeting_room,
  'storage': Icons.storage,
  'kitchen': Icons.kitchen,
  'dining': Icons.dining,
  'chair': Icons.chair,
  'library_books': Icons.library_books,
  'roofing': Icons.roofing,
  'stairs': Icons.stairs,
  'settings': Icons.settings,
  'deck': Icons.deck,
  'grass': Icons.grass,
  'person': Icons.person,
  'coffee': Icons.coffee,
  'print': Icons.print,
  'groups': Icons.groups,
  'hotel': Icons.hotel,
  'single_bed': Icons.single_bed,
  'bathroom': Icons.bathroom,
  'bathtub': Icons.bathtub,
  'arrow_forward': Icons.arrow_forward,
  'arrow_back': Icons.arrow_back,
  'circle_outlined': Icons.circle_outlined,
};

class FloorEditor {
  List<EditableRoom> rooms = [];
  List<EditableHotspot> hotspots = [];
}

class EditableRoom {
  String name;
  String imagePath;
  String iconName;
  String description;

  List<int> connectedRoomIds;

  final TextEditingController _nameCtrl;
  final TextEditingController _imageCtrl;
  final TextEditingController _descCtrl;

  EditableRoom({
    this.name = '',
    this.imagePath = '',
    this.iconName = 'circle_outlined',
    this.description = '',
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
