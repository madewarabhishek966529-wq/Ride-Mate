import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'data/database/app_database.dart';
import 'providers/providers.dart';
import 'services/notification_service.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  late Future<AppDatabaseInterface> _dbFuture;

  @override
  void initState() {
    super.initState();
    _dbFuture = AppDatabase.instance;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabaseInterface>(
      future: _dbFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to initialize database: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final db = snapshot.data!;
        return ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const RideMateApp(),
        );
      },
    );
  }
}
class RideMateApp extends ConsumerStatefulWidget {
  const RideMateApp({super.key});

  @override
  ConsumerState<RideMateApp> createState() => _RideMateAppState();
}

class _RideMateAppState extends ConsumerState<RideMateApp> {
  @override
  void initState() {
    super.initState();
    _initNotificationService();
  }

  Future<void> _initNotificationService() async {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.showQuickStartNotification();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: NotificationService().navigatorKey,
      title: 'RideMate',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
