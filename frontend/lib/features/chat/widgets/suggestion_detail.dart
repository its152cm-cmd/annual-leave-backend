import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/favourites_service.dart';

class DetailField {
  final String label;
  final String value;

  const DetailField(this.label, this.value);
}

/// Shared detail layout for attraction, restaurant, stay, and flight models.
class SuggestionDetailPage extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String category;
  final List<DetailField> details;
  final String favouriteKey;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;

  /// 'attraction', 'hotel' or 'food' adds the AI summary and the Google Maps
  /// link. Leave empty (flights) to show only [details].
  final String kind;
  final String city;
  final String knownText;

  const SuggestionDetailPage({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.details,
    required this.favouriteKey,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.kind = '',
    this.city = '',
    this.knownText = '',
  });

  @override
  State<SuggestionDetailPage> createState() => _SuggestionDetailPageState();
}

class _SuggestionDetailPageState extends State<SuggestionDetailPage> {
  Future<Map<String, dynamic>>? _future;

  bool get _hasAi => widget.kind.isNotEmpty && widget.city.trim().isNotEmpty;
  String get _cityName => widget.city.split(',').first.trim();

  @override
  void initState() {
    super.initState();
    if (_hasAi) _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final r = await ApiClient().get('/api/options/describe', query: {
      'name': widget.title,
      'city': _cityName,
      'kind': widget.kind,
      if (widget.knownText.isNotEmpty) 'extra': widget.knownText,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> _openMaps() async {
    final q = Uri.encodeComponent('${widget.title} $_cityName');
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _aiSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Couldn't load the AI summary right now.",
                style: TextStyle(color: AppTheme.textMuted),
              ),
              TextButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('Try again'),
              ),
            ],
          );
        }
        final d = snap.data!;
        final highlights = (d['highlights'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        final bestFor = (d['best_for'] ?? '').toString();
        final tip = (d['tip'] ?? '').toString();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F9F4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppTheme.primaryGreen),
                  SizedBox(width: 6),
                  Text(
                    'AI summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                (d['summary'] ?? '').toString(),
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              for (final h in highlights)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(h, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              if (bestFor.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Best for: $bestFor', style: const TextStyle(fontSize: 14)),
              ],
              if (tip.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Tip: $tip', style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Text(
                'Written by AI. Check opening hours and prices before you go.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final imageUrl = widget.imageUrl;
    final category = widget.category;
    final favouriteKey = widget.favouriteKey;
    final onToggleFavourite = widget.onToggleFavourite;
    final visibleDetails = widget.details
        .where((detail) => detail.value.trim().isNotEmpty)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              imageUrl,
              height: 320,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 320,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.image,
                  size: 48,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable:
                            SuggestionFavoritesService.favoritesRevision,
                        builder: (context, _, _) {
                          final isFavourite =
                              SuggestionFavoritesService().isFavorite(
                                favouriteKey,
                              ) ??
                              widget.isFavourite;
                          return IconButton(
                            onPressed: onToggleFavourite,
                            tooltip: isFavourite
                                ? 'Remove favourite'
                                : 'Add favourite',
                            icon: Icon(
                              isFavourite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavourite
                                  ? Colors.red
                                  : AppTheme.textMuted,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_hasAi) ...[
                    _aiSummary(),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openMaps,
                        icon: const Icon(Icons.reviews_outlined, size: 18),
                        label: const Text(
                          'Rating, reviews and photos on Google Maps',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (final detail in visibleDetails) ...[
                    Text(
                      detail.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail.value,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
