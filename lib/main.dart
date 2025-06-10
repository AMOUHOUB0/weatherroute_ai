import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(WeatherRadarApp());
}

class WeatherRadarApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radar Tutorial',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF1a1a1a),
        primaryColor: Colors.green,
      ),
      home: WeatherRadarScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final double windSpeed;
  final int humidity;
  final double visibility;
  final LatLng location;

  WeatherData({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.humidity,
    required this.visibility,
    required this.location,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, LatLng location) {
    return WeatherData(
      temperature: json['main']['temp'].toDouble(),
      description: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      windSpeed: json['wind']['speed'].toDouble(),
      humidity: json['main']['humidity'],
      visibility: json['visibility'].toDouble() / 1000,
      location: location,
    );
  }
}

class WeatherRadarScreen extends StatefulWidget {
  @override
  _WeatherRadarScreenState createState() => _WeatherRadarScreenState();
}

class _WeatherRadarScreenState extends State<WeatherRadarScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _radarAnimationController;
  late AnimationController _pulseAnimationController;

  List<Marker> _weatherMarkers = [];
  List<Polyline> _polylines = [];
  List<WeatherData> _weatherData = [];

  double _timeSliderValue = 0.5;
  bool _isPlaying = false;
  String _selectedLocation = "Casablanca, MA";
  double _currentTemp = 28.0;
  String _roadCondition = "Route sèche à 22:01";

  // Variables pour la destination et route
  String _destination = "";
  bool _showRouteWeather = false;
  List<WeatherData> _routeWeatherData = [];
  final TextEditingController _destinationController = TextEditingController();
  bool _showDestinationSearch = true;
  static const LatLng _casablancaCenter = LatLng(33.5731, -7.5898);
  
  // Variables pour la route
  List<LatLng> routeCoordinates = [];
  bool _isCalculatingRoute = false;
  String _routeDistance = "";
  String _routeDuration = "";
  LatLng? _currentLocation;

  // Données de prévision
  final List<Map<String, dynamic>> _forecastData = [
    {
      'day': 'VEN',
      'icon': Icons.wb_cloudy,
      'high': '25°',
      'low': '19°',
      'rain': '50%',
      'color': Colors.blue
    },
    {
      'day': 'SAM',
      'icon': Icons.thunderstorm,
      'high': '24°',
      'low': '18°',
      'rain': null,
      'color': Colors.orange
    },
    {
      'day': 'DIM',
      'icon': Icons.thunderstorm,
      'high': '26°',
      'low': '20°',
      'rain': null,
      'color': Colors.orange
    },
  ];

  @override
  void initState() {
    super.initState();
    _radarAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _getCurrentLocation();
    _generateWeatherMarkers();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocation = _casablancaCenter;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = _casablancaCenter;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedLocation = "${place.locality ?? 'Position actuelle'}, ${place.country ?? 'MA'}";
        });
      }
    } catch (e) {
      print('Erreur géolocalisation: $e');
      setState(() {
        _currentLocation = _casablancaCenter;
      });
    }
  }

  void _generateWeatherMarkers() {
    final List<LatLng> weatherPoints = [
      LatLng(33.5731, -7.5898), // Casablanca
      LatLng(34.0209, -6.8416), // Rabat
      LatLng(31.6295, -7.9811), // Marrakech
      LatLng(34.0181, -5.0078), // Fès
      LatLng(35.7595, -5.8340), // Tanger
      LatLng(30.4278, -9.5981), // Agadir
    ];

    List<Marker> markers = [];
    
    for (int i = 0; i < weatherPoints.length; i++) {
      LatLng point = weatherPoints[i];
      WeatherData weather = _generateDemoWeatherData(point);
      _weatherData.add(weather);

      markers.add(
        Marker(
          point: point,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showWeatherDetails(weather),
            child: AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimationController.value * 0.2),
                  child: _buildWeatherMarker(weather),
                );
              },
            ),
          ),
        ),
      );
    }

    setState(() {
      _weatherMarkers = markers;
    });
  }

  Widget _buildWeatherMarker(WeatherData weather) {
    Color markerColor = _getWeatherColor(weather.description);
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            markerColor.withOpacity(0.8),
            markerColor.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            _getWeatherIconData(weather.icon),
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    );
  }

  Color _getWeatherColor(String description) {
    if (description.toLowerCase().contains('pluie')) return Colors.blue;
    if (description.toLowerCase().contains('orage')) return Colors.red;
    if (description.toLowerCase().contains('nuage')) return Colors.grey;
    return Colors.green;
  }

  IconData _getWeatherIconData(String iconCode) {
    switch (iconCode) {
      case '01d': return Icons.wb_sunny;
      case '02d': case '03d': case '04d': return Icons.wb_cloudy;
      case '09d': case '10d': return Icons.grain;
      case '11d': return Icons.flash_on;
      default: return Icons.wb_cloudy;
    }
  }

  WeatherData _generateDemoWeatherData(LatLng location) {
    final random = math.Random((location.latitude + location.longitude * 1000).toInt());
    
    final descriptions = ['Ensoleillé', 'Nuageux', 'Pluvieux', 'Orageux'];
    final icons = ['01d', '02d', '10d', '11d'];
    
    int index = random.nextInt(descriptions.length);
    
    return WeatherData(
      temperature: 18 + random.nextInt(15).toDouble(),
      description: descriptions[index],
      icon: icons[index],
      windSpeed: 2 + random.nextInt(8).toDouble(),
      humidity: 40 + random.nextInt(40),
      visibility: 8 + random.nextInt(12).toDouble(),
      location: location,
    );
  }

  Future<void> _getRouteWeather() async {
    if (_destination.isEmpty) return;
    
    setState(() {
      _isCalculatingRoute = true;
      _showRouteWeather = false;
    });

    try {
      // Géocodage de la destination
      List<Location> locations = await locationFromAddress(_destination);
      if (locations.isEmpty) {
        print('Destination non trouvée');
        return;
      }
      
      LatLng destinationLatLng = LatLng(locations[0].latitude, locations[0].longitude);
      
      // Utiliser la position actuelle ou Casablanca par défaut
      LatLng startLatLng = _currentLocation ?? _casablancaCenter;
      
      // Calculer la route
      await _calculateRoute(startLatLng, destinationLatLng);
      
      // Obtenir la météo le long de la route
      await _getWeatherAlongRoute();
      
      setState(() {
        _showRouteWeather = true;
      });
      
    } catch (e) {
      print('Erreur lors du calcul de la route: $e');
      // Créer une route de démonstration si le géocodage échoue
      LatLng demoDestination = LatLng(34.0209, -6.8416); // Rabat
      LatLng startLatLng = _currentLocation ?? _casablancaCenter;
      await _calculateRoute(startLatLng, demoDestination);
      await _getWeatherAlongRoute();
      setState(() {
        _showRouteWeather = true;
      });
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  Future<void> _calculateRoute(LatLng start, LatLng destination) async {
    try {
      // Créer une route simple (ligne avec quelques points intermédiaires)
      List<LatLng> route = _generateRoutePoints(start, destination);
      
      // Calculer distance et durée approximatives
      double distance = _calculateDistance(start, destination);
      _routeDistance = "${distance.toStringAsFixed(0)} km";
      _routeDuration = "${(distance / 80 * 60).toStringAsFixed(0)} min"; // ~80 km/h moyenne
      
      // Créer la polyline - FIXED: Removed polylineId parameter
    Polyline routePolyline = Polyline(
  points: route,
  color: Colors.blue,
  strokeWidth: 4.0,
  // Supprimez isDotted si ça ne marche pas
);
      setState(() {
        routeCoordinates = route;
        _polylines = [routePolyline];
      });
      
      // Centrer la carte sur la route
      _fitMapToRoute(start, destination);
      
    } catch (e) {
      print('Erreur calcul route: $e');
    }
  }

  void _fitMapToRoute(LatLng start, LatLng destination) {
    double minLat = math.min(start.latitude, destination.latitude) - 0.05;
    double maxLat = math.max(start.latitude, destination.latitude) + 0.05;
    double minLng = math.min(start.longitude, destination.longitude) - 0.05;
    double maxLng = math.max(start.longitude, destination.longitude) + 0.05;
    
    LatLng southwest = LatLng(minLat, minLng);
    LatLng northeast = LatLng(maxLat, maxLng);
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(southwest, northeast),
        padding: EdgeInsets.all(50),
      ),
    );
  }

  List<LatLng> _generateRoutePoints(LatLng start, LatLng destination) {
    List<LatLng> points = [];
    int numPoints = 10; // Nombre de points intermédiaires
    
    for (int i = 0; i <= numPoints; i++) {
      double ratio = i / numPoints;
      double lat = start.latitude + (destination.latitude - start.latitude) * ratio;
      double lng = start.longitude + (destination.longitude - start.longitude) * ratio;
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude, start.longitude,
      end.latitude, end.longitude,
    ) / 1000; // Convertir en km
  }

  Future<void> _getWeatherAlongRoute() async {
    if (routeCoordinates.isEmpty) return;
    
    _routeWeatherData.clear();
    
    // Prendre quelques points le long de la route pour la météo
    List<LatLng> weatherCheckPoints = [];
    int step = math.max(1, (routeCoordinates.length / 3).round()); // 3 points de contrôle
    
    for (int i = 0; i < routeCoordinates.length; i += step) {
      if (i < routeCoordinates.length) {
        weatherCheckPoints.add(routeCoordinates[i]);
      }
    }
    
    // Ajouter le point de destination s'il n'y est pas
    if (weatherCheckPoints.isNotEmpty && weatherCheckPoints.last != routeCoordinates.last) {
      weatherCheckPoints.add(routeCoordinates.last);
    }
    
    // Générer des données météo pour chaque point
    for (LatLng point in weatherCheckPoints) {
      WeatherData weather = _generateDemoWeatherData(point);
      _routeWeatherData.add(weather);
    }
  }

  Widget _buildDestinationInput() {
    if (!_showDestinationSearch) {
      // Petit icône quand la recherche est cachée
      return Positioned(
        top: 180,
        left: 16,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _showDestinationSearch = true;
            });
          },
          child: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[600]!, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.blue, size: 16),
                if (_destination.isNotEmpty) ...[
                  SizedBox(width: 4),
                  Text(
                    _destination.length > 8 ? '${_destination.substring(0, 8)}...' : _destination,
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Barre de recherche complète
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Destination',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDestinationSearch = false;
                  });
                },
                child: Icon(Icons.close, color: Colors.grey[400], size: 20),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Entrez votre destination...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _destination = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (_destination.isNotEmpty) {
                    _getRouteWeather();
                    setState(() {
                      _showDestinationSearch = false; // Cache la barre après recherche
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCalculatingRoute ? Colors.grey : Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isCalculatingRoute
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
          if (_showRouteWeather) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Route vers $_destination',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(_routeDistance, style: TextStyle(color: Colors.white, fontSize: 12)),
                      SizedBox(width: 16),
                      Icon(Icons.access_time, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(_routeDuration, style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Météo sur la route:',
                    style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...(_routeWeatherData.isNotEmpty 
                    ? _routeWeatherData.map((weather) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(_getWeatherIconData(weather.icon), 
                                 color: _getWeatherColor(weather.description), size: 16),
                            SizedBox(width: 8),
                            Text('${weather.temperature.toInt()}°C', 
                                 style: TextStyle(color: Colors.white, fontSize: 12)),
                            SizedBox(width: 8),
                            Text(weather.description, 
                                 style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                          ],
                        ),
                      )).toList()
                    : [Text('Calcul en cours...', 
                            style: TextStyle(color: Colors.grey[400], fontSize: 12))]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1a1a1a),
      body: SafeArea(
        child: Stack(
          children: [
            // Carte en plein écran
            _buildRadarMap(),
            
            // Header en overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(),
            ),
            
            // Météo actuelle en overlay (en haut à gauche)
            Positioned(
              top: 80,
              left: 16,
              child: _buildCurrentWeatherCompact(),
            ),
            
            // Prévisions en overlay (en haut à droite)
            Positioned(
              top: 80,
              right: 16,
              child: _buildForecastCompact(),
            ),

            // Widget de destination
            if (_showDestinationSearch)
              Positioned(
                top: 180,
                left: 0,
                right: 0,
                child: _buildDestinationInput(),
              )
            else
              _buildDestinationInput(),
              
            // Contrôles en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radar Tutorial',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _selectedLocation,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          Icon(
            Icons.location_on,
            color: Colors.grey[400],
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildTempInfo(String temp, String time, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            temp,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(width: 4),
          Text(
            time,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCompact() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Température principale
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 0.7,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentTemp.toInt()}°',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'now',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTempInfo('86°', '4p', Colors.orange),
                  SizedBox(height: 4),
                  _buildTempInfo('64°', '4a', Colors.green),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCompact() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'VEN',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.wb_cloudy,
                color: Colors.blue,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                '50%',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '85° 69°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                'SAM',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
              SizedBox(width: 8),
              Icon(
                Icons.thunderstorm,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '84° 68°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarMap() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF2a2a2a),
      ),
      child: Stack(
        children: [
          // Carte OpenStreetMap en plein écran
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? _casablancaCenter,
              initialZoom: 6.0,
              minZoom: 4.0,
              maxZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.weatherradar',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _weatherMarkers),
            ],
          ),
          
          // Overlay radar animé
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _radarAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarOverlayPainter(_radarAnimationController.value),
                );
              },
            ),
          ),
          
          // Info route en haut à droite
          Positioned(
            top: 200,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Dry road @ 10:01 PM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider intensité
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LOW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                  ),
                  child: Slider(
                    value: _timeSliderValue,
                    onChanged: (value) {
                      setState(() {
                        _timeSliderValue = value;
                      });
                    },
                    activeColor: Colors.green,
                    inactiveColor: Colors.red,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HIGH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Contrôles lecture
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '12:30 PM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 30),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                  if (_isPlaying) {
                    _radarAnimationController.repeat();
                  } else {
                    _radarAnimationController.stop();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWeatherDetails(WeatherData weather) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2a2a2a),
          title: Text(
            'Détails Météo',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌡️ Température: ${weather.temperature.toStringAsFixed(1)}°C',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                '📝 Conditions: ${weather.description}',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                '💨 Vent: ${weather.windSpeed.toStringAsFixed(1)} m/s',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                '💧 Humidité: ${weather.humidity}%',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                '👁️ Visibilité: ${weather.visibility.toStringAsFixed(1)} km',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Fermer',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
     _destinationController.dispose();
    _radarAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
}

class RadarOverlayPainter extends CustomPainter {
  final double animationValue;

  RadarOverlayPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Zones météo animées
    _drawWeatherZones(canvas, size, paint);
    
    // Lignes de front
    _drawWeatherFronts(canvas, size, paint);
  }

  void _drawWeatherZones(Canvas canvas, Size size, Paint paint) {
    // Zone verte (pluie légère)
    paint.color = Colors.green.withOpacity(0.3 + animationValue * 0.2);
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.6),
      50 + (animationValue * 20),
      paint,
    );
    
    // Zone jaune (pluie modérée)
    paint.color = Colors.yellow.withOpacity(0.4 + animationValue * 0.2);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.4),
      30 + (animationValue * 15),
      paint,
    );
    
    // Zone rouge (orages)
    paint.color = Colors.red.withOpacity(0.3 + animationValue * 0.3);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      25 + (animationValue * 10),
      paint,
    );
  }

  void _drawWeatherFronts(Canvas canvas, Size size, Paint paint) {
    paint.color = Colors.white.withOpacity(0.8);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    
    // Fixed: Use ui.Path instead of latlong2.Path
    final path = ui.Path();
    path.moveTo(size.width * 0.1, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.3,
      size.width * 0.9,
      size.height * 0.4,
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}