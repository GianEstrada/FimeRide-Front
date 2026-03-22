

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/info_perfil.dart';
import 'package:fimeride_front/info_viajes.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:fimeride_front/resumen_viaje.dart';
import 'package:fimeride_front/viajes_recientes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'pagina_principal.dart';
import 'api_service.dart';

class OfercerViaje extends StatefulWidget {
  const OfercerViaje({super.key});

  @override
  _OfrecerViajeState createState() => _OfrecerViajeState();
}

class _OfrecerViajeState extends State<OfercerViaje> {
  String _fotoPerfil = 'assets/image/icono-perfil';
  String _nombreUsuario = 'Usuario';
  bool _isHaciaFime = true; // Controla el estado del switch "Hacia FIME" o "Desde FIME"
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _horaSalidaController = TextEditingController();
  final TextEditingController _horaLlegadaController = TextEditingController();
  final MapController _mapController = MapController();
  final TextEditingController _fechaController = TextEditingController();
  
  int _asientosDisponibles = 1;

  String? _selectedHoraDropdown; // Para el dropdown de horas
  TimeOfDay? _selectedHoraReloj; // Para el reloj de horas
  List<String> _suggestions = []; // Lista de sugerencias de direcciones

  LatLng _currentLocation = LatLng(25.6866, -100.3161); // Coordenadas iniciales (Monterrey, NL)
  
  @override
  void initState() {
  super.initState();
  _fetchUsuarioInfo();
}

  final List<String> horasDropdown = [
    "M1", "M2", "M3", "M4", "M5", "M6",
    "V1", "V2", "V3", "V4", "V5", "V6",
    "N1", "N2", "N3", "N4", "N5", "N6"
  ];

  Future<void> _selectHoraReloj(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedHoraReloj ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedHoraReloj = picked;
        controller.text = picked.format(context); // Actualiza el controlador con la hora seleccionada
      });
    }
  }

   Future<void> _fetchUsuarioInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('nombre');
    print("Nombre recuperado de SharedPreferences: $nombre");

    setState(() {
      _fotoPerfil = prefs.getString('foto_perfil') ?? 'assets/default_avatar.png';
      _nombreUsuario = nombre?.split(' ')[0] ?? 'Usuario'; // Solo el primer nombre
    });
  }

  Future<void> _selectFecha(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(), // No permitir fechas pasadas
    lastDate: DateTime.now().add(Duration(days: 365)), // Permitir hasta un año en el futuro
  );
  if (picked != null) {
    setState(() {
      _fechaController.text = "${picked.day}/${picked.month}/${picked.year}"; // Formato de fecha
    });
  }
}

  Future<void> _getSuggestions(String query) async {
  if (mapboxAccessToken == null || mapboxAccessToken!.isEmpty) {
    print("Error: El token de Mapbox no está configurado.");
    return;
  }

  final url =
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$mapboxAccessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List features = data['features'];
      setState(() {
        _suggestions = features.map((feature) => feature['place_name'] as String).toList();
      });
    } else {
      print("Error al obtener sugerencias: ${response.statusCode}");
    }
  } catch (e) {
    print("Error al conectar con la API de Mapbox: $e");
  }
}

Future<void> _reverseGeocode(LatLng location) async {
  if (mapboxAccessToken == null || mapboxAccessToken!.isEmpty) {
    print("Error: El token de Mapbox no está configurado.");
    return;
  }

  final url =
      "https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json?access_token=$mapboxAccessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['features'].isNotEmpty) {
        setState(() {
          _direccionController.text = data['features'][0]['place_name'];
        });
      }
    } else {
      print("Error al obtener la dirección: ${response.statusCode}");
    }
  } catch (e) {
    print("Error al conectar con la API de Mapbox: $e");
  }
}

  Future<void> _geocodeAddress(String address) async {
  if (mapboxAccessToken == null || mapboxAccessToken!.isEmpty) {
    print("Error: El token de Mapbox no está configurado.");
    return;
  }

  final url =
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$address.json?access_token=$mapboxAccessToken";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['features'].isNotEmpty) {
        final coordinates = data['features'][0]['geometry']['coordinates'];
        setState(() {
          _currentLocation = LatLng(coordinates[1], coordinates[0]); // Actualiza la ubicación del pin
        });
        _mapController.move(_currentLocation, 15.0); // Mueve el mapa al nuevo centro con zoom 15
      } else {
        print("No se encontraron resultados para la dirección ingresada.");
      }
    } else {
      print("Error al geocodificar la dirección: ${response.statusCode}");
    }
  } catch (e) {
    print("Error al conectar con la API de Mapbox: $e");
  }
}

void _mostrarResumenViaje() {
  // Validar que los campos obligatorios no estén vacíos
  if (_direccionController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Por favor, ingresa una dirección.")),
    );
    return;
  }

  if (_horaSalidaController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Por favor, selecciona una hora de salida.")),
    );
    return;
  }

  if (_horaLlegadaController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Por favor, selecciona una hora de llegada.")),
    );
    return;
  }

  if (_fechaController.text.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Por favor, selecciona una fecha para el viaje.")),
  );
  return;
}
  // Convertir las horas a minutos desde la medianoche
  final int horaSalidaMinutos = _convertHoraToMinutes(_horaSalidaController.text);
  final int horaLlegadaMinutos = _convertHoraToMinutes(_horaLlegadaController.text);

  // Validar que las horas sean válidas
  if (horaSalidaMinutos == -1 || horaLlegadaMinutos == -1) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Por favor, selecciona horarios válidos.")),
    );
    return;
  }

  // Validar que la hora de salida sea anterior a la hora de llegada
  if (horaSalidaMinutos >= horaLlegadaMinutos) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("La hora de salida debe ser anterior a la hora de llegada.")),
    );
    return;
  }

  // Coordenadas de la Facultad de Ingeniería Mecánica y Eléctrica (FIME)
  final LatLng fimeLocation = LatLng(25.7250, -100.3134);

  // Determina los puntos de inicio y fin según el estado del switch
  final LatLng startPoint = _isHaciaFime ? _currentLocation : fimeLocation;
  final LatLng endPoint = _isHaciaFime ? fimeLocation : _currentLocation;

  // Determina las direcciones de inicio y final según el estado del switch
  final String direccionInicio = _isHaciaFime
      ? _direccionController.text // Dirección proporcionada por el usuario
      : "Facultad de Ingeniería Mecánica y Eléctrica, UANL"; // Dirección de FIME
  final String direccionFinal = _isHaciaFime
      ? "Facultad de Ingeniería Mecánica y Eléctrica, UANL" // Dirección de FIME
      : _direccionController.text; // Dirección proporcionada por el usuario

  // Navega a la pantalla de resumen del viaje
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ResumenViajeScreen(
        startPoint: startPoint,
      endPoint: endPoint,
      direccionInicio: direccionInicio,
      direccionFinal: direccionFinal,
      descripcion: _descripcionController.text,
      costo: _costoController.text,
      horaSalida: _horaSalidaController.text,
      horaLlegada: _horaLlegadaController.text,
      asientosDisponibles: _asientosDisponibles,
      fecha: _fechaController.text, // Pasa los asientos disponibles
      ),
    ),
  ).then((result) {
    if (result != null) {
      // Restaura los datos devueltos desde la pantalla de resumen
      setState(() {
        _direccionController.text = result['direccionInicio'] ?? '';
        _descripcionController.text = result['descripcion'] ?? '';
        _costoController.text = result['costo'] ?? '';
        _horaSalidaController.text = result['horaSalida'] ?? '';
        _horaLlegadaController.text = result['horaLlegada'] ?? '';
        _asientosDisponibles = result['asientosDisponibles'] ?? 1;
        _fechaController.text = result['fecha'] ?? '';
      });
    }
  });
}

int _convertHoraToMinutes(String hora) {
  // Mapa de horarios basado en la nomenclatura proporcionada
  final Map<String, int> horasDropdownMap = {
    "M1": 7 * 60, // 7:00 AM
    "M2": 7 * 60 + 50, // 7:50 AM
    "M3": 8 * 60 + 40, // 8:40 AM
    "M4": 9 * 60 + 30, // 9:30 AM
    "M5": 10 * 60 + 20, // 10:20 AM
    "M6": 11 * 60 + 10, // 11:10 AM
    "V1": 12 * 60, // 12:00 PM
    "V2": 12 * 60 + 50, // 12:50 PM
    "V3": 13 * 60 + 40, // 1:40 PM
    "V4": 14 * 60 + 30, // 2:30 PM
    "V5": 15 * 60 + 20, // 3:20 PM
    "V6": 16 * 60 + 10, // 4:10 PM
    "N1": 17 * 60, // 5:00 PM
    "N2": 17 * 60 + 45, // 5:45 PM
    "N3": 18 * 60 + 30, // 6:30 PM
    "N4": 19 * 60 + 15, // 7:15 PM
    "N5": 20 * 60, // 8:00 PM
    "N6": 20 * 60 + 45, // 8:45 PM
  };

  // Si la hora está en el mapa del dropdown, devuelve los minutos correspondientes
  if (horasDropdownMap.containsKey(hora)) {
    return horasDropdownMap[hora]!;
  }

  // Si no está en el mapa, intenta convertirla como formato de hora normal
  try {
    final timeParts = hora.split(":");
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1].split(" ")[0]);
    final isPM = hora.contains("PM");
    return (isPM && hour != 12 ? hour + 12 : hour) * 60 + minute;
  } catch (e) {
    // Si no se puede convertir, devuelve -1 (error)
    return -1;
  }
}

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    print("Mapbox Access Token: $mapboxAccessToken");
    // Estilos de texto dinámicos basados en el ancho de la pantalla
    TextStyle generalTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.045, // Tamaño dinámico para texto general
    );

    TextStyle greenTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Color.fromARGB(255, 0, 87, 54),
      fontSize: screenWidth * 0.045, // Tamaño dinámico para texto verde
    );

    TextStyle headerTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.06, // Tamaño más grande para encabezados
      fontWeight: FontWeight.bold,
    );

    TextStyle buttonTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.05, // Tamaño dinámico para botones
    );

    return Scaffold(
      resizeToAvoidBottomInset: true, // Permite que el contenido se ajuste al teclado
      drawer: Drawer(
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      DrawerHeader(
        decoration: BoxDecoration(
          color: Color.fromARGB(255, 0, 87, 54),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: _fotoPerfil.startsWith('http')
                  ? NetworkImage(_fotoPerfil)
                  : AssetImage(_fotoPerfil) as ImageProvider,
            ),
            SizedBox(width: 16),
            Text(
              _nombreUsuario,
              style: TextStyle(
                fontFamily: 'ADLaMDisplay',
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      ListTile(
        leading: Icon(Icons.directions_car, color: Colors.black),
        title: Text('Mis Viajes', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ViajesRecientes()),
          );
        },
      ),
      ListTile(
        leading: Icon(Icons.star, color: Colors.black),
        title: Text('Favoritos', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FavoritosScreen()), // Redirige a la pantalla de mensajes
          );
        },
      ),
      ListTile(
        leading: Icon(Icons.message, color: Colors.black), // Ícono de mensajes
        title: Text('Mensajes', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ListaMensajesScreen()), // Redirige a la pantalla de mensajes
          );
        },
      ),
      ListTile(
        leading: Icon(Icons.settings, color: Colors.black),
        title: Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ConfiguracionScreen()),
          );
        },
      ),
      ListTile(
        leading: Icon(Icons.help, color: Colors.green),
        title: Text('Ayuda', style: TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          _showAyudaDialog(context);
        },
      ),
      ListTile(
        leading: Icon(Icons.logout, color: Colors.red),
        title: Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        onTap: () {
          _cerrarSesion(context);
        },
      ),
    ],
  ),
),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Builder(
                            builder: (BuildContext context) {
                              return FloatingActionButton(
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                backgroundColor: const Color.fromARGB(255, 0, 87, 54),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Desde FIME",
                                style: generalTextStyle,
                              ),
                              Switch(
                                value: _isHaciaFime,
                                onChanged: (value) {
                                  setState(() {
                                    _isHaciaFime = value;
                                    _selectedHoraDropdown = null;
                                    _selectedHoraReloj = null;
                                  });
                                },
                                activeThumbColor: Colors.white,
                                activeTrackColor: Color.fromARGB(255, 0, 87, 54),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.white54,
                              ),
                              Text(
                                "Hacia FIME",
                                style: generalTextStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 90.0), // Ajuste del margen inferior
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
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _direccionController,
                                decoration: InputDecoration(
                                  labelText: "Ingresar Dirección",
                                  hintText: "Ejemplo: Av. Universidad 123",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty) {
                                    _getSuggestions(value);
                                    _geocodeAddress(value);
                                  } else {
                                    setState(() {
                                      _suggestions = [];
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              if (_suggestions.isNotEmpty)
  SizedBox(
    height: 150,
    child: ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_suggestions[index]),
          onTap: () async {
            // Actualiza el campo de texto con la sugerencia seleccionada
            _direccionController.text = _suggestions[index];

            // Limpia las sugerencias
            setState(() {
              _suggestions = [];
            });

            // Geocodifica la dirección seleccionada y actualiza el mapa
            await _geocodeAddress(_direccionController.text);
          },
        );
      },
    ),
  ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 300,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    center: _currentLocation,
                                    zoom: 15.0,
                                    onTap: (tapPosition, point) {
                                      setState(() {
                                        _currentLocation = point;
                                      });
                                      _reverseGeocode(point);
                                      _mapController.move(point, 15.0);
                                    },
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
                                          point: _currentLocation,
                                          width: 80.0,
                                          height: 80.0,
                                          builder: (ctx) => Icon(
                                            Icons.location_pin,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              GestureDetector(
                                onTap: () => _selectFecha(context),
                                child: AbsorbPointer(
                                  child: TextField(
                                    controller: _fechaController,
                                    decoration: InputDecoration(
                                      labelText: "Fecha del Viaje",
                                      hintText: "Seleccionar Fecha",
                                      border: OutlineInputBorder(),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Hora de salida
                              _isHaciaFime
    ? GestureDetector(
        onTap: () => _selectHoraReloj(context, _horaSalidaController),
        child: AbsorbPointer(
          child: TextField(
            controller: _horaSalidaController,
            decoration: InputDecoration(
              labelText: "Hora de Salida",
              hintText: "Seleccionar Hora",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      )
    : DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "Hora de Salida",
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        initialValue: horasDropdown.contains(_selectedHoraDropdown) ? _selectedHoraDropdown : null,
        items: horasDropdown
            .map((hora) => DropdownMenuItem(
                  value: hora,
                  child: Text(hora, style: greenTextStyle),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedHoraDropdown = value;
            _horaSalidaController.text = value ?? ""; // Asigna el valor al controlador
          });
        },
      ),
                              const SizedBox(height: 16),
                              _isHaciaFime
    ? DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "Hora de Llegada",
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        initialValue: horasDropdown.contains(_selectedHoraDropdown) ? _selectedHoraDropdown : null,
        items: horasDropdown
            .map((hora) => DropdownMenuItem(
                  value: hora,
                  child: Text(hora, style: greenTextStyle),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedHoraDropdown = value;
            _horaLlegadaController.text = value ?? ""; // Asigna el valor al controlador
          });
        },
      )
    : GestureDetector(
        onTap: () => _selectHoraReloj(context, _horaLlegadaController),
        child: AbsorbPointer(
          child: TextField(
            controller: _horaLlegadaController,
            decoration: InputDecoration(
              labelText: "Hora de Llegada",
              hintText: "Seleccionar Hora",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _descripcionController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: "Descripción del Viaje",
                                  hintText: "Ejemplo: Viaje cómodo, no se permite fumar.",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                               const SizedBox(height: 16),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      "Asientos Disponibles:",
      style: TextStyle(
        fontFamily: 'ADLaMDisplay',
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              if (_asientosDisponibles > 1) { // Cambia el límite inferior a 1
                _asientosDisponibles--;
              }
            });
          },
          icon: const Icon(Icons.remove, color: Colors.red),
        ),
        Text(
          '$_asientosDisponibles',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              if (_asientosDisponibles < 7) { // Mantén el límite superior en 7
                _asientosDisponibles++;
              }
            });
          },
          icon: const Icon(Icons.add, color: Colors.green),
        ),
      ],
    ),
  ],
),
const SizedBox(height: 16),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _costoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: "Costo del Viaje",
                                  hintText: "Ejemplo: 50",
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      _mostrarResumenViaje(); // Muestra el resumen del viaje

                                      print("Viaje ofrecido con éxito");
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color.fromARGB(255, 0, 87, 54),
                                    ),
                                    child: Text("Aceptar", style: buttonTextStyle),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: Text("Cancelar", style: buttonTextStyle),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home, color: Color.fromARGB(255, 0, 87, 54)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PaginaPrincipal()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.directions_car, color: Color.fromARGB(255, 0, 87, 54)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => InfoViajes()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Color.fromARGB(255, 0, 87, 54)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.group, color: Color.fromARGB(255, 0, 87, 54)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ViajesRecientes()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, color: Color.fromARGB(255, 0, 87, 54)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => InfoPerfil()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _cerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Cerrar Sesión"),
          content: Text("¿Estás seguro de que deseas cerrar sesión?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => PaginaPrincipal()),
                );
              },
              child: Text("Cerrar Sesión"),
            ),
          ],
        );
      },
    );
  }

   void _showAyudaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Ayuda"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Universidad FIME"),
              Text("Unidad de Soporte Técnico"),
              SizedBox(height: 8),
              Text("Teléfono: +52 81 1234 5678"),
              Text("Correo: soporte@fime.universidad.mx"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }
}