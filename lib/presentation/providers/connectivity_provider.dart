import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// true si hay conectividad. Emite el estado inicial y luego cada cambio,
/// para que la UI pueda mostrar/ocultar el indicador de offline de forma global.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield initial != ConnectivityResult.none;
  yield* connectivity.onConnectivityChanged
      .map((result) => result != ConnectivityResult.none);
});
