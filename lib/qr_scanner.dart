import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'enter_room_page.dart';
import 'home_page.dart'; // make sure this file exists

// Simple Madgwick AHRS implementation (adapted for Dart)
class MadgwickAHRS {
  double beta; // algorithm gain
  List<double> quaternion = [1.0, 0.0, 0.0, 0.0];

  MadgwickAHRS({this.beta = 0.1});

  // Full Madgwick update. gx,gy,gz in rad/s, ax,ay,az in any unit (will be normalized),
  // mx,my,mz in any unit (will be normalized). dt in seconds.
  void update(double gx, double gy, double gz, double ax, double ay, double az, double mx, double my, double mz, double dt) {
    // Based on the original implementation by Sebastian Madgwick
    double q1 = quaternion[0];
    double q2 = quaternion[1];
    double q3 = quaternion[2];
    double q4 = quaternion[3];

    // Normalize accelerometer measurement
    double norm = math.sqrt(ax * ax + ay * ay + az * az);
    if (norm == 0.0) return; // handle NaN
    ax /= norm;
    ay /= norm;
    az /= norm;

    // Normalize magnetometer measurement
    norm = math.sqrt(mx * mx + my * my + mz * mz);
    if (norm == 0.0) return;
    mx /= norm;
    my /= norm;
    mz /= norm;

    // Reference direction of Earth's magnetic field
  final hx = mx * (q1 * q1 - q2 * q2 - q3 * q3 + q4 * q4) + 2.0 * my * (q1 * q4 + q2 * q3) + 2.0 * mz * (q2 * q4 - q1 * q3);
  final hy = 2.0 * mx * (q2 * q3 - q1 * q4) + my * (q1 * q1 + q2 * q2 - q3 * q3 - q4 * q4) + 2.0 * mz * (q1 * q2 + q3 * q4);
  final twoBx = math.sqrt(hx * hx + hy * hy);
  final twoBz = -2.0 * mx * (q2 * q4 - q1 * q3) + 2.0 * my * (q1 * q2 + q3 * q4) + mz * (q1 * q1 - q2 * q2 + q3 * q3 - q4 * q4);

    // Gradient descent algorithm corrective step
  final s1 = (-2.0 * (q3 * (2.0 * q2 * q4 - 2.0 * q1 * q3 - ax) + q4 * (2.0 * q1 * q2 + 2.0 * q3 * q4 - ay)) + (-twoBz * q3 + twoBx * q4) * (2.0 * q2 * q3 - 2.0 * q1 * q4 - mx) + (-twoBx * q3 - twoBz * q4) * (2.0 * q1 * q3 + 2.0 * q2 * q4 - my) + twoBx * q2 * (2.0 * q1 * q2 - 2.0 * q3 * q4 - mz));
  final s2 = (2.0 * (q4 * (2.0 * q2 * q4 - 2.0 * q1 * q3 - ax) + q1 * (2.0 * q1 * q2 + 2.0 * q3 * q4 - ay)) + (-twoBz * q4 + twoBx * q1) * (2.0 * q2 * q3 - 2.0 * q1 * q4 - mx) + (twoBx * q4 + twoBz * q1) * (2.0 * q1 * q3 + 2.0 * q2 * q4 - my) + twoBx * q3 * (2.0 * q1 * q2 - 2.0 * q3 * q4 - mz));
  final s3 = (-2.0 * (q1 * (2.0 * q2 * q4 - 2.0 * q1 * q3 - ax) + q2 * (2.0 * q1 * q2 + 2.0 * q3 * q4 - ay)) + (-twoBz * q1 + twoBx * q2) * (2.0 * q2 * q3 - 2.0 * q1 * q4 - mx) + (-twoBx * q1 - twoBz * q2) * (2.0 * q1 * q3 + 2.0 * q2 * q4 - my) + twoBx * q4 * (2.0 * q1 * q2 - 2.0 * q3 * q4 - mz));
  final s4 = (2.0 * (q2 * (2.0 * q2 * q4 - 2.0 * q1 * q3 - ax) + q3 * (2.0 * q1 * q2 + 2.0 * q3 * q4 - ay)) + (-twoBz * q2 + twoBx * q3) * (2.0 * q2 * q3 - 2.0 * q1 * q4 - mx) + (twoBx * q2 + twoBz * q3) * (2.0 * q1 * q3 + 2.0 * q2 * q4 - my) + twoBx * q1 * (2.0 * q1 * q2 - 2.0 * q3 * q4 - mz));

    // normalize step magnitude
  final sNorm = math.sqrt(s1 * s1 + s2 * s2 + s3 * s3 + s4 * s4);
  if (sNorm == 0.0) return;
  final s1Norm = s1 / sNorm;
  final s2Norm = s2 / sNorm;
  final s3Norm = s3 / sNorm;
  final s4Norm = s4 / sNorm;

    // Rate of change of quaternion from gyroscope
  final qDot1 = 0.5 * (-q2 * gx - q3 * gy - q4 * gz) - beta * s1Norm;
  final qDot2 = 0.5 * (q1 * gx + q3 * gz - q4 * gy) - beta * s2Norm;
  final qDot3 = 0.5 * (q1 * gy - q2 * gz + q4 * gx) - beta * s3Norm;
  final qDot4 = 0.5 * (q1 * gz + q2 * gy - q3 * gx) - beta * s4Norm;

    // Integrate to yield quaternion
    q1 += qDot1 * dt;
    q2 += qDot2 * dt;
    q3 += qDot3 * dt;
    q4 += qDot4 * dt;
    // Normalize quaternion
    norm = math.sqrt(q1 * q1 + q2 * q2 + q3 * q3 + q4 * q4);
    q1 /= norm;
    q2 /= norm;
    q3 /= norm;
    q4 /= norm;

    quaternion[0] = q1;
    quaternion[1] = q2;
    quaternion[2] = q3;
    quaternion[3] = q4;
  }

  // convenience when only gyro and accel available (no mag)
  void updateIMU(double gx, double gy, double gz, double ax, double ay, double az, double dt) {
    // call update with zero magnetometer which will skip mag normalization
    update(gx, gy, gz, ax, ay, az, 0.0, 0.0, 0.0, dt);
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String scannedText = "Scan a QR Code";
  String guidance = "Align QR in the center";
  double heading = 0.0; // fused heading in degrees
  bool headingValid = false;
  // desired heading ranges (allow multiple ranges)
  // Each inner list is [minDegree, maxDegree]
  final List<List<double>> allowedHeadingRanges = [
    [100.0, 140.0],
    [280.0, 320.0],
  ];
  final FlutterTts flutterTts = FlutterTts();
  DateTime lastSpoken = DateTime.now();
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<dynamic>? _rotationSub;
  // simple complementary filter state
  double _fusedYaw = 0.0; // fused yaw (radians)
  // Madgwick AHRS instance
  final MadgwickAHRS _ahrs = MadgwickAHRS(beta: 0.1);
  bool _calibrating = false;
  final List<MagnetometerEvent> _magSamples = [];
  final List<GyroscopeEvent> _gyroSamples = [];
  final List<AccelerometerEvent> _accelSamples = [];
  // calibration values
  double _magBiasX = 0.0;
  double _magBiasY = 0.0;
  double _magBiasZ = 0.0;
  double _magScaleX = 1.0;
  double _magScaleY = 1.0;
  // full 3x3 soft-iron correction matrix (row-major)
  List<double> _magCorrection = [1, 0, 0, 0, 1, 0, 0, 0, 1];
  int _lastSensorTimestamp = 0; // microseconds
  // platform fused heading (from Android rotation-vector) when available
  bool _platformHeadingAvailable = false;
  double _platformHeading = 0.0;
  // Beep timer for out-of-range guidance
  Timer? _beepTimer; // ticker that checks whether to fire a beep
  int _beepIntervalMs = 600; // desired interval in ms (updated frequently)
  int _beepTickMs = 40; // ticker frequency in ms (smaller = more responsive)
  // configurable min/max beep interval (ms). Smaller min -> faster beeps when far.
  int _beepMinIntervalMs = 120; // was 200
  int _beepMaxIntervalMs = 700; // was 800
  // cap the distance used for mapping (degrees). Larger cap stretches mapping.
  double _beepDistanceCap = 60.0; // was 90.0
  DateTime _lastBeep = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _speak(String msg) async {
    if (DateTime.now().difference(lastSpoken).inSeconds >= 2) {
      lastSpoken = DateTime.now();
      await flutterTts.stop();
      await flutterTts.speak(msg);
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    final detected = capture.barcodes.firstOrNull;
    if (detected == null) return;

    final value = detected.rawValue;
    if (value == null) return;

    // Only allow processing when heading is within any required range
    if (!headingValid || !_isHeadingInRange(heading)) {
      setState(() {
        guidance = 'Point device to ${_rangesText()} to scan.';
      });
      _speak('Turn to the required direction to scan the QR code.');
      return;
    }

    try {
      final data = json.decode(value);
      final locationName = data["name"] ?? "Unknown location";
      final locationId = data["location_id"] ?? "";
      final audioAnnouncement =
          data["audio_announcement"] ?? "You are at $locationName";

      setState(() {
        scannedText = locationName;
      });

      _speak(audioAnnouncement);

      // ✅ Check if locationId matches room format (N + 3 digits)
      final roomRegex = RegExp(r'^[Nn]\d{3}$');
      if (roomRegex.hasMatch(locationId)) {
        // Valid QR → navigate to EnterRoomPage
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                // pass the QR location id (e.g. "N003") so routing uses the node id
                builder: (_) => EnterRoomPage(currentLocation: locationId),
              ),
            );
          }
        });
      } else {
        // ❌ Invalid QR → go back home
        _speak("Invalid QR, please scan again.");
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      // ❌ Not JSON at all
      _speak("Invalid QR, please scan again.");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      });
    }
  }

  bool _isHeadingInRange(double h) {
    // normalize
    double nh = (h % 360 + 360) % 360;
    // check each allowed range (handles wrap-around ranges too)
    for (final r in allowedHeadingRanges) {
      final double a = r[0];
      final double b = r[1];
      if (a <= b) {
        if (nh >= a && nh <= b) return true;
      } else {
        // wrap-around (e.g., 350..10)
        if (nh >= a || nh <= b) return true;
      }
    }
    return false;
  }

  // Human-readable text for guidance showing all allowed ranges, e.g. "100°–140° or 280°–320°"
  String _rangesText() {
    return allowedHeadingRanges
        .map((r) => '${r[0].toInt()}°–${r[1].toInt()}°')
        .join(' or ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(title: const Text('QR Scanner')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleBarcode),
          // Bottom controls: use SafeArea and flexible sizing to avoid overflow
          SafeArea(
            bottom: true,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(12),
                // allow flexible height, but enforce reasonable min/max to keep layout stable
                constraints: const BoxConstraints(minHeight: 72, maxHeight: 220),
                width: double.infinity,
                color: Colors.black54,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        scannedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guidance,
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        headingValid
                            ? 'Heading: ${heading.toStringAsFixed(1)}°'
                            : 'Heading: calibrating...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_calibrating) {
            _stopAndComputeCalibration();
          } else {
            _startCalibration();
          }
        },
        tooltip: _calibrating ? 'Stop calibration' : 'Start calibration',
        child: Icon(_calibrating ? Icons.stop : Icons.tune),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize sensors for a basic complementary filter using gyro + accel.
    // Note: without magnetometer this is an approximation; we use device heading
    // from sensors when available via sensors_plus accelerometer/gyro fusion.
    // We'll integrate gyro around Z to estimate yaw and slowly correct with a
    // crude accelerometer-derived yaw when possible.
  // use non-deprecated stream APIs
  _accelSub = accelerometerEventStream().listen((e) {
    _lastAccel = e;
    if (_calibrating) {
      _accelSamples.add(e);
    }
  });
  _gyroSub = gyroscopeEventStream().listen(_onGyroEvent);
  _magSub = magnetometerEventStream().listen(_onMagEvent);
    // Small delay before marking heading valid to allow initial convergence
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        headingValid = true;
      });
    });

    // Listen to native Android fused rotation-vector (if provided) via EventChannel.
    // Channel name matches the native implementation registered in MainActivity.
    try {
      const channel = EventChannel('com.example.indoornavigate/rotation');
      _rotationSub = channel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final dynamic hv = event['heading'] ?? event['azimuth'] ?? event['yaw'];
          if (hv != null) {
            double? h;
            if (hv is double) h = hv;
            else if (hv is int) h = hv.toDouble();
            else if (hv is String) h = double.tryParse(hv);
            if (h != null) {
              _platformHeading = (h % 360 + 360) % 360;
              _platformHeadingAvailable = true;
              // update UI immediately
              setState(() {
                heading = _platformHeading;
        guidance = _isHeadingInRange(heading)
          ? 'Aligned: you can scan now.'
          : 'Point device to ${_rangesText()} to scan.';
              });
            }
          }
        }
      }, onError: (err) {
        // If EventChannel isn't available or errors, fallback to Madgwick AHRS
        _platformHeadingAvailable = false;
      });
    } catch (e) {
      _platformHeadingAvailable = false;
    }
  }


  AccelerometerEvent? _lastAccel;
  MagnetometerEvent? _lastMag;

  void _onGyroEvent(GyroscopeEvent g) {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_lastSensorTimestamp == 0) _lastSensorTimestamp = now;
    final dt = (now - _lastSensorTimestamp) / 1e6; // seconds
    _lastSensorTimestamp = now;
    // Use last accel/mag samples; fall back to zeros if missing
    final ax = _lastAccel?.x.toDouble() ?? 0.0;
    final ay = _lastAccel?.y.toDouble() ?? 0.0;
    final az = _lastAccel?.z.toDouble() ?? 0.0;
  final rawMx = _lastMag?.x.toDouble() ?? 0.0;
  final rawMy = _lastMag?.y.toDouble() ?? 0.0;
  final rawMz = _lastMag?.z.toDouble() ?? 0.0;
    final corrected = _applyMagCorrection(rawMx, rawMy, rawMz - _magBiasZ);
  final mx = corrected[0];
  final my = corrected[1];
  final mz = corrected[2];
    if (_calibrating) {
      _gyroSamples.add(g);
    }
    // clamp dt to avoid huge steps after app pause
    final clampedDt = dt.clamp(1e-4, 0.5);
    _ahrs.update(g.x.toDouble(), g.y.toDouble(), g.z.toDouble(), ax, ay, az, mx, my, mz, clampedDt);
    _ahrs.update(g.x.toDouble(), g.y.toDouble(), g.z.toDouble(), ax, ay, az, mx, my, mz, dt);
    _updateFusedHeading();
  }

  void _onMagEvent(MagnetometerEvent m) {
    if (_calibrating) {
      // collect samples for calibration
      _magSamples.add(m);
    }
  _lastMag = m;
  _updateFusedHeading();
  }

  void _updateFusedHeading() {
    // Prefer platform fused heading when available (Android rotation-vector).
    if (_platformHeadingAvailable) {
      // platformHeading is already normalized
      heading = _platformHeading;
    setState(() {
      guidance = _isHeadingInRange(heading)
          ? 'Aligned: you can scan now.'
          : 'Point device to ${_rangesText()} to scan.';
    });
    // Update beeping state after guidance change
    _updateBeepState();
      return;
    }

    // Fallback: compute fused orientation from AHRS quaternion
    final q = _ahrs.quaternion;
    // yaw (heading) from quaternion: yaw = atan2(2*(q0*q3 + q1*q2), 1 - 2*(q2^2 + q3^2))
    final q0 = q[0], q1 = q[1], q2 = q[2], q3 = q[3];
    final yaw = math.atan2(2.0 * (q0 * q3 + q1 * q2), 1.0 - 2.0 * (q2 * q2 + q3 * q3));
    _fusedYaw = yaw;
    // convert to degrees and normalize
    final deg = (_fusedYaw * 180 / math.pi) % 360;
    heading = (deg + 360) % 360;
    setState(() {
      guidance = _isHeadingInRange(heading)
          ? 'Aligned: you can scan now.'
          : 'Point device to ${_rangesText()} to scan.';
    });
    // Update beeping state after guidance change
    _updateBeepState();
  }

  @override
  void dispose() {
  _accelSub?.cancel();
  _gyroSub?.cancel();
  _magSub?.cancel();
  _rotationSub?.cancel();
  _beepTimer?.cancel();
    super.dispose();
  }

  // Compute minimal angular distance (in degrees) from heading to the nearest allowed range.
  // Returns 0 if heading is inside any allowed range.
  double _distanceToClosestRange(double h) {
    final nh = (h % 360 + 360) % 360;
    double minDist = 360.0;
    for (final r in allowedHeadingRanges) {
      final a = (r[0] % 360 + 360) % 360;
      final b = (r[1] % 360 + 360) % 360;
      if (a <= b) {
        if (nh >= a && nh <= b) return 0.0;
        // distance to [a,b]
        final d = math.min((nh - a).abs(), (nh - b).abs());
        minDist = math.min(minDist, d);
      } else {
        // wrap-around range e.g. 350..10
        if (nh >= a || nh <= b) return 0.0;
        // distances to edges across wrap
        final d1 = ((nh - a) % 360).abs();
        final d2 = ((nh - b) % 360).abs();
        minDist = math.min(minDist, math.min(d1, d2));
      }
    }
    // ensure within [0,180]
    if (minDist > 180) minDist = 360 - minDist;
    return minDist;
  }

  void _updateBeepState() {
    // If heading is inside range, stop beeping
    if (!mounted) return;
    final outside = !_isHeadingInRange(heading);
    if (!outside) {
      if (_beepTimer != null) {
        _beepTimer?.cancel();
        _beepTimer = null;
      }
      return;
    }

  // compute distance to ranges (0..180)
  final dist = _distanceToClosestRange(heading);
  // map distance to interval: dist 0 -> maxInterval, dist >= cap -> minInterval
  final capped = math.min(dist, _beepDistanceCap);
  final ratio = (capped / _beepDistanceCap).clamp(0.0, 1.0);
  final interval = (_beepMaxIntervalMs - (ratio * (_beepMaxIntervalMs - _beepMinIntervalMs))).round();

    // update desired interval
    _beepIntervalMs = interval;

    // if outside and ticker not started, start a short-period ticker that
    // checks elapsed time and fires beeps; this avoids cancelling/creating
    // timers repeatedly while heading is moving.
    if (_beepTimer == null) {
      _lastBeep = DateTime.fromMillisecondsSinceEpoch(0);
      _beepTimer = Timer.periodic(Duration(milliseconds: _beepTickMs), (_) async {
        final now = DateTime.now();
        if (now.difference(_lastBeep).inMilliseconds >= _beepIntervalMs) {
          _lastBeep = now;
          try {
            SystemSound.play(SystemSoundType.alert);
          } catch (e) {
            // ignore if unsupported
          }
          try {
            await HapticFeedback.vibrate();
          } catch (e) {
            // ignore
          }
        }
      });
    }
  }

  // Calibration helpers
  Future<void> _startCalibration() async {
    setState(() {
      _calibrating = true;
      _magSamples.clear();
      guidance = 'Calibrating: slowly rotate device in figure-8...';
    });
  }

  Future<void> _stopAndComputeCalibration() async {
    setState(() {
      _calibrating = false;
      guidance = 'Calibration stopped. Computing offsets...';
    });

    if (_magSamples.isEmpty) {
      setState(() {
        guidance = 'No samples collected; calibration failed.';
      });
      return;
    }

    // Algebraic ellipsoid least-squares fit
    final m = _magSamples.length;
    final D = List.generate(m, (_) => List.filled(9, 0.0));
    final d = List.filled(m, 0.0);
    for (int i = 0; i < m; i++) {
      final x = _magSamples[i].x;
      final y = _magSamples[i].y;
      final z = _magSamples[i].z;
      D[i][0] = x * x;
      D[i][1] = y * y;
      D[i][2] = z * z;
      D[i][3] = 2 * x * y;
      D[i][4] = 2 * x * z;
      D[i][5] = 2 * y * z;
      D[i][6] = 2 * x;
      D[i][7] = 2 * y;
      D[i][8] = 2 * z;
      d[i] = 1.0;
    }

    // Solve normal equations (D^T D) p = D^T d for parameter vector p
    // Use Iteratively Re-weighted Least Squares (IRLS) with a bisquare weight
    // function to reduce influence of outliers.
    List<double>? p;
    // initial unweighted solve
    final dtD0 = List.generate(9, (_) => List.filled(9, 0.0));
    final dtd0 = List.filled(9, 0.0);
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        double sum = 0.0;
        for (int k = 0; k < m; k++) {
          sum += D[k][i] * D[k][j];
        }
        dtD0[i][j] = sum;
      }
      double sumd = 0.0;
      for (int k = 0; k < m; k++) {
        sumd += D[k][i] * d[k];
      }
      dtd0[i] = sumd;
    }
    p = _solveLinearSystem9(dtD0, dtd0);
    if (p != null) {
      const int maxIters = 10;
      for (int iter = 0; iter < maxIters; iter++) {
        // compute residuals r = D*p - d
        final residuals = List.filled(m, 0.0);
        for (int k = 0; k < m; k++) {
          double pred = 0.0;
          for (int j = 0; j < 9; j++) {
            pred += D[k][j] * p![j];
          }
          residuals[k] = pred - d[k];
        }
        // robust scale (MAD)
  final s = _madScale(residuals);
        final c = math.max(1e-9, 4.685 * s);
        // compute bisquare weights
        final weights = List.filled(m, 1.0);
        for (int k = 0; k < m; k++) {
          final r = residuals[k];
          final ar = (r / c).abs();
          if (ar >= 1.0) {
            weights[k] = 0.0;
          } else {
            final tmp = 1.0 - ar * ar;
            weights[k] = tmp * tmp;
          }
        }
        // build weighted normal equations
        final dtDw = List.generate(9, (_) => List.filled(9, 0.0));
        final dtdW = List.filled(9, 0.0);
        for (int i = 0; i < 9; i++) {
          for (int j = 0; j < 9; j++) {
            double sum = 0.0;
            for (int k = 0; k < m; k++) {
              sum += weights[k] * D[k][i] * D[k][j];
            }
            dtDw[i][j] = sum;
          }
          double sumd = 0.0;
          for (int k = 0; k < m; k++) {
            sumd += weights[k] * D[k][i] * d[k];
          }
          dtdW[i] = sumd;
        }
        final pNew = _solveLinearSystem9(dtDw, dtdW);
        if (pNew == null) break;
        // check convergence
        double maxDiff = 0.0;
      for (int j = 0; j < 9; j++) {
        maxDiff = math.max(maxDiff, (pNew[j] - p![j]).abs());
      }
  p = pNew;
        if (maxDiff < 1e-6) break;
      }
    }
    if (p == null) {
      // fallback to simple mean if linear solve fails
      double meanX = 0.0, meanY = 0.0, meanZ = 0.0;
      for (var s in _magSamples) {
        meanX += s.x;
        meanY += s.y;
        meanZ += s.z;
      }
      meanX /= m;
      meanY /= m;
      meanZ /= m;
      _magBiasX = meanX;
      _magBiasY = meanY;
      _magBiasZ = meanZ;
      // leave correction identity
    } else {
      // Reconstruct quadratic form Q (3x3), linear term p_lin, and constant d0
  final a11 = p[0];
  final a22 = p[1];
  final a33 = p[2];
  final a12 = p[3];
  final a13 = p[4];
  final a23 = p[5];
  final b1 = p[6];
  final b2 = p[7];
  final b3 = p[8];

      final Q = [
        [a11, a12, a13],
        [a12, a22, a23],
        [a13, a23, a33]
      ];
      final B = [b1, b2, b3];
      // center c = -0.5 * Q^{-1} * B
  final qInv = _invert3x3(Q);
  if (qInv == null) {
        // fallback to mean
        double meanX = 0.0, meanY = 0.0, meanZ = 0.0;
        for (var s in _magSamples) {
          meanX += s.x;
          meanY += s.y;
          meanZ += s.z;
        }
        meanX /= m;
        meanY /= m;
        meanZ /= m;
        _magBiasX = meanX;
        _magBiasY = meanY;
        _magBiasZ = meanZ;
      } else {
  final cx = -0.5 * (qInv[0][0] * B[0] + qInv[0][1] * B[1] + qInv[0][2] * B[2]);
  final cy = -0.5 * (qInv[1][0] * B[0] + qInv[1][1] * B[1] + qInv[1][2] * B[2]);
  final cz = -0.5 * (qInv[2][0] * B[0] + qInv[2][1] * B[1] + qInv[2][2] * B[2]);
        _magBiasX = cx;
        _magBiasY = cy;
        _magBiasZ = cz;
        // compute transformed matrix: T = Q / (-d + c^T Q c)
        // compute constant d0 = c^T Q c - 1 (since original constant assumed 1 on RHS)
        double cQc = cx * (Q[0][0] * cx + Q[0][1] * cy + Q[0][2] * cz) +
            cy * (Q[1][0] * cx + Q[1][1] * cy + Q[1][2] * cz) +
            cz * (Q[2][0] * cx + Q[2][1] * cy + Q[2][2] * cz);
        final scale = 1.0 / math.max(cQc, 1e-12);
        final T = List.generate(3, (i) => List.filled(3, 0.0));
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            T[i][j] = Q[i][j] * scale;
          }
        }
        // compute correction matrix M = sqrtm(T^{-1}) approx via eigen-decomp
  final eig = _jacobiEigenDecomposition(T);
        final vals = eig['values'] as List<double>;
        final vecs = eig['vectors'] as List<List<double>>;
        final invSqrt = List.generate(3, (i) => 1.0 / math.sqrt(math.max(vals[i], 1e-12)));
        final M = List.generate(3, (_) => List.filled(3, 0.0));
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            double ssum = 0.0;
            for (int k = 0; k < 3; k++) {
              ssum += vecs[k][i] * invSqrt[k] * vecs[k][j];
            }
            M[i][j] = ssum;
          }
        }
  _magCorrection = [M[0][0], M[0][1], M[0][2], M[1][0], M[1][1], M[1][2], M[2][0], M[2][1], M[2][2]];
      }
    }

    // persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('magBiasX', _magBiasX);
    await prefs.setDouble('magBiasY', _magBiasY);
    await prefs.setDouble('magScaleX', _magScaleX);
    await prefs.setDouble('magScaleY', _magScaleY);
    // Tune beta from gyro noise: estimate variance and choose beta ~ 0.5*std
    double beta = _ahrs.beta;
    if (_gyroSamples.isNotEmpty) {
      final meanX = _gyroSamples.map((g) => g.x).reduce((a, b) => a + b) / _gyroSamples.length;
      final varX = _gyroSamples.map((g) => (g.x - meanX) * (g.x - meanX)).reduce((a, b) => a + b) / _gyroSamples.length;
      final std = math.sqrt(varX);
      // heuristic mapping from gyro std to beta
      beta = (std * 0.5).clamp(0.01, 1.0);
      _ahrs.beta = beta;
      await prefs.setDouble('madgwickBeta', beta);
    }

    setState(() {
      guidance = 'Calibration saved.';
    });
  }

  double _madScale(List<double> data) {
    if (data.isEmpty) return 1.0;
    final sorted = List<double>.from(data)..sort();
    final med = sorted[sorted.length ~/ 2];
    final absDev = sorted.map((v) => (v - med).abs()).toList()..sort();
    final mad = absDev[absDev.length ~/ 2];
    return mad == 0.0 ? 1.0 : mad * 1.4826; // consistent estimator for normal
  }

  Future<void> _loadCalibration() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _magBiasX = prefs.getDouble('magBiasX') ?? 0.0;
      _magBiasY = prefs.getDouble('magBiasY') ?? 0.0;
      _magScaleX = prefs.getDouble('magScaleX') ?? 1.0;
      _magScaleY = prefs.getDouble('magScaleY') ?? 1.0;
  final beta = prefs.getDouble('madgwickBeta') ?? _ahrs.beta;
  _ahrs.beta = beta;
    });
  }

  // Apply hard-iron bias and soft-iron correction matrix to a magnetometer vector
  List<double> _applyMagCorrection(double mx, double my, double mz) {
    // subtract bias (bias stored as mean)
    final bx = mx - _magBiasX;
    final by = my - _magBiasY;
    final bz = mz; // keep z centered
    final M = _magCorrection;
    final rx = M[0] * bx + M[1] * by + M[2] * bz;
    final ry = M[3] * bx + M[4] * by + M[5] * bz;
    final rz = M[6] * bx + M[7] * by + M[8] * bz;
    return [rx, ry, rz];
  }

  // Jacobi eigen-decomposition for symmetric 3x3 matrix. Returns map with 'values' and 'vectors'
  Map<String, Object> _jacobiEigenDecomposition(List<List<double>> A) {
    // Initialize V as identity
    final V = List.generate(3, (_) => List.generate(3, (i) => i == 0 ? 1.0 : 0.0));
    // copy A
    final a = List.generate(3, (i) => List.from(A[i]));
    const int maxIter = 50;
    for (int iter = 0; iter < maxIter; iter++) { 
      // find largest off-diagonal
      double max = 0.0;
      int p = 0, q = 1;
      for (int i = 0; i < 3; i++) {
        for (int j = i + 1; j < 3; j++) {
          final v = a[i][j].abs();
          if (v > max) {
            max = v;
            p = i;
            q = j;
          }
        }
      }
      if (max < 1e-12) break;
      final app = a[p][p];
      final aqq = a[q][q];
      final apq = a[p][q];
  final phi = 0.5 * math.atan2(2 * apq, aqq - app);
  final c = math.cos(phi);
      final s = math.sin(phi);
      // rotate
      for (int i = 0; i < 3; i++) {
        final aip = a[i][p];
        final aiq = a[i][q];
        a[i][p] = c * aip - s * aiq;
        a[i][q] = s * aip + c * aiq;
      }
      for (int i = 0; i < 3; i++) {
        final api = a[p][i];
        final aqi = a[q][i];
        a[p][i] = c * api - s * aqi;
        a[q][i] = s * api + c * aqi;
      }
      // update diagonal
      a[p][p] = c * c * app - 2 * s * c * apq + s * s * aqq;
      a[q][q] = s * s * app + 2 * s * c * apq + c * c * aqq;
      a[p][q] = 0.0;
      a[q][p] = 0.0;
      // update eigenvector matrix V
      for (int i = 0; i < 3; i++) {
        final vip = V[i][p];
        final viq = V[i][q];
        V[i][p] = c * vip - s * viq;
        V[i][q] = s * vip + c * viq;
      }
    }
    final values = [a[0][0], a[1][1], a[2][2]];
    return {'values': values, 'vectors': V};
  }

  // Solve 9x9 linear system using Gaussian elimination. Returns null on failure.
  List<double>? _solveLinearSystem9(List<List<double>> A, List<double> b) {
    final n = 9;
    final M = List.generate(n, (i) => List.filled(n + 1, 0.0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        M[i][j] = A[i][j];
      }
      M[i][n] = b[i];
    }
    for (int i = 0; i < n; i++) {
      // pivot
      int pivot = i;
      for (int r = i + 1; r < n; r++) {
        if (M[r][i].abs() > M[pivot][i].abs()) pivot = r;
      }
      if (M[pivot][i].abs() < 1e-12) return null;
      if (pivot != i) {
        final tmp = M[i];
        M[i] = M[pivot];
        M[pivot] = tmp;
      }
      final div = M[i][i];
      for (int j = i; j <= n; j++) {
        M[i][j] /= div;
      }
      for (int r = 0; r < n; r++) {
        if (r == i) continue;
        final factor = M[r][i];
        for (int c = i; c <= n; c++) {
          M[r][c] -= factor * M[i][c];
        }
      }
    }
    final x = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      x[i] = M[i][n];
    }
    return x;
  }

  // Invert symmetric 3x3 matrix, return null on failure
  List<List<double>>? _invert3x3(List<List<double>> A) {
    final a = A[0][0];
    final b = A[0][1];
    final c = A[0][2];
    final d = A[1][0];
    final e = A[1][1];
    final f = A[1][2];
    final g = A[2][0];
    final h = A[2][1];
    final i = A[2][2];
    final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (det.abs() < 1e-18) return null;
    final invDet = 1.0 / det;
  final aInv = List.generate(3, (_) => List.filled(3, 0.0));
  aInv[0][0] = (e * i - f * h) * invDet;
  aInv[0][1] = (c * h - b * i) * invDet;
  aInv[0][2] = (b * f - c * e) * invDet;
  aInv[1][0] = (f * g - d * i) * invDet;
  aInv[1][1] = (a * i - c * g) * invDet;
  aInv[1][2] = (c * d - a * f) * invDet;
  aInv[2][0] = (d * h - e * g) * invDet;
  aInv[2][1] = (b * g - a * h) * invDet;
  aInv[2][2] = (a * e - b * d) * invDet;
  return aInv;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // load calibration on start
    _loadCalibration();
  }
}
