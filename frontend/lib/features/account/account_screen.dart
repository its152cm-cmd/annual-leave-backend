import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';

import '../../core/theme/app_theme.dart';
import '../../models/account_profile.dart';
import '../../services/account_service.dart';
import 'account_settings_screens.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountService _accountService = AccountService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late Future<AccountProfile?> _userFuture = _accountService.getCurrentUser();
  bool _isSubmitting = false;
  bool _isCreatingAccount = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final user = _isCreatingAccount
          ? await _accountService.signUp(
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            )
          : await _accountService.signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (mounted) {
        setState(() {
          _userFuture = Future.value(user);
        });
        context.go('/home');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message?.toString() ?? 'Check your details.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signOut() async {
    await _accountService.signOut();
    if (mounted) {
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _userFuture = Future.value(null);
      });
    }
  }

  Future<void> _openSetting(String setting, AccountProfile user) async {
    final Widget page = switch (setting) {
      'Edit Profile' => EditAccountProfileScreen(profile: user),
      'Comfort Family Travel' => const ComfortFamilyTravelScreen(),
      'Notifications' => const NotificationSettingsScreen(),
      'Currency' => const CurrencySettingsScreen(),
      _ => const SizedBox.shrink(),
    };

    if (setting == 'Edit Profile') {
      final updatedProfile = await Navigator.of(context)
          .push<AccountProfile>(MaterialPageRoute(builder: (_) => page));
      if (updatedProfile != null && mounted) {
        setState(() {
          _userFuture = Future.value(updatedProfile);
        });
      }
      return;
    }
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: FutureBuilder<AccountProfile?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load your account: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            );
          }

          final user = snapshot.data;
          if (user == null) return _buildSignedOutView();
          return _buildProfileView(user);
        },
      ),
    );
  }

  Widget _buildProfileView(AccountProfile user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipOval(
                child: user.avatarBytes != null
                    ? Image.memory(user.avatarBytes!, fit: BoxFit.cover)
                    : user.avatarUrl.isEmpty
                    ? const ColoredBox(
                        color: AppTheme.surfaceSecondary,
                        child: Icon(Icons.person, color: AppTheme.primaryGreen),
                      )
                    : user.avatarUrl.startsWith('assets/')
                    ? Image.asset(
                        user.avatarUrl,
                        fit: BoxFit.cover,
                        alignment:
                            user.avatarUrl.endsWith('paris-traveller.jpg')
                            ? const Alignment(0.7, 0)
                            : Alignment.center,
                        errorBuilder: (_, _, _) =>
                            const _ProfileAvatarPlaceholder(),
                      )
                    : Image.network(
                        user.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const _ProfileAvatarPlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'User ID: ${user.userId}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => _openSetting('Edit Profile', user),
              icon: const Icon(Icons.edit_outlined),
              color: AppTheme.primaryGreen,
            ),
          ],
        ),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatisticTile(
              value: '${user.countriesVisited}',
              label: 'Countries visited',
            ),
            _StatisticTile(
              value: '${user.citiesExplored}',
              label: 'Cities explored',
            ),
            _StatisticTile(
              value: '${user.tripsCompleted}',
              label: 'Trips completed',
            ),
            _StatisticTile(
              value: '${_formatDistance(user.distanceTravelledKm)} km',
              label: 'Travelled',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Account Settings',
          style: TextStyle(
            color: AppTheme.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        for (final setting in const [
          'Edit Profile',
          'Notifications',
          'Currency',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: const Color(0xFFF3F3F7),
              borderRadius: BorderRadius.circular(13),
              child: ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                title: Text(setting, style: const TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _openSetting(setting, user),
              ),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _signOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3737),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedOutView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 72,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: 16),
              Text(
                _isCreatingAccount ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_isCreatingAccount) ...[
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _authInputDecoration('Your name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _authInputDecoration('Email address'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                decoration: _authInputDecoration(
                  'Password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isCreatingAccount ? 'Create account' : 'Sign In'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _isCreatingAccount = !_isCreatingAccount),
                child: Text(
                  _isCreatingAccount
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                  style: const TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _authInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF3F3F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDistance(int distance) {
    if (distance < 1000) return distance.toString();
    final formatted = (distance / 1000).toStringAsFixed(
      distance % 1000 == 0 ? 0 : 2,
    );
    return formatted;
  }
}

class _ProfileAvatarPlaceholder extends StatelessWidget {
  const _ProfileAvatarPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppTheme.surfaceSecondary,
    child: Icon(Icons.person, color: AppTheme.primaryGreen),
  );
}

class _StatisticTile extends StatelessWidget {
  const _StatisticTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
