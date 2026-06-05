// #Ciclo5 CU19 - Servicio de monitoreo de conectividad
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ConnectivityService {
  // Singleton
  static final ConnectivityService instance = ConnectivityService._internal();
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _lastKnownStatus = true;

  /// Stream that emits true (online) or false (offline)
  Stream<bool> get onConnectivityChanged => _controller.stream;
  
  /// Current connectivity status
  bool get isOnline => _lastKnownStatus;

  /// Initialize - call once in main.dart
  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        // Verify real connectivity by pinging backend
        final reallyOnline = await _checkRealConnectivity();
        if (reallyOnline != _lastKnownStatus) {
          _lastKnownStatus = reallyOnline;
          _controller.add(reallyOnline);
        }
      } else {
        if (_lastKnownStatus != false) {
          _lastKnownStatus = false;
          _controller.add(false);
        }
      }
    });
    // Initial check
    _checkAndEmit();
  }

  Future<void> _checkAndEmit() async {
    final results = await _connectivity.checkConnectivity();
    final hasConnection = !results.contains(ConnectivityResult.none);
    if (hasConnection) {
      _lastKnownStatus = await _checkRealConnectivity();
    } else {
      _lastKnownStatus = false;
    }
    _controller.add(_lastKnownStatus);
  }

  Future<bool> _checkRealConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/docs'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// Check current connectivity
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return false;
    return _checkRealConnectivity();
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
