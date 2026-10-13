import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homempage/core/theme/app_theme.dart';
import '../../services/account_service.dart';

class MainNavigationWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationWrapper({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AccountService.signedIn,
      builder: (context, signedIn, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              // Sticky Top Gradient Header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE8F5E9), // Light mint green at the top
                      Color(0xFFF1F8E9), // Very subtle soft green
                      Colors.white,      // Blends smoothly into pure white
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false, // Only apply safe area padding to the top (status bar / notch)
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'annual leave',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Tab View Content (Scrolls under header)
              Expanded(
                child: navigationShell,
              ),
            ],
          ),
        ),
      ),
      // No navigation bar until someone is signed in (the login page is the only page).
      bottomNavigationBar: !AccountService.signedIn.value ? null : Container(
        alignment: Alignment.center,
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryGreen,
            unselectedItemColor: AppTheme.textMuted,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 0,
            backgroundColor: Colors.white,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.business_center_outlined),
                label: 'Trips',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}