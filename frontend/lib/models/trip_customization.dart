class PreferenceCardItem {
  final String id;
  final String title;
  final String tag;
  final String category; // Food, Cafés, Shopping, Nature, Culture, History, Nightlife, Adventure, Photography, Local experiences, Famous attractions, Hidden gems
  final String imageUrl;
  final String city; // the destination city this card belongs to

  PreferenceCardItem({
    required this.id,
    required this.title,
    required this.tag,
    required this.category,
    required this.imageUrl,
    this.city = '',
  });

  factory PreferenceCardItem.fromJson(Map<String, dynamic> json) {
    return PreferenceCardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      tag: json['tag'] ?? '',
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? '',
      city: json['city'] ?? '',
    );
  }
}