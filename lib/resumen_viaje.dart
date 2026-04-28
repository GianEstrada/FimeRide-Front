import 'dart:convert';
import 'package:fimeride_front/api_service.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResumenViajeScreen extends StatefulWidget {
  final LatLng startPoint;
  final LatLng endPoint;
  final String descripcion;
  final String costo;
  final String horaSalida;
  final String horaLlegada;
  final String direccionInicio;
  final String direccionFinal;
  final int asientosDisponibles;
  final String fecha;
  final String modeloVehiculo;
  final String placasVehiculo;

  const ResumenViajeScreen({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.direccionInicio,
    required this.direccionFinal,
    required this.descripcion,
    required this.costo,
    required this.horaSalida,
    required this.horaLlegada,
    required this.asientosDisponibles,
    required this.fecha,
    required this.modeloVehiculo,
    required this.placasVehiculo,
  });

  @override
  _ResumenViajeScreenState createState() => _ResumenViajeScreenState(); // Devuelve la instancia del estado
}

class _ResumenViajeScreenState extends State<ResumenViajeScreen> {
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final route = await _getRoute(widget.startPoint, widget.endPoint);
    setState(() {
      _routePoints = route;
    });
  }


Future<int?> obtenerConductorId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('conductor_id'); // Devuelve el conductor_id o null si no está guardado
}


  Future<List<LatLng>> _getRoute(LatLng start, LatLng end) async {
    final String url =
        "https://api.mapbox.com/directions/v5/mapbox/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&access_token=$mapboxAccessToken";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        return coordinates
            .map((coord) => LatLng(coord[1], coord[0]))
            .toList(); // Convierte las coordenadas a LatLng
      } else {
        print("Error al obtener la ruta: ${response.statusCode}");
      }
    } catch (e) {
      print("Error al conectar con la API de Mapbox Directions: $e");
    }
    return [];
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

    TextStyle buttonTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.05,
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
                  "Resumen del Viaje",
                  style: headerTextStyle,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 90.0),
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
                                    "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken",
                                additionalOptions: {
                                  'accessToken': mapboxAccessToken ?? '',
                                  'id': 'mapbox.streets',
                                },
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
                        Text("Dirección de Inicio: ${widget.direccionInicio}"),
                        Text("Dirección Final: ${widget.direccionFinal}"),
                        Text("Descripción: ${widget.descripcion}"),
                        Text("Asientos Disponibles: ${widget.asientosDisponibles}"),
                        Text("Costo: \$${widget.costo}"),
                        Text("Hora de Salida: ${widget.horaSalida}"),
                        Text("Hora de Llegada: ${widget.horaLlegada}"),
                        Text("Fecha del Viaje: ${widget.fecha}"),
                        Text("Modelo del Vehiculo: ${widget.modeloVehiculo}"),
                        Text("Placas: ${widget.placasVehiculo}"),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'direccionInicio': widget.direccionInicio,
                          'direccionFinal': widget.direccionFinal,
                          'descripcion': widget.descripcion,
                          'asientosDisponibles': widget.asientosDisponibles,
                          'costo': widget.costo,
                          'horaSalida': widget.horaSalida,
                          'horaLlegada': widget.horaLlegada,
                          'fecha': widget.fecha,
                          'modeloVehiculo': widget.modeloVehiculo,
                          'placasVehiculo': widget.placasVehiculo,
                        }
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: Text("Cancelar", style: buttonTextStyle),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        
                        final response = await _registrarViaje();
    if (response != null && response['message'] == 'Viaje registrado exitosamente') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Viaje registrado exitosamente")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PaginaPrincipal()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al registrar el viaje: ${response?['error'] ?? 'Desconocido'}")),
      );
    }
                        print("Viaje confirmado");
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => PaginaPrincipal()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 87, 54),
                      ),
                      child: Text("Confirmar", style: buttonTextStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

Future<Map<String, dynamic>?> _registrarViaje() async {
  final prefs = await SharedPreferences.getInstance();
  final usuarioId = prefs.getInt('usuario_id'); // Recupera el usuario_id
  final conductorId = prefs.getInt('conductor_id'); // Recupera el conductor_id

  if (usuarioId == null || conductorId == null) {
    print("Error: usuario_id o conductor_id no encontrado");
    return null;
  }

  // Convertir la fecha al formato YYYY-MM-DD
  final List<String> fechaPartes = widget.fecha.split('/'); // Divide la fecha en partes
  final String fechaFormateada =
      '${fechaPartes[2]}-${fechaPartes[1].padLeft(2, '0')}-${fechaPartes[0].padLeft(2, '0')}';

  final String direccion = widget.direccionInicio.contains("Facultad de Ingeniería")
      ? widget.direccionFinal
      : widget.direccionInicio;

  final url = Uri.parse('https://fimeride.onrender.com/api/registrar_viaje/');
  final Map<String, dynamic> data = {
    
    'direccion': direccion,
    'es_hacia_fime': widget.direccionFinal.contains("Facultad de Ingeniería"),
    'hora_salida': widget.horaSalida,
    'hora_llegada': widget.horaLlegada,
    'descripcion': widget.descripcion,
    'direccion_inicio': widget.direccionInicio,
    'direccion_destino': widget.direccionFinal,
    'origen_lat': widget.startPoint.latitude,
    'origen_lng': widget.startPoint.longitude,
    'destino_lat': widget.endPoint.latitude,
    'destino_lng': widget.endPoint.longitude,
    'modelo_vehiculo': widget.modeloVehiculo,
    'placas_vehiculo': widget.placasVehiculo,
    'asientos_disponibles': widget.asientosDisponibles,
    'costo': widget.costo,
    'fecha_viaje': fechaFormateada, // Usa la fecha formateada
    'usuario_id': usuarioId,
    'conductor_id': conductorId,
  };

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      print("Error al registrar el viaje: ${response.body}");
      return jsonDecode(response.body);
    }
  } catch (e) {
    print("Error de conexión: $e");
    return null;
  }
}
}

