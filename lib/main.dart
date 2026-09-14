import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/gtfs_service.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/main_shell.dart';
import 'screens/reviewer_home_screen.dart';
import 'theme.dart';

final gtfsService = GtfsService();

const String supabaseUrl = 'https://ybqbfcpnmxhealnxozip.supabase.co';
const String supabaseAnonKey = 'sb_publishable_JMYUjIJ81VMEeLG3EwmuXA_yFq3X247';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await gtfsService.load();
  } catch (e) {

    print('GTFS data not loaded yet (add files to assets/gtfs/): $e');
  }

  if (supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' && supabaseUrl.startsWith('http')) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,

        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
    } catch (e) {

      print('Supabase failed to initialize — check your URL/key: $e');
    }
  } else {

    print('Supabase not configured yet — running with local (SQLite) storage only.');
  }

  runApp(const DriveOrRideApp());
}

class DriveOrRideApp extends StatelessWidget {
  const DriveOrRideApp({super.key});

  Future<Widget> _determineInitialScreen() async {
    final auth = AuthService();
    if (!auth.isLoggedIn) return const SplashScreen();

    try {
      final profile = await auth.fetchCurrentProfile();
      if (profile != null && profile.isReviewer) return const ReviewerHomeScreen();
    } catch (e) {

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