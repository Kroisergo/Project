import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium_libs/sodium_libs_sumo.dart';

final sodiumProvider = FutureProvider<SodiumSumo>((ref) async {
  return SodiumSumoInit.init();
});
