import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'panorama_data.dart';

class HousesStore extends ChangeNotifier {
  static final HousesStore instance = HousesStore._();
  HousesStore._();

  final List<PanoramaData> houses = [];
  int selectedIndex = 0;

  void addHouse(PanoramaData house) {
    houses.add(house);
    selectedIndex = houses.length - 1;
    notifyListeners();
  }

  void deleteHouse(int index) {
    if (index >= 0 && index < houses.length) {
      houses.removeAt(index);
      if (selectedIndex >= houses.length) selectedIndex = houses.length - 1;
      notifyListeners();
    }
  }

  void selectHouse(int index) {
    if (index >= 0 && index < houses.length) {
      selectedIndex = index;
      notifyListeners();
    }
  }

  PanoramaData? get selectedHouse =>
      houses.isNotEmpty ? houses[selectedIndex] : null;

  Future<void> saveHouseToFile(PanoramaData house, String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/house_$id.json');
    await file.writeAsString(jsonEncode(house.toJson()));
  }

  Future<PanoramaData?> loadHouseFromFile(String id) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/house_$id.json');
    if (!file.existsSync()) return null;
    final jsonStr = await file.readAsString();
    return PanoramaData.fromJson(jsonDecode(jsonStr));
  }
}