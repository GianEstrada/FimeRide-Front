import 'dart:convert';

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/info_perfil.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/ofercer_viaje.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:fimeride_front/chat_screen.dart';
import 'package:fimeride_front/viajes_recientes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InfoViajes extends StatefulWidget {
  const InfoViajes({super.key});

  @override
  _InfoViajesState createState() => _InfoViajesState();
}

class _InfoViajesState extends State<InfoViajes> {
  String _fotoPerfil = 'assets/image/icono-perfil';
  String _nombreUsuario = 'Usuario';
  bool _isConductor = false;
  bool _isConductorEnabled = false; // Controla el estado del switch "Conductor" o "Pasajero"
  List<dynamic> _viajesPasajero = []; // Lista para los datos de pasajero
  List<dynamic> _viajesConductor = []; // Lista para los datos de conductor

@override
void initState() {
  super.initState();
  _fetchViajesPasajero();
  _fetchViajesConductor(); 
  _fetchUsuarioInfo();
  _checkConductorStatus();
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

  Future<void> _checkConductorStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final conductorId = prefs.getInt('conductor_id');

    if (conductorId != null) {
      final url = Uri.parse("https://fimeride.onrender.com/api/conductor_estado/$conductorId/");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _isConductorEnabled = responseData['activo']; // Habilita el switch si el conductor está activo
        });
      }
    }
  }

Future<void> _fetchViajesPasajero() async {
  final prefs = await SharedPreferences.getInstance();
  final pasajeroId = prefs.getInt('pasajero_id');

  if (pasajeroId == null) {
    _showErrorDialog(context, "Error: No se encontró el ID del pasajero.");
    return;
  }

  final url = Uri.parse("https://fimeride.onrender.com/api/viajes_realizados/pasajero/$pasajeroId/");

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        _viajesPasajero = responseData is List ? responseData : [];
      });
    } else {
      _showErrorDialog(context, "Error al obtener los viajes como pasajero.");
    }
  } catch (e) {
    _showErrorDialog(context, "Error de conexión: $e");
  }
}

Future<void> _fetchViajesConductor() async {
  final prefs = await SharedPreferences.getInstance();
  final conductorId = prefs.getInt('conductor_id');

  if (conductorId == null) {
    _showErrorDialog(context, "Error: No se encontró el ID del conductor.");
    return;
  }

  final url = Uri.parse("https://fimeride.onrender.com/api/viajes_realizados/conductor/$conductorId/");

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        _viajesConductor = responseData is List ? responseData : [];
      });
    } else {
      _showErrorDialog(context, "Error al obtener los viajes como conductor.");
    }
  } catch (e) {
    _showErrorDialog(context, "Error de conexión: $e");
  }
}
  
  Future<List<dynamic>> fetchViajesRealizadosPasajero(int pasajeroId) async {
  final url = Uri.parse("https://fimeride.onrender.com/api/viajes_realizados/pasajero/$pasajeroId/");
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Error al obtener los viajes realizados del pasajero");
  }
}
Future<List<dynamic>> fetchViajesRealizadosConductor(int conductorId) async {
  final url = Uri.parse("https://fimeride.onrender.com/api/viajes_realizados/conductor/$conductorId/");
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception("Error al obtener los viajes realizados del conductor");
  }
}



  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Estilos de texto dinámicos basados en el ancho de la pantalla
    TextStyle greenTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Color.fromARGB(255, 0, 87, 54),
      fontSize: screenWidth * 0.045,
    );

    TextStyle buttonTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: Colors.white,
      fontSize: screenWidth * 0.04,
    );

    return Scaffold(
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
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Builder(
                        builder: (BuildContext context) {
                          return FloatingActionButton(
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                            },
                            backgroundColor: Color.fromARGB(255, 0, 87, 54),
                            child: Icon(
                              Icons.menu,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Pasajero",
                          style: greenTextStyle,
                        ),
                        Switch(
                          value: _isConductor,
                          onChanged:_isConductorEnabled 
                            ?(value) {
                              setState(() {
                                _isConductor = value; 
                              });
                            }
                            :null,
                          activeColor: Colors.white,
                          activeTrackColor: Color.fromARGB(255, 0, 87, 54),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.white54,
                        ),
                        Text(
                          "Conductor",
                          style: greenTextStyle,
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: _isConductor
                    ? _buildConductorList(greenTextStyle, buttonTextStyle)
                    : _buildPasajeroList(greenTextStyle, buttonTextStyle),
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
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color.fromARGB(255, 0, 87, 54)),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final conductorId = prefs.getInt('conductor_id');

                      if (conductorId == null) {
                        // Si no hay conductor_id, muestra el popup
                        _showNoPermisosDialog(context);
                        return;
                      }

                      final url = Uri.parse("https://fimeride.onrender.com/api/conductor_estado/$conductorId/");
                      final response = await http.get(url);

                      if (response.statusCode == 200) {
                        final responseData = jsonDecode(response.body);
                        final isActive = responseData['activo'];

                        if (isActive) {
                        // Si el conductor está activo, permite la acción normal
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => OfercerViaje()),
                          );
                        } else {
                        // Si el conductor no está activo, muestra el popup
                        _showNoPermisosDialog(context);
                        }
                      } else {
                        // Maneja errores de la solicitud
                        _showErrorDialog(context, "Error al verificar el estado del conductor.");
                      }
                    },
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
      ),
    );
  }

    void _showNoPermisosDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Permiso denegado"),
        content: const Text(
          "No tienes permisos de conductor. ¿Quieres enviar una solicitud para ser conductor?",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FormularioConductores(usuarioId: 0)), // Ajusta según sea necesario
              );
            },
            child: const Text("Enviar solicitud"),
          ),
        ],
      );
    },
  );
}

void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cerrar"),
          ),
        ],
      );
    },
  );
}

Widget _buildPasajeroView(Map<String, dynamic> viaje, TextStyle greenTextStyle, TextStyle buttonTextStyle) {
  final direccion = viaje['direccion'] ?? "Dirección no disponible";
  final fecha = viaje['fecha_viaje'] ?? "Fecha no disponible";
  final conductor = viaje['conductor']?['nombre'] ?? "Conductor no disponible";

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Dirección: $direccion", style: greenTextStyle),
      Text("Fecha: $fecha", style: greenTextStyle),
      Text("Conductor: $conductor", style: greenTextStyle),
      ElevatedButton(
        onPressed: () {
          print("Reportar viaje");
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: Text("Reportar", style: buttonTextStyle),
      ),
    ],
  );
}

Widget _buildConductorView(Map<String, dynamic> viaje, TextStyle greenTextStyle, TextStyle buttonTextStyle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Dirección: ${viaje['direccion']}", style: greenTextStyle),
      Text("Fecha: ${viaje['fecha_viaje']}", style: greenTextStyle),
      SizedBox(height: 8),
      Row(
        children: (viaje['pasajeros'] as List<dynamic>).map((pasajero) {
          return GestureDetector(
            onTap: () {
              _showPasajeroPopup(context, pasajero, greenTextStyle, buttonTextStyle);
            },
            child: Column(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(pasajero['foto_perfil']),
                ),
                Text(pasajero['nombre'].split(' ')[0], style: greenTextStyle),
                SizedBox(width: 8),
              ],
            ),
          );
          
        }).toList(),
        
      ),
    ],
  );
}

Widget _buildPasajeroList(TextStyle greenTextStyle, TextStyle buttonTextStyle) {
  if (_viajesPasajero.isEmpty) {
    return Center(child: Text("No hay viajes realizados como pasajero.", style: greenTextStyle));
  }

  return ListView.builder(
    itemCount: _viajesPasajero.length,
    itemBuilder: (context, index) {
      final viaje = _viajesPasajero[index];
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildPasajeroView(viaje, greenTextStyle, buttonTextStyle),
        ),
      );
    },
  );
}

Widget _buildConductorList(TextStyle greenTextStyle, TextStyle buttonTextStyle) {
  if (_viajesConductor.isEmpty) {
    return Center(child: Text("No hay viajes realizados como conductor.", style: greenTextStyle));
  }

  return ListView.builder(
    itemCount: _viajesConductor.length,
    itemBuilder: (context, index) {
      final viaje = _viajesConductor[index];
      return Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildConductorView(viaje, greenTextStyle, buttonTextStyle),
        ),
      );
    },
  );
}

void _showPasajeroPopup(BuildContext context, Map<String, dynamic> pasajero, TextStyle greenTextStyle, TextStyle buttonTextStyle) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Pasajero: ${pasajero['nombre']}", style: greenTextStyle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(pasajero['foto_perfil']),
            ),
            ElevatedButton(
              onPressed: () {
                print("Reportar pasajero");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Reportar", style: buttonTextStyle),
            ),
          ],
        ),
      );
    },
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
