import 'package:flutter/material.dart';

class RoomPresetDef {
  final int id;
  final String label;
  final IconData icon;
  const RoomPresetDef(this.id, this.label, this.icon);
}

const List<RoomPresetDef> kRoomPresetCatalog = [
  RoomPresetDef(0, 'Living room', Icons.living),
  RoomPresetDef(1, 'Kitchen', Icons.kitchen),
  RoomPresetDef(2, 'Dining room', Icons.dining),
  RoomPresetDef(3, 'Bedroom', Icons.hotel),
  RoomPresetDef(4, 'Master bedroom', Icons.single_bed),
  RoomPresetDef(5, 'Guest room', Icons.hotel),
  RoomPresetDef(6, 'Bathroom', Icons.bathroom),
  RoomPresetDef(7, 'Toilet', Icons.wc),
  RoomPresetDef(8, 'Shower', Icons.shower),
  RoomPresetDef(9, 'Hallway', Icons.hiking),
  RoomPresetDef(10, 'Office / Study', Icons.work),
  RoomPresetDef(11, 'Garage', Icons.garage),
  RoomPresetDef(12, 'Laundry', Icons.garage),
  RoomPresetDef(13, 'Stairs', Icons.stairs),
  RoomPresetDef(14, 'Balcony', Icons.balcony),
  RoomPresetDef(15, 'Patio / Terrace', Icons.deck),
  RoomPresetDef(16, 'Entry / Foyer', Icons.door_front_door),
  RoomPresetDef(17, 'Closet', Icons.inventory_2),
  RoomPresetDef(18, 'Pantry', Icons.inventory_2),
  RoomPresetDef(19, 'Storage', Icons.storage),
  RoomPresetDef(20, 'Playroom', Icons.toys),
  RoomPresetDef(21, 'Gym', Icons.fitness_center),
  RoomPresetDef(22, 'Living – Seating', Icons.weekend),
  RoomPresetDef(23, 'Living – TV area', Icons.tv),
  RoomPresetDef(24, 'Kitchen – Island', Icons.countertops),
  RoomPresetDef(25, 'Kitchen – Pantry', Icons.countertops),
  RoomPresetDef(26, 'Bedroom – Closet', Icons.checkroom),
  RoomPresetDef(27, 'Bath – Vanity', Icons.checkroom),
  RoomPresetDef(28, 'Bath – Tub', Icons.bathtub),
  RoomPresetDef(29, 'Bath – Shower', Icons.shower),
];

const int kPresetNone = -1;

RoomPresetDef? getPresetById(int id) {
  if (id < 0) return null;
  return kRoomPresetCatalog.firstWhere(
    (p) => p.id == id,
    orElse: () => const RoomPresetDef(-1, '', Icons.circle_outlined),
  );
}

RoomPresetDef? getPresetByLabel(String label) {
  final t = label.trim().toLowerCase();
  try {
    return kRoomPresetCatalog.firstWhere(
      (p) => p.label.toLowerCase() == t,
    );
  } catch (_) {
    return null;
  }
}
