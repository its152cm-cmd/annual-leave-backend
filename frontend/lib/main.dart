import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routing and navigation/app_router.dart';
import 'core/push/push_service.dart';
import 'services/account_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccountService.restoreSession();
  PushService.init(); // silent: only registers if notifications were already allowed
  runApp(const AnnualLeaveApp());
}

class AnnualLeaveApp extends StatelessWidget {
  const AnnualLeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: routerRevision,
      builder: (context, revision, _) => MaterialApp.router(
        key: ValueKey(revision),
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootMessengerKey,
        title: 'Annual Leave',
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}