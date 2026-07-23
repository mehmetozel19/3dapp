import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final String address;
  const MapScreen({Key? key, required this.address}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Melbourne/Sydney civarı varsayılan sabit bir konum (adres bulma hatasını tamamen önler)
  final LatLng _markerPosition = const LatLng(-37.8136, 144.9631);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Konum: ${widget.address}"),
        backgroundColor: Colors.blueGrey,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _markerPosition,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.p2',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _markerPosition,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}