import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class LocationService {
  Map<String, dynamic>? _locationsCache;

  Future<void> _ensureLoaded() async {
    if (_locationsCache != null) return;
    try {
      final jsonString = await rootBundle.loadString('assets/locations.json');
      _locationsCache = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _locationsCache = {};
    }
  }

  Future<List<String>> getStates() async {
    await _ensureLoaded();
    final states = _locationsCache!.keys.toList();
    states.sort();
    return states;
  }

  Future<List<String>> getDistricts(String state) async {
    await _ensureLoaded();
    final stateData = _locationsCache![state] as Map<String, dynamic>?;
    if (stateData == null) return [];
    final districts = stateData.keys.toList();
    districts.sort();
    return districts;
  }

  Future<List<String>> getTalukas(String state, String district) async {
    await _ensureLoaded();
    final stateData = _locationsCache![state] as Map<String, dynamic>?;
    if (stateData == null) return [];
    final talukas = stateData[district] as List<dynamic>?;
    if (talukas == null) return [];
    return talukas.map((e) => e.toString()).toList();
  }
}
