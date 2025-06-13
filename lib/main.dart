import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'alerts_page.dart';
import 'recommendation_page.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(WeatherRouteApp());
}

const openWeatherApiKey = 'a08c63daf8a569834c3a9b1c069a33a5';
const openRouteServiceApiKey =
    '5b3ce3597851110001cf6248d4eaa58434564f419b9b483bdb39a982';

class WeatherRouteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Météo Route Maroc',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0a0a0a),
      ),
      home: WeatherRouteScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherAlert {
  final String type; // "temp", "rain", "storm", etc.
  final String message;
  final String segment;
  final Color color;
  final IconData icon;

  WeatherAlert({
    required this.type,
    required this.message,
    required this.segment,
    required this.color,
    required this.icon,
  });
}




class RouteWeatherPoint {
  final LatLng location;
  final String weatherCondition;
  final double temperature;
  final IconData weatherIcon;
  final Color weatherColor;
  final String cityName;
  final double humidity;
  final double windSpeed;
  final double rainIntensity;

  RouteWeatherPoint({
    required this.location,
    required this.weatherCondition,
    required this.temperature,
    required this.weatherIcon,
    required this.weatherColor,
    required this.cityName,
    required this.humidity,
    required this.windSpeed,
    required this.rainIntensity,
  });
}

class RouteSegment {
  final LatLng startPoint;
  final LatLng endPoint;
  final double distance;
  final double duration;
  final String segmentName;
  final RouteWeatherPoint startWeather;
  final RouteWeatherPoint endWeather;

  RouteSegment({
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.duration,
    required this.segmentName,
    required this.startWeather,
    required this.endWeather,
  });
}

class WeatherRouteScreen extends StatefulWidget {
  @override
  _WeatherRouteScreenState createState() => _WeatherRouteScreenState();
}

class _WeatherRouteScreenState extends State<WeatherRouteScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _weatherCache = {};

 Map<String, LatLng> _moroccanCities = {
  'Casablanca': LatLng(33.5731, -7.5898), // Valeurs par défaut
  'Rabat': LatLng(34.0209, -6.8416),
};

Map<String, String> _cityVariations = {
  'casablanca': 'Casablanca', // Valeurs par défaut
  'casa': 'Casablanca',
  'rabat': 'Rabat',
};
  late AnimationController _loadingController;
  late AnimationController _pulseController;
  LatLng? _currentLocation;
  String _currentLocationName = "Recherche de localisation...";
  List<Polyline> _routeLines = [];
  List<Marker> _weatherMarkers = [];
  List<RouteSegment> _routeSegments = [];

  bool _isLocationLoading = true;
  bool _isRouteCalculating = false;
  bool _hasActiveRoute = false;
  bool _showSearchBar = true;

  String riskType = '';
  double riskLevel = 0.0;
  String recommendation = '';
  String _routeDistance = "";
  String _routeDuration = "";
  String _selectedDestination = "";

 
  
String? findClosestCity(String userInput, List<String> cities) {
  if (userInput.isEmpty) return null;

  final normalizedInput = userInput.toLowerCase().trim();

 if (_cityVariations.containsKey(normalizedInput)) {
    return _cityVariations[normalizedInput];
  }

   final exactMatch = _moroccanCities.keys.firstWhere(
    (city) => city.toLowerCase() == normalizedInput,
    orElse: () => '',
  );

  if (exactMatch.isNotEmpty) return exactMatch;

   final bestMatch = extractTop(
    query: normalizedInput,
    choices: _moroccanCities.keys.toList(),
    limit: 1,
    cutoff: 60,
  ).firstOrNull;

  return (bestMatch != null && bestMatch.score >= 60) ? bestMatch.choice : null;
}
Future<void> _loadCitiesData() async {
  try {
    final String response = await rootBundle.loadString('assets/cities.json');
    final data = json.decode(response);
    
    final cities = data['cities'] as Map<String, dynamic>;
    _moroccanCities = cities.map((key, value) => 
      MapEntry(key, LatLng(value['lat'], value['lng'])));
    
    _cityVariations = Map<String, String>.from(data['city_variations']);
  } catch (e) {
    print('Error loading cities data: $e');
    // Valeurs par défaut
    _moroccanCities = {
      'Casablanca': LatLng(33.5731, -7.5898),
      'Rabat': LatLng(34.0209, -6.8416),
    };
    _cityVariations = {
      'casablanca': 'Casablanca',
      'casa': 'Casablanca',
      'rabat': 'Rabat',
    };
  }
}
  List<WeatherAlert> _checkForWeatherAlerts() {
    List<WeatherAlert> alerts = [];

    for (var segment in _routeSegments) {
      if (segment.startWeather.temperature > 35 ||
          segment.endWeather.temperature > 35) {
        alerts.add(
          WeatherAlert(
            type: "temp",
            message:
                "Température élevée (${segment.startWeather.temperature.toInt()}°C) sur ${segment.segmentName}",
            segment: segment.segmentName,
            color: Colors.orange,
            icon: Icons.warning,
          ),
        );
      }

      if (segment.startWeather.weatherCondition.contains('orage') ||
          segment.endWeather.weatherCondition.contains('orage')) {
        alerts.add(
          WeatherAlert(
            type: "storm",
            message: "Orages prévus sur ${segment.segmentName}",
            segment: segment.segmentName,
            color: Colors.deepPurple,
            icon: Icons.thunderstorm,
          ),
        );
      }

      if (segment.startWeather.weatherCondition.contains('pluie forte') ||
          segment.endWeather.weatherCondition.contains('pluie forte')) {
        alerts.add(
          WeatherAlert(
            type: "rain",
            message: "Pluie forte sur ${segment.segmentName}",
            segment: segment.segmentName,
            color: Colors.blue,
            icon: Icons.water_drop,
          ),
        );
      }

      if (segment.startWeather.windSpeed > 30 ||
          segment.endWeather.windSpeed > 30) {
        alerts.add(
          WeatherAlert(
            type: "wind",
            message:
                "Vent fort (${segment.startWeather.windSpeed.toInt()} km/h) sur ${segment.segmentName}",
            segment: segment.segmentName,
            color: Colors.green,
            icon: Icons.air,
          ),
        );
      }
    }

    return alerts;
  }

  void _navigateToAlertsPage() {
    final alerts = _checkForWeatherAlerts();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AlertsPage(alerts: alerts)),
    );
  }

  Widget _buildAlertsButton() {
    return FloatingActionButton(
      onPressed: _navigateToAlertsPage,
      backgroundColor: Colors.orange,
      mini: true,
      child: Badge(
        isLabelVisible: _checkForWeatherAlerts().isNotEmpty,
        label: Text(_checkForWeatherAlerts().length.toString()),
        child: Icon(Icons.notifications_active, color: Colors.white),
      ),
    );
  }

  Future<void> _getRecommendationFromAPI({
    required double temperature,
    required double humidity,
    required double windSpeed,
    required double rainIntensity,
  }) async {
    final url = Uri.parse('http://192.168.0.113:5000/predict');

    print('Envoi de la requête à: $url'); // Debug
    try {
      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "temperature": temperature,
              "humidity": humidity,
              "wind_speed": windSpeed,
              "rain_intensity": rainIntensity,
            }),
          )
          .timeout(Duration(seconds: 5));

      print('Réponse reçue: ${response.statusCode}'); // Debug
      print('Corps de la réponse: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final type = data['risk_type'];
        final level = data['risk_level'];
        final rec = data['recommendation'];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecommendationPage(
              riskType: type,
              riskLevel: double.tryParse(level.toString()) ?? 0.0,
              recommendation: rec,
            ),
          ),
        );
      } else {
        print("Erreur API : ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur API: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Erreur connexion API : $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur de connexion: $e")));
    }
  }

  Future<void> _proceedWithRouteCalculation(
    String displayName,
    LatLng destinationCoords,
  ) async {
    if (_currentLocation == null) return;

    setState(() {
      _isRouteCalculating = true;
      _selectedDestination = displayName;
      _showSearchBar = false;
    });

    try {
      final routePoints = await _fetchRoutePoints(
        _currentLocation!,
        destinationCoords,
      );

      await _calculateRouteSegments(routePoints);

      double totalDistance = 0;
      for (var segment in _routeSegments) {
        totalDistance += segment.distance;
      }

      _routeDistance = "${totalDistance.toStringAsFixed(0)} km";
      _routeDuration = "${(totalDistance / 80 * 60).toStringAsFixed(0)} min";

      List<Marker> routeMarkers = [];
      for (var segment in _routeSegments) {
        routeMarkers.add(
          Marker(
            point: segment.startPoint,
            width: 60,
            height: 60,
            child: _buildRouteWeatherMarker(segment.startWeather),
          ),
        );

        if (segment == _routeSegments.last) {
          routeMarkers.add(
            Marker(
              point: segment.endPoint,
              width: 60,
              height: 60,
              child: _buildRouteWeatherMarker(segment.endWeather),
            ),
          );
        }
      }

      Polyline routeLine = Polyline(
        points: routePoints,
        color: Color(0xFF00C853),
        strokeWidth: 4.0,
      );

      setState(() {
        _routeLines = [routeLine];
        _weatherMarkers = routeMarkers;
        _hasActiveRoute = true;
      });

      _fitMapToRoute(_currentLocation!, destinationCoords);
    } catch (e) {
      print('Erreur calcul route: $e');
      _showErrorSnackBar(
        "Erreur lors du calcul de l'itinéraire. Veuillez réessayer.",
      );
    } finally {
      setState(() {
        _isRouteCalculating = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

   _loadCitiesData().then((_) {
    _initializeLocation();
  });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchWeatherData(LatLng location) async {
    final cacheKey = '${location.latitude},${location.longitude}';

    if (_weatherCache.containsKey(cacheKey)) {
      return _weatherCache[cacheKey]!;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.openweathermap.org/data/2.5/weather?'
              'lat=${location.latitude}&lon=${location.longitude}'
              '&appid=$openWeatherApiKey&units=metric&lang=fr',
            ),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weatherData = {
          'temperature': data['main']['temp'],
          'condition': data['weather'][0]['description'],
          'humidity': data['main']['humidity'].toDouble(),
          'windSpeed': data['wind']['speed'].toDouble(),
          'rainIntensity': data['rain']?['1h'] ?? 0.0,
        };
        _weatherCache[cacheKey] = weatherData;
        return weatherData;
      } else {
        // Return default weather data if API fails
        return {
          'temperature': 20.0,
          'condition': 'partiellement nuageux',
          'humidity': 50.0,
          'windSpeed': 10.0,
          'rainIntensity': 0.0,
        };
      }
    } catch (e) {
      print('Error fetching weather data: $e');
      // Return default weather data
      return {
        'temperature': 20.0,
        'condition': 'partiellement nuageux',
        'humidity': 50.0,
        'windSpeed': 10.0,
      };
    }
  }

  Future<void> _initializeLocation() async {
    try {
      await _loadCitiesData();
      await _getCurrentLocation();
      await _loadInitialWeatherData();
    } catch (e) {
      print('Erreur initialisation: $e');
      setState(() {
        _currentLocation = _moroccanCities['Casablanca'];
        _currentLocationName = "Casablanca, Maroc";
        _isLocationLoading = false;
      });
      await _loadInitialWeatherData();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Services de localisation désactivés');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission de localisation refusée');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée définitivement');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String locationName = "Position actuelle";
      if (placemarks.isNotEmpty) {
        locationName =
            "${placemarks[0].locality ?? 'Position actuelle'}, Maroc";
      }

      setState(() {
        _currentLocation = newLocation;
        _currentLocationName = locationName;
        _isLocationLoading = false;
      });

      _mapController.move(_currentLocation!, 12.0);
    } catch (e) {
      print('Erreur géolocalisation: $e');
      setState(() {
        _currentLocation = _moroccanCities['Casablanca'] ?? 
          LatLng(33.5731, -7.5898); // Fallback explicite
        _currentLocationName = "Casablanca, Maroc";
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _loadInitialWeatherData() async {
    List<Marker> markers = [];

    for (var cityEntry in _moroccanCities.entries) {
      try {
        final weather = await _fetchWeatherData(cityEntry.value);
        final point = RouteWeatherPoint(
          location: cityEntry.value,
          weatherCondition: weather['condition'],
          temperature: weather['temperature'],
          weatherIcon: _getWeatherIcon(weather['condition']),
          weatherColor: _getWeatherColor(weather['condition']),
          cityName: cityEntry.key,
          humidity: weather['humidity'],
          windSpeed: weather['windSpeed'],
          rainIntensity: weather['rainIntensity'] ?? 0.0,
        );

        markers.add(
          Marker(
            point: cityEntry.value,
            width: 80,
            height: 80,
            child: _buildWeatherMarker(point),
          ),
        );
      } catch (e) {
        print('Erreur chargement météo pour ${cityEntry.key}: $e');
      }
    }

    setState(() {
      _weatherMarkers = markers;
    });
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('nuageux')) return Icons.cloud;
    if (condition.contains('pluie')) return Icons.water_drop;
    if (condition.contains('orage')) return Icons.thunderstorm;
    if (condition.contains('neige')) return Icons.ac_unit;
    if (condition.contains('soleil') || condition.contains('dégagé')) {
      return Icons.wb_sunny;
    }
    return Icons.cloud;
  }

  Color _getWeatherColor(String condition) {
    if (condition.contains('nuageux')) return Colors.blueGrey;
    if (condition.contains('pluie')) return Colors.blue;
    if (condition.contains('orage')) return Colors.deepPurple;
    if (condition.contains('neige')) return Colors.lightBlue;
    if (condition.contains('soleil') || condition.contains('dégagé')) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  Widget _buildWeatherMarker(RouteWeatherPoint point) {
    return GestureDetector(
      onTap: () => _showWeatherDetails(point),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              point.weatherColor.withOpacity(0.8),
              point.weatherColor.withOpacity(0.4),
              point.weatherColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: point.weatherColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(point.weatherIcon, color: Colors.white, size: 16),
                Text(
                  '${point.temperature.toInt()}°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteWeatherMarker(RouteWeatherPoint point) {
    return GestureDetector(
      onTap: () => _showWeatherDetails(point),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              point.weatherColor.withOpacity(0.8),
              point.weatherColor.withOpacity(0.4),
              point.weatherColor.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: point.weatherColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(point.weatherIcon, color: Colors.white, size: 12),
                Text(
                  '${point.temperature.toInt()}°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWeatherDetails(RouteWeatherPoint point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF1a1a1a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(point.weatherIcon, color: point.weatherColor, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.cityName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        point.weatherCondition,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${point.temperature.toInt()}°C',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.water_drop, color: Colors.blue),
                    Text(
                      '${point.humidity.toInt()}%',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Humidité',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.air, color: Colors.green),
                    Text(
                      '${point.windSpeed.toInt()} km/h',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Vent',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LatLng>> _fetchRoutePoints(LatLng start, LatLng end) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.openrouteservice.org/v2/directions/driving-car?'
              'api_key=$openRouteServiceApiKey'
              '&start=${start.longitude},${start.latitude}'
              '&end=${end.longitude},${end.latitude}',
            ),
            headers: {'Accept': 'application/json, application/geo+json'},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'];
        return coordinates
            .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
            .toList();
      } else {
        throw Exception(
          'Échec du chargement de la route: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erreur fetchRoutePoints: $e');
      throw Exception('Impossible de récupérer les points de la route');
    }
  }

  Future<void> _calculateRouteSegments(List<LatLng> routePoints) async {
    _routeSegments.clear();

    // Sample points along the route (every 10 points)
    final step = math.max(1, routePoints.length ~/ 10);

    for (int i = 0; i < routePoints.length - 1; i += step) {
      // Add delay between API calls
      if (i > 0) await Future.delayed(Duration(milliseconds: 200));

      LatLng start = routePoints[i];
      LatLng end = routePoints[math.min(i + step, routePoints.length - 1)];

      double distance =
          Geolocator.distanceBetween(
            start.latitude,
            start.longitude,
            end.latitude,
            end.longitude,
          ) /
          1000;

      String segmentName;
      if (i == 0) {
        segmentName = "Départ";
      } else if (i >= routePoints.length - step) {
        segmentName = "Arrivée";
      } else {
        segmentName = "Étape ${i ~/ step + 1}";
      }

      try {
        final startWeatherData = await _fetchWeatherData(start);
        final endWeatherData = await _fetchWeatherData(end);

        RouteWeatherPoint startWeather = RouteWeatherPoint(
          location: start,
          weatherCondition: startWeatherData['condition'],
          temperature: startWeatherData['temperature'],
          weatherIcon: _getWeatherIcon(startWeatherData['condition']),
          weatherColor: _getWeatherColor(startWeatherData['condition']),
          cityName: i == 0 ? "Départ" : "Point ${i ~/ step + 1}",
          humidity: startWeatherData['humidity'],
          windSpeed: startWeatherData['windSpeed'],
          rainIntensity: startWeatherData['rainIntensity'] ?? 0.0,
        );

        RouteWeatherPoint endWeather = RouteWeatherPoint(
          location: end,
          weatherCondition: endWeatherData['condition'],
          temperature: endWeatherData['temperature'],
          weatherIcon: _getWeatherIcon(endWeatherData['condition']),
          weatherColor: _getWeatherColor(endWeatherData['condition']),
          cityName: i >= routePoints.length - step
              ? "Arrivée"
              : "Point ${i ~/ step + 2}",
          humidity: endWeatherData['humidity'],
          windSpeed: endWeatherData['windSpeed'],
          rainIntensity: endWeatherData['rainIntensity'] ?? 0.0,
        );

        _routeSegments.add(
          RouteSegment(
            startPoint: start,
            endPoint: end,
            distance: distance,
            duration: distance / 80,
            segmentName: segmentName,
            startWeather: startWeather,
            endWeather: endWeather,
          ),
        );
      } catch (e) {
        print('Error in segment $i: $e');
        // Add segment with default weather data
        _routeSegments.add(
          RouteSegment(
            startPoint: start,
            endPoint: end,
            distance: distance,
            duration: distance / 80,
            segmentName: segmentName,
            startWeather: RouteWeatherPoint(
              location: start,
              weatherCondition: 'partiellement nuageux',
              temperature: 20.0,
              weatherIcon: Icons.cloud,
              weatherColor: Colors.blueGrey,
              cityName: i == 0 ? "Départ" : "Point ${i ~/ step + 1}",
              humidity: 50.0,
              windSpeed: 10.0,
              rainIntensity: 0.0,
            ),
            endWeather: RouteWeatherPoint(
              location: end,
              weatherCondition: 'partiellement nuageux',
              temperature: 20.0,
              weatherIcon: Icons.cloud,
              weatherColor: Colors.blueGrey,
              cityName: i >= routePoints.length - step
                  ? "Arrivée"
                  : "Point ${i ~/ step + 2}",
              humidity: 50.0,
              windSpeed: 10.0,
              rainIntensity: 0.0,
            ),
          ),
        );
      }
    }
  }

  Future<void> _calculateRouteWeather(String destination) async {
    if (destination.isEmpty) {
      _showErrorSnackBar("Veuillez entrer une destination");
      return;
    }

    final List<String> availableCities = _moroccanCities.keys.toList();
    final String? closestCity = findClosestCity(destination, availableCities);

    if (closestCity == null) {
      // Trouver les 3 meilleures correspondances pour les suggestions
      final suggestions = extractTop(
        query: destination.toLowerCase(),
        choices: availableCities,
        limit: 3,
        cutoff: 40,
      ).where((match) => match.score > 40).toList();

      if (suggestions.isNotEmpty) {
        final suggestionText = suggestions.map((s) => s.choice).join(', ');
        _showErrorSnackBar(
          "Ville non trouvée. Vouliez-vous dire : $suggestionText?",
          duration: Duration(seconds: 4),
        );
      } else {
        _showErrorSnackBar(
          "Ville non trouvée. Essayez un nom plus précis comme 'Marrakech', 'Casablanca'...",
          duration: Duration(seconds: 4),
        );
      }
      return;
    }

    // Si on a trouvé une ville proche mais différente de l'input
    if (destination.toLowerCase() != closestCity.toLowerCase()) {
      _showErrorSnackBar(
        "Itinéraire vers $closestCity",
        duration: Duration(seconds: 2),
      );
    }

    await _proceedWithRouteCalculation(
      closestCity,
      _moroccanCities[closestCity]!,
    );
  }

  void _fitMapToRoute(LatLng start, LatLng end) {
    double minLat = math.min(start.latitude, end.latitude);
    double maxLat = math.max(start.latitude, end.latitude);
    double minLng = math.min(start.longitude, end.longitude);
    double maxLng = math.max(start.longitude, end.longitude);

    LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    double zoom = _calculateZoomLevel(minLat, maxLat, minLng, maxLng);
    _mapController.move(center, zoom);
  }

  double _calculateZoomLevel(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
  ) {
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = math.max(latDiff, lngDiff);

    if (maxDiff > 5) return 6.0;
    if (maxDiff > 2) return 8.0;
    if (maxDiff > 1) return 9.0;
    if (maxDiff > 0.5) return 10.0;
    return 11.0;
  }

  void _showErrorSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routeLines.clear();
      _routeSegments.clear();
      _hasActiveRoute = false;
      _showSearchBar = true;
      _searchController.clear();
    });

    // Recharger les marqueurs météo des villes
    _loadInitialWeatherData();

    // Revenir à la vue initiale
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 6.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildHeader(),

          if (_showSearchBar) _buildSearchBar(),
          if (_hasActiveRoute) ...[
            _buildRouteInfo(),
            _buildRouteSegmentsList(),
            _buildChangeDestinationButton(),
          ],
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLocationButton(),
                SizedBox(height: 8), // Espace de 8 pixels
                if (_hasActiveRoute) _buildResetButton(),
                if (_hasActiveRoute) SizedBox(height: 8), // Espace conditionnel
                _buildAlertsButton(),
                SizedBox(height: 8), // Espace de 8 pixels
                _buildRecommendationButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
     final fallbackLocation = LatLng(33.5731, -7.5898); // Casablanca par défaut
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation ?? _moroccanCities['Casablanca']!,
        initialZoom: _hasActiveRoute ? 8.0 : 6.0,
        minZoom: 5.0,
        maxZoom: 16.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.weatherroute',
        ),
        if (_routeLines.isNotEmpty) PolylineLayer(polylines: _routeLines),
        if (_weatherMarkers.isNotEmpty) MarkerLayer(markers: _weatherMarkers),
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Météo Route',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isLocationLoading)
                      Row(
                        children: [
                          SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00C853),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Localisation...',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _currentLocationName,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                  ],
                ),
              ),
              Icon(Icons.location_on, color: Color(0xFF00C853), size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher une destination...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: _isRouteCalculating
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00C853),
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.arrow_forward, color: Color(0xFF00C853)),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        _calculateRouteWeather(_searchController.text);
                      }
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _calculateRouteWeather(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Positioned(
      top: 190,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a1a).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF00C853), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Color(0xFF00C853), size: 20),
                SizedBox(width: 8),
                Text(
                  'Route vers $_selectedDestination',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.straighten, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text(_routeDistance, style: TextStyle(color: Colors.white)),
                SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(_routeDuration, style: TextStyle(color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSegmentsList() {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        height: 150,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _routeSegments.length,
          itemBuilder: (context, index) {
            final segment = _routeSegments[index];
            return Container(
              width: 200,
              margin: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Color(0xFF1a1a1a).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF00C853), width: 1),
              ),
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    segment.segmentName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.blue, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${segment.distance.toStringAsFixed(1)} km",
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.access_time, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "${(segment.duration * 60).toStringAsFixed(0)} min",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Icon(
                            segment.startWeather.weatherIcon,
                            color: segment.startWeather.weatherColor,
                          ),
                          Text(
                            "${segment.startWeather.temperature.toInt()}°C",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: Colors.grey),
                      Column(
                        children: [
                          Icon(
                            segment.endWeather.weatherIcon,
                            color: segment.endWeather.weatherColor,
                          ),
                          Text(
                            "${segment.endWeather.temperature.toInt()}°C",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendationButton() {
    return FloatingActionButton(
      onPressed: () {
        if (_routeSegments.isNotEmpty) {
          final firstSegment = _routeSegments.first;
          final weather = firstSegment.startWeather;
          _getRecommendationFromAPI(
            temperature: weather.temperature,
            humidity: weather.humidity,
            windSpeed: weather.windSpeed,
            rainIntensity: weather.rainIntensity,
          );
        }
      },
      backgroundColor: Colors.blueAccent,
      mini: true,
      child: Icon(Icons.tips_and_updates, color: Colors.white),
    );
  }

  Widget _buildChangeDestinationButton() {
    return Positioned(
      top: 120,
      right: 16,
      child: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showSearchBar = true;
            _hasActiveRoute = false;
          });
        },
        backgroundColor: Color(0xFF1a1a1a),
        mini: true,
        child: Icon(Icons.edit_location, color: Colors.white),
      ),
    );
  }

  Widget _buildLocationButton() {
    return FloatingActionButton(
      onPressed: _getCurrentLocation,
      backgroundColor: Color(0xFF00C853),
      mini: true,
      child: _isLocationLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(Icons.my_location, color: Colors.white),
    );
  }

  Widget _buildResetButton() {
    return FloatingActionButton(
      onPressed: _clearRoute,
      backgroundColor: Colors.red[700],
      mini: true,
      child: Icon(Icons.clear, color: Colors.white),
    );
  }
}
