part of 'package:companion_flutter/main.dart';

class _WeatherService {
  const _WeatherService._();

  static const _fallbackCity = '杭州';
  static const _fallbackTimezone = 'Asia/Shanghai';
  static const _forecastDays = 10;

  // Session-level cache of the last successfully fetched forecast, keyed by
  // agent (or city as fallback). Keeps the page from resetting to placeholder
  // data every time it is re-entered within the same app session.
  static final Map<String, _WeatherForecast> _forecastCache = {};

  static _WeatherForecast? cachedForecast(String key) {
    final cached = _forecastCache[key];
    if (cached == null) return null;
    // Drop cache that no longer starts at today (e.g. fetched before
    // midnight); otherwise the "today" sections would show yesterday.
    final now = DateTime.now();
    final firstDay = cached.days.first.date;
    final coversToday =
        firstDay.year == now.year &&
        firstDay.month == now.month &&
        firstDay.day == now.day;
    if (!coversToday) {
      _forecastCache.remove(key);
      return null;
    }
    return cached;
  }

  static void storeForecast(String key, _WeatherForecast forecast) {
    _forecastCache[key] = forecast;
  }

  static _WeatherForecast placeholderForCity(String? city) {
    final displayName = _normalizeCityName(city);
    final location = _WeatherLocation(
      displayName: displayName.isEmpty ? _fallbackCity : displayName,
      latitude: 30.29365,
      longitude: 120.16142,
      timezone: _fallbackTimezone,
    );
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);
    final days = List.generate(_forecastDays, (dayIndex) {
      final date = baseDate.add(Duration(days: dayIndex));
      final minTemp = 19.0 + (dayIndex % 3);
      final maxTemp = 27.0 + (dayIndex % 4);
      final code = dayIndex % 5 == 3 ? 61 : 2;
      final hours = List.generate(24, (hour) {
        final temperature =
            minTemp +
            (maxTemp - minTemp) *
                (0.5 + 0.5 * math.sin((hour - 7) / 24 * math.pi * 2));
        return _WeatherHour(
          time: DateTime(date.year, date.month, date.day, hour),
          temperature: temperature,
          apparentTemperature: temperature + 1,
          humidity: 58 + (hour % 6) * 2,
          rainProbability: code == 61 ? 42 : 8,
          weatherCode: code,
          windSpeed: 8 + (hour % 4),
          windDirection: '东南风',
          aqi: 42 + dayIndex.toDouble(),
        );
      });
      return _WeatherDay(
        index: dayIndex,
        date: date,
        weatherCode: code,
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        maxRainProbability: code == 61 ? 42 : 8,
        maxWindSpeed: 12,
        dominantWindDirection: '东南风',
        hours: hours,
      );
    });
    return _WeatherForecast(
      days: days,
      current: days.first.displaySnapshot(null),
      location: location,
    );
  }

  static Future<_WeatherForecast> fetchForCity(String? city) async {
    final location = await _resolveLocation(city);
    final forecastUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': _forecastDays.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature,precipitation',
      'hourly':
          'temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant',
    });

    final weather = await _getJson(forecastUri);
    final aqi = await _fetchAqiByHour(location);
    return _parseForecast(weather, aqi, location);
  }

  static Future<_WeatherLocation> _resolveLocation(String? city) async {
    final candidates = <String>[
      _normalizeCityName(city),
      _fallbackCity,
    ].where((value) => value.isNotEmpty).toSet();

    for (final candidate in candidates) {
      try {
        final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': candidate,
          'count': '5',
          'language': 'zh',
          'format': 'json',
          'countryCode': 'CN',
        });
        final json = await _getJson(uri);
        final results = json['results'];
        if (results is! List || results.isEmpty) continue;
        final selected = results.whereType<Map<String, dynamic>>().firstWhere(
          (item) => item['country_code'] == 'CN',
          orElse: () => results.whereType<Map<String, dynamic>>().first,
        );
        final latitude = _asDouble(selected['latitude']);
        final longitude = _asDouble(selected['longitude']);
        if (latitude == 0 && longitude == 0) continue;
        final name = (selected['name'] as String?)?.trim();
        final timezone = (selected['timezone'] as String?)?.trim();
        return _WeatherLocation(
          displayName: name == null || name.isEmpty ? candidate : name,
          latitude: latitude,
          longitude: longitude,
          timezone: timezone == null || timezone.isEmpty
              ? _fallbackTimezone
              : timezone,
        );
      } catch (_) {
        continue;
      }
    }

    return const _WeatherLocation(
      displayName: _fallbackCity,
      latitude: 30.29365,
      longitude: 120.16142,
      timezone: _fallbackTimezone,
    );
  }

  static String _normalizeCityName(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    final parts = raw
        .split(RegExp(r'[\s,，、/]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      final second = _stripAdministrativeTail(parts[1]);
      if (second.isNotEmpty) return second;
    }

    final compact = raw.replaceAll(RegExp(r'[\s,，、/]+'), '');
    final cityIndex = compact.indexOf('市');
    if (cityIndex > 0) {
      final beforeCity = compact.substring(0, cityIndex);
      final boundaryEnd = _lastProvinceBoundaryEnd(beforeCity);
      final city = beforeCity.substring(boundaryEnd + 1);
      final normalized = _stripAdministrativeTail(city);
      if (normalized.isNotEmpty) return normalized;
    }

    for (final suffix in const ['自治州', '地区', '盟']) {
      final index = compact.indexOf(suffix);
      if (index > 0) {
        final before = compact.substring(0, index);
        final boundaryEnd = _lastProvinceBoundaryEnd(before);
        final city = before.substring(boundaryEnd + 1);
        if (city.isNotEmpty) return city;
      }
    }

    final boundaryEnd = _lastProvinceBoundaryEnd(compact);
    if (boundaryEnd >= 0 && boundaryEnd < compact.length - 1) {
      final city = _stripAdministrativeTail(compact.substring(boundaryEnd + 1));
      if (city.isNotEmpty) return city;
    }

    return _stripAdministrativeTail(compact);
  }

  static int _lastProvinceBoundaryEnd(String value) {
    var result = -1;
    for (final marker in const ['特别行政区', '自治区', '省']) {
      final index = value.lastIndexOf(marker);
      if (index >= 0) result = math.max(result, index + marker.length - 1);
    }
    return result;
  }

  static String _stripAdministrativeTail(String value) {
    var result = value.trim();
    for (final suffix in const ['市', '地区', '盟', '自治州']) {
      if (result.endsWith(suffix) && result.length > suffix.length) {
        result = result.substring(0, result.length - suffix.length);
      }
    }
    for (final marker in const ['区', '县', '街道', '镇', '乡']) {
      final index = result.indexOf(marker);
      if (index > 1) return result.substring(0, index);
    }
    return result;
  }

  static Future<Map<String, double>> _fetchAqiByHour(
    _WeatherLocation location,
  ) async {
    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'timezone': location.timezone,
      'forecast_days': _forecastDays.toString(),
      'hourly': 'us_aqi',
    });

    try {
      final json = await _getJson(uri);
      final hourly = json['hourly'] as Map<String, dynamic>?;
      final times = _stringList(hourly?['time']);
      final values = _numList(hourly?['us_aqi']);
      final result = <String, double>{};
      for (var i = 0; i < math.min(times.length, values.length); i += 1) {
        final value = values[i];
        if (value != null) result[times[i]] = value;
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Weather API ${response.statusCode}: $body',
          uri: uri,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected weather response');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static _WeatherForecast _parseForecast(
    Map<String, dynamic> json,
    Map<String, double> aqiByHour,
    _WeatherLocation location,
  ) {
    final currentJson = json['current'] as Map<String, dynamic>?;
    final current = currentJson == null
        ? null
        : _WeatherSnapshot(
            temperature: _asDouble(currentJson['temperature_2m']),
            apparentTemperature: _asDouble(currentJson['apparent_temperature']),
            humidity: _asDouble(currentJson['relative_humidity_2m']),
            weatherCode: _asInt(currentJson['weather_code']),
            windSpeed: _asDouble(currentJson['wind_speed_10m']),
            windDirection: _windDirection(
              _asDouble(currentJson['wind_direction_10m']),
            ),
          );

    final hourly = json['hourly'] as Map<String, dynamic>?;
    final hourlyTimes = _stringList(hourly?['time']);
    final hourlyTemps = _numList(hourly?['temperature_2m']);
    final hourlyFeels = _numList(hourly?['apparent_temperature']);
    final hourlyHumidity = _numList(hourly?['relative_humidity_2m']);
    final hourlyRain = _numList(hourly?['precipitation_probability']);
    final hourlyCodes = _numList(hourly?['weather_code']);
    final hourlyWind = _numList(hourly?['wind_speed_10m']);
    final hourlyDirection = _numList(hourly?['wind_direction_10m']);

    final hoursByDay = <String, List<_WeatherHour>>{};
    for (var i = 0; i < hourlyTimes.length; i += 1) {
      final time = DateTime.parse(hourlyTimes[i]);
      final key = _dateKey(time);
      final hour = _WeatherHour(
        time: time,
        temperature: hourlyTemps.elementAtOrNull(i) ?? 0,
        apparentTemperature:
            hourlyFeels.elementAtOrNull(i) ??
            hourlyTemps.elementAtOrNull(i) ??
            0,
        humidity: hourlyHumidity.elementAtOrNull(i) ?? 0,
        rainProbability: hourlyRain.elementAtOrNull(i) ?? 0,
        weatherCode: (hourlyCodes.elementAtOrNull(i) ?? 0).round(),
        windSpeed: hourlyWind.elementAtOrNull(i) ?? 0,
        windDirection: _windDirection(hourlyDirection.elementAtOrNull(i) ?? 0),
        aqi: aqiByHour[hourlyTimes[i]],
      );
      hoursByDay.putIfAbsent(key, () => []).add(hour);
    }

    final daily = json['daily'] as Map<String, dynamic>?;
    final dates = _stringList(daily?['time']);
    final maxTemps = _numList(daily?['temperature_2m_max']);
    final minTemps = _numList(daily?['temperature_2m_min']);
    final rain = _numList(daily?['precipitation_probability_max']);
    final codes = _numList(daily?['weather_code']);
    final wind = _numList(daily?['wind_speed_10m_max']);
    final windDirection = _numList(daily?['wind_direction_10m_dominant']);

    final days = <_WeatherDay>[];
    for (var i = 0; i < math.min(_forecastDays, dates.length); i += 1) {
      final date = DateTime.parse(dates[i]);
      final hours = hoursByDay[_dateKey(date)] ?? const <_WeatherHour>[];
      final code =
          (codes.elementAtOrNull(i) ??
                  (hours.isEmpty ? 0 : hours.first.weatherCode))
              .round();
      days.add(
        _WeatherDay(
          index: i,
          date: date,
          weatherCode: code,
          minTemperature: minTemps.elementAtOrNull(i) ?? _minHour(hours),
          maxTemperature: maxTemps.elementAtOrNull(i) ?? _maxHour(hours),
          maxRainProbability: rain.elementAtOrNull(i) ?? _maxRain(hours),
          maxWindSpeed: wind.elementAtOrNull(i) ?? _maxWind(hours),
          dominantWindDirection: _windDirection(
            windDirection.elementAtOrNull(i) ?? 0,
          ),
          hours: hours,
        ),
      );
    }

    if (days.isEmpty) throw const FormatException('Weather forecast is empty');
    return _WeatherForecast(days: days, current: current, location: location);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  static List<double?> _numList(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item is num ? item.toDouble() : null).toList();
  }

  static double _asDouble(Object? value) => value is num ? value.toDouble() : 0;

  static int _asInt(Object? value) => value is num ? value.round() : 0;

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static double _minHour(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.temperature).reduce(math.min);
  }

  static double _maxHour(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.temperature).reduce(math.max);
  }

  static double _maxRain(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.rainProbability).reduce(math.max);
  }

  static double _maxWind(List<_WeatherHour> hours) {
    if (hours.isEmpty) return 0;
    return hours.map((h) => h.windSpeed).reduce(math.max);
  }
}

class _WeatherLocation {
  const _WeatherLocation({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String timezone;
}

class _WeatherForecast {
  const _WeatherForecast({
    required this.days,
    required this.current,
    required this.location,
  });

  final List<_WeatherDay> days;
  final _WeatherSnapshot? current;
  final _WeatherLocation location;
}

class _WeatherDay {
  const _WeatherDay({
    required this.index,
    required this.date,
    required this.weatherCode,
    required this.minTemperature,
    required this.maxTemperature,
    required this.maxRainProbability,
    required this.maxWindSpeed,
    required this.dominantWindDirection,
    required this.hours,
  });

  final int index;
  final DateTime date;
  final int weatherCode;
  final double minTemperature;
  final double maxTemperature;
  final double maxRainProbability;
  final double maxWindSpeed;
  final String dominantWindDirection;
  final List<_WeatherHour> hours;

  String get weatherText => _weatherText(weatherCode);

  String get dateLabel =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String get futureTitle {
    if (index == 0) return '今天';
    if (index == 1) return '明天';
    return date._weatherWeekdayLabel;
  }

  List<_WeatherHour> get stripHours {
    if (hours.isEmpty) return const [];
    final selected = <_WeatherHour>[];
    for (final target in const [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]) {
      selected.add(_nearestHour(target));
    }
    return selected;
  }

  _WeatherHour _nearestHour(int targetHour) {
    return hours.reduce((a, b) {
      final aDistance = (a.time.hour - targetHour).abs();
      final bDistance = (b.time.hour - targetHour).abs();
      return aDistance <= bDistance ? a : b;
    });
  }

  _WeatherSnapshot displaySnapshot(_WeatherSnapshot? current) {
    if (index == 0 && current != null) return current;
    final hour = hours.isEmpty
        ? null
        : _nearestHour(index == 0 ? DateTime.now().hour : 14);
    if (hour == null) {
      return _WeatherSnapshot(
        temperature: (minTemperature + maxTemperature) / 2,
        apparentTemperature: (minTemperature + maxTemperature) / 2,
        humidity: 0,
        weatherCode: weatherCode,
        windSpeed: maxWindSpeed,
        windDirection: dominantWindDirection,
      );
    }
    return _WeatherSnapshot(
      temperature: hour.temperature,
      apparentTemperature: hour.apparentTemperature,
      humidity: hour.humidity,
      weatherCode: hour.weatherCode,
      windSpeed: hour.windSpeed,
      windDirection: hour.windDirection,
    );
  }
}

class _WeatherHour {
  const _WeatherHour({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.rainProbability,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
    required this.aqi,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double rainProbability;
  final int weatherCode;
  final double windSpeed;
  final String windDirection;
  final double? aqi;
}

class _WeatherSnapshot {
  const _WeatherSnapshot({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.windSpeed,
    required this.windDirection,
  });

  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final int weatherCode;
  final double windSpeed;
  final String windDirection;
}

extension on DateTime {
  String get _weatherWeekdayLabel {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[weekday - 1];
  }
}

String _weatherText(int code) {
  if (code == 0) return '晴';
  if (code == 1 || code == 2) return '多云';
  if (code == 3) return '阴';
  if (code == 45 || code == 48) return '有雾';
  if (code >= 51 && code <= 67) return '小雨';
  if (code >= 71 && code <= 77) return '有雪';
  if (code >= 80 && code <= 82) return '阵雨';
  if (code >= 95) return '雷雨';
  return '多云';
}

String _weatherAsset(int code, {required int hour}) {
  final isNight = hour < 6 || hour >= 20;
  if (code == 0) return 'assets/weather/sunny.png';
  if (code == 1 || code == 2) {
    return isNight
        ? 'assets/weather/cloudy.png'
        : 'assets/weather/partly_cloudy.png';
  }
  if (code == 3 || code == 45 || code == 48) {
    return 'assets/weather/cloudy.png';
  }
  if (code >= 71 && code <= 77) return 'assets/weather/snow.png';
  if (code >= 95) return 'assets/weather/storm_rain.png';
  if (code >= 51 && code <= 67) return 'assets/weather/rain.png';
  if (code >= 80 && code <= 82) return 'assets/weather/storm_rain.png';
  return isNight
      ? 'assets/weather/cloudy.png'
      : 'assets/weather/partly_cloudy.png';
}

bool _isSunnyWeather(int code) => code == 0;

bool _isPartlyCloudyWeather(int code) => code == 1 || code == 2;

bool _isRainWeather(int code) => (code >= 51 && code <= 67) || code >= 80;

bool _isSnowWeather(int code) => code >= 71 && code <= 77;

bool _isThunderWeather(int code) => code >= 95;

String _weatherMoodLine(_WeatherDay day) {
  if (day.maxRainProbability >= 55) return '今天是小雨天，\n我的心情也变得安静了一点';
  if (day.maxTemperature >= 30) return '阳光有点认真，\n记得把防晒也放进行程里';
  if (day.minTemperature <= 10) return '天气有点凉，\n适合把外套和温柔都带上';
  if (day.weatherCode == 0 || day.weatherCode == 1 || day.weatherCode == 2) {
    return '天气很轻快，\n适合出去走走也适合慢慢聊';
  }
  return '云层慢慢铺开，\n今天可以把节奏放柔一点';
}

String _windDirection(double degrees) {
  final normalized = degrees % 360;
  const labels = ['北风', '东北风', '东风', '东南风', '南风', '西南风', '西风', '西北风'];
  final index = ((normalized + 22.5) ~/ 45) % labels.length;
  return labels[index];
}
