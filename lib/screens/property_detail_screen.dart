import 'package:flutter/material.dart';
import '../models/property.dart';
import 'map_screen.dart'; // Konum haritası için

class PropertyDetailScreen extends StatelessWidget {
  final Property property;

  const PropertyDetailScreen({Key? key, required this.property}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(property.title)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Evin Büyük Resmi
            Image.asset(property.imageUrl, height: 300, width: double.infinity, fit: BoxFit.cover),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('\$${property.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, color: Colors.teal)),
                  const SizedBox(height: 20),

                  // Tıklanabilir Konum Bilgisi
                  ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.red),
                    title: const Text("Location"),
                    subtitle: Text(property.address),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapScreen(address: property.address)),
                      );
                    },
                  ),

                  const Divider(),

                  // Özellikler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _featureIcon(Icons.bed, "${property.bedrooms} Beds"),
                      _featureIcon(Icons.bathtub, "${property.bathrooms} Baths"),
                      _featureIcon(Icons.directions_car, "${property.parking} Parking"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureIcon(IconData icon, String text) {
    return Column(children: [Icon(icon), Text(text)]);
  }
}