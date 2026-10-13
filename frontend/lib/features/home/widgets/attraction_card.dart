import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/attraction.dart';

class AttractionCard extends StatelessWidget {
  final String title;
  final String location;
  final String imageUrl;
  final String price;
  final List<String> tags;
  final double? rating;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback? onTap;
  final String fallbackImageUrl;
  final IconData placeholderIcon;

  const AttractionCard({
    super.key,
    required this.title,
    required this.location,
    required this.imageUrl,
    this.price = 'Free',
    this.tags = const [],
    this.rating = 4.8,
    this.isFavorite = false,
    this.onFavorite = _noop,
    this.onTap,
    this.fallbackImageUrl = '',
    this.placeholderIcon = Icons.place_outlined,
  });

  static void _noop() {}

  factory AttractionCard.fromModel(
    Attraction attraction, {
    bool? isFavorite,
    VoidCallback? onFavorite,
    VoidCallback? onTap,
  }) {
    return AttractionCard(
      title: attraction.title,
      location: attraction.location,
      imageUrl: attraction.imageUrl,
      price: attraction.price,
      tags: attraction.tags,
      rating: attraction.rating,
      isFavorite: isFavorite ?? attraction.isFavourite,
      onFavorite: onFavorite ?? _noop,
      onTap: onTap,
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(location),
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.attach_money, label: price),
              if (rating != null)
                _DetailRow(icon: Icons.star, label: rating!.toStringAsFixed(1)),
              if (tags.isNotEmpty)
                _DetailRow(icon: Icons.label_outline, label: tags.join(', ')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(placeholderIcon, size: 40, color: Colors.grey.shade500),
        ),
      );

  Widget _fallback() {
    final fb = fallbackImageUrl.trim();
    if (fb.isEmpty) return _placeholder();
    return Image.network(
      fb,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _buildImage() {
    final primary = imageUrl.trim();
    if (primary.isEmpty) return _fallback();
    return Image.network(
      primary,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showDetails(context),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 3),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: _buildImage(),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (rating != null) ...[
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(rating!.toStringAsFixed(1)),
                          ],
                          const Spacer(),
                          Text(
                            price,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: onFavorite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
