import 'package:flutter/material.dart';
import 'package:p2/screens/features/panorama/house-panorama-core.dart';
import '../constants/colors.dart';
import '../widgets/property_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/category_chip.dart';
import '../models/property.dart';
import 'login_screen.dart';

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
      propertyType: 'Villa',
    ),
    Property(
      id: '2',
      title: 'Family House with Garden',
      address: '45 Smith St, Sydney NSW 2000',
      price: 12000,
      bedrooms: 4,
      bathrooms: 2,
      parking: 2,
      imageUrl: 'assets/images/v3.jpg',
      propertyType: 'House',
    ),
    Property(
      id: '3',
      title: 'Waterfront Luxury Villa',
      address: '78 Beach Rd, Gold Coast QLD 4217',
      price: 25000,
      bedrooms: 5,
      bathrooms: 3,
      parking: 3,
      imageUrl: 'assets/images/v2.jpg',
      propertyType: 'Villa',
    ),
    Property(
      id: '4',
      title: 'Modern Apartment in CBD',
      address: '123 Collins St, Melbourne VIC 3000',
      price: 65000,
      bedrooms: 2,
      bathrooms: 2,
      parking: 1,
      imageUrl: 'assets/images/v6.jpg',
      propertyType: 'Apartment',
    ),
  ];

  final List<String> categories = [
    'All',
    'House',
    'Apartment',
    'Unit',
    'Townhouse',
    'Land',
    'Rural',
  ];

  String selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo3d.png',
              height: 35,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.home, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              '3D App',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Temizlenen Kısım: Bildirim ve Favori butonları kaldırıldı.

          // 3D Tasarım Butonu
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HousePanoramaCoreScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_home_work, color: AppColors.accentYellow),
            label: const Text(
              'Design a 3D House',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),

          // Çıkış Yap Butonu
          IconButton(
            icon: const Icon(Icons.logout),
            color: AppColors.accentYellow,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(),
            ),

            // Categories
            Container(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return CategoryChip(
                    label: categories[index],
                    isSelected: selectedCategory == categories[index],
                    onTap: () {
                      setState(() {
                        selectedCategory = categories[index];
                      });
                    },
                  );
                },
              ),
            ),

            // Featured Properties
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Featured Properties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Featured Properties Card
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/v1.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color.fromRGBO(0, 0, 0, 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentYellow,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Luxury Waterfront Villa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Starting from \$140,000',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Regular Properties List Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Properties',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Property List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                return PropertyCard(property: properties[index]);
              },
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: Colors.grey[600],
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Sell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.primaryDark,
        child: const Icon(Icons.filter_list, color: Colors.white),
      ),
    );
  }
}