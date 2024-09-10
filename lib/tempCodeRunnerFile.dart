import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async'; // For simulating backend calls
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const SurakshaApp());
}

class SurakshaApp extends StatelessWidget {
  const SurakshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suraksha',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SignUpPage(),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  String _selectedUserType = 'Citizen';

  void _signUp() {
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all fields'),
      ));
      return;
    }

    if (_selectedUserType == 'Citizen') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CitizenDashboard(username: username)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AuthorityDashboard(username: username)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suraksha - Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: !_showPassword,
            ),
            Row(
              children: [
                Checkbox(
                  value: _showPassword,
                  onChanged: (bool? value) {
                    setState(() {
                      _showPassword = value!;
                    });
                  },
                ),
                const Text('Show Password')
              ],
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: _selectedUserType,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedUserType = newValue!;
                });
              },
              items: <String>['Citizen', 'Authority']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signUp,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class CitizenDashboard extends StatefulWidget {
  final String username;
  const CitizenDashboard({super.key, required this.username});

  @override
  _CitizenDashboardState createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  Position? _currentPosition;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _alertActive = false;
  String _statusText =
      'Press the button and say "Raksha" three times to activate';
  String _lastWords = '';
  int _rakshaCount = 0;

  @override
  void initState() {
    super.initState();
    _initSpeechRecognizer();
  }

  void _initSpeechRecognizer() async {
    await _speech.initialize(
      onStatus: (status) => print('onStatus: $status'),
      onError: (errorNotification) => print('onError: $errorNotification'),
    );
  }

  Future<void> _listen() async {
    if (!_speech.isAvailable) {
      setState(() => _statusText = 'Speech recognition not available');
      return;
    }

    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
      if (status.isDenied) {
        setState(() => _statusText = 'Microphone permission denied');
        return;
      }
    }

    if (!_isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _statusText = 'Listening: $_lastWords';
            if (_lastWords.toLowerCase().contains('raksha')) {
              _rakshaCount++;
              _statusText = 'Raksha count: $_rakshaCount';
              if (_rakshaCount >= 3) {
                _activateAlert();
              }
            }
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      setState(() => _statusText = 'Stopped listening');
    }
  }

  void _activateAlert() {
    setState(() {
      _alertActive = true;
      _isListening = false;
      _statusText =
          'EMERGENCY ALERT ACTIVATED!\nAttempting to notify authorities...';
    });
    _speech.stop();
    _notifyAuthorities();
  }

  Future<void> _notifyAuthorities() async {
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _statusText += '\nAuthorities have been notified. Help is on the way.';
    });
  }

  void _cancelAlert() {
    setState(() {
      _alertActive = false;
      _lastWords = '';
      _rakshaCount = 0;
      _statusText =
          'Alert cancelled. Press the button and say "Raksha" three times to activate';
    });
  }

  void _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Location services are disabled.'),
      ));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are denied.'),
        ));
        return;
      }
    }

    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {});
  }

  void _submitFeedback() {
    // Functionality to submit feedback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suraksha - Citizen Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${widget.username}',
                style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _listen,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(24),
                backgroundColor: _isListening ? Colors.red : Colors.blue,
              ),
              child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 50),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: TextStyle(
                  fontSize: 18,
                  color: _alertActive ? Colors.red : Colors.black),
              textAlign: TextAlign.center,
            ),
            if (_alertActive)
              ElevatedButton(
                onPressed: _cancelAlert,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                child: const Text('Cancel Alert'),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SafeMapsPage()),
                );
              },
              child: const Text('Safe Maps'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitFeedback,
              child: const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class SafeMapsPage extends StatelessWidget {
  const SafeMapsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Maps'),
      ),
      body: const Center(
        child: Text('Map functionality will be available here.'),
      ),
    );
  }
}

class AuthorityDashboard extends StatefulWidget {
  final String username;
  const AuthorityDashboard({super.key, required this.username});

  @override
  _AuthorityDashboardState createState() => _AuthorityDashboardState();
}

class _AuthorityDashboardState extends State<AuthorityDashboard> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedState;
  final List<String> _states = [
    'Maharashtra',
    'Gujarat',
    'Goa',
    'Kerala',
    'Karnataka',
    'Tamil Nadu',
    'Andhra Pradesh',
    'Telangana',
    'West Bengal',
    'Bihar',
    'Jharkhand',
    'Odisha',
    'Punjab',
    'Haryana',
    'Rajasthan',
    'Uttar Pradesh',
    'Madhya Pradesh',
    'Chhattisgarh',
    'Assam',
    'Sikkim',
    'Arunachal Pradesh',
    'Nagaland',
    'Manipur',
    'Tripura',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Andaman and Nicobar Islands',
    'Lakshadweep',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Puducherry',
    'Delhi',
    'Chandigarh',
    'Jammu and Kashmir',
    'Ladakh'
  ];
  Map<String, String> _profile = {};

  void _createProfile() {
    setState(() {
      _profile = {
        'Name': _nameController.text,
        'State': _selectedState ?? '',
        'City': _cityController.text,
        'Phone': _phoneController.text,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authority Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            DropdownButton<String>(
              hint: const Text('Select State'),
              value: _selectedState,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedState = newValue!;
                });
              },
              items: _states.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createProfile,
              child: const Text('Create Profile'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShowDetailsPage(profile: _profile),
                  ),
                );
              },
              child: const Text('Show Details'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShowDetailsPage extends StatelessWidget {
  final Map<String, String> profile;
  const ShowDetailsPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Show Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: profile.isEmpty
              ? const Text('No data entered')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: profile.entries
                      .map((entry) => Text('${entry.key}: ${entry.value}'))
                      .toList(),
                ),
        ),
      ),
    );
  }
}
