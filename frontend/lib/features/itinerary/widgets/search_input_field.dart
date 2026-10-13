import 'package:flutter/material.dart';

class SearchInputField extends StatelessWidget {
  final String hintText;
  final bool showFilterIcon;

  const SearchInputField({
    super.key,
    required this.hintText,
    this.showFilterIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: showFilterIcon ? const Icon(Icons.filter_list, color: Colors.grey) : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
