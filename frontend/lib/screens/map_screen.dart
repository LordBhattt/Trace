// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/payment_service.dart';
import 'map_logic.dart';
import 'driver_simulation.dart';
import 'ride_summary_screen.dart';

/// TRACE Map screen: FULLY FIXED VERSION + Uber-like Trace-themed driver panel
class MapScreen extends StatefulWidget {
  final String serviceType; // "cab" or "food"
  const MapScreen({super.key, required this.serviceType});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  // Palette
  static const Color bg = Color(0xFF0C2C2E);
  static const Color gold = Color(0xFFD4AF37);
  static const Color champagne = Color(0xFFF4E4C1);
  static const Color royalBlue = Color(0xFF4DA6FF);
  static const Color royalGlow = Color(0xFFB3E0FF);

  final MapController _map = MapController();

  // selection
  LatLng? _pickup;
  LatLng? _drop;
  String? _pickupLabel;
  String? _dropLabel;

  // route
  List<LatLng> _routePoints = [];
  List<double> _routeCumKm = [];
  double? _distanceKm;
  int? _etaMin;
  bool _routing = false;
  String? _routeError;

  // driver live marker
  LatLng? _driverPos;
  final List<LatLng> _driverTrail = [];

  // driver / trip phase
  DriverSimulation? _driverSim;
  DriverPhase _driverPhase = DriverPhase.idle;
  int? _liveEtaMin;

  // ETA timer in seconds (more granular)
  int? _liveEtaSec;
  Timer? _etaTimer;

  // UI state
  String _distanceStatusText = "";

  // cab/food options
  bool _cabOptionsChosen = false;
  bool _allowFoodStops = false;
  int _maxAllowedStopsByRider = 0;
  bool _foodOptionsChosen = false;
  bool _foodTrySharedCab = false;

  // suggestions
  List<FoodSuggestion> _suggestions = [];
  final Set<int> _selectedSuggestions = {};

  // Payment / ride state
  bool _rideCompleted = false;
  bool _processingPayment = false;
  bool _isPaid = false;

  // fare from backend
  int _fareTotal = 0;
  int _fareBase = 0;
  int _fareDistance = 0;
  int _fareTime = 0;
  int _fareFoodStops = 0;

  Map<String, dynamic>? _rideObj;

  // ride meta stored locally
  String? _rideId;
  DateTime? _rideCreatedAt;
  String? _rideStatus; // 'pending'|'confirmed'|'assigned'|'started'|'completed'|'cancelled'|'paid'

  // animation for route reveal
  late final AnimationController _routeAnim;
  double get _t => _routeAnim.value;

  // cancel window: 3 minutes after confirmation
  static const Duration kCancelWindow = Duration(minutes: 3);

  // Driver panel management
  bool _driverSheetOpen = false;
  StateSetter? _driverSheetSetState; // captured setModalState of the driver panel

  @override
  void initState() {
    super.initState();
    _routeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _loadRideFromPrefs();
  }

  @override
  void dispose() {
    _routeAnim.dispose();
    _driverSim?.dispose();
    _stopEtaTimer();
    // ❌ no PaymentService.dispose(), we create/destroy inside openCheckout
    super.dispose();
  }

  // Load persisted ride info
  Future<void> _loadRideFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('current_ride_id');
    final created = prefs.getString('current_ride_created_at');
    final status = prefs.getString('current_ride_status');

    DateTime? dt;
    try {
      if (created != null) dt = DateTime.parse(created);
    } catch (_) {
      dt = null;
    }

    setState(() {
      _rideId = id;
      _rideCreatedAt = dt;
      _rideStatus = status;
      _rideCompleted = status == 'completed' || status == 'paid';
      _isPaid = status == 'paid';
    });
  }

  // ---------------- ETA timer helpers ----------------
  void _startEtaTimer({required int initialSeconds}) {
    _stopEtaTimer();
    _liveEtaSec = initialSeconds;
    // set an initial _liveEtaMin for backwards compatibility
    _liveEtaMin = (_liveEtaSec! + 59) ~/ 60;

    _etaTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        _stopEtaTimer();
        return;
      }
      if (_liveEtaSec == null) return;
      if (_liveEtaSec! > 0) {
        setState(() {
          _liveEtaSec = _liveEtaSec! - 1;
          _liveEtaMin = (_liveEtaSec! + 59) ~/ 60;
        });
        // propagate update to driver panel if open
        _driverSheetSetState?.call(() {});
      } else {
        // reached zero — stop but keep showing 0
        _stopEtaTimer();
        setState(() {
          _liveEtaMin = 0;
        });
        _driverSheetSetState?.call(() {});
      }
    });
  }

  void _stopEtaTimer() {
    try {
      _etaTimer?.cancel();
    } catch (_) {}
    _etaTimer = null;
  }

  // Compute display ETA minutes (prefer second-accurate live ETA if available)
  int get _displayEtaMinutes {
    if (_liveEtaSec != null) {
      return (_liveEtaSec! + 59) ~/ 60;
    }
    if (_liveEtaMin != null) return _liveEtaMin!;
    if (_etaMin != null) return _etaMin!;
    return 0;
  }

  // ---------------- PAYMENT: CAB RIDE ----------------
  Future<void> _handlePayment() async {
    if (_rideId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active ride to pay for.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _processingPayment = true);

    try {
      // 1) Get Razorpay key
      final key = await ApiService.getRazorpayKey();
      if (key == null || key.isEmpty) {
        throw Exception('Unable to fetch Razorpay key');
      }

      // 2) Create payment order (backend decides amount)
      final orderResp = await ApiService.createPaymentOrder(_rideId!);
      if (orderResp['success'] != true || orderResp['orderId'] == null) {
        throw Exception(orderResp['message'] ?? 'Order creation failed');
      }

      final String razorpayOrderId = orderResp['orderId'];
      final int serverAmount = ((orderResp['amount'] ?? 0) as num).toInt(); // paise
      final String amountInRupees = (serverAmount ~/ 100).toString();

      // 3) Open Razorpay (matches PaymentService.openCheckout signature)
      final paymentRes = await PaymentService.openCheckout(
        key: key,
        amount: serverAmount,
        orderId: razorpayOrderId,
        name: 'TRACE Ride',
        description: 'Cab fare payment',
        amountInRupees: amountInRupees,
        rideId: _rideId!,
      );

      if (paymentRes['success'] != true) {
        throw Exception(paymentRes['message'] ?? 'Payment failed');
      }

      // 4) Verify payment with backend
      final verifyResp = await ApiService.verifyPayment(
        paymentId: paymentRes['paymentId'],
        orderId: razorpayOrderId,
        signature: paymentRes['signature'],
        rideId: _rideId!,
      );

      if (verifyResp['success'] != true) {
        throw Exception(verifyResp['message'] ?? 'Payment verification failed');
      }

      final ride = (verifyResp['ride'] ?? {}) as Map<String, dynamic>;

      // 5) Persist + update local state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_ride_status', 'paid');

      if (!mounted) return;

      setState(() {
        _processingPayment = false;
        _isPaid = true;
        _rideStatus = 'paid';
        _rideObj = ride;

        // Update fare fields from server
        final pricing = (ride['pricing'] ?? {}) as Map<String, dynamic>;
        int asInt(dynamic v) {
          if (v == null) return 0;
          if (v is num) return v.round();
          return int.tryParse(v.toString()) ?? 0;
        }

        _fareBase = asInt(pricing['baseFare']);
        _fareDistance = asInt(pricing['distanceFare']);
        _fareTime = asInt(pricing['timeFare']);
        _fareFoodStops = asInt(pricing['foodStopFare']);
        _fareTotal = asInt(pricing['totalFare']);
      });

      // Close driver sheet if open
      if (_driverSheetOpen) {
        try {
          Navigator.pop(context);
        } catch (_) {}
        _driverSheetOpen = false;
        _driverSheetSetState = null;
      }

      // Go to summary screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideSummaryScreen(ride: _rideObj ?? ride),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // 👇 rest of your MapScreen code continues below this, unchanged


  // ---------------- Driver simulation with proper phase sync and ETA timer ----------------
  void _startDriverSimulation() {
    if (_pickup == null || _routePoints.isEmpty || _etaMin == null) {
      return;
    }

    // If ride wasn't created on backend, do not start simulation.
    if (_rideId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride not created yet. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 🔥 FIX: Show "Searching for drivers" phase first
    setState(() {
      _driverPhase = DriverPhase.searchingDriver;
      // hide any previous driver marker/trail while searching
      _driverPos = null;
      _driverTrail.clear();
    });

    // Open driver panel if not already open
    if (!_driverSheetOpen) {
      _showDriverDetailsSheet();
    } else {
      // ensure panel updates
      _driverSheetSetState?.call(() {});
    }

    // Wait 3 seconds before actually assigning a driver (simulate driver search)
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      // double-check ride still active
      if (_rideId == null) {
        setState(() => _driverPhase = DriverPhase.idle);
        _driverSheetSetState?.call(() {});
        return;
      }

      // Create and start the simulation
      _driverSim?.dispose();
      _driverSim = DriverSimulation(
        onPhaseChanged: (phase) async {
          if (!mounted) return;

          setState(() {
            _driverPhase = phase;
          });

          // Update driver sheet if open
          _driverSheetSetState?.call(() {});

          // When a driver is assigned or arriving, set an ETA countdown (in seconds)
          if (phase == DriverPhase.driverAssigned || phase == DriverPhase.driverArriving) {
            final int initialSec = (_etaMin ?? 3) * 60;
            _startEtaTimer(initialSeconds: initialSec);

            // Persist assigned state
            if (_rideId != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('current_ride_status', 'assigned');
              setState(() => _rideStatus = 'assigned');
            }
          }

          // If driver starts trip, persist started status and ensure ETA timer remains (trip ETA)
          if (phase == DriverPhase.onTrip) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_ride_status', 'started');
            if (mounted) setState(() => _rideStatus = 'started');
            // keep ETA timer running (DriverSimulation may update live ETA via onPositionUpdate)
          }

          // 🔥 CRITICAL: Mark ride completed when destination reached
          if (phase == DriverPhase.reachedDestination) {
            // stop ETA timer and mark completed
            _stopEtaTimer();
            await _markRideCompleted();
            if (mounted) {
              setState(() {
                _rideCompleted = true;
                _liveEtaSec = 0;
                _liveEtaMin = 0;
              });
            }
            _driverSheetSetState?.call(() {});
          }

          // 🔥 Sync phase changes with backend
          if (_rideId != null) {
            String? backendStatus;
            switch (phase) {
              case DriverPhase.driverAssigned:
                backendStatus = 'assigned';
                break;
              case DriverPhase.driverArriving:
                backendStatus = 'arriving';
                break;
              case DriverPhase.driverAtPickup:
                backendStatus = 'atPickup';
                break;
              case DriverPhase.onTrip:
                backendStatus = 'started';
                break;
              case DriverPhase.reachedDestination:
                backendStatus = 'completed';
                break;
              default:
                break;
            }

            if (backendStatus != null) {
              try {
                await ApiService.updateRideStatus(_rideId!, backendStatus);
              } catch (e) {
                print('Error updating ride status: $e');
              }
            }
          }
        },
        onPositionUpdate: (pos, trail, liveEta) {
          if (!mounted) return;
          setState(() {
            // Only display driver marker when the phase is not searchingDriver
            _driverPos = pos;
            _driverTrail
              ..clear()
              ..addAll(trail);
            // liveEta from simulation is expected in minutes; convert to seconds
            if (liveEta != null) {
              _liveEtaSec = liveEta * 60;
              _liveEtaMin = (_liveEtaSec! + 59) ~/ 60;
              // restart timer with provided seconds
              _startEtaTimer(initialSeconds: _liveEtaSec!);
            }
          });
          _driverSheetSetState?.call(() {});
        },
      );

      // Immediately set assigned phase (DriverSimulation likely will call phases as well).
      if (mounted) {
        setState(() {
          _driverPhase = DriverPhase.driverAssigned;
        });
        _driverSheetSetState?.call(() {});
      }

      _driverSim!.start(
        pickup: _pickup!,
        routePoints: _routePoints,
        baseEtaMinutes: _etaMin ?? 10,
      );
    });
  }

  String _driverPhaseLabel() {
    switch (_driverPhase) {
      case DriverPhase.idle:
        return '';
      case DriverPhase.searchingDriver:
        return 'Searching for drivers near you…';
      case DriverPhase.driverAssigned:
        return 'Driver assigned • finalising details…';
      case DriverPhase.driverArriving:
        return 'Driver is on the way to pickup';
      case DriverPhase.driverAtPickup:
        return 'Driver has reached the pickup location';
      case DriverPhase.onTrip:
        final eta = _displayEtaMinutes;
        return eta != 0 ? 'On trip • ETA ~ $eta min' : 'On trip to destination';
      case DriverPhase.reachedDestination:
        return 'Destination reached • Trip completed';
    }
  }

  bool get _hasActiveDriverFlow =>
      _driverPhase != DriverPhase.idle &&
      _driverPhase != DriverPhase.reachedDestination &&
      _driverPhase != DriverPhase.searchingDriver;

  // ---------------- dialogs ----------------
  Future<void> _askCabOptions() async {
    if (_cabOptionsChosen) return;
    _cabOptionsChosen = true;

    final maxByDist = maxAllowedFoodStopsByDistance(_distanceKm);
    int tempStops = maxByDist.clamp(0, 2);

    final result = await showDialog<CabPref>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CabDialog(
        allowFoodStops: _allowFoodStops,
        maxByDistance: maxByDist,
        initialStops: tempStops,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _allowFoodStops = result.allow;
        _maxAllowedStopsByRider = result.maxStops;
      });

      if (_allowFoodStops) {
        _generateSuggestionsAlongRoute();
      } else {
        _suggestions.clear();
        _selectedSuggestions.clear();
      }
    }
  }

  Future<void> _askFoodOptions() async {
    if (_foodOptionsChosen) return;
    _foodOptionsChosen = true;

    if ((_distanceKm ?? 0) > kMaxFoodDistanceKm) {
      if (!mounted) return;
      setState(() {
        _routeError =
            "We keep food fresh — deliveries over ${kMaxFoodDistanceKm.toStringAsFixed(0)} km are not supported.";
        _distanceStatusText = _routeError!;
      });
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FoodDialog(),
    );

    if (result != null && mounted) {
      setState(() => _foodTrySharedCab = result);
    }
  }

  // ---------------- search sheet ----------------
  Future<void> _openSearchSheet() async {
    final res = await showModalBottomSheet<SelectedPoints>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SearchSheet(),
    );

    if (res != null && mounted) {
      _driverSim?.stop();
      _stopEtaTimer();
      setState(() {
        _pickup = res.pickup;
        _drop = res.drop;
        _pickupLabel = res.pickupLabel;
        _dropLabel = res.dropLabel;
        _routePoints = [];
        _routeCumKm = [];
        _distanceKm = null;
        _etaMin = null;
        _routing = false;
        _routeError = null;
        _distanceStatusText = "";
        _cabOptionsChosen = false;
        _allowFoodStops = false;
        _maxAllowedStopsByRider = 0;
        _foodOptionsChosen = false;
        _foodTrySharedCab = false;
        _suggestions = [];
        _selectedSuggestions.clear();
        _driverPos = null;
        _driverTrail.clear();
        _driverPhase = DriverPhase.idle;
        _liveEtaMin = null;
        _liveEtaSec = null;
        _rideCompleted = false;
        _processingPayment = false;
        _isPaid = false;
        _rideId = null;
        _rideStatus = null;
        _fareTotal = 0;
        _fareBase = 0;
        _fareDistance = 0;
        _fareTime = 0;
        _fareFoodStops = 0;
        _rideObj = null;
      });
      await _fetchRoute();
    }
  }

  // ---------------- fetch route via OSRM ----------------
  Future<void> _fetchRoute() async {
    if (_pickup == null || _drop == null) return;
    if (!mounted) return;

    setState(() {
      _routing = true;
      _routeError = null;
      _routePoints = [];
      _routeCumKm = [];
      _distanceKm = null;
      _etaMin = null;
      _suggestions = [];
      _selectedSuggestions.clear();
      _driverPos = null;
      _driverTrail.clear();
      _driverPhase = DriverPhase.idle;
      _liveEtaMin = null;
      _liveEtaSec = null;
    });

    try {
      final lon1 = _pickup!.longitude.toStringAsFixed(6);
      final lat1 = _pickup!.latitude.toStringAsFixed(6);
      final lon2 = _drop!.longitude.toStringAsFixed(6);
      final lat2 = _drop!.latitude.toStringAsFixed(6);

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson',
      );

      final resp = await http.get(
        url,
        headers: {'User-Agent': 'trace-app/1.0'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Routing request timed out');
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('Routing server error (${resp.statusCode})');
      }

      final data = jsonDecode(resp.body);
      if (data['code'] != 'Ok' ||
          data['routes'] == null ||
          (data['routes'] as List).isEmpty) {
        throw Exception('No road route found');
      }

      final route = data['routes'][0];
      final distanceMeters = (route['distance'] ?? 0).toDouble();
      final durationSeconds = (route['duration'] ?? 0).toDouble();
      final coords = (route['geometry']['coordinates'] as List);

      final pts = <LatLng>[
        for (final c in coords)
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];

      // cumulative distances
      final cum = <double>[0.0];
      final dist = Distance();
      for (int i = 1; i < pts.length; i++) {
        final seg = dist.as(LengthUnit.Kilometer, pts[i - 1], pts[i]);
        cum.add(cum.last + seg);
      }

      if (!mounted) return;

      setState(() {
        _routePoints = pts;
        _routeCumKm = cum;
        _distanceKm = distanceMeters / 1000.0;
        _etaMin = (durationSeconds / 60.0).round();
      });

      // center map on route
      try {
        final bounds = LatLngBounds(pts.first, pts.first);
        for (final p in pts) {
          bounds.extend(p);
        }
        final center = LatLng((bounds.south + bounds.north) / 2,
            (bounds.west + bounds.east) / 2);
        _map.move(center, 11.0);
      } catch (_) {
        try {
          _map.move(pts[0], 11.0);
        } catch (_) {}
      }

      final d = (_distanceKm ?? 0);
      final ms = (900 + (d * 25).clamp(0, 2600)).round();
      _routeAnim.duration = Duration(milliseconds: ms);
      _routeAnim.forward(from: 0);
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError = "Request timed out. Please check your internet connection.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routeError = "No road route is possible between these locations.";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _routing = false;
        _distanceStatusText =
            statusFromDistance(_pickup, _drop, _distanceKm, _routeError);
      });

      if (_routeError == null) {
        if (widget.serviceType == 'cab') {
          await _askCabOptions();
          if (_allowFoodStops) _generateSuggestionsAlongRoute();
        } else {
          await _askFoodOptions();
        }
      }
    }
  }

  // ---------------- suggestions generation ----------------
  void _generateSuggestionsAlongRoute() {
    _selectedSuggestions.clear();
    if (!_allowFoodStops) return;
    if (_routePoints.isEmpty || _distanceKm == null) return;

    _suggestions = generateSuggestionsAlongRoute(_routePoints, _distanceKm);
    if (mounted) setState(() {});
  }

  // ---------------- Backend integration helpers ----------------
  Future<void> _createRideBackend() async {
    if (_pickup == null ||
        _drop == null ||
        _distanceKm == null ||
        _etaMin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing route details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final foodStops = _selectedSuggestions.length;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final resp = await ApiService.createRide(
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropLat: _drop!.latitude,
        dropLng: _drop!.longitude,
        distanceKm: _distanceKm!,
        etaMin: _etaMin!,
        foodStops: foodStops,
      );

      try {
        Navigator.pop(context);
      } catch (_) {}

      if (resp['success'] == true && resp['ride'] != null) {
        final ride = resp['ride'] as Map<String, dynamic>;
        final rideId = ride['_id'] ?? ride['id'] ?? resp['rideId'];

        if (rideId != null) {
          final prefs = await SharedPreferences.getInstance();
          final nowIso = DateTime.now().toIso8601String();
          await prefs.setString('current_ride_id', rideId.toString());
          await prefs.setString('current_ride_created_at', nowIso);
          await prefs.setString('current_ride_status', 'confirmed');

          int asInt(dynamic v) {
            if (v == null) return 0;
            if (v is num) return v.round();
            return int.tryParse(v.toString()) ?? 0;
          }

          final pricing = (ride['pricing'] ?? {}) as Map<String, dynamic>;

          setState(() {
            _rideId = rideId.toString();
            _rideCreatedAt = DateTime.parse(nowIso);
            _rideStatus = 'confirmed';
            _rideObj = ride;
            _fareBase = asInt(pricing['baseFare']);
            _fareDistance = asInt(pricing['distanceFare']);
            _fareTime = asInt(pricing['timeFare']);
            _fareFoodStops = asInt(pricing['foodStopFare']);
            _fareTotal = asInt(pricing['totalFare']);
          });
        }
      } else {
        final message = resp['message'] ?? 'Failed to create ride';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      try {
        Navigator.pop(context);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create ride error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 FIX #3: Enhanced cancel logic checking "started" status
  bool _canCancelNow() {
    if (_rideId == null) return false;

    // 🔥 Cannot cancel if ride started, completed, or paid
    if (_rideCompleted ||
        _isPaid ||
        (_rideStatus != null &&
            ['started', 'completed', 'paid'].contains(_rideStatus))) {
      return false;
    }

    // 🔥 Cannot cancel after 3 minutes
    if (_rideCreatedAt != null) {
      final diff = DateTime.now().difference(_rideCreatedAt!);
      if (diff > kCancelWindow) return false;
    }

    return true;
  }

  Future<void> _cancelRideBackend({bool showMessages = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rideId = prefs.getString('current_ride_id');

      if (rideId == null) {
        if (showMessages && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active ride to cancel'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!_canCancelNow()) {
        String reason = 'Cannot cancel this ride.';
        if (_rideCompleted ||
            _isPaid ||
            (_rideStatus != null &&
                ['completed', 'paid', 'started'].contains(_rideStatus))) {
          reason = 'Ride already started/completed/paid — cancellation not allowed.';
        } else if (_rideCreatedAt != null &&
            DateTime.now().difference(_rideCreatedAt!) > kCancelWindow) {
          reason = 'Cancellation window of 3 minutes has passed.';
        }

        if (showMessages && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(reason), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final resp = await ApiService.cancelRide(rideId);

      try {
        Navigator.pop(context);
      } catch (_) {}

      if (resp['success'] == true) {
        await prefs.remove('current_ride_id');
        await prefs.remove('current_ride_created_at');
        await prefs.remove('current_ride_status');

        if (!mounted) return;

        _stopEtaTimer();
        setState(() {
          _rideId = null;
          _rideCreatedAt = null;
          _rideStatus = null;
          _rideCompleted = false;
          _isPaid = false;
          _driverPhase = DriverPhase.idle;
          _driverPos = null;
          _driverTrail.clear();
          _fareTotal = 0;
          _fareBase = 0;
          _fareDistance = 0;
          _fareTime = 0;
          _fareFoodStops = 0;
          _rideObj = null;
          _liveEtaSec = null;
          _liveEtaMin = null;
        });

        // close driver panel if open
        if (_driverSheetOpen) {
          try {
            Navigator.pop(context);
          } catch (_) {}
          _driverSheetOpen = false;
          _driverSheetSetState = null;
        }

        if (showMessages && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride cancelled'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final msg = resp['message'] ?? 'Cancel failed';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      try {
        Navigator.pop(context);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancel error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🔥 FIX #4: Mark ride completed with backend call
  Future<void> _markRideCompleted() async {
    if (_rideId == null) return;

    try {
      // 🔥 Call backend to mark completed
      final resp = await ApiService.completeRide(_rideId!);

      if (resp['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_ride_status', 'completed');

        if (!mounted) return;

        setState(() {
          _rideCompleted = true;
          _rideStatus = 'completed';
        });

        _driverSheetSetState?.call(() {});
      }
    } catch (e) {
      print('Error marking ride completed: $e');
      // Still update UI even if backend call fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_ride_status', 'completed');

      if (!mounted) return;

      setState(() {
        _rideCompleted = true;
        _rideStatus = 'completed';
      });

      _driverSheetSetState?.call(() {});
    }
  }

  // ---------------- UI rendering ----------------
  @override
  Widget build(BuildContext context) {
    final displayedRoute = animatedRoutePoints(_t, _routePoints, _routeCumKm);
    final trailPoints = _driverTrail.isNotEmpty ? List<LatLng>.from(_driverTrail) : <LatLng>[];

    // ETA display for bottom card
    final int etaDisplay = _displayEtaMinutes;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.serviceType == 'cab'
                  ? Icons.directions_car_rounded
                  : Icons.restaurant_rounded,
              color: gold,
            ),
            const SizedBox(width: 8),
            Text(
              widget.serviceType == 'cab' ? 'Book a Cab' : 'Order Food',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: champagne,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _openSearchSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1F2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: champagne, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (_pickupLabel == null && _dropLabel == null)
                            ? 'Set Pickup & Drop'
                            : '${_pickupLabel ?? 'Pickup'} → ${_dropLabel ?? 'Drop'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: const MapOptions(
                    initialCenter: LatLng(19.0760, 72.8777),
                    initialZoom: 11.2,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.trace.app',
                    ),
                    if (displayedRoute.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: displayedRoute,
                            strokeWidth: 6,
                            color: royalBlue,
                            borderStrokeWidth: 3,
                            borderColor: royalGlow,
                          ),
                        ],
                      ),
                    if (trailPoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: trailPoints,
                            strokeWidth: 8,
                            color: gold.withOpacity(0.55),
                            borderStrokeWidth: 0,
                          ),
                          Polyline(
                            points: trailPoints,
                            strokeWidth: 3,
                            color: Colors.white.withOpacity(0.85),
                            borderStrokeWidth: 0,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_pickup != null)
                          Marker(
                            point: _pickup!,
                            width: 48,
                            height: 48,
                            child: _marker(Icons.location_on, Colors.amber),
                          ),
                        if (_drop != null)
                          Marker(
                            point: _drop!,
                            width: 48,
                            height: 48,
                            child: _marker(Icons.flag_rounded, Colors.greenAccent),
                          ),
                        // Show driver marker only when we are not in "searchingDriver" phase.
                        if (_driverPos != null && _driverPhase != DriverPhase.searchingDriver)
                          Marker(
                            point: _driverPos!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 12,
                  child: _routing
                      ? _badge(
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Routing…',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        )
                      : (_routeError != null
                          ? _badge(
                              color: Colors.red.shade700,
                              child: Text(
                                _routeError!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _bottomCard(context, etaDisplay),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _marker(IconData icon, Color color) => Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.28),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 26),
      );

  Widget _badge({required Widget child, Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.black87),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.35)),
        ),
        child: child,
      );

  Widget _bottomCard(BuildContext context, int etaDisplay) {
    final hasRoute = _routePoints.isNotEmpty && _routeError == null;
    final canShowSuggestions =
        hasRoute && widget.serviceType == 'cab' && _allowFoodStops;
    final selectedCount = _selectedSuggestions.length;
    final riderMax = _maxAllowedStopsByRider;
    final maxByDist = maxAllowedFoodStopsByDistance(_distanceKm);
    final hardMax = riderMax == 0 ? maxByDist : riderMax.clamp(0, maxByDist);

    final foodModeSmart = widget.serviceType == 'food' && _foodTrySharedCab;
    double estSavingsPct = 0;
    if (foodModeSmart && (_distanceKm ?? 0) > 0) {
      estSavingsPct = 0.2;
    }

    final driverLabel = _driverPhaseLabel();

    // Disable confirm if ride is already created or in progress/completed
    final confirmDisabled = (_rideId != null &&
        (_rideStatus == 'started' ||
            _rideStatus == 'completed' ||
            _rideStatus == 'paid'));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1929), Color(0xFF162447)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: gold.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoRow(Icons.location_on_outlined, _pickupLabel ?? 'Choose pickup'),
          const SizedBox(height: 8),
          _infoRow(Icons.flag_outlined, _dropLabel ?? 'Choose drop'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.straighten, color: champagne, size: 18),
              const SizedBox(width: 6),
              Text(
                (hasRoute && _distanceKm != null)
                    ? '${_distanceKm!.toStringAsFixed(1)} km'
                    : '— km',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, color: champagne, size: 18),
              const SizedBox(width: 6),
              Text(
                (hasRoute)
                    ? '$etaDisplay min'
                    : '— min',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _distanceStatusText,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (driverLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    driverLabel,
                    style: TextStyle(
                      color: _hasActiveDriverFlow
                          ? Colors.greenAccent
                          : Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.serviceType == 'food' && _routeError == null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _foodTrySharedCab ? Icons.local_taxi : Icons.delivery_dining,
                  color: champagne,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _foodTrySharedCab
                        ? "Trying shared cab delivery • est. save ~${(estSavingsPct * 100).round()}%"
                        : "Normal delivery selected (fastest)",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
          if (canShowSuggestions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSuggestionsSheet,
                    icon: const Icon(Icons.dataset_outlined),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: gold.withOpacity(0.45)),
                      foregroundColor: champagne,
                    ),
                    label: Text(
                      selectedCount > 0
                          ? 'Suggestions along route • $selectedCount selected (max $hardMax)'
                          : 'Suggestions along route (max $hardMax)',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_pickup != null && _drop != null && _routeError == null && !confirmDisabled)
                  ? () async {
                      String msg;
                      if (widget.serviceType == 'cab') {
                        final chosen = _suggestions
                            .where((s) => _selectedSuggestions.contains(s.id))
                            .toList();
                        final totalAdded = chosen.fold<double>(
                            0.0, (sum, s) => sum + s.estAddedMinutes);

                        if (_allowFoodStops && chosen.isNotEmpty) {
                          msg =
                              'Ride confirmed • ${chosen.length} stop(s) • est. +${totalAdded.toStringAsFixed(0)} min';
                        } else if (_allowFoodStops) {
                          msg =
                              'Ride confirmed • food stops allowed (none selected yet)';
                        } else {
                          msg = 'Ride confirmed (no food stops)';
                        }

                        // Create ride on backend and only proceed when successful
                        await _createRideBackend();

                        // check ride created - if not, abort
                        if (_rideId == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ride creation failed.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        _startDriverSimulation();
                      } else {
                        msg = _foodTrySharedCab
                            ? 'Food order placed • shared cab mode (if available)'
                            : 'Food order placed • normal delivery';
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: gold,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                disabledBackgroundColor: Colors.white24,
                foregroundColor: bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Driver panel that updates in-place (AnimatedSwitcher + AnimatedSize)
  void _showDriverDetailsSheet() {
    if (_driverSheetOpen) {
      // already open - just force update
      _driverSheetSetState?.call(() {});
      return;
    }

    _driverSheetOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          // store setState so outer changes can update modal content
          _driverSheetSetState = setModalState;

          // ensure we clear flags when modal closes
          return WillPopScope(
            onWillPop: () async {
              _driverSheetOpen = false;
              _driverSheetSetState = null;
              return true;
            },
            child: SafeArea(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  // height varies by phase; AnimatedSize animates it
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0C2C2E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildDriverPanelContent(setModalState),
                  ),
                ),
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      // cleanup
      _driverSheetOpen = false;
      _driverSheetSetState = null;
    });
  }

  // Build the content depending on current driver phase. Use AnimatedSwitcher for smooth content transitions.
  Widget _buildDriverPanelContent(StateSetter setModalState) {
    // disable cancel if completed/paid/started
    final completed = _rideCompleted || _driverPhase == DriverPhase.reachedDestination;
    final canCancel = _canCancelNow() && !completed;

    final etaToShow = _displayEtaMinutes;
    final int fare = _fareTotal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // top handle
        Container(width: 46, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _panelHeaderForPhase(keyForPhase(_driverPhase)),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _panelBodyForPhase(_driverPhase, etaToShow, fare, canCancel),
        ),
      ],
    );
  }

  // small header widget (changes with phase)
  Widget _panelHeaderForPhase(Key key) {
    String title;
    IconData icon;
    Color iconColor = royalBlue;

    switch (_driverPhase) {
      case DriverPhase.searchingDriver:
        title = 'Searching nearby drivers';
        icon = Icons.search;
        iconColor = royalBlue;
        break;
      case DriverPhase.driverAssigned:
        title = 'Driver assigned';
        icon = Icons.verified;
        iconColor = gold;
        break;
      case DriverPhase.driverArriving:
        title = 'Driver is arriving';
        icon = Icons.directions_car;
        iconColor = royalBlue;
        break;
      case DriverPhase.driverAtPickup:
        title = 'Driver at pickup';
        icon = Icons.place;
        iconColor = Colors.greenAccent;
        break;
      case DriverPhase.onTrip:
        title = 'On trip';
        icon = Icons.navigation;
        iconColor = Colors.greenAccent;
        break;
      case DriverPhase.reachedDestination:
        title = 'Trip completed';
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      default:
        title = 'Driver';
        icon = Icons.person;
    }

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  _driverPhaseLabel(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // small ETA badge
          if (_driverPhase != DriverPhase.searchingDriver && (_displayEtaMinutes > 0 || _liveEtaSec != null))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Text('$_displayEtaMinutes min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const Text('ETA', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Key keyForPhase(DriverPhase p) => ValueKey<int>(p.index);

  // panel body based on phase
  Widget _panelBodyForPhase(DriverPhase phase, int etaToShow, int fare, bool canCancel) {
    // Searching: minimal compact view with animated dots
    if (phase == DriverPhase.searchingDriver) {
      return Container(
        key: const ValueKey('searching'),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 6),
            const Text('We’re looking for the best Trace drivers nearby...', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Searching…', style: TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                // allow user to cancel during searching if within cancel window
                if (canCancel) {
                  _cancelRideBackend();
                  try {
                    Navigator.pop(context);
                  } catch (_) {}
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot cancel at this moment.'), backgroundColor: Colors.red));
                }
              },
              style: TextButton.styleFrom(foregroundColor: champagne),
              child: const Text('Cancel ride'),
            ),
          ],
        ),
      );
    }

    // For assigned / arriving / atPickup / onTrip / completed show driver card & actions
    // Shared driver info (use fake driver details like before; later plug actual backend data)
    final driverWidget = Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white12,
          backgroundImage: const NetworkImage('https://i.pravatar.cc/150?img=12'),
          onBackgroundImageError: (_, __) {},
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rajesh Kumar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: const [
              Icon(Icons.star, color: Colors.amber, size: 16),
              SizedBox(width: 6),
              Text('4.8 • Toyota Camry', style: TextStyle(color: Colors.white70)),
            ])
          ]),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.phone),
          color: champagne,
          style: IconButton.styleFrom(backgroundColor: Colors.white12),
        ),
      ],
    );

    // Build the dynamic body
    switch (phase) {
      case DriverPhase.driverAssigned:
        return Container(
          key: const ValueKey('assigned'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              driverWidget,
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF14242F), borderRadius: BorderRadius.circular(10), border: Border.all(color: gold.withOpacity(0.2))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Arriving in', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text('$etaToShow min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                    ElevatedButton(
                      onPressed: () {
                        // Quick contact or help — placeholder
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: bg),
                      child: const Text('Contact'),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canCancel
                          ? () async {
                              await _cancelRideBackend();
                              if (!mounted) return;
                              try {
                                Navigator.pop(context);
                              } catch (_) {}
                            }
                          : null,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), foregroundColor: Colors.redAccent),
                      child: const Text('Cancel ride'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );

      case DriverPhase.driverArriving:
      case DriverPhase.driverAtPickup:
        return Container(
          key: ValueKey(phase == DriverPhase.driverArriving ? 'arriving' : 'atpickup'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              driverWidget,
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: royalBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: royalBlue.withOpacity(0.12))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(phase == DriverPhase.driverArriving ? 'Driver arriving' : 'Driver at pickup', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text('$etaToShow min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: bg),
                      child: const Text('Share ETA'),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canCancel
                        ? () async {
                            await _cancelRideBackend();
                            if (!mounted) return;
                            try {
                              Navigator.pop(context);
                            } catch (_) {}
                          }
                        : null,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), foregroundColor: Colors.redAccent),
                    child: const Text('Cancel ride'),
                  ),
                ),
              ]),
            ],
          ),
        );

      case DriverPhase.onTrip:
        return Container(
          key: const ValueKey('ontrip'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              driverWidget,
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.14))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('En route to destination', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text('$etaToShow min • keep seatbelt on', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                    ElevatedButton(
                      onPressed: () {
                        // Report / help
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: bg),
                      child: const Text('Help'),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // no cancel during trip
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12), foregroundColor: Colors.white70),
                    child: const Text('Cancellation disabled'),
                  ),
                ),
              ]),
            ],
          ),
        );

      case DriverPhase.reachedDestination:
        return Container(
          key: const ValueKey('completed'),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              driverWidget,
              const SizedBox(height: 12),
              // Fare breakdown + Pay button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF14242F), borderRadius: BorderRadius.circular(10), border: Border.all(color: gold.withOpacity(0.2))),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Base Fare', style: TextStyle(color: Colors.white70)), Text('₹$_fareBase', style: const TextStyle(color: Colors.white70))]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Distance Fare', style: TextStyle(color: Colors.white70)), Text('₹$_fareDistance', style: const TextStyle(color: Colors.white70))]),
                    if (_fareTime > 0) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Time Fare', style: TextStyle(color: Colors.white70)), Text('₹$_fareTime', style: const TextStyle(color: Colors.white70))]),
                    ],
                    if (_fareFoodStops > 0) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Food stops', style: TextStyle(color: Colors.white70)), Text('₹$_fareFoodStops', style: const TextStyle(color: Colors.white70))]),
                    ],
                    const Divider(color: Colors.white24, height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Fare', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), Text('₹$fare', style: const TextStyle(color: gold, fontWeight: FontWeight.w700))]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_processingPayment || _isPaid)
                      ? null
                      : () async {
                          await _handlePayment();
                          _driverSheetSetState?.call(() {});
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: _isPaid ? Colors.green : gold, foregroundColor: bg, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _processingPayment
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isPaid ? 'Paid' : 'Pay ₹$fare', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              // allow remove ride or close panel
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      try {
                        Navigator.pop(context);
                      } catch (_) {}
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white12), foregroundColor: Colors.white70),
                    child: const Text('Close'),
                  ),
                ),
              ]),
            ],
          ),
        );

      default:
        return Container(key: const ValueKey('default'), padding: const EdgeInsets.symmetric(vertical: 12), child: const SizedBox.shrink());
    }
  }

  Widget _infoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, color: champagne, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ),
        ],
      );

  void _showSuggestionsSheet() {
    final maxByDist = maxAllowedFoodStopsByDistance(_distanceKm);
    final hardMax = _maxAllowedStopsByRider == 0
        ? maxByDist
        : _maxAllowedStopsByRider.clamp(0, maxByDist);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFF0C2C2E),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: champagne,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local deliveries you may allow on this ride',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Rules: ≤ ${kMaxFoodDistanceKm.toStringAsFixed(0)} km • Detour ≤ ${kMaxDetourKm.toStringAsFixed(0)} km • Max $hardMax stops',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _suggestions.isEmpty
                            ? const Center(
                                child: Text(
                                  'No suggestions for this route.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _suggestions.length,
                                separatorBuilder: (_, __) => const Divider(
                                  color: Colors.white12,
                                  height: 1,
                                ),
                                itemBuilder: (_, i) {
                                  final s = _suggestions[i];
                                  final selected =
                                      _selectedSuggestions.contains(s.id);
                                  final disabled = !s.allowed ||
                                      (!selected &&
                                          _selectedSuggestions.length >= hardMax);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            s.label,
                                            style: TextStyle(
                                              color: s.allowed
                                                  ? Colors.white
                                                  : Colors.white38,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (!s.allowed)
                                          const Text(
                                            'Not allowed',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Delivery: ${s.distanceKm.toStringAsFixed(1)} km • Detour: +${s.pickupDetourKm.toStringAsFixed(1)} / +${s.dropDetourKm.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Est. extra time: ~${s.estAddedMinutes.toStringAsFixed(0)} min • Est. save: ~${(s.estSavingsPct * 100).round()}%',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Switch(
                                      value: selected,
                                      activeThumbColor: gold,
                                      onChanged: disabled
                                          ? null
                                          : (v) {
                                              setState(() {
                                                if (v) {
                                                  _selectedSuggestions.add(s.id);
                                                } else {
                                                  _selectedSuggestions
                                                      .remove(s.id);
                                                }
                                              });
                                              setModalState(() {});
                                            },
                                    ),
                                    onTap: disabled
                                        ? null
                                        : () {
                                            setState(() {
                                              if (selected) {
                                                _selectedSuggestions.remove(s.id);
                                              } else if (_selectedSuggestions
                                                      .length <
                                                  hardMax) {
                                                _selectedSuggestions.add(s.id);
                                              }
                                            });
                                            setModalState(() {});
                                          },
                                  );
                                },
                              ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: bg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ===== Dialog widgets & helpers =====
class CabDialog extends StatefulWidget {
  final bool allowFoodStops;
  final int maxByDistance;
  final int initialStops;

  const CabDialog({
    super.key,
    required this.allowFoodStops,
    required this.maxByDistance,
    required this.initialStops,
  });

  @override
  State<CabDialog> createState() => _CabDialogState();
}

class _CabDialogState extends State<CabDialog> {
  bool _allow = false;
  late int _stops;

  @override
  void initState() {
    super.initState();
    _allow = widget.allowFoodStops;
    _stops = widget.initialStops;
  }

  @override
  Widget build(BuildContext context) {
    final hardMax = maxAllowedFoodStopsByDistance(null)
        .clamp(0, widget.maxByDistance);

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1F2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        "Ride preferences",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Allow your driver to accept local food deliveries along the route?",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _allow,
            onChanged: (v) => setState(() => _allow = v),
            activeColor: _MapScreenState.gold,
            title: const Text(
              "Allow food stops",
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Opacity(
            opacity: _allow ? 1 : 0.4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Max deliveries (0–$hardMax)",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: _allow && _stops > 0
                          ? () => setState(() => _stops--)
                          : null,
                      icon: const Icon(Icons.remove_circle),
                      color: _MapScreenState.gold,
                    ),
                    Text(
                      "$_stops",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    IconButton(
                      onPressed: _allow && _stops < hardMax
                          ? () => setState(() => _stops++)
                          : null,
                      icon: const Icon(Icons.add_circle),
                      color: _MapScreenState.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Detour per delivery ≤ 7 km • Delivery distance ≤ 30 km • Same city only",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, CabPref(false, 0)),
          child: const Text(
            "No, normal ride",
            style: TextStyle(
              color: _MapScreenState.champagne,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _MapScreenState.gold,
            foregroundColor: _MapScreenState.bg,
          ),
          onPressed: () => Navigator.pop(context, CabPref(_allow, _stops)),
          child: const Text("Continue"),
        ),
      ],
    );
  }
}

class FoodDialog extends StatelessWidget {
  const FoodDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1F2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        "Delivery preference",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: const Text(
        "Choose how you want your food delivered:",
        style: TextStyle(color: Colors.white70),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            "Normal (fastest)",
            style: TextStyle(
              color: _MapScreenState.champagne,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _MapScreenState.gold,
            foregroundColor: _MapScreenState.bg,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Try shared cab (save if available)"),
        ),
      ],
    );
  }
}

// ===== Search sheet =====
class SearchSheet extends StatefulWidget {
  const SearchSheet({super.key});

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();
  bool _selectingPickup = true;
  List<Place> _results = [];
  LatLng? _p1;
  LatLng? _p2;

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _results = []);
      return;
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$q&format=jsonv2&limit=8',
      );

      final res = await http.get(
        url,
        headers: {
          'User-Agent': 'trace-app/1.0 (search@traceapp.dev)',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Search timed out');
        },
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (!mounted) return;

        setState(() {
          _results = data
              .map(
                (e) => Place(
                  name: e['display_name'] ?? '',
                  lat: double.tryParse(e['lat'] ?? '') ?? 0,
                  lon: double.tryParse(e['lon'] ?? '') ?? 0,
                ),
              )
              .toList();
        });
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = []);
    }
  }

  void _choose(Place p) {
    if (_selectingPickup) {
      _p1 = LatLng(p.lat, p.lon);
      _pickupCtrl.text = p.name;
      _selectingPickup = false;
    } else {
      _p2 = LatLng(p.lat, p.lon);
      _dropCtrl.text = p.name;
    }

    if (!mounted) return;
    setState(() => _results = []);
  }

  bool get _ready => _p1 != null && _p2 != null;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.92;

    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Color(0xFF0C2C2E),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              _field(
                label: 'Pickup',
                controller: _pickupCtrl,
                active: _selectingPickup,
                onTap: () => setState(() => _selectingPickup = true),
                onChanged: _search,
              ),
              const SizedBox(height: 12),
              _field(
                label: 'Drop',
                controller: _dropCtrl,
                active: !_selectingPickup,
                onTap: () => setState(() => _selectingPickup = false),
                onChanged: _search,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _selectingPickup
                              ? 'Search pickup location'
                              : 'Search drop location',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Colors.white12,
                          height: 1,
                        ),
                        itemBuilder: (_, i) {
                          final s = _results[i];
                          return ListTile(
                            onTap: () => _choose(s),
                            leading: Icon(
                              _selectingPickup
                                  ? Icons.location_on
                                  : Icons.flag_rounded,
                              color: Colors.amber.shade300,
                            ),
                            title: Text(
                              s.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready
                      ? () => Navigator.pop(
                            context,
                            SelectedPoints(
                              pickup: _p1!,
                              drop: _p2!,
                              pickupLabel: _pickupCtrl.text,
                              dropLabel: _dropCtrl.text,
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade400,
                    disabledBackgroundColor: Colors.white24,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Use these locations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool active,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.amber : Colors.white24,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              label == 'Pickup' ? Icons.location_on : Icons.flag_rounded,
              color: active ? Colors.amber : Colors.white60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search $label',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper classes
class Place {
  final String name;
  final double lat;
  final double lon;

  Place({required this.name, required this.lat, required this.lon});
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

class CabPref {
  final bool allow;
  final int maxStops;

  CabPref(this.allow, this.maxStops);
}
