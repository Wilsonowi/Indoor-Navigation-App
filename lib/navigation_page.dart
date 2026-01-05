import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_compass/flutter_compass.dart';

class NavigationPage extends StatefulWidget {
  final List<String> route;
  final List<String> instructions;

  const NavigationPage({
    super.key,
    required this.route,
    required this.instructions,
  });

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final FlutterTts flutterTts = FlutterTts();
  StreamSubscription<CompassEvent>? _compassSubscription;

  int currentSegment = 0; // index of current edge
  int remainingSeconds = 0;
  double? currentHeading; // compass heading in degrees

  @override
  void initState() {
    super.initState();
    _initCompass();
    flutterTts.awaitSpeakCompletion(true); // wait until speech finishes
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.8); // faster speed
    flutterTts.setPitch(1.0);
    _startNextInstruction();
  }

  void _initCompass() {
    _compassSubscription = FlutterCompass.events!.listen((event) {
      setState(() {
        currentHeading = event.heading;
      });
    });
  }

  Future<void> _speak(String msg) async {
    await flutterTts.stop();
    await flutterTts.speak(msg);
  }

  Future<void> _startNextInstruction() async {
    if (currentSegment >= widget.route.length - 1) {
      await _speak("You have reached your destination.");
      return;
    }

    final from = widget.route[currentSegment];
    final to = widget.route[currentSegment + 1];
    final instruction = widget.instructions[currentSegment];

    // extract distance (meters) and convert to seconds assuming 1.0 m/s
    final distance = _extractDistance(instruction);
    remainingSeconds = distance; // seconds (1 m/s)

    // 🔥 Speak full instruction first
    await _speak(
      "From $from to $to. $instruction. Estimated walking time $remainingSeconds seconds.",
    );

    if (!mounted) return;
    setState(() {
      currentSegment++;
    });

    // 🔥 Only start countdown after speaking is done
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds <= 0) {
        timer.cancel();
        _checkCompassForTurn();
        return;
      }
      setState(() {
        remainingSeconds--;
      });
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  int _extractDistance(String instruction) {
    final regex = RegExp(r'(\d+) meters');
    final match = regex.firstMatch(instruction);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 5; // default 5 meters -> 5 seconds
  }

  void _checkCompassForTurn() {
    if (currentSegment >= widget.route.length - 1) {
      _speak("Arrived at destination.");
      return;
    }

    final instruction = widget.instructions[currentSegment];
    if (instruction.toLowerCase().contains("turn")) {
      _speak("Please adjust your orientation to match the turn.");

      // wait until user aligns (simple check)
      // create a temporary subscription and cancel it when aligned
      late StreamSubscription<CompassEvent> tempSub;
      tempSub = FlutterCompass.events!.listen((event) {
        final heading = event.heading ?? 0;
        if (_isAligned(heading, instruction)) {
          _speak("Correct direction. Continue walking.");
          tempSub.cancel();
          _startNextInstruction();
        }
      });
    } else {
      // if no turn, go straight to next
      _startNextInstruction();
    }
  }

  bool _isAligned(double heading, String instruction) {
    // simple demo logic: check if user is facing approx correct direction
    // you can refine with actual angles later
    if (instruction.toLowerCase().contains("left")) {
      return heading >= 80 && heading <= 100; // facing ~90°
    }
    if (instruction.toLowerCase().contains("right")) {
      return heading >= 260 && heading <= 280; // facing ~270°
    }
    if (instruction.toLowerCase().contains("straight")) {
      return heading <= 10 || heading >= 350; // facing ~0°
    }
    return true;
  }

  // map highlight logic
  bool _isRoomActive(String room) {
    if (currentSegment == 0) return room == widget.route.first;
    if (currentSegment >= widget.route.length) return room == widget.route.last;
    return room == widget.route[currentSegment] ||
        room == widget.route[currentSegment - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Block N Navigation"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Map section
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 7; i >= 4; i--)
                          _RoomBox(
                            room: "N00$i",
                            active: _isRoomActive("N00$i"),
                          ),
                        _RoomBox(room: "Exit", active: _isRoomActive("Exit")),
                        for (int i = 1; i >= 3; i++)
                          _RoomBox(
                            room: "N00$i",
                            active: _isRoomActive("N00$i"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoomBox(room: "Exit", active: _isRoomActive("Exit")),
                        _RoomBox(room: "N008", active: _isRoomActive("N008")),
                        _RoomBox(
                          room: "Toilet",
                          active: _isRoomActive("Toilet"),
                        ),
                        _RoomBox(room: "N009", active: _isRoomActive("N009")),
                        for (int i = 12; i >= 10; i--)
                          _RoomBox(room: "N0$i", active: _isRoomActive("N0$i")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: Colors.black),

          // Status + Instructions
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    currentSegment >= widget.route.length - 1
                        ? "Arrived at destination: ${widget.route.last}"
                        : "Heading to: ${widget.route[currentSegment]} "
                              "(${remainingSeconds} s left)",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.instructions.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: index < currentSegment
                            ? Colors.green[100]
                            : Colors.white,
                        child: ListTile(
                          leading: Icon(
                            index < currentSegment
                                ? Icons.check_circle
                                : Icons.directions_walk,
                            color: index < currentSegment
                                ? Colors.green
                                : Colors.black,
                          ),
                          title: Text(widget.instructions[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomBox extends StatelessWidget {
  final String room;
  final bool active;

  const _RoomBox({required this.room, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        room,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
