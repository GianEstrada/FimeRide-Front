import 'dart:convert';

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/info_perfil.dart';
import 'package:fimeride_front/info_viajes.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/login.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:fimeride_front/chat_screen.dart';
import 'package:fimeride_front/viaje_en_curso.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ofercer_viaje.dart';
import 'viajes_recientes.dart';

class PaginaPrincipal extends StatefulWidget {
  @override
  _PaginaPrincipalState createState() => _PaginaPrincipalState();
}

class _PaginaPrincipalState extends State<PaginaPrincipal> {
  bool _isConductor = false;
  bool _isConductorEnabled = false;
  List<dynamic> _viajes = [];
  List<dynamic> _asignaciones = [];
  String _fotoPerfil = 'assets/image/icono-perfil'; // Imagen predeterminada
  String _nombreUsuario = 'Usuario';

  @override
  void initState() {
    super.initState();
    _checkConductorStatus();
    _fetchViajes();
    _fetchUsuarioInfo();
  }

  @override
  void dispose() {
    // Cancela cualquier operación o referencia antes de que el widget sea eliminado
    super.dispose();
  }

  Future<void> _checkConductorStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final conductorId = prefs.getInt('conductor_id');

    if (conductorId != null) {
      final url = Uri.parse("https://fimeride.onrender.com/api/conductor_estado/$conductorId/");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isConductorEnabled = responseData['activo']; // Habilita el switch si el conductor está activo
          });
        }
      }
    }
  }

Future<void> _fetchViajes() async {
  final prefs = await SharedPreferences.getInstance();
  final conductorId = prefs.getInt('conductor_id'); // Obtener el ID del conductor logueado

  if (conductorId == null) {
    print("Error: conductor_id no encontrado");
    return;
  }

  final url = Uri.parse("https://fimeride.onrender.com/api/viajes/?conductor_id=$conductorId");
  final response = await http.get(url);

  if (response.statusCode == 200) {
    if (mounted) {
      setState(() {
        _viajes = jsonDecode(response.body); // Almacena los viajes filtrados
      });
    }
  } else {
    print("Error al obtener los viajes: ${response.statusCode}");
  }
}

Future<void> _fetchAsignaciones() async {
  final prefs = await SharedPreferences.getInstance();
  final conductorId = prefs.getInt('conductor_id');

  if (conductorId == null) {
    print("Error: conductor_id no encontrado");
    return;
  }

  final url = Uri.parse("https://fimeride.onrender.com/api/asignaciones/conductor/$conductorId/");
  final response = await http.get(url);

  if (response.statusCode == 200) {
    if (mounted) {
      setState(() {
        _asignaciones = jsonDecode(response.body); // Almacena las asignaciones
      });
    }
  } else {
    print("Error al obtener las asignaciones: ${response.statusCode}");
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
      ListTile(
        leading: Icon(Icons.logout, color: Colors.red),
        title: Text('Viaje en curso', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        onTap: () {
          Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViajeEnProcesoScreen(
          startPoint: LatLng(25.6866, -100.3161),
          endPoint: LatLng(25.7250, -100.3134),
          direccionInicio: "Monterrey, NL",
          direccionFinal: "Facultad de Ingeniería Mecánica y Eléctrica, UANL",
          conductorNombre: "Juan Pérez",
          conductorFoto: "https://example.com/foto.jpg",
          modeloVehiculo: "Toyota Corolla 2020",
          placasVehiculo: "ABC-1234",
        ),
      ),
    );
        },
      ),
    ],
  ),
),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
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
                          onChanged: _isConductorEnabled
                              ? (value) {
                              setState(() {
                                _isConductor = value;
                              });
                              if (value) {
                                _fetchAsignaciones(); // Cargar asignaciones si es conductor
                              }
                            }
                              : null,
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80.0), // Ajuste para evitar que los elementos queden detrás del menú
                      itemCount: _isConductor ? _asignaciones.length : _viajes.length,
                      itemBuilder: (context, index) {
                        if (_isConductor) {
                        final asignacion = _asignaciones[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: asignacion['pasajero']['foto_perfil'] != null
                                          ? NetworkImage(asignacion['pasajero']['foto_perfil'])
                                          : AssetImage('assets/image/icono-perfil') as ImageProvider,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            asignacion['pasajero']['nombre'],
                                            style: greenTextStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "Dirección: ${asignacion['viaje']['direccion']}",
                                  style: greenTextStyle,
                                ),
                                Text(
                                  "Hora de salida: ${asignacion['viaje']['hora_salida']}",
                                  style: greenTextStyle,
                                ),
                                Text(
                                  "Hora de llegada: ${asignacion['viaje']['hora_llegada']}",
                                  style: greenTextStyle,
                                ),
                                Text(
                                  "Descripción: ${asignacion['viaje']['descripcion']}",
                                  style: greenTextStyle,
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children:[
                                          ElevatedButton(
                                            onPressed: () async {
                                                final url = Uri.parse("https://fimeride.onrender.com/api/asignaciones/${asignacion['id']}/");
                                                final response = await http.patch(
                                                  url,
                                                  headers: {
                                                    'Content-Type': 'application/json',
                                                  },
                                                  body: jsonEncode({'asignado': true}),
                                                );

                                               if (response.statusCode == 200) {
                                                  print("Asignación aceptada exitosamente");
                                                  _fetchAsignaciones();
                                                } else {
                                                  print("Error al aceptar la asignación: ${response.statusCode}");
                                                } 
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color.fromARGB(255, 0, 87, 54),
                                            ),
                                            child: Text("Aceptar", style: buttonTextStyle),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async{
                                              final url = Uri.parse("https://fimeride.onrender.com/api/asignaciones/${asignacion['id']}/");
                                              final response = await http.patch(
                                                url,
                                                headers: {
                                                  'Content-Type': 'application/json',
                                                },
                                                body: jsonEncode({'asignado': false}),
                                              );
                                              if (response.statusCode == 200) {
                                                print("Asignación rechazada exitosamente");
                                                _fetchAsignaciones();
                                              } else {
                                                print("Error al rechazar la asignación: ${response.statusCode}");
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: Text("Rechazar", style: buttonTextStyle),
                                          ),

                                        ]
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        final viaje = _viajes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
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
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: viaje['conductor']['foto_perfil'] != null
                                          ? NetworkImage(viaje['conductor']['foto_perfil'])
                                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            viaje['conductor']['nombre'],
                                            style: greenTextStyle.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            ),
                                          ), 
                                          Text(
                                            "Salida: ${viaje['hora_salida']} - Regreso: ${viaje['hora_llegada']}",
                                            style: greenTextStyle,
                                          ),
                                          Text(
                                            viaje['es_hacia_fime']
                                              ? "Direccion de inicio: ${viaje['direccion']}"
                                              : "Direccion de regreso: ${viaje['direccion']}",
                                            style: greenTextStyle,
                                          ),
                                          Text(
                                            viaje['es_hacia_fime'] ? "Hacia FIME" : "Desde FIME",
                                            style: greenTextStyle.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: viaje['es_hacia_fime'] ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          Text(
                                            "Asientos disponibles: ${viaje['asientos_disponibles']}",
                                            style: greenTextStyle,
                                          ),
                                          Text(
                                            "Fecha: ${viaje['fecha_viaje']}",
                                            style: greenTextStyle,
                                          ),
                                          Text(
                                            "Descripción: ${viaje['descripcion']}",
                                            style: greenTextStyle,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                  onPressed: () async{
                                    final prefs = await SharedPreferences.getInstance();
                                    final pasajeroId = prefs.getInt('pasajero_id');
                                    final viajeId = viaje['id'];

                                    if (pasajeroId == null) {
                                      // Si no hay pasajero_id, muestra el popup
                                      _showNoPermisosDialog(context);
                                      return;
                                    }
                                    final url = Uri.parse("https://fimeride.onrender.com/api/asignaciones/");
                                    final response = await http.post(
                                      url,
                                      headers: {
                                        'Content-Type': 'application/json',
                                      },
                                      body: jsonEncode({
                                        'pasajero_id': pasajeroId,
                                        'viaje_id': viajeId,
                                      }),
                                    );

                                    if (response.statusCode == 201) {
                                      _showSuccessDialog(context);
                                    } else if (response.statusCode == 400) {
                                     _showErrorDialog(context, "Ya has solicitado este viaje.");
                                    }else {
                                      print("Error al enviar la solicitud: ${response.statusCode}");
                                    }
                                  },
                                  
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color.fromARGB(255, 0, 87, 54),
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  ),
                                  child: Text("Separar el viaje", style: buttonTextStyle),
                                ),
                                SizedBox(width: 8), // Espacio entre los botones
                                ElevatedButton(onPressed: (){
                                  final int viajeId = viaje['id'];
                                  final Map<String, dynamic> conductor = viaje['conductor'];

                                  if (conductor == null || conductor['id'] == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error al obtener la información del conductor.")),
                                    );
                                    return;
                                  }	
                                  
                                  final Map<String, dynamic> otroUsuario = {
                                    'id': conductor['id'],
                                    'nombre': conductor['nombre'],
                                    'foto_perfil': conductor['foto_perfil'] ?? 'assets/image/icono-perfil.png',                                 
                                     };
                                  
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        otroUsuario: otroUsuario,
                                        idViaje: viajeId,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Color.fromARGB(255, 4, 53, 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                  ), 
                                child: Text("Contactar conductor", style: buttonTextStyle),)
                                    
                                  ],
                                ),
                                
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ]
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
                    onPressed: () {},
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

void _cerrarSesion(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // Elimina todos los datos almacenados
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => PantallaInicio()), // Redirige a la pantalla de inicio de sesión
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

void _showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Solicitud enviada"),
        content: const Text("Tu solicitud ha sido enviada exitosamente."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el popup
            },
            child: const Text("Aceptar"),
          ),
        ],
      );
    },
  );
}
}