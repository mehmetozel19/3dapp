import 'package:flutter/material.dart';
import '../constants/colors.dart'; // Renk sınıfının doğru import edildiğinden emin olun

class SearchBarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search properties...',
        // ESKİ: AppColors.primaryTurquoise -> YENİ: AppColors.primaryDark
        prefixIcon: Icon(Icons.search, color: AppColors.primaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryDark), // Odaklanınca koyu renk olsun
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}