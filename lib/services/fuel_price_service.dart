import 'dart:convert';
import 'package:http/http.dart' as http;

class FuelPriceService {
  static const _url = 'https://api.data.gov.my/data-catalogue?id=fuelprice';

  Future<double> getLatestPrice(String fuelType) async {
    try {
      final response = await http.get(Uri.parse(_url));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        final levelEntries = data.where((row) => row['series_type'] == 'level' && row[fuelType] != null);
        if (levelEntries.isNotEmpty) {
          return (levelEntries.last[fuelType] as num).toDouble();
        }
      }
    } catch (e) {

      print('FuelPriceService error: $e');
    }
    return fuelType == 'ron97' ? 2.30 : 2.05;
  }
}