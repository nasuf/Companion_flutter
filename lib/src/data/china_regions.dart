part of 'package:companion_flutter/main.dart';

class ChinaRegions {
  const ChinaRegions._();

  static Future<ChinaRegionData> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/china_regions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final regionMap = decoded['regions'] as Map<String, dynamic>;
    final data = ChinaRegionData(
      regions: regionMap.map((province, citiesValue) {
        final cities = citiesValue as Map<String, dynamic>;
        return MapEntry(
          province,
          cities.map((city, districtsValue) {
            final districts = (districtsValue as List<dynamic>)
                .map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList(growable: false);
            return MapEntry(city, districts);
          }),
        );
      }),
    );
    _cached = data;
    return data;
  }

  static ChinaRegionData? _cached;
}

class ChinaRegionData {
  const ChinaRegionData({required this.regions});

  final Map<String, Map<String, List<String>>> regions;

  List<String> get provinces => regions.keys.toList(growable: false);

  List<String> citiesFor(String? province) {
    final cities = regions[province];
    if (cities == null || cities.isEmpty) return const [];
    return cities.keys.toList(growable: false);
  }

  List<String> districtsFor(String? province, String? city) {
    final districts = regions[province]?[city];
    if (districts == null || districts.isEmpty) {
      return const ['市辖区', '其他区县'];
    }
    return districts;
  }
}
