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

final Map<String, String> _cityVariations = {
  // Casablanca
  'casablanca': 'Casablanca',
  'casa': 'Casablanca',
  'dar beida': 'Casablanca',
  'dar el beida': 'Casablanca',
  'casabianca': 'Casablanca',
  'casabalnca': 'Casablanca',
  'casablanca': 'Casablanca',

  // Rabat
  'rabat': 'Rabat',
  'rabatt': 'Rabat',
  'rebat': 'Rabat',
  'rabbat': 'Rabat',

  // Marrakech
  'marrakech': 'Marrakech',
  'marrakesh': 'Marrakech',
  'marakech': 'Marrakech',
  'marakesh': 'Marrakech',
  'marakkech': 'Marrakech',
  'marrakch': 'Marrakech',
  'marrakec': 'Marrakech',
  'marakeche': 'Marrakech',
  'marakesch': 'Marrakech',

  // Fès
  'fes': 'Fès',
  'fez': 'Fès',
  'fas': 'Fès',
  'fass': 'Fès',

  // Tanger
  'tanger': 'Tanger',
  'tangier': 'Tanger',
  'tangiers': 'Tanger',
  'tanja': 'Tanger',
  'tangere': 'Tanger',
  'tanjer': 'Tanger',

  // Agadir
  'agadir': 'Agadir',
  'agadier': 'Agadir',
  'agadire': 'Agadir',
  'agader': 'Agadir',

  // Salé
  'sale': 'Salé',
  'salé': 'Salé',
  'sala': 'Salé',
  'salle': 'Salé',

  // Meknès
  'meknes': 'Meknès',
  'meknès': 'Meknès',
  'meknas': 'Meknès',
  'meknass': 'Meknès',
  'mequinez': 'Meknès',
  'mekinez': 'Meknès',

  // Oujda
  'oujda': 'Oujda',
  'oujeda': 'Oujda',
  'wajda': 'Oujda',
  'ujda': 'Oujda',

  // Kenitra
  'kenitra': 'Kenitra',
  'kenitra': 'Kenitra',
  'kénitra': 'Kenitra',
  'qenitra': 'Kenitra',
  'port lyautey': 'Kenitra',

  // Tétouan
  'tetouan': 'Tétouan',
  'tétouan': 'Tétouan',
  'tetuan': 'Tétouan',
  'titwan': 'Tétouan',
  'tetuoan': 'Tétouan',

  // Safi
  'safi': 'Safi',
  'saffi': 'Safi',
  'asfi': 'Safi',

  // Mohammedia
  'mohammedia': 'Mohammedia',
  'mohamedia': 'Mohammedia',
  'mohammadya': 'Mohammedia',
  'fedala': 'Mohammedia',

  // Khouribga
  'khouribga': 'Khouribga',
  'khouribgha': 'Khouribga',
  'khuribga': 'Khouribga',
  'houribga': 'Khouribga',

  // El Jadida
  'el jadida': 'El Jadida',
  'eljadida': 'El Jadida',
  'jadida': 'El Jadida',
  'el-jadida': 'El Jadida',
  'mazagan': 'El Jadida',

  // Beni Mellal
  'beni mellal': 'Beni Mellal',
  'benimellal': 'Beni Mellal',
  'bni mellal': 'Beni Mellal',

  // Nador
  'nador': 'Nador',
  'nadur': 'Nador',
  'nadir': 'Nador',

  // Taza
  'taza': 'Taza',
  'taza': 'Taza',
  'teza': 'Taza',

  // Settat
  'settat': 'Settat',
  'setttat': 'Settat',
  'setat': 'Settat',

  // Larache
  'larache': 'Larache',
  'el araish': 'Larache',
  'elaraish': 'Larache',
  'araish': 'Larache',

  // Ksar El Kebir
  'ksar el kebir': 'Ksar El Kebir',
  'ksar elkebir': 'Ksar El Kebir',
  'ksarelkebir': 'Ksar El Kebir',
  'alcazarquivir': 'Ksar El Kebir',

  // Khemisset
  'khemisset': 'Khemisset',
  'khémisset': 'Khemisset',
  'khemiset': 'Khemisset',
  'khmisset': 'Khemisset',

  // Guelmim
  'guelmim': 'Guelmim',
  'goulimine': 'Guelmim',
  'guelmin': 'Guelmim',
  'guellmim': 'Guelmim',

  // Berrechid
  'berrechid': 'Berrechid',
  'berrachid': 'Berrechid',
  'brechid': 'Berrechid',

  // Oued Zem
  'oued zem': 'Oued Zem',
  'ouedzem': 'Oued Zem',
  'wed zem': 'Oued Zem',

  // Taourirt
  'taourirt': 'Taourirt',
  'tawrirt': 'Taourirt',
  'taourit': 'Taourirt',

  // Berkane
  'berkane': 'Berkane',
  'berkan': 'Berkane',
  'barkane': 'Berkane',

  // Tiznit
  'tiznit': 'Tiznit',
  'tiznet': 'Tiznit',
  'tizneet': 'Tiznit',

  // Tan-Tan
  'tan-tan': 'Tan-Tan',
  'tantan': 'Tan-Tan',
  'tan tan': 'Tan-Tan',

  // Ouarzazate
  'ouarzazate': 'Ouarzazate',
  'warzazat': 'Ouarzazate',
  'ouarzazat': 'Ouarzazate',
  'warzazate': 'Ouarzazate',
  'ourzazate': 'Ouarzazate',

  // Dakhla
  'dakhla': 'Dakhla',
  'dajla': 'Dakhla',
  'dakla': 'Dakhla',
  'villa cisneros': 'Dakhla',

  // Laayoune
  'laayoune': 'Laayoune',
  'layoune': 'Laayoune',
  'el aaiun': 'Laayoune',
  'el ayoun': 'Laayoune',
  'aaiun': 'Laayoune',

  // Chefchaouen
  'chefchaouen': 'Chefchaouen',
  'chaouen': 'Chefchaouen',
  'chef chaouen': 'Chefchaouen',
  'chefchaoun': 'Chefchaouen',
  'xauen': 'Chefchaouen',
  'chaoun': 'Chefchaouen',

  // Essaouira
  'essaouira': 'Essaouira',
  'saouira': 'Essaouira',
  'mogador': 'Essaouira',
  'esaouira': 'Essaouira',
  'essawira': 'Essaouira',

  // Ifrane
  'ifrane': 'Ifrane',
  'ifran': 'Ifrane',
  'ifren': 'Ifrane',

  // Azrou
  'azrou': 'Azrou',
  'azru': 'Azrou',
  'azroo': 'Azrou',

  // Midelt
  'midelt': 'Midelt',
  'midlet': 'Midelt',
  'midalt': 'Midelt',

  // Errachidia
  'errachidia': 'Errachidia',
  'rachidia': 'Errachidia',
  'rachidiya': 'Errachidia',
  'ksar es souk': 'Errachidia',

  // Zagora
  'zagora': 'Zagora',
  'zagorra': 'Zagora',
  'zagoura': 'Zagora',

  // Merzouga
  'merzouga': 'Merzouga',
  'merzuga': 'Merzouga',
  'merzouga': 'Merzouga',

  // Tinghir
  'tinghir': 'Tinghir',
  'tineghir': 'Tinghir',
  'tinerhir': 'Tinghir',
  'tinrir': 'Tinghir',

  // Tafraoute
  'tafraoute': 'Tafraoute',
  'tafraout': 'Tafraoute',
  'tafraut': 'Tafraoute',

  // Asilah
  'asilah': 'Asilah',
  'asila': 'Asilah',
  'arcila': 'Asilah',
  'arzila': 'Asilah',

  // Al Hoceima
  'al hoceima': 'Al Hoceima',
  'alhoceima': 'Al Hoceima',
  'alhucemas': 'Al Hoceima',
  'hoceima': 'Al Hoceima',

  // Martil
  'martil': 'Martil',
  'martiel': 'Martil',
  'marteel': 'Martil',

  // Cabo Negro
  'cabo negro': 'Cabo Negro',
  'cabonegro': 'Cabo Negro',
  'cap negro': 'Cabo Negro',

  // Mehdia
  'mehdia': 'Mehdia',
  'mehdya': 'Mehdia',
  'medya': 'Mehdia',

  // Oualidia
  'oualidia': 'Oualidia',
  'walidia': 'Oualidia',
  'oualidya': 'Oualidia',

  // Sidi Ifni
  'sidi ifni': 'Sidi Ifni',
  'sidiifni': 'Sidi Ifni',
  'si ifni': 'Sidi Ifni',

  // Boulemane
  'boulemane': 'Boulemane',
  'boulman': 'Boulemane',
  'boulmane': 'Boulemane',

  // Figuig
  'figuig': 'Figuig',
  'figig': 'Figuig',
  'figuigue': 'Figuig',

  // Jerada
  'jerada': 'Jerada',
  'jrada': 'Jerada',
  'jerrada': 'Jerada',

  // Sidi Slimane
  'sidi slimane': 'Sidi Slimane',
  'sidislimane': 'Sidi Slimane',
  'si slimane': 'Sidi Slimane',

  // Sidi Kacem
  'sidi kacem': 'Sidi Kacem',
  'sidikacem': 'Sidi Kacem',
  'si kacem': 'Sidi Kacem',

  // Youssoufia
  'youssoufia': 'Youssoufia',
  'yousoufia': 'Youssoufia',
  'louis gentil': 'Youssoufia',

  // Skhirate
  'skhirate': 'Skhirate',
  'skhiratt': 'Skhirate',
  'skirate': 'Skhirate',

  // Temara
  'temara': 'Temara',
  'tmara': 'Temara',
  'témara': 'Temara',

  // Ain Harrouda
  'ain harrouda': 'Ain Harrouda',
  'ainharrouda': 'Ain Harrouda',
  'ain harouda': 'Ain Harrouda',

  // Ben Guerir
  'ben guerir': 'Ben Guerir',
  'benguerir': 'Ben Guerir',
  'ben grir': 'Ben Guerir',

  // Lieux emblématiques de Casablanca
  'hassan ii mosque': 'Hassan II Mosque',
  'hassan 2 mosque': 'Hassan II Mosque',
  'mosquee hassan ii': 'Hassan II Mosque',
  'mosquée hassan ii': 'Hassan II Mosque',
  'mosquee hassan 2': 'Hassan II Mosque',
  'grande mosquee': 'Hassan II Mosque',

  'quartier habous': 'Quartier Habous',
  'habous': 'Quartier Habous',
  'habous quarter': 'Quartier Habous',
  'nouvelle medina': 'Quartier Habous',

  'place mohammed v': 'Place Mohammed V',
  'place mohammed 5': 'Place Mohammed V',
  'mohammed v square': 'Place Mohammed V',
  'place moh v': 'Place Mohammed V',

  'cathedrale du sacre-coeur': 'Cathédrale du Sacré-Cœur',
  'cathedrale': 'Cathédrale du Sacré-Cœur',
  'sacred heart cathedral': 'Cathédrale du Sacré-Cœur',
  'sacre coeur': 'Cathédrale du Sacré-Cœur',

  'marche central': 'Marché Central',
  'marché central': 'Marché Central',
  'central market': 'Marché Central',
  'marche': 'Marché Central',

  'corniche ain diab': 'Corniche Ain Diab',
  'corniche': 'Corniche Ain Diab',
  'ain diab': 'Corniche Ain Diab',
  'aindiab': 'Corniche Ain Diab',

  'twin center': 'Twin Center',
  'twins center': 'Twin Center',
  'twin centre': 'Twin Center',
  'tours jumelles': 'Twin Center',

  'morocco mall': 'Morocco Mall',
  'morocco mall': 'Morocco Mall',
  'maroc mall': 'Morocco Mall',

  'ancienne medina': 'Ancienne Médina',
  'ancienne médina': 'Ancienne Médina',
  'old medina': 'Ancienne Médina',
  'medina': 'Ancienne Médina',
  'médina': 'Ancienne Médina',

  'port de casablanca': 'Port de Casablanca',
  'port casa': 'Port de Casablanca',
  'casablanca port': 'Port de Casablanca',
  'port': 'Port de Casablanca',

  'parc de la ligue arabe': 'Parc de la Ligue Arabe',
  'parc ligue arabe': 'Parc de la Ligue Arabe',
  'ligue arabe': 'Parc de la Ligue Arabe',
  'arab league park': 'Parc de la Ligue Arabe',

  'boulevard zerktouni': 'Boulevard Zerktouni',
  'zerktouni': 'Boulevard Zerktouni',
  'bd zerktouni': 'Boulevard Zerktouni',

  'quartier gauthier': 'Quartier Gauthier',
  'gauthier': 'Quartier Gauthier',
  'gauthier quarter': 'Quartier Gauthier',

  'anfa place': 'Anfa Place',
  'anfa': 'Anfa Place',
  'anfaplace': 'Anfa Place',

  'sidi abderrahman': 'Sidi Abderrahman',
  'sidi abderrahmane': 'Sidi Abderrahman',
  'si abderrahman': 'Sidi Abderrahman',

  'quartier maarif': 'Quartier Maarif',
  'maarif': 'Quartier Maarif',
  'maarif quarter': 'Quartier Maarif',
  'ma3arif': 'Quartier Maarif',

  'technopark': 'Technopark',
  'techno park': 'Technopark',
  'techno parc': 'Technopark',

  'zenata': 'Zenata',
  'zinata': 'Zenata',
  'znata': 'Zenata',

  'stade mohammed v': 'Stade Mohammed V',
  'stade mohammed 5': 'Stade Mohammed V',
  'stadium mohammed v': 'Stade Mohammed V',
  'complexe mohammed v': 'Stade Mohammed V',

  'villa des arts': 'Villa des Arts',
  'villa arts': 'Villa des Arts',
  'villa d arts': 'Villa des Arts',

  'quartier bourgogne': 'Quartier Bourgogne',
  'bourgogne': 'Quartier Bourgogne',

  'quartier racine': 'Quartier Racine',
  'racine': 'Quartier Racine',

  'quartier des hopitaux': 'Quartier des Hôpitaux',
  'quartier des hôpitaux': 'Quartier des Hôpitaux',
  'quartier hopitaux': 'Quartier des Hôpitaux',
  'hopitaux': 'Quartier des Hôpitaux',

  'quartier palmier': 'Quartier Palmier',
  'palmier': 'Quartier Palmier',

  'quartier oasis': 'Quartier Oasis',
  'oasis': 'Quartier Oasis',

  'quartier californie': 'Quartier Californie',
  'californie': 'Quartier Californie',
  'california': 'Quartier Californie',

  'quartier beausejour': 'Quartier Beauséjour',
  'quartier beauséjour': 'Quartier Beauséjour',
  'beausejour': 'Quartier Beauséjour',
  'beauséjour': 'Quartier Beauséjour',

  'quartier polo': 'Quartier Polo',
  'polo': 'Quartier Polo',

  'quartier oulfa': 'Quartier Oulfa',
  'oulfa': 'Quartier Oulfa',
  'wlfa': 'Quartier Oulfa',

  'quartier hay mohammadi': 'Quartier Hay Mohammadi',
  'hay mohammadi': 'Quartier Hay Mohammadi',
  'haymohammadi': 'Quartier Hay Mohammadi',
  'mohammadi': 'Quartier Hay Mohammadi',
};
String? findClosestCity(String userInput, List<String> cities) {
  if (userInput.isEmpty) return null;

  final normalizedInput = userInput.toLowerCase().trim();

  if (_cityVariations.containsKey(normalizedInput)) {
    return _cityVariations[normalizedInput];
  }

  final exactMatch = cities.firstWhere(
    (city) => city.toLowerCase() == normalizedInput,
    orElse: () => '',
  );

  if (exactMatch.isNotEmpty) return exactMatch;

  final bestMatch = extractTop(
    query: normalizedInput,
    choices: cities,
    limit: 1,
    cutoff: 60,
  ).firstOrNull;

  return (bestMatch != null && bestMatch.score >= 60) ? bestMatch.choice : null;
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

  final Map<String, LatLng> _moroccanCities = {
    // Grandes métropoles
    'Casablanca': LatLng(33.5731, -7.5898),
    'Rabat': LatLng(34.0209, -6.8416),
    'Marrakech': LatLng(31.6295, -7.9811),
    'Fès': LatLng(34.0181, -5.0078),
    'Tanger': LatLng(35.7595, -5.8340),
    'Agadir': LatLng(30.4278, -9.5981),

    // Villes importantes
    'Salé': LatLng(34.0531, -6.7985),
    'Meknès': LatLng(33.8935, -5.5473),
    'Oujda': LatLng(34.6814, -1.9086),
    'Kenitra': LatLng(34.2610, -6.5802),
    'Tétouan': LatLng(35.5889, -5.3626),
    'Safi': LatLng(32.2994, -9.2372),
    'Mohammedia': LatLng(33.6861, -7.3826),
    'Khouribga': LatLng(32.8811, -6.9063),
    'El Jadida': LatLng(33.2316, -8.5007),
    'Beni Mellal': LatLng(32.3373, -6.3498),
    'Nador': LatLng(35.1681, -2.9287),
    'Taza': LatLng(34.2133, -4.0103),

    // Villes moyennes
    'Settat': LatLng(33.0018, -7.6160),
    'Larache': LatLng(35.1932, -6.1563),
    'Ksar El Kebir': LatLng(35.0017, -5.9090),
    'Khemisset': LatLng(33.8244, -6.0691),
    'Guelmim': LatLng(28.9870, -10.0574),
    'Berrechid': LatLng(33.2655, -7.5877),
    'Oued Zem': LatLng(32.8634, -6.5735),
    'Taourirt': LatLng(34.4092, -2.8953),
    'Berkane': LatLng(34.9252, -2.3220),
    'Tiznit': LatLng(29.6974, -9.7316),
    'Tan-Tan': LatLng(28.4378, -11.1036),
    'Ouarzazate': LatLng(30.9335, -6.9370),
    'Dakhla': LatLng(23.7185, -15.9582),
    'Laayoune': LatLng(27.1253, -13.1625),

    // Villes touristiques et historiques
    'Chefchaouen': LatLng(35.1688, -5.2636),
    'Essaouira': LatLng(31.5084, -9.7595),
    'Ifrane': LatLng(33.5228, -5.1106),
    'Azrou': LatLng(33.4345, -5.2110),
    'Midelt': LatLng(32.6852, -4.7345),
    'Errachidia': LatLng(31.9314, -4.4244),
    'Zagora': LatLng(30.3276, -5.8368),
    'Merzouga': LatLng(31.0801, -4.0135),
    'Tinghir': LatLng(31.5145, -5.5331),
    'Tafraoute': LatLng(29.7252, -8.9739),

    // Villes côtières
    'Asilah': LatLng(35.4656, -6.0353),
    'Al Hoceima': LatLng(35.2517, -3.9372),
    'Martil': LatLng(35.6178, -5.2756),
    'Cabo Negro': LatLng(35.6889, -5.2944),
    'Mehdia': LatLng(34.2542, -6.6436),
    'Oualidia': LatLng(32.7364, -9.0306),
    'Sidi Ifni': LatLng(29.3797, -10.1731),

    // Autres villes importantes
    'Boulemane': LatLng(33.3623, -4.7288),
    'Figuig': LatLng(32.1091, -1.2255),
    'Jerada': LatLng(34.3142, -2.1625),
    'Sidi Slimane': LatLng(34.2654, -5.9263),
    'Sidi Kacem': LatLng(34.2214, -5.7081),
    'Youssoufia': LatLng(32.2465, -8.5311),
    'Skhirate': LatLng(33.8569, -7.0403),
    'Temara': LatLng(33.9289, -6.9067),
    'Ain Harrouda': LatLng(33.6380, -7.2580),
    'Ben Guerir': LatLng(32.2362, -7.9541),

    // Lieux emblématiques de Casablanca
    'Hassan II Mosque': LatLng(33.6080, -7.6327),
    'Quartier Habous': LatLng(33.5845, -7.6103),
    'Place Mohammed V': LatLng(33.5928, -7.6192),
    'Cathédrale du Sacré-Cœur': LatLng(33.5956, -7.6212),
    'Marché Central': LatLng(33.5943, -7.6167),
    'Corniche Ain Diab': LatLng(33.5518, -7.6615),
    'Twin Center': LatLng(33.5911, -7.6261),
    'Morocco Mall': LatLng(33.5464, -7.6686),
    'Ancienne Médina': LatLng(33.5970, -7.6151),
    'Port de Casablanca': LatLng(33.6061, -7.6183),
    'Parc de la Ligue Arabe': LatLng(33.5867, -7.6353),
    'Boulevard Zerktouni': LatLng(33.5877, -7.6242),
    'Quartier Gauthier': LatLng(33.5910, -7.6230),
    'Anfa Place': LatLng(33.5738, -7.6410),
    'Sidi Abderrahman': LatLng(33.5371, -7.6898),
    'Quartier Maarif': LatLng(33.5836, -7.6198),
    'Technopark': LatLng(33.5202, -7.6600),
    'Zenata': LatLng(33.6425, -7.4892),
    'Stade Mohammed V': LatLng(33.5267, -7.6591),
    'Villa des Arts': LatLng(33.5889, -7.6403),
    'Quartier Bourgogne': LatLng(33.5756, -7.6456),
    'Quartier Racine': LatLng(33.5694, -7.6523),
    'Quartier des Hôpitaux': LatLng(33.5799, -7.6442),
    'Quartier Palmier': LatLng(33.5833, -7.6389),
    'Quartier Oasis': LatLng(33.5500, -7.6800),
    'Quartier Californie': LatLng(33.5600, -7.6650),
    'Quartier Beauséjour': LatLng(33.5722, -7.6500),
    'Quartier Polo': LatLng(33.5650, -7.6400),
    'Quartier Oulfa': LatLng(33.5550, -7.5900),
    'Quartier Hay Mohammadi': LatLng(33.5450, -7.5500),
  };

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

    _initializeLocation();
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
        _currentLocation = _moroccanCities['Casablanca'];
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
