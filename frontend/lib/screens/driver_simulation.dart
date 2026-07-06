// lib/driver_simulation.dart
import 'dart:async';
import 'package:latlong2/latlong.dart';

import 'map_logic.dart';

/// Phases of the driver / trip lifecycle.
enum DriverPhase {
  idle,
  searchingDriver,
  driverAssigned,
  driverArriving,
  driverAtPickup,
  onTrip,
  reachedDestination,
}

/// Handles simulated driver assignment + live movement.
class DriverSimulation {
  final void Function(DriverPhase phase) onPhaseChanged;
  final void Function(LatLng pos, List<LatLng> trail, int? liveEtaMin)
      onPositionUpdate;

  Timer? _phaseTimer;
  Timer? _moveTimer;

  DriverPhase _phase = DriverPhase.idle;
  List<LatLng> _toPickup = [];
  List<LatLng> _route = [];
  int _routeEtaMin = 0;

  int _index = 0;
  final List<LatLng> _trail = [];

  bool get isRunning => _moveTimer != null || _phaseTimer != null;

  DriverSimulation({
    required this.onPhaseChanged,
    required this.onPositionUpdate,
  });

  void _setPhase(DriverPhase p) {
    _phase = p;
    onPhaseChanged(p);
  }

  /// Start full flow:
  ///   Searching → Assigned → Arriving → AtPickup → OnTrip → ReachedDestination
  void start({
    required LatLng pickup,
    required List<LatLng> routePoints,
    required int baseEtaMinutes,
  }) {
    stop();

    if (routePoints.length < 2) return;

    _route = List<LatLng>.from(routePoints);
    _routeEtaMin = baseEtaMinutes <= 0 ? 10 : baseEtaMinutes;

    // Simulate driver starting ~1.2 km away from pickup
    final start = offsetLatLng(
      pickup,
      km: 1.2,
      bearingDeg: 60,
    );

    _toPickup = _buildLinearPath(start, pickup, 25);
    _index = 0;
    _trail.clear();

    // 1) Searching
    _setPhase(DriverPhase.searchingDriver);
    _phaseTimer = Timer(const Duration(seconds: 3), () {
      // 2) Assigned
      _setPhase(DriverPhase.driverAssigned);

      _phaseTimer = Timer(const Duration(seconds: 1), () {
        // 3) Arriving → move along _toPickup
        _setPhase(DriverPhase.driverArriving);
        _startMoveLeg(
          points: _toPickup,
          tickMs: 400,
          onDone: () {
            _setPhase(DriverPhase.driverAtPickup);

            // Small wait at pickup, then start trip
            _phaseTimer = Timer(const Duration(seconds: 1), () {
              _setPhase(DriverPhase.onTrip);
              _startMoveLeg(
                points: _route,
                tickMs: 500,
                onDone: () {
                  _setPhase(DriverPhase.reachedDestination);
                  // final ETA 0
                  if (_route.isNotEmpty) {
                    _notifyPosition(_route.last, 0);
                  }
                },
              );
            });
          },
        );
      });
    });
  }

  /// Stop all timers.
  void stop() {
    _phaseTimer?.cancel();
    _moveTimer?.cancel();
    _phaseTimer = null;
    _moveTimer = null;
  }

  void dispose() {
    stop();
  }

  void _startMoveLeg({
    required List<LatLng> points,
    required int tickMs,
    required void Function() onDone,
  }) {
    if (points.length < 2) {
      onDone();
      return;
    }

    _moveTimer?.cancel();
    _index = 0;
    _trail.clear();

    final totalPoints = points.length;

    _moveTimer = Timer.periodic(Duration(milliseconds: tickMs), (timer) {
      if (_index >= totalPoints) {
        timer.cancel();
        _moveTimer = null;
        onDone();
        return;
      }

      final pos = points[_index];
      _trail.add(pos);
      if (_trail.length > 40) _trail.removeAt(0);

      int? eta;
      if (_phase == DriverPhase.onTrip && totalPoints > 1) {
        final remainingFraction =
            1.0 - (_index / (totalPoints - 1)).clamp(0.0, 1.0);
        eta = (remainingFraction * _routeEtaMin).ceil();
        if (eta < 1 && remainingFraction > 0) eta = 1;
      } else if (_phase == DriverPhase.driverArriving) {
        eta = 3; // simple fixed ETA when arriving at pickup
      }

      onPositionUpdate(pos, List<LatLng>.from(_trail), eta);
      _index++;
    });
  }

  void _notifyPosition(LatLng pos, int? eta) {
    _trail.add(pos);
    if (_trail.length > 40) _trail.removeAt(0);
    onPositionUpdate(pos, List<LatLng>.from(_trail), eta);
  }

  List<LatLng> _buildLinearPath(LatLng a, LatLng b, int steps) {
    if (steps <= 1) return [a, b];

    final pts = <LatLng>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lon = a.longitude + (b.longitude - a.longitude) * t;
      pts.add(LatLng(lat, lon));
    }
    return pts;
  }
}
