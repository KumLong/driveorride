import 'package:shared_preferences/shared_preferences.dart';

/// Stores which fuel type the user's car actually uses — RON95 (the
/// default, since most Malaysian vehicles use it) or RON97. This is a
/// simple DEVICE-level setting (like a property of the car being
/// driven), not tied to any account — matching how it works in real
/// life: your car needs the same fuel type regardless of which app
/// account you happen to be logged into.
class FuelPreferenceService {
  static const _key = 'fuel_type_preference';

  Future<String> getFuelType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'ron95'; // RON95 is the sensible default
  }

  Future<void> setFuelType(String fuelType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, fuelType);
  }
}