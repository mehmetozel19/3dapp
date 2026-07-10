import 'dart:io';
import 'dart:convert' as convert;

import 'package:flutter/material.dart';
import 'house_creator.dart';
import 'panorama_view.dart';
import '../../../features/panorama/theme/ui_styles.dart';
import '../../../models/panorama_data.dart';
import '../../../models/houses_store.dart';

class HousePanoramaCoreScreen extends StatefulWidget {
  const HousePanoramaCoreScreen({super.key});

  @override
  State<HousePanoramaCoreScreen> createState() =>
      _HousePanoramaCoreScreenState();
}

class _HousePanoramaCoreScreenState extends State<HousePanoramaCoreScreen> {
  @override
  Widget build(BuildContext context) {
    final housesStore = HousesStore.instance;
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: housesStore,
            builder: (context, _) {
              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: Colors.grey.shade700),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        Text(
                          '3D Tour App',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'House CRUD & Panorama',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: housesStore.houses.length,
                      itemBuilder: (context, index) {
                        final house = housesStore.houses[index];
                        return SavedHouseCard(
                          house: house,
                          selected: index == housesStore.selectedIndex,
                          onSelect: () => housesStore.selectHouse(index),
                          onDelete: () => housesStore.deleteHouse(index),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New House'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HouseCreatorScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class SavedHouseCard extends StatelessWidget {
  final PanoramaData house;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const SavedHouseCard({
    super.key,
    required this.house,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final store = house;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final floors = store.floorRooms.keys.toList()..sort();
        final roomCount = floors.fold<int>(
            0, (sum, f) => sum + (store.floorRooms[f]?.length ?? 0));
        final hotspotCount = floors.fold<int>(
            0, (sum, f) => sum + (store.floorHotspots[f]?.length ?? 0));
        final floorCount = floors.length;
        final hasData = roomCount > 0;

        String thumbPath = store.houseThumbnail;

        final isAsset = thumbPath.startsWith('assets/');
        final thumbWidget = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppStyles.border, width: AppStyles.borderWidth),
              color: AppStyles.surfaceMuted,
            ),
            child: Image.file(
              File(thumbPath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderThumb(),
            ),
          ),
        );

        final rawJson = _rawJson(store);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppStyles.surface,
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
            border: Border.all(
                color: AppStyles.border, width: AppStyles.borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbWidget,
                const SizedBox(height: 10),
                Text(
                  store.houseName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    _specChip(Icons.layers, '$floorCount floors'),
                    _specChip(Icons.meeting_room, '$roomCount panoramas'),
                    _specChip(Icons.link, '$hotspotCount hotspots'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _pillButton(
                      context: context,
                      icon: Icons.play_circle_fill,
                      label: 'Open',
                      onTap: hasData
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PanoramaViewScreen(
                                    title: house.houseName,
                                    initialHouse: house,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                    _pillButton(
                      context: context,
                      icon: Icons.edit,
                      label: 'Edit',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HouseCreatorScreen(
                              initialHouse: house,
                              houseIndex:
                                  HousesStore.instance.houses.indexOf(house),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Raw data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppStyles.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppStyles.border, width: AppStyles.borderWidth),
                  ),
                  child: SizedBox(
                    height: 400,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            rawJson,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppStyles.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _rawJson(PanoramaData store) {
    final floors = store.floorRooms.keys.toList()..sort();
    final data = {
      'houseName': store.houseName,
      'houseAddress': store.houseAddress,
      'houseArea': store.houseArea,
      'houseThumbnail': store.houseThumbnail,
      'floors': floors.map((f) {
        final rooms = store.floorRooms[f] ?? const <RoomData>[];
        final hotspots = store.floorHotspots[f] ?? const <HotspotData>[];
        return {
          'floor': f,
          'rooms': rooms
              .map((r) => {
                    'id': r.id,
                    'presetId': r.presetId,
                    'imagePath': r.imagePath,
                    'name': r.name,
                    'icon': {
                      'codePoint': r.icon.codePoint,
                      'fontFamily': r.icon.fontFamily,
                    },
                    'connectedRoomIds': r.connectedRoomIds,
                  })
              .toList(),
          'hotspots': hotspots
              .map((h) => {
                    'from': h.fromRoomId,
                    'to': h.toRoomId,
                    'lat': h.latitude,
                    'lon': h.longitude,
                    'text': h.text,
                    'icon': {
                      'codePoint': h.icon.codePoint,
                      'fontFamily': h.icon.fontFamily,
                    },
                  })
              .toList(),
        };
      }).toList(),
    };
    return const convert.JsonEncoder.withIndent('  ').convert(data);
  }

  static Widget _placeholderThumb() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.photo, color: Colors.white38, size: 28),
      ),
    );
  }

  static Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppStyles.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppStyles.border, width: AppStyles.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppStyles.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(fontSize: 12, color: AppStyles.textSecondary)),
        ],
      ),
    );
  }

  static Widget _pillButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? AppStyles.controlBg : AppStyles.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppStyles.border, width: AppStyles.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: enabled ? Colors.grey.shade800 : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.grey.shade800 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
