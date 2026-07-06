// lib/map_logic.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Shared constants
const double kMaxFoodDistanceKm = 30.0;
const double kMaxDetourKm = 7.0;
const int kGlobalMaxStops = 5;

/// Status text based on route distance and error.
String statusFromDistance(
  LatLng? pickup,
  LatLng? drop,
  double? distanceKm,
  String? routeError,
) {
  if (pickup == null || drop == null) return '';
  if (routeError != null) return routeError;
  final d = distanceKm ?? 0;
  if (d > 2500) {
    return "International route — cab only. No food deliveries.";
  }
  if (d > 700) {
    return "Interstate route — cab allowed. Local food stops only.";
  }
  if (d > 50) {
    return "Long route — limited local deliveries (≤7 km detour).";
  }
  return "Optimal Route";
}

int maxAllowedFoodStopsByDistance(double? distanceKm) {
  if (distanceKm == null) return 0;
  final byDistance = (distanceKm / 20.0).floor();
  return byDistance.clamp(0, kGlobalMaxStops);
}

double avgSpeedKmphFor(double routeKm) => routeKm <= 50 ? 40 : 70;

double estimateMinutes(double distanceKm, double avgSpeed) =>
    avgSpeed <= 0 ? 0 : (distanceKm / avgSpeed) * 60.0;

/// Geo helpers
double distKm(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Kilometer, a, b);

LatLng offsetLatLng(
  LatLng start, {
  required double km,
  required double bearingDeg,
}) {
  const R = 6371.0;
  final d = km / R;
  final br = bearingDeg * pi / 180.0;
  final lat1 = start.latitude * pi / 180.0;
  final lon1 = start.longitude * pi / 180.0;

  final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(br));
  final lon2 = lon1 +
      atan2(
        sin(br) * sin(d) * cos(lat1),
        cos(d) - sin(lat1) * sin(lat2),
      );

  return LatLng(lat2 * 180.0 / pi, lon2 * 180.0 / pi);
}

double pointToSegmentDistanceKm(LatLng p, LatLng a, LatLng b) {
  final px = p.longitude, py = p.latitude;
  final ax = a.longitude, ay = a.latitude;
  final bx = b.longitude, by = b.latitude;

  final dx = bx - ax;
  final dy = by - ay;

  double t = 0.0;
  final denom = dx * dx + dy * dy;
  if (denom > 0) {
    t = ((px - ax) * dx + (py - ay) * dy) / denom;
    t = t.clamp(0.0, 1.0);
  }

  final proj = LatLng(ay + t * dy, ax + t * dx);
  return distKm(p, proj);
}

double distanceToRouteKm(LatLng p, List<LatLng> poly, {int step = 10}) {
  if (poly.length < 2) return double.infinity;
  double minKm = double.infinity;
  for (int i = 0; i < poly.length - 1; i += step) {
    final a = poly[i];
    final b = poly[min(i + step, poly.length - 1)];
    final d = pointToSegmentDistanceKm(p, a, b);
    if (d < minKm) minKm = d;
  }
  return minKm;
}

/// Return subset of route based on animation parameter t ∈ [0,1]
List<LatLng> animatedRoutePoints(
  double t,
  List<LatLng> routePoints,
  List<double> routeCumKm,
) {
  if (routePoints.length < 2 || routeCumKm.isEmpty) return [];
  t = t.clamp(0, 1);
  final total = routeCumKm.last;
  final target = total * t;

  int idx = routeCumKm.indexWhere((v) => v >= target);
  if (idx <= 0) return [routePoints.first];
  if (idx == -1) return List<LatLng>.from(routePoints);

  final prevIdx = idx - 1;
  final d0 = routeCumKm[prevIdx];
  final d1 = routeCumKm[idx];
  final segLen = (d1 - d0).clamp(1e-9, double.infinity);
  final f = ((target - d0) / segLen).clamp(0.0, 1.0);

  final a = routePoints[prevIdx];
  final b = routePoints[idx];

  final interp = LatLng(
    a.latitude + (b.latitude - a.latitude) * f,
    a.longitude + (b.longitude - a.longitude) * f,
  );

  final out = routePoints.sublist(0, idx);
  out.add(interp);
  return out;
}

/// Generate simulated food-stop suggestions along route.
List<FoodSuggestion> generateSuggestionsAlongRoute(
  List<LatLng> routePoints,
  double? distanceKm,
) {
  final suggestions = <FoodSuggestion>[];
  if (routePoints.isEmpty || distanceKm == null) return suggestions;

  final anchors = <LatLng>[];
  final idx =
      [0.2, 0.4, 0.6, 0.8].map((t) => (t * (routePoints.length - 1)).round());
  for (final i in idx) {
    if (i >= 0 && i < routePoints.length) anchors.add(routePoints[i]);
  }

  final rnd = Random(42);
  final avgSpeed = avgSpeedKmphFor(distanceKm);

  for (int i = 0; i < anchors.length; i++) {
    final a = anchors[i];
    final pickup = offsetLatLng(
      a,
      km: 1 + rnd.nextDouble() * 3,
      bearingDeg: rnd.nextDouble() * 360,
    );
    final drop = offsetLatLng(
      pickup,
      km: 2 + rnd.nextDouble() * 10,
      bearingDeg: rnd.nextDouble() * 360,
    );

    final foodDistance = distKm(pickup, drop);
    final pickupDetour = distanceToRouteKm(pickup, routePoints, step: 10);
    final dropDetour = distanceToRouteKm(drop, routePoints, step: 10);

    final allowed = (foodDistance <= kMaxFoodDistanceKm) &&
        (pickupDetour <= kMaxDetourKm) &&
        (dropDetour <= kMaxDetourKm);

    final addedDistance = pickupDetour + dropDetour + foodDistance;
    final addedMinutes = estimateMinutes(addedDistance, avgSpeed);
    final savingsPct = 0.18 + rnd.nextDouble() * 0.10;

    suggestions.add(FoodSuggestion(
      id: i,
      label: "Local Delivery ${i + 1}",
      pickup: pickup,
      drop: drop,
      distanceKm: foodDistance,
      pickupDetourKm: pickupDetour,
      dropDetourKm: dropDetour,
      allowed: allowed,
      estAddedMinutes: addedMinutes,
      estSavingsPct: savingsPct,
    ));
  }

  return suggestions;
}

/// Models shared by map screen + dialogs + sheets.

class FoodSuggestion {
  final int id;
  final String label;
  final LatLng pickup;
  final LatLng drop;
  final double distanceKm;
  final double pickupDetourKm;
  final double dropDetourKm;
  final bool allowed;
  final double estAddedMinutes;
  final double estSavingsPct;

  FoodSuggestion({
    required this.id,
    required this.label,
    required this.pickup,
    required this.drop,
    required this.distanceKm,
    required this.pickupDetourKm,
    required this.dropDetourKm,
    required this.allowed,
    required this.estAddedMinutes,
    required this.estSavingsPct,
  });
}

class CabPref {
  final bool allow;
  final int maxStops;

  CabPref(this.allow, this.maxStops);
}

class Place {
  final String name;
  final double lat;
  final double lon;

  Place({
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class SelectedPoints {
  final LatLng pickup;
  final LatLng drop;
  final String pickupLabel;
  final String dropLabel;

  SelectedPoints({
    required this.pickup,
    required this.drop,
    required this.pickupLabel,
    required this.dropLabel,
  });
}
