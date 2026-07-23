import 'package:flutter/material.dart';
import 'package:p2/screens/features/panorama/house-panorama-core.dart';
import '../constants/colors.dart';
import '../widgets/property_card.dart';
import '../widgets/search_bar.dart';
import '../models/property.dart';
import 'login_screen.dart';
import 'property_detail_screen.dart'; // PropertyDetailScreen import edildi

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Property> properties = [
    Property(
        id: '1',
        title: 'Modern Apartment in CBD',
        address: '123 Collins St, Melbourne VIC 3000',
        price: 65000,
        bedrooms: 2,
        bathrooms: 2,
        parking: 1,
        imageUrl: 'assets/images/v4.jpg',
        propertyType: 'Villa'),
    Property(
        id: '2',
        title: 'Family House with Garden',
        address: '45 Smith St, Sydney NSW 2000',
        price: 12000,
        bedrooms: 4,
        bathrooms: 2,
        parking: 2,
        imageUrl: 'assets/images/v3.jpg',
        propertyType: 'House'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Row(
          children: [
            const Text(
              '3D Ausqa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HousePanoramaCoreScreen()),
                );
              },
              icon: const Icon(Icons.view_in_ar, color: Colors.white, size: 20),
              label: const Text(
                '3D Design',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => LoginScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                // Kartın tamamına veya içindeki "View Detail" butonuna tıklandığında geçiş yapması için:
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyDetailScreen(property: property),
                      ),
                    );
                  },
                  child: PropertyCard(property: property),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}