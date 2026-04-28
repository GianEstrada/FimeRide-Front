import 'dart:convert';

import 'package:fimeride_front/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PreinicioConductorScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;

  const PreinicioConductorScreen({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  Future<void> _accionConductor(BuildContext context, String accion) async {
    final viajeId = data['viaje_id'];
    final url = Uri.parse('https://fimeride.onrender.com/api/viajes/$viajeId/accion_conductor/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accion': accion}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (accion == 'iniciar' && context.mounted) {
        Navigator.of(context).pop();
      }
      await onRefresh();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo ejecutar la accion: ${response.body}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pasajeros = (data['pasajeros'] as List<dynamic>? ?? []);
    final puedeIniciar = data['puede_iniciar'] == true;
    final puedeEsperarMas = data['puede_esperar_5_mas'] == true;
    final origenLat = (data['origen_lat'] as num?)?.toDouble();
    final origenLng = (data['origen_lng'] as num?)?.toDouble();
    final destinoLat = (data['destino_lat'] as num?)?.toDouble();
    final destinoLng = (data['destino_lng'] as num?)?.toDouble();
    final canShowMap =
        origenLat != null && origenLng != null && destinoLat != null && destinoLng != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Preinicio del viaje')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ruta: ${data['inicio']} -> ${data['destino']}'),
            const SizedBox(height: 8),
            Text('Hora salida: ${data['hora_salida']}'),
            const SizedBox(height: 8),
            Text('Conductor: ${data['conductor_nombre'] ?? 'Conductor'}'),
            const SizedBox(height: 8),
            Text('Vehiculo: ${data['vehiculo']}'),
            if ((data['placas_vehiculo'] as String?)?.isNotEmpty == true)
              Text('Placas: ${data['placas_vehiculo']}'),
            const SizedBox(height: 12),
            if (canShowMap)
              SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(origenLat, origenLng),
                    zoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(origenLat, origenLng),
                          width: 40,
                          height: 40,
                          builder: (_) => const Icon(Icons.trip_origin, color: Colors.green),
                        ),
                        Marker(
                          point: LatLng(destinoLat, destinoLng),
                          width: 40,
                          height: 40,
                          builder: (_) => const Icon(Icons.location_pin, color: Colors.red),
                        ),
                      ],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [LatLng(origenLat, origenLng), LatLng(destinoLat, destinoLng)],
                          strokeWidth: 4,
                          color: Colors.blue,
                        )
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Pasajeros', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: pasajeros.length,
                itemBuilder: (context, index) {
                  final pasajero = pasajeros[index] as Map<String, dynamic>;
                  final abordo = pasajero['abordo_confirmado'] == true;
                  return ListTile(
                    leading: Icon(
                      abordo ? Icons.check_circle : Icons.hourglass_bottom,
                      color: abordo ? Colors.green : Colors.orange,
                    ),
                    title: Text(pasajero['nombre'] ?? 'Pasajero'),
                    subtitle: Text(abordo ? 'Confirmado a bordo' : 'Pendiente por confirmar'),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: puedeIniciar
                        ? () => _accionConductor(context, 'iniciar')
                        : null,
                    child: const Text('Iniciar viaje'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: puedeEsperarMas
                        ? () => _accionConductor(context, 'esperar_5_mas')
                        : null,
                    child: const Text('Esperar 5 min mas'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class PreinicioPasajeroScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onConfirmarAbordo;

  const PreinicioPasajeroScreen({
    super.key,
    required this.data,
    required this.onConfirmarAbordo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preinicio del viaje')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu viaje: ${data['inicio']} -> ${data['destino']}'),
            const SizedBox(height: 8),
            Text('Hora salida: ${data['hora_salida']}'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onConfirmarAbordo,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar que ya subi al vehiculo'),
            ),
          ],
        ),
      ),
    );
  }
}
