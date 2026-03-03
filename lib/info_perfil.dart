import 'dart:convert';

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/info_viajes.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/ofercer_viaje.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:fimeride_front/viajes_recientes.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InfoPerfil extends StatefulWidget {
  const InfoPerfil({super.key});

  @override
  _InfoPerfilState createState() => _InfoPerfilState();
}

class _InfoPerfilState extends State<InfoPerfil> with SingleTickerProviderStateMixin {
  String _fotoPerfil = 'assets/image/icono-perfil';
  String _nombreUsuario = 'Usuario';
  int usuarioId = 0; // Inicializa el ID del usuario
  
  late AnimationController _controller;
  late Animation<Offset> _animation;
  Map<String, dynamic>? _usuarioInfo;

  @override
  void initState() {
    super.initState();
    _loadUsuarioInfo();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<Offset>(
      begin: const Offset(0, -1), // Comienza fuera de la pantalla
      end: Offset.zero,           // Termina en su posición normal
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward(); // Inicia la animación al cargar la pantalla
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Future<void> _loadUsuarioInfo() async {
    final usuarioInfo = await _fetchUsuarioInfo();
    if (mounted) {
      setState(() {
        _usuarioInfo = usuarioInfo;
      });
    }
  }


Future<Map<String, dynamic>?> _fetchUsuarioInfo() async {
  final prefs = await SharedPreferences.getInstance();
  final usuarioId = prefs.getInt('usuario_id');
  final nombre = prefs.getString('nombre');

  if (usuarioId == null) {
    print("Error: usuario_id no encontrado");
    return null;
  }

  setState(() {
      _fotoPerfil = prefs.getString('foto_perfil') ?? 'assets/default_avatar.png';
      _nombreUsuario = nombre?.split(' ')[0] ?? 'Usuario'; // Solo el primer nombre
    });

  final url = Uri.parse("https://fimeride.onrender.com/api/usuario/$usuarioId/");
  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Devuelve la información del usuario
    } else if (response.statusCode == 404) {
      print("Error: Usuario no encontrado");
    } else {
      print("Error al obtener la información del usuario: ${response.statusCode}");
    }
  } catch (e) {
    print("Error de conexión: $e");
  }
  return null;
}

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    TextStyle titleStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      fontSize: screenWidth * 0.05,
      fontWeight: FontWeight.bold,
      color: Colors.black,
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
          Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _animation,
              child: ClipPath(
                clipper: DiagonalClipper(),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.75, // Ajustar la altura
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30), // Reducir el margen superior
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _usuarioInfo == null
                                ? Center(child: CircularProgressIndicator())
                                : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            SizedBox(height: 100),
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: _usuarioInfo!['foto_perfil'] != null
                                  ? NetworkImage(_usuarioInfo!['foto_perfil'])
                                  : null,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _usuarioInfo!['nombre_completo'],
                              style: titleStyle,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Matrícula: ${_usuarioInfo!['matricula']}",
                              style: titleStyle.copyWith(fontSize: screenWidth * 0.04),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Correo: ${_usuarioInfo!['correo_universitario']}",
                              style: titleStyle.copyWith(fontSize: screenWidth * 0.04),
                            ),
                           SizedBox(height: 8),
                            Text(
                              "Periodo Activo: Enero-Junio 2025",
                              style: titleStyle.copyWith(fontSize: screenWidth * 0.04),
                            ),
                           SizedBox(height: 8),
                            Text(
                              "Estado Pasajero: ${_usuarioInfo!['estado_pasajero'] ? 'Activo' : 'Inactivo'}",
                              style: titleStyle.copyWith(fontSize: screenWidth * 0.04),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Estado Conductor: ${_usuarioInfo!['estado_conductor'] ? 'Activo' : 'Inactivo'}",
                              style: titleStyle.copyWith(fontSize: screenWidth * 0.04),
                            ),
                          ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
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
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 48, // Ajustar la altura del botón flotante
            left: 16,
            child: Builder(
              builder: (BuildContext context) {
                return FloatingActionButton(
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                  backgroundColor: const Color.fromARGB(255, 0, 87, 54),
                  child: const Icon(Icons.menu, color: Colors.white),
                );
              },
            ),
          ),
        ],
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
                MaterialPageRoute(builder: (context) => FormularioConductores(usuarioId: usuarioId)), // Ajusta según sea necesario
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
}

class DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 100); // Punto inferior izquierdo
    path.lineTo(size.width, size.height); // Punto inferior derecho
    path.lineTo(size.width, 0); // Punto superior derecho
    path.close(); // Cierra el camino
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}