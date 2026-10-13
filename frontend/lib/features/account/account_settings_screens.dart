import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/push/push_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account_profile.dart';
import '../../models/account_settings.dart';
import '../../services/account_service.dart';

const _avatarChoices = [
  'assets/avatars/blue-hamster.jpg',
  'assets/avatars/hiking-traveller.jpg',
  'assets/avatars/ski-traveller.jpg',
  'assets/avatars/paris-traveller.jpg',
  'assets/avatars/green-traveller.jpg',
];

class EditAccountProfileScreen extends StatefulWidget {
  const EditAccountProfileScreen({super.key, required this.profile});

  final AccountProfile profile;

  @override
  State<EditAccountProfileScreen> createState() =>
      _EditAccountProfileScreenState();
}

class _EditAccountProfileScreenState extends State<EditAccountProfileScreen> {
  final AccountService _service = AccountService();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.profile.name,
  );
  late String _avatarUrl = widget.profile.avatarUrl;
  Uint8List? _avatarBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _avatarBytes = widget.profile.avatarBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseOwnPhoto() async {
    final picker = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (picker == null || !mounted) return;
    try {
      final image = await ImagePicker().pickImage(
        source: picker == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _avatarBytes = bytes);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to choose photo: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = widget.profile.copyWith(
        name: name,
        avatarUrl: _avatarUrl,
        avatarBytes: _avatarBytes,
        clearAvatarBytes: _avatarBytes == null,
      );
      final saved = await _service.updateProfile(profile);
      if (mounted) Navigator.pop(context, saved);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: _AvatarPreview(
              imageUrl: _avatarUrl,
              imageBytes: _avatarBytes ?? widget.profile.avatarBytes,
              radius: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose an avatar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final avatar in _avatarChoices)
                GestureDetector(
                  key: ValueKey(
                    'avatar-choice-${_avatarChoices.indexOf(avatar)}',
                  ),
                  onTap: () => setState(() {
                    _avatarUrl = avatar;
                    _avatarBytes = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _avatarUrl == avatar && _avatarBytes == null
                            ? AppTheme.primaryGreen
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _AvatarPreview(imageUrl: avatar, radius: 27),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseOwnPhoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add your own profile picture'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

class ComfortFamilyTravelScreen extends StatefulWidget {
  const ComfortFamilyTravelScreen({super.key});

  @override
  State<ComfortFamilyTravelScreen> createState() =>
      _ComfortFamilyTravelScreenState();
}

class _ComfortFamilyTravelScreenState extends State<ComfortFamilyTravelScreen> {
  final AccountService _service = AccountService();
  ComfortTravelSettings _settings = const ComfortTravelSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.getComfortSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _loading = false;
      });
    }
  }

  Future<void> _update(ComfortTravelSettings settings) async {
    setState(() => _settings = settings);
    await _service.setComfortSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comfort Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Comfort Family Travel',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plan meaningful journeys optimized for happy kids, relaxed parents, and comfortable grandparents.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 22),
                const _ComfortFeature(
                  icon: Icons.accessible_forward,
                  title: 'Shorter Walks',
                  subtitle: 'Keep walking times under your custom thresholds.',
                ),
                const SizedBox(height: 10),
                const _ComfortFeature(
                  icon: Icons.coffee_outlined,
                  title: 'More Rest Breaks',
                  subtitle:
                      'Schedule calming cafes or parks between busy stops.',
                ),
                const SizedBox(height: 10),
                const _ComfortFeature(
                  icon: Icons.airplanemode_active_outlined,
                  title: 'Accessible Routes',
                  subtitle: 'Prefer step-free transport and routes with fewer stairs.',
                ),
                const SizedBox(height: 22),
                _SettingCard(
                  title: 'Max Walking',
                  subtitle: 'Between any two stops',
                  trailing: Text(
                    '${_settings.maxWalkingMinutes} min',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Slider(
                    value: _settings.maxWalkingMinutes.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    label: '${_settings.maxWalkingMinutes} min',
                    onChanged: (value) => _update(
                      _settings.copyWith(maxWalkingMinutes: value.round()),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SettingCard(
                  title: 'Max Activities',
                  subtitle: 'Recommended limit per day',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _settings.maxActivitiesPerDay <= 1
                            ? null
                            : () => _update(
                                _settings.copyWith(
                                  maxActivitiesPerDay:
                                      _settings.maxActivitiesPerDay - 1,
                                ),
                              ),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${_settings.maxActivitiesPerDay}'),
                      IconButton(
                        onPressed: () => _update(
                          _settings.copyWith(
                            maxActivitiesPerDay:
                                _settings.maxActivitiesPerDay + 1,
                          ),
                        ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingCard(
                  title: 'Rest Break Frequency',
                  subtitle: 'Auto-schedule a break after travel',
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const [1, 2, 3])
                        ChoiceChip(
                          label: Text(
                            option == 1 ? 'Every hour' : 'Every $option hrs',
                          ),
                          selected: _settings.restBreakFrequency == option,
                          onSelected: (_) => _update(
                            _settings.copyWith(restBreakFrequency: option),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingCard(
                  title: 'Travel Comfort Options',
                  child: Column(
                    children: [
                      _SwitchSetting(
                        title: 'Accessible Transport Only',
                        subtitle: 'Bus/train routes with step-free boarding',
                        value: _settings.accessibleTransportOnly,
                        onChanged: (value) => _update(
                          _settings.copyWith(accessibleTransportOnly: value),
                        ),
                      ),
                      _SwitchSetting(
                        title: 'Nearby Restrooms Priority',
                        subtitle:
                            'Highlight spots with accessible public toilets',
                        value: _settings.nearbyRestroomsPriority,
                        onChanged: (value) => _update(
                          _settings.copyWith(nearbyRestroomsPriority: value),
                        ),
                      ),
                      _SwitchSetting(
                        title: 'Minimize Stairs',
                        subtitle: 'Choose routes with fewer stairs',
                        value: _settings.minimizeStairs,
                        onChanged: (value) =>
                            _update(_settings.copyWith(minimizeStairs: value)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final AccountService _service = AccountService();
  String _deviceState = 'unavailable';

  Future<void> _checkDevice() async {
    final state = await PushService.permissionState();
    if (mounted) setState(() => _deviceState = state);
  }

  Future<void> _enableDevice() async {
    final ok = await PushService.init(askPermission: true);
    await _checkDevice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Notifications are on for this device.'
          : 'Notifications are blocked. Allow them in your browser settings for this site.'),
    ));
  }

  Future<void> _sendTest() async {
    try {
      final devices = await PushService.sendTest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(devices == 0
            ? 'No device is saved yet. Tap "Turn on" first.'
            : 'Test sent. It should arrive in a few seconds.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send the test. Try again.")),
      );
    }
  }
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkDevice();
    _service.getNotifications().then((value) {
      if (mounted) {
        setState(() {
          _preferences = value;
          _loading = false;
        });
      }
    });
  }

  Future<void> _save(NotificationPreferences value) async {
    setState(() => _preferences = value);
    await _service.setNotifications(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'All notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Turn all notifications on or off'),
                  value: _preferences.allEnabled,
                  onChanged: (value) => _save(_preferences.setAll(value)),
                ),
                const Divider(),
                if (_deviceState != 'unavailable') ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('This device'),
                    subtitle: Text(switch (_deviceState) {
                      'granted' => 'Push notifications are on',
                      'denied' => 'Blocked in the browser. Allow notifications for this site to turn them on.',
                      _ => 'Get alerts even when the app is closed',
                    }),
                    trailing: _deviceState == 'granted'
                        ? TextButton(onPressed: _sendTest, child: const Text('Send test'))
                        : TextButton(
                            onPressed: _deviceState == 'denied' ? null : _enableDevice,
                            child: const Text('Turn on'),
                          ),
                  ),
                  const Divider(),
                ],
                _notificationTile(
                  'Trip updates',
                  'Changes and updates to your trips',
                  _preferences.tripUpdates,
                  (value) => _save(_preferences.copyWith(tripUpdates: value)),
                ),
                _notificationTile(
                  'Group chat',
                  'Messages and mentions from your travel group',
                  _preferences.groupChat,
                  (value) => _save(_preferences.copyWith(groupChat: value)),
                ),
                _notificationTile(
                  'Travel reminders',
                  'Upcoming flights, bookings, and itinerary reminders',
                  _preferences.reminders,
                  (value) => _save(_preferences.copyWith(reminders: value)),
                ),
                _notificationTile(
                  'Offers and recommendations',
                  'Travel inspiration and occasional offers',
                  _preferences.promotions,
                  (value) => _save(_preferences.copyWith(promotions: value)),
                ),
              ],
            ),
    );
  }

  Widget _notificationTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final AccountService _service = AccountService();
  String _currency = 'MYR';
  bool _loading = true;
  static const currencies = {
    'MYR': 'Malaysian Ringgit',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'SGD': 'Singapore Dollar',
    'AUD': 'Australian Dollar',
    'CNY': 'Chinese Yuan',
  };

  @override
  void initState() {
    super.initState();
    _service.getCurrency().then((value) {
      if (mounted) {
        setState(() {
          _currency = value;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Currency')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    'Choose the currency used to display trip costs.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                RadioGroup<String>(
                  groupValue: _currency,
                  onChanged: (value) {
                    if (value != null) unawaited(_selectCurrency(value));
                  },
                  child: Column(
                    children: [
                      for (final currency in currencies.entries)
                        RadioListTile<String>(
                          value: currency.key,
                          title: Text(currency.key),
                          subtitle: Text(currency.value),
                          activeColor: AppTheme.primaryGreen,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _selectCurrency(String currency) async {
    setState(() => _currency = currency);
    await _service.setCurrency(currency);
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({
    required this.imageUrl,
    this.imageBytes,
    required this.radius,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = imageBytes != null
        ? Image.memory(imageBytes!, fit: BoxFit.cover)
        : imageUrl.isNotEmpty
        ? imageUrl.startsWith('assets/')
              ? Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  alignment: imageUrl.endsWith('paris-traveller.jpg')
                      ? const Alignment(0.7, 0)
                      : Alignment.center,
                  errorBuilder: (_, _, _) => const _AvatarPlaceholder(),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _AvatarPlaceholder(),
                )
        : const _AvatarPlaceholder();
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(child: image),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppTheme.surfaceSecondary,
    child: Icon(Icons.person, color: AppTheme.primaryGreen),
  );
}

class _ComfortFeature extends StatelessWidget {
  const _ComfortFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFEDE7E3)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;
    final childWidget = child;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEDE7E3)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailingWidget,
              ],
            ),
            if (childWidget != null) ...[
              const SizedBox(height: 8),
              childWidget,
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
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
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
    ),
    value: value,
    activeTrackColor: AppTheme.primaryGreen,
    onChanged: onChanged,
  );
}
