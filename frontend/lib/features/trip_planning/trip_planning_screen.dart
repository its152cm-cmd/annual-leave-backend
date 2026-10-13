import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account_settings.dart';
import '../../models/trip_customization.dart';
import '../../services/account_service.dart';

class TripCustomizationSwipeOverlay extends StatefulWidget {
  final List<PreferenceCardItem> cards;
  final String city;
  /// decision: 'like', 'dislike' or 'skip'
  final void Function(PreferenceCardItem card, String decision)? onDecision;

  const TripCustomizationSwipeOverlay({
    super.key,
    required this.cards,
    this.city = '',
    this.onDecision,
  });

  @override
  State<TripCustomizationSwipeOverlay> createState() =>
      _TripCustomizationSwipeOverlayState();
}

class _TripCustomizationSwipeOverlayState
    extends State<TripCustomizationSwipeOverlay> {
  int _currentIndex = 0;

  void _decide(String decision) {
    if (_currentIndex < widget.cards.length) {
      widget.onDecision?.call(widget.cards[_currentIndex], decision);
    }
    setState(() {
      _currentIndex++;
    });
  }

  void _onSwipe(DismissDirection direction) =>
      _decide(direction == DismissDirection.startToEnd ? 'like' : 'dislike');

  Widget _roundButton(IconData icon, Color color, String label, String decision) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _decide(decision),
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height * 0.82;

    return Container(
      height: availableHeight,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header with Title & Close Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Let's explore some places!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.primaryGreen),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Progress indicator text
          if (_currentIndex < widget.cards.length)
            Text(
              'Question ${_currentIndex + 1} of ${widget.cards.length}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),

          const SizedBox(height: 12),

          // Swipe Card Stack Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _currentIndex < widget.cards.length
                  ? Column(
                      children: [
                        Expanded(
                          child: Dismissible(
                            key: ValueKey('${widget.cards[_currentIndex].id}-$_currentIndex'),
                            direction: DismissDirection.horizontal,
                            onDismissed: _onSwipe,
                            child: _SwipeCardWidget(
                              card: widget.cards[_currentIndex],
                              city: widget.cards[_currentIndex].city.isNotEmpty ? widget.cards[_currentIndex].city : widget.city,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _roundButton(Icons.close_rounded, Colors.redAccent, 'Dislike', 'dislike'),
                            _roundButton(Icons.arrow_upward_rounded, Colors.amber.shade700, 'Skip', 'skip'),
                            _roundButton(Icons.favorite_rounded, AppTheme.primaryGreen, 'Like', 'like'),
                          ],
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'All preferences customized!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeCardWidget extends StatelessWidget {
  final PreferenceCardItem card;

  const _SwipeCardWidget({required this.card, this.city = ''});
  final String city;

  Future<void> _openGoogle() async {
    final q = Uri.encodeComponent('${card.title} $city');
    await launchUrl(
      Uri.parse('https://www.google.com/search?q=$q&tbm=isch'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6FA987), Color(0xFF2F6B4F)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconFor(card.category), size: 80, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openGoogle,
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
            label: const Text('See photos on Google', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70)),
          ),
        ],
      ),
    ),
  );

  IconData _iconFor(String c) {
    switch (c) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Cafes':
        return Icons.local_cafe_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Nightlife':
        return Icons.nightlife_rounded;
      case 'Nature':
        return Icons.park_rounded;
      case 'Culture':
        return Icons.museum_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Image with Error Handling
            Positioned.fill(
              child: card.imageUrl.isEmpty
                  ? _placeholder()
                  : Image.network(
                      card.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _placeholder(),
                    ),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              ),
            ),

            // Card Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${card.category} · ${card.tag}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DefaultPreferencesOverlay extends StatefulWidget {
  const DefaultPreferencesOverlay({super.key});

  @override
  State<DefaultPreferencesOverlay> createState() =>
      _DefaultPreferencesOverlayState();
}

class _DefaultPreferencesOverlayState
    extends State<DefaultPreferencesOverlay> {
  final AccountService _accountService = AccountService();
  ComfortTravelSettings _settings = const ComfortTravelSettings();
  TravelDefaults _travel = const TravelDefaults();
  bool _loading = true;

  static const _dietOptions = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free', 'No Seafood'];
  static const _paceOptions = ['Relaxed', 'Moderate', 'Fast-paced'];
  static const _interestOptions = ['Culture & History', 'Nature', 'Shopping', 'Foodie', 'Nightlife'];

  List<String> _toggle(List<String> list, String v) =>
      list.contains(v) ? (List<String>.from(list)..remove(v)) : [...list, v];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final settings = await _accountService.getComfortSettings();
    final travel = await _accountService.getTravelDefaults();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _travel = travel;
      _loading = false;
    });
  }

  void _updateSettings(ComfortTravelSettings settings) {
    setState(() => _settings = settings);
  }

  Future<void> _savePreferences() async {
    await _accountService.setComfortSettings(_settings);
    await _accountService.setTravelDefaults(_travel);
    if (mounted) Navigator.of(context).pop(_settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: mediaQuery.viewInsets.bottom + 20,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Default Travel Preferences',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Scrollable Preferences
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      ComfortPreferenceCard(
                        title: 'Food & Dietary',
                        subtitle: 'Used when planning meals',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final o in _dietOptions)
                              FilterChip(
                                label: Text(o),
                                selected: _travel.dietary.contains(o),
                                onSelected: (_) => setState(() => _travel =
                                    _travel.copyWith(dietary: _toggle(_travel.dietary, o))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Trip Pace',
                        subtitle: 'How packed your days should be',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final o in _paceOptions)
                              ChoiceChip(
                                label: Text(o),
                                selected: _travel.pace == o,
                                onSelected: (_) => setState(() =>
                                    _travel = _travel.copyWith(pace: _travel.pace == o ? '' : o)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Hotel Preference',
                        subtitle: 'Star rating you like to stay in',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final n in const [0, 3, 4, 5])
                              ChoiceChip(
                                label: Text(n == 0 ? 'Any' : '$n★'),
                                selected: _travel.hotelStars == n,
                                onSelected: (_) =>
                                    setState(() => _travel = _travel.copyWith(hotelStars: n)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Interests',
                        subtitle: 'What you enjoy most',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final o in _interestOptions)
                              FilterChip(
                                label: Text(o),
                                selected: _travel.interests.contains(o),
                                onSelected: (_) => setState(() => _travel =
                                    _travel.copyWith(interests: _toggle(_travel.interests, o))),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Max Walking',
                        subtitle: 'Between any two stops',
                        trailing: Text(
                          '${_settings.maxWalkingMinutes} min',
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Column(
                          children: [
                            Slider(
                              value: _settings.maxWalkingMinutes.toDouble(),
                              min: 5,
                              max: 30,
                              divisions: 5,
                              onChanged: (value) => _updateSettings(
                                _settings.copyWith(maxWalkingMinutes: value.round()),
                              ),
                            ),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [Text('5 min'), Text('30 min')],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Max Activities',
                        subtitle: 'Recommended limit per day',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _settings.maxActivitiesPerDay <= 1
                                  ? null
                                  : () => _updateSettings(
                                      _settings.copyWith(
                                        maxActivitiesPerDay: _settings.maxActivitiesPerDay - 1,
                                      ),
                                    ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${_settings.maxActivitiesPerDay}'),
                            IconButton(
                              onPressed: () => _updateSettings(
                                _settings.copyWith(
                                  maxActivitiesPerDay: _settings.maxActivitiesPerDay + 1,
                                ),
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        child: const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        title: 'Rest Break Frequency',
                        subtitle: 'Auto-schedule a break after travel',
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final option in const [1, 2, 3])
                              ChoiceChip(
                                label: Text(option == 1 ? 'Every hour' : 'Every $option hrs'),
                                selected: _settings.restBreakFrequency == option,
                                onSelected: (_) => _updateSettings(
                                  _settings.copyWith(restBreakFrequency: option),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ComfortPreferenceCard(
                        child: Column(
                          children: [
                            _ComfortPreferenceSwitch(
                              title: 'Accessible Transport Only',
                              subtitle: 'Bus/Train routes with step-free boarding',
                              value: _settings.accessibleTransportOnly,
                              onChanged: (value) => _updateSettings(
                                _settings.copyWith(accessibleTransportOnly: value),
                              ),
                            ),
                            _ComfortPreferenceSwitch(
                              title: 'Nearby Restrooms Priority',
                              subtitle: 'Highlight spots with accessible public toilets',
                              value: _settings.nearbyRestroomsPriority,
                              onChanged: (value) => _updateSettings(
                                _settings.copyWith(nearbyRestroomsPriority: value),
                              ),
                            ),
                            _ComfortPreferenceSwitch(
                              title: 'Minimize Stairs',
                              subtitle: 'Choose routes with fewer stairs',
                              value: _settings.minimizeStairs,
                              onChanged: (value) => _updateSettings(
                                _settings.copyWith(minimizeStairs: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // Save Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Save Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ComfortPreferenceCard extends StatelessWidget {
  const ComfortPreferenceCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE8E1DB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (subtitle != null)
                      Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        if (title != null) const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _ComfortPreferenceSwitch extends StatelessWidget {
  const _ComfortPreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.primaryGreen),
      ],
    ),
  );
}
