import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/gtfs_service.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

final gtfsService = GtfsService(); // shared instance used across screens

// ⚠️ REPLACE these with your own Supabase project's URL and anon key
// once you have one — until then, the app still runs and shows the UI,
// it just skips remote (Supabase) sync and falls back to local-only.
const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

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
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveOrRide',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}
