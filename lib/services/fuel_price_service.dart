import 'dart:convert';
import 'package:http/http.dart' as http;

/// Fetches Malaysia's real, live weekly fuel prices from data.gov.my.
///
/// CORRECTED field structure, confirmed by directly fetching the live
/// endpoint: each row has 'ron95', 'ron97', 'diesel' as separate
/// number fields (NOT a 'fuel_type'/'price' pair, which was the
/// original — wrong — assumption). A 'series_type' field distinguishes
/// "level" (the real absolute price) from "change_weekly" (just that
/// week's change amount, not a usable price at all).
class FuelPriceService {
  static const _url = 'https://api.data.gov.my/data-catalogue?id=fuelprice';

  /// [fuelType] must be 'ron95' or 'ron97' — matches the real field
  /// names used by the government API directly, so no translation is
  /// needed between what the user picks and what gets requested here.
  Future<double> getLatestPrice(String fuelType) async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        // Only "level" rows hold a real, absolute price — "change_weekly"
        // rows hold just that week's price CHANGE (e.g. +0.25 or -0.15),
        // which would be meaningless if used directly as a price.
        final levelEntries = data.where((row) => row['series_type'] == 'level' && row[fuelType] != null);
        if (levelEntries.isNotEmpty) {
          return (levelEntries.last[fuelType] as num).toDouble();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('FuelPriceService error: $e');
    }
    return fuelType == 'ron97' ? 2.30 : 2.05; // fallback if API call fails (e.g. offline demo)
  }
}