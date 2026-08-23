import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches Malaysia's real, live weekly fuel prices from data.gov.my
/// (same api.data.gov.my pattern as the Weather API in Practical 10).
class FuelPriceService {
  static const _url = 'https://api.data.gov.my/data-catalogue?id=fuelprice';

  /// ⚠️ VERIFY the exact field names once you run this for real —
  /// I have not personally confirmed 'fuel_type'/'price' are correct;
  /// print the raw response once and adjust if needed.
  Future<double> getLatestRon95Price() async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final ron95Entries = data.where((row) => row['fuel_type'] == 'ron95');
        if (ron95Entries.isNotEmpty) {
          return double.parse(ron95Entries.last['price'].toString());
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('FuelPriceService error: $e');
    }
    return 2.05; // fallback if API call fails (e.g. offline demo)
  }
}
