import 'package:shared_preferences/shared_preferences.dart';

class FuelPreferenceService {
  static const _key = 'fuel_type_preference';

  Future<String> getFuelType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'ron95';
  }

  Future<void> setFuelType(String fuelType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, fuelType);
  }
}