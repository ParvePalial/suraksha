import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async'; // For simulating backend calls
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

void main() {
  runApp(const SurakshaApp());
}

class SurakshaApp extends StatelessWidget {
  const SurakshaApp({Key? key}) : super(key: key);

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
  const SignUpPage({Key? key}) : super(key: key);

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
        MaterialPageRoute(builder: (context) => CitizenDashboard(username: username)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AuthorityDashboard(username: username)),
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
  const CitizenDashboard({Key? key, required this.username}) : super(key: key);

  @override
  _CitizenDashboardState createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  Position? _currentPosition;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _alertActive = false;
  String _statusText = 'Press the button and say "Raksha" three times to activate';
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
      _statusText = 'EMERGENCY ALERT ACTIVATED!\nAttempting to notify authorities...';
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
      _statusText = 'Alert cancelled. Press the button and say "Raksha" three times to activate';
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
            Text('Welcome, ${widget.username}', style: const TextStyle(fontSize: 24)),
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
              style: TextStyle(fontSize: 18, color: _alertActive ? Colors.red : Colors.black),
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


class SafeMapsPage extends StatefulWidget {
  const SafeMapsPage({Key? key}) : super(key: key);

  @override
  _SafeMapsPageState createState() => _SafeMapsPageState();
}

class _SafeMapsPageState extends State<SafeMapsPage> {
  MapboxMapController? mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';

  // Mapbox Studio style URL
  static const String mapboxStyleUrl ='https://api.mapbox.com/styles/v1/codersamurai/cm0ssu9lc00q901o301562nne/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiY29kZXJzYW11cmFpIiwiYSI6ImNtMHNwNWZnNzBobnUycXMwaWMyMzJzN20ifQ.6NSYGuIGf6Or94OQaNujIg/draft';
  //static const String mapboxStyleUrl = 'https://api.mapbox.com/styles/v1/codersamurai/cm0ssu9lc00q901o301562nne.html?title=copy&access_token=pk.eyJ1IjoiY29kZXJzYW11cmFpIiwiYSI6ImNtMHNwNWZnNzBobnUycXMwaWMyMzJzN20ifQ.6NSYGuIGf6Or94OQaNujIg&zoomwheel=true&fresh=true#2/37.75/-92.25';
  static const String mapboxAccessToken = 'pk.eyJ1IjoiY29kZXJzYW11cmFpIiwiYSI6ImNtMHNwNWZnNzBobnUycXMwaWMyMzJzN20ifQ.6NSYGuIGf6Or94OQaNujIg';

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      await _getCurrentLocation();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize map: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permissions are denied.');
      }
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _onMapCreated(MapboxMapController controller) {
    mapController = controller;
    _addMarker();
    _setupLocationTracking();
  }

  void _addMarker() {
    if (_currentPosition != null && mapController != null) {
      mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          iconImage: 'assets/marker.png',
          iconSize: 1.5,
        ),
      );
    }
  }

  void _setupLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() => _currentPosition = position);
      _updateMapPosition();
    });
  }

  void _updateMapPosition() {
    if (mapController != null && _currentPosition != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Maps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _updateMapPosition,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    } else if (_currentPosition == null) {
      return const Center(child: Text('Unable to get current location'));
    } else {
      return Stack(
        children: [
          MapboxMap(
            accessToken: mapboxAccessToken,
            styleString: mapboxStyleUrl,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.TrackingGPS,
            minMaxZoomPreference: const MinMaxZoomPreference(11, 17),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _toggleMapLayers,
              child: const Icon(Icons.layers),
            ),
          ),
        ],
      );
    }
  }

  void _toggleMapLayers() {
    // Implement layer toggling functionality
    // This could show a modal bottom sheet with different map layer options
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Standard'),
                onTap: () {
                  // Switch to standard map style
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.satellite),
                title: const Text('Satellite'),
                onTap: () {
                  // Switch to satellite map style
                  Navigator.pop(context);
                },
              ),
              // Add more map style options as needed
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}



class AuthorityDashboard extends StatefulWidget {
  final String username;
  const AuthorityDashboard({Key? key, required this.username}) : super(key: key);

  @override
  _AuthorityDashboardState createState() => _AuthorityDashboardState();
}

class _AuthorityDashboardState extends State<AuthorityDashboard> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedState;
  final List<String> _states = [
    'Maharashtra', 'Gujarat', 'Goa', 'Kerala', 'Karnataka', 'Tamil Nadu', 'Andhra Pradesh', 'Telangana', 'West Bengal',
    'Bihar', 'Jharkhand', 'Odisha', 'Punjab', 'Haryana', 'Rajasthan', 'Uttar Pradesh', 'Madhya Pradesh', 'Chhattisgarh',
    'Assam', 'Sikkim', 'Arunachal Pradesh', 'Nagaland', 'Manipur', 'Tripura', 'Meghalaya', 'Mizoram', 'Nagaland', 'Andaman and Nicobar Islands',
    'Lakshadweep', 'Dadra and Nagar Haveli and Daman and Diu', 'Puducherry', 'Delhi', 'Chandigarh', 'Jammu and Kashmir', 'Ladakh'
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
  const ShowDetailsPage({Key? key, required this.profile}) : super(key: key);

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