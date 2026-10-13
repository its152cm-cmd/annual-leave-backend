import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/data/countries.dart';
import '../../../core/theme/app_theme.dart';

/// Pick a country, then one of its cities (no typing a place name).
/// Returns "City, Country", or null if closed.
Future<String?> showCityPicker(BuildContext context, {String current = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CityPicker(current: current),
  );
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.current});
  final String current;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  static final Map<String, List<String>> _cache = {};

  String _query = '';
  String? _country;
  List<String> _cities = [];
  bool _loading = false;
  String? _error;

  Future<void> _openCountry(String country) async {
    setState(() {
      _country = country;
      _query = '';
      _error = null;
      _cities = _cache[country] ?? [];
      _loading = _cities.isEmpty;
    });
    if (_cities.isNotEmpty) return;
    try {
      final r = await ApiClient().get('/api/options/cities', query: {'country': country});
      final list = ((r as Map)['cities'] as List).map((e) => '$e').toList();
      _cache[country] = list;
      if (mounted && _country == country) {
        setState(() {
          _cities = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && _country == country) {
        setState(() {
          _loading = false;
          _error = e is ApiException ? e.message : 'We could not load the cities. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final country = _country;
    final source = country == null ? allCountries : _cities;
    final shown = source
        .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SizedBox(
      height: height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (country != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      _country = null;
                      _query = '';
                    }),
                  ),
                Expanded(
                  child: Text(
                    country == null ? 'Choose a country' : 'Cities in $country',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey(country),
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: country == null ? 'Search country' : 'Search city',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF5F7F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(country, shown)),
          ],
        ),
      ),
    );
  }

  Widget _body(String? country, List<String> shown) {
    if (country != null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (country != null && _error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openCountry(country),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (shown.isEmpty) {
      return Center(
        child: Text(
          country == null ? 'No country found.' : 'No city found.',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return ListView.builder(
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final name = shown[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(name),
          trailing: Icon(
            country == null ? Icons.chevron_right : Icons.place_outlined,
            size: 18,
            color: AppTheme.textMuted,
          ),
          onTap: () {
            if (country == null) {
              _openCountry(name);
            } else {
              Navigator.pop(context, '$name, $country');
            }
          },
        );
      },
    );
  }
}
