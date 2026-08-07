import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static Map<String, dynamic> _rates = {};

  static Future<void> loadRates() async {
    final response = await http.get(
      Uri.parse('https://open.er-api.com/v6/latest/INR'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _rates = json['rates'];
    }
  }

  static double getRate(String currency) {
    return (_rates[currency.toUpperCase()] ?? 1).toDouble();
  }

  static double convert(double amountInInr, String currency) {
    return amountInInr * getRate(currency);
  }
}