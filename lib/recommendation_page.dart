import 'package:flutter/material.dart';

class RecommendationPage extends StatelessWidget {
  final String riskType;
  final double riskLevel;
  final String recommendation;

  const RecommendationPage({
    required this.riskType,
    required this.riskLevel,
    required this.recommendation,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Détermine la couleur et l'icône selon le niveau de risque
    final Map<String, dynamic> riskData = getRiskInfo(riskLevel, riskType);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 201, 202, 207),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 25,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: riskData['color'],
                  child: Icon(
                    riskData['icon'],
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  recommendation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Chip(
                  label: Text(
                    "Type de risque : $riskType",
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: riskData['color'],
                ),
                const SizedBox(height: 10),
                Text(
                  "Niveau de risque : ${riskLevel.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: riskData['color'],
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Retour"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> getRiskInfo(double level, String type) {
    if (type == "normal" || level == 0.0) {
      return {"color": Colors.green, "icon": Icons.wb_sunny};
    } else if (level <= 0.3) {
      return {"color": Colors.yellow[700], "icon": Icons.cloud};
    } else if (level <= 0.6) {
      return {"color": Colors.orange, "icon": Icons.cloud_queue};
    } else if (level <= 0.8) {
      return {"color": Colors.red, "icon": Icons.warning};
    } else {
      return {"color": Colors.purple, "icon": Icons.ac_unit};
    }
  }
}
