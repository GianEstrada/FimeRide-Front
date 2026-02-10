import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class ViajeEnProcesoScreen extends StatefulWidget {
  final LatLng startPoint;
  final LatLng endPoint;
  final String direccionInicio;
  final String direccionFinal;
  final String conductorNombre;
  final String conductorFoto;
  final String modeloVehiculo;
  final String placasVehiculo;
  // Added: mapbox access token must be provided at runtime (not stored in repo)
  final String mapboxAccessToken;

  const ViajeEnProcesoScreen({
    Key? key,
    required this.startPoint,
    required this.endPoint,
    required this.direccionInicio,
    required this.direccionFinal,
    required this.conductorNombre,
    required this.conductorFoto,
    required this.modeloVehiculo,
    required this.placasVehiculo,
    required this.mapboxAccessToken,
  }) : super(key: key);

  @override
  _ViajeEnProcesoScreenState createState() => _ViajeEnProcesoScreenState();
}

class _ViajeEnProcesoScreenState extends State<ViajeEnProcesoScreen> {
  List<LatLng> _routePoints = [];
  String _estadoViaje = "En camino"; // Estado inicial del viaje
  int _tiempoRestante = 0; // Tiempo estimado de llegada en minutos

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _calcularTiempoRestante();
  }

  Future<void> _loadRoute() async {
    final route = await _getRoute(widget.startPoint, widget.endPoint);
    setState(() {
      _routePoints = route;
    });
  }

  Future<List<LatLng>> _getRoute(LatLng start, LatLng end) async {
    final String url =
        // use the token provided to the widget instead of a hardcoded value
        "https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=${widget.mapboxAccessToken}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates
            .map((coord) => LatLng(coord[1], coord[0]))
            .toList();
      } else {
        print("Error al obtener la ruta: ${response.statusCode}");
      }
    } catch (e) {
      print("Error al conectar con la API de Mapbox Directions: $e");
    }
    return [];
  }

  void _calcularTiempoRestante() {
    // Simula el cálculo del tiempo restante (puedes usar datos reales si tienes acceso a ellos)
    setState(() {
      _tiempoRestante = 15; // Ejemplo: 15 minutos restantes
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    TextStyle generalTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.045,
    );

    TextStyle headerTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.06,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 162, 100),
                  Color.fromARGB(255, 0, 87, 54),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  "Viaje en Proceso",
                  style: headerTextStyle,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FlutterMap(
                            options: MapOptions(
                              center: widget.startPoint,
                              zoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=${widget.mapboxAccessToken}",
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: widget.startPoint,
                                    width: 80.0,
                                    height: 80.0,
                                    builder: (ctx) => const Icon(
                                      Icons.location_pin,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                  ),
                                  Marker(
                                    point: widget.endPoint,
                                    width: 80.0,
                                    height: 80.0,
                                    builder: (ctx) => const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                              if (_routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routePoints,
                                      strokeWidth: 4.0,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text("Estado del viaje: $_estadoViaje", style: generalTextStyle),
                        Text("Tiempo restante: $_tiempoRestante minutos", style: generalTextStyle),
                        Text("Conductor: ${widget.conductorNombre}", style: generalTextStyle),
                        Text("Vehículo: ${widget.modeloVehiculo} (${widget.placasVehiculo})", style: generalTextStyle),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Lógica para cancelar el viaje
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text("Cancelar"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                // Lógica para contactar al conductor
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(255, 0, 87, 54),
                              ),
                              child: Text("Contactar"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}