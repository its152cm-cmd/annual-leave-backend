import 'dart:convert';
import 'favourites_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/push/push_service.dart';
import '../core/routing and navigation/app_router.dart';
import '../mock/mock_chat_list.dart';
import '../mock/mock_trip_summary.dart';
import '../models/account_profile.dart';
import '../models/account_settings.dart';
import 'chat_list_service.dart';
import 'expense_service.dart';
import 'trip_service.dart';

class AccountService {
  static AccountProfile? _currentUser;

  /// True while someone is signed in. The router listens to this.
  static final ValueNotifier<bool> signedIn = ValueNotifier(false);

  static const _tokenKey = 'al_token';
  static const _refreshKey = 'al_refresh';
  static String _currencyCode = 'MYR';
  static NotificationPreferences _notifications =
      const NotificationPreferences();
  static ComfortTravelSettings _comfortSettings = const ComfortTravelSettings();
  static TravelDefaults _travelDefaults = const TravelDefaults();

  Future<AccountProfile?> getCurrentUser() async => _currentUser;

  /// Called once when the app starts: signs back in from the saved session.
  static Future<void> restoreSession() async {
    ApiClient.onTokenExpired = _renewToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null) return;
      ApiClient.sessionToken = token;
      ApiClient.refreshToken = prefs.getString(_refreshKey);
      final me = await ApiClient().get('/api/me');
      _setUser(Map<String, dynamic>.from(me as Map));
    } catch (e) {
      debugPrint('[login] could not restore the session: $e');
      await _forgetSession();
    }
  }

  /// Everything on screen belongs to one account, so reload it all.
  static void _resetScreens() {
    ExpenseService.clearCache();
    TripService.clearCache();
    SuggestionFavoritesService.reset();
    if (signedIn.value) SuggestionFavoritesService.load();
    ChatListService.conversationsRevision.value++;
  }

  /// Chats of the person who just left must not show for the next person.
  static void _wipeLocalChats() {
    final conversations = List<dynamic>.from(
      mockChatListData['conversations'] as List<dynamic>? ?? const [],
    );
    mockChatListData['conversations'] = conversations
        .where(
          (c) => !ExpenseService.isSavedGroup(
            (c as Map<String, dynamic>)['groupId'] as String? ?? '',
          ),
        )
        .toList();
    mockTripSummaryDatabase.removeWhere(
      (groupId, _) => ExpenseService.isSavedGroup(groupId),
    );
  }

  static void _setUser(Map<String, dynamic> profile) {
    _currentUser = AccountProfile.fromJson(profile);
    signedIn.value = true;
    _loadSettings();
    _wipeLocalChats();
    _resetScreens();
    resetAppRouter();
  }

  /// Currency, notifications, comfort and travel defaults live on the server, so they follow the account.
  static Future<void> _loadSettings() async {
    try {
      final r = Map<String, dynamic>.from(await ApiClient().get('/api/me/settings') as Map);
      _currencyCode = '${r['currency_code'] ?? 'MYR'}';
      final n = Map<String, dynamic>.from((r['notifications'] ?? {}) as Map);
      _notifications = NotificationPreferences(
        tripUpdates: n['trip_updates'] as bool? ?? true,
        groupChat: n['group_chat'] as bool? ?? true,
        reminders: n['reminders'] as bool? ?? true,
        promotions: n['promotions'] as bool? ?? false,
      );
      final c = Map<String, dynamic>.from((r['comfort'] ?? {}) as Map);
      _comfortSettings = ComfortTravelSettings(
        maxWalkingMinutes: (c['max_walking_minutes'] as num?)?.toInt() ?? 15,
        maxActivitiesPerDay: (c['max_activities_per_day'] as num?)?.toInt() ?? 3,
        restBreakFrequency: (c['rest_break_frequency'] as num?)?.toInt() ?? 1,
        accessibleTransportOnly: c['accessible_transport_only'] as bool? ?? true,
        nearbyRestroomsPriority: c['nearby_restrooms_priority'] as bool? ?? true,
        minimizeStairs: c['minimize_stairs'] as bool? ?? false,
      );
      _travelDefaults = TravelDefaults.fromJson(
        r['travel'] is Map ? Map<String, dynamic>.from(r['travel'] as Map) : null,
      );
    } catch (e) {
      debugPrint('[account] could not load the settings: $e');
    }
  }

  static Future<void> _saveSettings(Map<String, dynamic> changes) async {
    try {
      await ApiClient().put('/api/me/settings', changes);
    } catch (e) {
      debugPrint('[account] could not save the settings: $e');
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> session) async {
    ApiClient.sessionToken = session['token'] as String;
    ApiClient.refreshToken = session['refreshToken'] as String?;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, ApiClient.sessionToken!);
      if (ApiClient.refreshToken != null) {
        await prefs.setString(_refreshKey, ApiClient.refreshToken!);
      }
    } catch (_) {}
    PushService.init(askPermission: true); // after login: ask once to allow notifications
  }

  static Future<void> _forgetSession() async {
    ApiClient.sessionToken = null;
    ApiClient.refreshToken = null;
    _currentUser = null;
    _currencyCode = 'MYR';
    _notifications = const NotificationPreferences();
    _comfortSettings = const ComfortTravelSettings();
    _travelDefaults = const TravelDefaults();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshKey);
    } catch (_) {}
    signedIn.value = false;
    _wipeLocalChats();
    _resetScreens();
    resetAppRouter();
  }

  /// The login lasts about an hour; this swaps in a fresh one.
  static Future<bool> _renewToken() async {
    final refresh = ApiClient.refreshToken;
    if (refresh == null) {
      await _forgetSession();
      return false;
    }
    try {
      final session = await ApiClient().post('/api/auth/refresh', {
        'refreshToken': refresh,
      });
      await _saveSession(Map<String, dynamic>.from(session as Map));
      return true;
    } catch (_) {
      await _forgetSession();
      return false;
    }
  }

  Future<void> signOut() async {
    await PushService.stop();
    await _forgetSession();
    ExpenseService.clearCache();
  }

  Future<AccountProfile> updateProfile(AccountProfile profile) async {
    var saved = profile;
    try {
      await ApiClient().patch('/api/me', {'name': profile.name});
      final bytes = profile.avatarBytes;
      if (bytes != null) {
        // a new photo: keep it on the server so it survives signing out
        final me = await ApiClient().post('/api/me/avatar', {
          'mimeType': _imageMime(bytes),
          'dataBase64': base64Encode(bytes),
        });
        final url = '${(me as Map)['avatar_url'] ?? ''}';
        if (url.isNotEmpty) saved = profile.copyWith(avatarUrl: url);
      } else if (profile.avatarUrl != _currentUser?.avatarUrl) {
        // one of the built-in avatars (or none)
        await ApiClient().patch('/api/me', {'avatar_url': profile.avatarUrl});
      }
    } catch (e) {
      debugPrint('[account] could not save the profile: $e');
    }
    _currentUser = saved;
    return saved;
  }

  String _imageMime(Uint8List b) {
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 11 && b[8] == 0x57 && b[9] == 0x45) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> getCurrency() async => _currencyCode;

  Future<String> setCurrency(String currencyCode) async {
    _currencyCode = currencyCode;
    await _saveSettings({'currency_code': currencyCode});
    return _currencyCode;
  }

  Future<NotificationPreferences> getNotifications() async => _notifications;

  Future<NotificationPreferences> setNotifications(
    NotificationPreferences preferences,
  ) async {
    _notifications = preferences;
    await _saveSettings({
      'notifications': {
        'trip_updates': preferences.tripUpdates,
        'group_chat': preferences.groupChat,
        'reminders': preferences.reminders,
        'promotions': preferences.promotions,
      },
    });
    return preferences;
  }

  Future<ComfortTravelSettings> getComfortSettings() async => _comfortSettings;

  Future<ComfortTravelSettings> setComfortSettings(
    ComfortTravelSettings settings,
  ) async {
    _comfortSettings = settings;
    await _saveSettings({
      'comfort': {
        'max_walking_minutes': settings.maxWalkingMinutes,
        'max_activities_per_day': settings.maxActivitiesPerDay,
        'rest_break_frequency': settings.restBreakFrequency,
        'accessible_transport_only': settings.accessibleTransportOnly,
        'nearby_restrooms_priority': settings.nearbyRestroomsPriority,
        'minimize_stairs': settings.minimizeStairs,
      },
    });
    return settings;
  }

  Future<TravelDefaults> getTravelDefaults() async => _travelDefaults;

  Future<TravelDefaults> setTravelDefaults(TravelDefaults defaults) async {
    _travelDefaults = defaults;
    await _saveSettings({'travel': defaults.toJson()});
    return defaults;
  }

  Future<AccountProfile> signIn({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Enter both an email address and password.');
    }
    return _authenticate('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AccountProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Enter both an email address and password.');
    }
    return _authenticate('/api/auth/signup', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<AccountProfile> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    ExpenseService.clearCache();
    final session = Map<String, dynamic>.from(
      await ApiClient().post(path, body) as Map,
    );
    await _saveSession(session);
    _setUser(Map<String, dynamic>.from(session['profile'] as Map));
    return _currentUser!;
  }
}
