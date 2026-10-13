import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

/// Bottom sheet with a short explanation of a hotel, attraction or restaurant.
/// [kind] is 'attraction', 'hotel' or 'food'.
Future<void> showPlaceDetailSheet(
  BuildContext context, {
  required String name,
  required String city,
  required String kind,
  String imageUrl = '',
  String subtitle = '',
  List<String> facts = const [],
  String knownText = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PlaceDetailSheet(
      name: name,
      city: city.split(',').first.trim(),
      kind: kind,
      imageUrl: imageUrl,
      subtitle: subtitle,
      facts: facts,
      knownText: knownText,
    ),
  );
}

class _PlaceDetailSheet extends StatefulWidget {
  const _PlaceDetailSheet({
    required this.name,
    required this.city,
    required this.kind,
    required this.imageUrl,
    required this.subtitle,
    required this.facts,
    required this.knownText,
  });

  final String name;
  final String city;
  final String kind;
  final String imageUrl;
  final String subtitle;
  final List<String> facts;
  final String knownText;

  @override
  State<_PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<_PlaceDetailSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final r = await ApiClient().get('/api/options/describe', query: {
      'name': widget.name,
      'city': widget.city,
      'kind': widget.kind,
      if (widget.knownText.isNotEmpty) 'extra': widget.knownText,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> _reportClosed() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Permanently closed?'),
        content: Text('Hide "${widget.name}" from suggestions for everyone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, hide it')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ApiClient().post('/api/options/closed', {'name': widget.name, 'city': widget.city});
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Thanks! It will no longer be suggested.')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openMaps() async {
    final q = Uri.encodeComponent('${widget.name} ${widget.city}');
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.imageUrl,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              widget.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
            if (widget.facts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.facts
                    .where((f) => f.trim().isNotEmpty)
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  );
                }
                if (snap.hasError || snap.data == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.knownText.isNotEmpty) Text(widget.knownText),
                      const SizedBox(height: 8),
                      Text(
                        "Couldn't load the AI summary right now.",
                        style: TextStyle(color: Colors.grey[600]),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (d['summary'] ?? '').toString(),
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                    if (highlights.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Highlights',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final h in highlights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  h,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (bestFor.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Best for: $bestFor', style: const TextStyle(fontSize: 13)),
                    ],
                    if (tip.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Tip: $tip', style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Summary written by AI. Check opening hours and prices before you go.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.reviews_outlined, size: 18),
                label: const Text('Reviews and photos on Google Maps'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _reportClosed,
                icon: const Icon(Icons.report_gmailerrorred_outlined, size: 16),
                label: const Text('Report as permanently closed'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }
}
