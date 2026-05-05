import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<String> fetchWeatherString() async {
    final position = await _getPosition();

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${position.latitude}'
      '&longitude=${position.longitude}'
      '&current=temperature_2m,relative_humidity_2m,'
      'wind_speed_10m,wind_direction_10m,surface_pressure'
      '&wind_speed_unit=ms'
      '&timezone=auto',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Помилка API: ${response.statusCode}');
    }

    final current =
        (jsonDecode(response.body) as Map<String, dynamic>)['current']
            as Map<String, dynamic>;

    final temp     = (current['temperature_2m']     as num).toDouble();
    final humidity = (current['relative_humidity_2m'] as num).toInt();
    final wind     = (current['wind_speed_10m']     as num).toDouble();
    final windDir  = (current['wind_direction_10m'] as num).toInt();
    final pressure = (current['surface_pressure']   as num).toDouble();

    final tempSign = temp >= 0 ? '+' : '';
    return 'Т: $tempSign${temp.toStringAsFixed(0)}°C'
        ' · Вітер: ${wind.toStringAsFixed(1)} м/с ${_windDir(windDir)}'
        ' · Вол.: $humidity%'
        ' · Тиск: ${pressure.toStringAsFixed(0)} гПа';
  }

  Future<Position> _getPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Доступ до геолокації відхилено');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Доступ до геолокації назавжди заблоковано. Відкрийте налаштування.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  static const _dirs = ['Пн', 'ПнСх', 'Сх', 'ПдСх', 'Пд', 'ПдЗх', 'Зх', 'ПнЗх'];

  String _windDir(int degrees) => _dirs[((degrees + 22.5) / 45).floor() % 8];
}
