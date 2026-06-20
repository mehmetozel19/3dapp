class Property {
  final String id;
  final String title;
  final String address;
  final double price;
  final int bedrooms;
  final int bathrooms;
  final int parking;
  final String imageUrl;
  final String propertyType;

  Property({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.parking,
    required this.imageUrl,
    required this.propertyType,
  });
}