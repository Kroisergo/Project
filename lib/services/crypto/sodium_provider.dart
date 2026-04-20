import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium_sumo.dart';

final sodiumProvider = FutureProvider<SodiumSumo>((ref) async {
  return SodiumSumoInit.init();
});
