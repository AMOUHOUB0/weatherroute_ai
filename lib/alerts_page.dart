import 'package:flutter/material.dart';
import 'main.dart';


class AlertsPage extends StatelessWidget {
  final List<WeatherAlert> alerts;

  AlertsPage({required this.alerts});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes Météo'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF0a0a0a),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, 
                      size: 60, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune alerte météo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Conditions météo normales sur votre trajet',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: const Color(0xFF1a1a1a),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: alert.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: alert.color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(alert.icon, color: alert.color),
                    ),
                    title: Text(
                      alert.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      alert.segment,
                      style: TextStyle(
                        color: Colors.grey[400],
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[600],
                    ),
                    onTap: () {
                      // Vous pourriez ajouter une action quand on clique sur une alerte
                    },
                  ),
                );
              },
            ),
    );
  }
}