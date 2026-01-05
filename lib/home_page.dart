import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'qr_scanner.dart';

// Dummy QR Scanner Page for now

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts flutterTts = FlutterTts();
  int _scanClickCount = 0;
  // int _classClickCount = 0;

  // Function to speak
  Future<void> _speak(String msg) async {
    await flutterTts.speak(msg);
  }

  /*
  void _handleGoNextClass() {
    setState(() {
      _classClickCount++;
    });

    if (_classClickCount == 1) {
      _speak("Go Next Class");
    } else if (_classClickCount == 2) {
      _classClickCount = 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Go Next Class clicked")));
    }
  }
*/
  void _handleScanButton() {
    setState(() {
      _scanClickCount++;
    });

    if (_scanClickCount == 1) {
      _speak("Scan QR Code");
    } else if (_scanClickCount == 2) {
      _scanClickCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QRScannerPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("UTAR Navigate"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/utarlogo.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),

              // Welcome Text
              const Text(
                "Welcome To UTAR Navigate",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),

              // Button: Go Next Class
              /*
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _handleGoNextClass,
                  child: const Text(
                    "Go Next Class",
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              */
              // Button: Scan QR Code (double press with TTS)
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _handleScanButton,
                  child: const Text(
                    "Scan QR Code",
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
