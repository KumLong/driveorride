import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/gtfs_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/reviewer_home_screen.dart';
import 'theme.dart';

final gtfsService = GtfsService(); // shared instance used across screens

// ⚠️ REPLACE these with your own Supabase project's URL and anon key
// once you have one — until then, the app still runs and shows the UI,
// it just skips remote (Supabase) sync and falls back to local-only.
const String supabaseUrl = 'https://ybqbfcpnmxhealnxozip.supabase.co';
const String supabaseAnonKey = 'sb_publishable_JMYUjIJ81VMEeLG3EwmuXA_yFq3X247';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to load real GTFS data — but don't crash the whole app if the
  // .txt files haven't been copied into assets/gtfs/ yet. This lets you
  // see and test the UI before wiring up every real data source.
  try {
    await gtfsService.load();
  } catch (e) {
    // ignore: avoid_print
    print('GTFS data not loaded yet (add files to assets/gtfs/): $e');
  }

  // Same for Supabase — only actually connect if real credentials were
  // provided. Placeholder text would otherwise throw on initialize().
  if (supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' && supabaseUrl.startsWith('http')) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        // PKCE (the newer default) requires a secret that only exists
        // on the device that originally requested a password reset —
        // it can never work when the reset link is opened on a
        // DIFFERENT device (e.g. requested on this emulator, opened on
        // a phone's email app), which is exactly what real password
        // reset needs to support. Switching to the older 'implicit'
        // flow fixes this, confirmed via Supabase's own server logs
        // showing "pkce_..." tokens being rejected as invalid the
        // moment they were opened from a different device.
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Supabase failed to initialize — check your URL/key: $e');
    }
  } else {
    // ignore: avoid_print
    print('Supabase not configured yet — running with local (SQLite) storage only.');
  }

  runApp(const DriveOrRideApp());
}

class DriveOrRideApp extends StatelessWidget {
  const DriveOrRideApp({super.key});

  /// Determines where the app should open. Checking is_reviewer
  /// requires a real database fetch (not just "is a session present"),
  /// so this whole determination has to be async — reviewer accounts
  /// land on their own dedicated dashboard, never the normal app.
  Future<Widget> _determineInitialScreen() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return const SplashScreen();

    try {
      final profile = await auth.fetchCurrentProfile();
      if (profile != null && profile.isReviewer) return const ReviewerHomeScreen();
    } catch (e) {
      // ignore: avoid_print
      print('Could not check reviewer status, defaulting to normal app: $e');
    }
    return const MainShell();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveOrRide',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: FutureBuilder<Widget>(
        future: _determineInitialScreen(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data!;
        },
      ),
    );
  }
}