import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'indoor_navigation.dart';
import 'navigation_page.dart';

class EnterRoomPage extends StatefulWidget {
  final String currentLocation;

  const EnterRoomPage({Key? key, required this.currentLocation})
    : super(key: key);

  @override
  State<EnterRoomPage> createState() => _EnterRoomPageState();
}

class _EnterRoomPageState extends State<EnterRoomPage> {
  final TextEditingController roomController = TextEditingController();
  final IndoorNavigation nav = IndoorNavigation();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = "";

  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    roomController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    // Ensure microphone permission before initializing speech recognition
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required for speech recognition',
            ),
          ),
        );
        // Offer to open app settings if permanently denied
        if (result.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please enable microphone permission in app settings',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    }
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    setState(() => _isListening = true);

    _speech.listen(
      onResult: (val) {
        setState(() => _lastWords = val.recognizedWords);
      },
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    final normalized = _normalizeSpokenRoom(_lastWords);

    if (normalized.isNotEmpty) {
      setState(() => roomController.text = normalized);
      await _tts.speak("Detected destination $normalized");
    }
  }

  void _startNavigation() {
    final destination = roomController.text.trim().toUpperCase();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a room.")));
      return;
    }

    final route = nav.calculateRoute(
      widget.currentLocation.trim().toUpperCase(),
      destination,
    );

    if (route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No route found to $destination")));
      return;
    }

    final instructions = <String>[];
    for (int i = 0; i < route.length - 1; i++) {
      instructions.add(nav.getInstruction(route[i], route[i + 1]));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NavigationPage(route: route, instructions: instructions),
      ),
    );
  }

  String _normalizeSpokenRoom(String spoken) {
    if (spoken.trim().isEmpty) return "";
    final lower = spoken.toLowerCase();

    // Replace words with digits
    final Map<String, String> numMap = {
      'zero': '0',
      'oh': '0',
      'o': '0',
      'one': '1',
      'two': '2',
      'to': '2',
      'too': '2',
      'three': '3',
      'four': '4',
      'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'nine': '9',
      'ten': '10',
    };

    String cleaned = lower;
    numMap.forEach((word, digit) {
      cleaned = cleaned.replaceAll(RegExp("\\b$word\\b"), digit);
    });

    // Remove spaces and non-alphanumeric
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    // If starts with N and has digits after it
    if (cleaned.startsWith("N") && cleaned.length > 1) {
      String digits = cleaned.substring(1).padLeft(3, '0');
      return "N$digits";
    }

    // If only digits, prepend N
    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      return "N${cleaned.padLeft(3, '0')}";
    }

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Enter Destination Room"),
        backgroundColor: Colors.black,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          // Add bottom padding equal to the keyboard inset so content
          // can scroll above the keyboard when it appears.
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          // Ensure the scroll view grows to fill available height so
          // keyboard insets are applied and content can scroll when needed.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You are currently at: ${widget.currentLocation}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Enter your destination room number:",
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "e.g. N010",
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: GestureDetector(
                      onLongPressStart: (_) => _startListening(),
                      onLongPressEnd: (_) => _stopListening(),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: _isListening ? Colors.red : Colors.black,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _lastWords.isEmpty
                        ? "Hold mic and speak your destination"
                        : "Heard: $_lastWords",
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  // The button is intentionally left out of the main column so
                  // it can be placed in the Scaffold.bottomNavigationBar where
                  // it remains visible and clickable above the keyboard.
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          12 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                onPressed: _startNavigation,
                child: const Text(
                  "Start Navigation",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
