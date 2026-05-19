import 'dart:convert';

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'info_perfil.dart';
import 'info_viajes.dart';
import 'ofercer_viaje.dart';
import 'pagina_principal.dart';
import 'viajes_recientes.dart';

class PantallaReportes extends StatefulWidget {
  const PantallaReportes({super.key});

  @override
  _PantallaReportesState createState() => _PantallaReportesState();
}

class _PantallaReportesState extends State<PantallaReportes> {
  String _fotoPerfil = 'assets/image/icono-perfil';
  String _nombreUsuario = 'Usuario';
  int? _usuarioId;
  bool _isConductor = false;
  bool _isConductorEnabled = false;
  bool _isLoading = true;
  List<dynamic> _reportes = [];

  static const _baseUrl = 'https://fimeride.onrender.com/api';

  static const _categoriasLabel = {
    'conduccion': 'Conducción',
    'seguridad': 'Seguridad',
    'vehiculo': 'Vehículo',
    'viaje_en_curso': 'Viaje en curso',
    'auto_tiempo_excedido': 'Tiempo excedido (auto)',
    'otro': 'Otro',
  };

  static const _estadoColor = {
    'pendiente': Color(0xFFE67E22),
    'en_revision': Color(0xFF2980B9),
    'resuelto': Color(0xFF27AE60),
    'cerrado': Color(0xFF7F8C8D),
  };

  @override
  void initState() {
    super.initState();
    _fetchUsuarioInfo();
    _checkConductorStatus();
  }

  Future<void> _fetchUsuarioInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('nombre');
    final usuarioId = prefs.getInt('usuario_id');

    if (!mounted) return;
    setState(() {
      _fotoPerfil =
          prefs.getString('foto_perfil') ?? 'assets/image/icono-perfil';
      _nombreUsuario = nombre?.split(' ').first ?? 'Usuario';
      _usuarioId = usuarioId;
    });

    await _fetchReportes();
  }

  Future<void> _fetchReportes() async {
    if (_usuarioId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final url = Uri.parse('$_baseUrl/reportes/usuario/$_usuarioId/');
    try {
      final response = await http.get(url);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _reportes = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConductorStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final conductorId = prefs.getInt('conductor_id');
    if (conductorId == null) return;

    final url = Uri.parse('$_baseUrl/conductor_estado/$conductorId/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() => _isConductorEnabled = data['activo'] == true);
      }
    } catch (_) {}
  }

  String _formatFecha(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final greenTextStyle = TextStyle(
      fontFamily: 'ADLaMDisplay',
      color: const Color.fromARGB(255, 0, 87, 54),
      fontSize: screenWidth * 0.045,
    );

    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Fondo degradado
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
                // Barra superior
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder:
                            (ctx) => FloatingActionButton(
                              heroTag: 'drawer_reportes',
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                              backgroundColor:
                                  const Color.fromARGB(255, 0, 87, 54),
                              child: const Icon(
                                Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Pasajero', style: greenTextStyle),
                          Switch(
                            value: _isConductor,
                            onChanged:
                                _isConductorEnabled
                                    ? (v) => setState(() => _isConductor = v)
                                    : null,
                            activeThumbColor: Colors.white,
                            activeTrackColor:
                                const Color.fromARGB(255, 0, 87, 54),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.white54,
                          ),
                          Text('Conductor', style: greenTextStyle),
                        ],
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Título
                const Text(
                  'Mis Reportes',
                  style: TextStyle(
                    fontFamily: 'ADLaMDisplay',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Lista de reportes
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _reportes.isEmpty
                          ? const Center(
                            child: Text(
                              'No tienes reportes enviados',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                          : RefreshIndicator(
                            onRefresh: _fetchReportes,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: _reportes.length,
                              itemBuilder: (ctx, i) =>
                                  _buildReporteCard(_reportes[i]),
                            ),
                          ),
                ),
              ],
            ),
          ),
          // Barra de navegación inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildReporteCard(Map<String, dynamic> r) {
    final categoria =
        _categoriasLabel[r['categoria']?.toString()] ??
        r['categoria']?.toString() ??
        '—';
    final estado = r['estado']?.toString() ?? 'pendiente';
    final color = _estadoColor[estado] ?? const Color(0xFF7F8C8D);
    final fecha = _formatFecha(r['creado_en']?.toString());
    final descripcion = r['descripcion']?.toString() ?? '';
    final viajeDir = r['viaje_direccion']?.toString() ?? '';
    final fechaViaje = r['fecha_viaje']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      color: Color.fromARGB(255, 0, 87, 54),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      categoria,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    estado,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (viajeDir.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$viajeDir  ($fechaViaje)',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (viajeDir.isNotEmpty) const SizedBox(height: 6),
            Text(
              descripcion,
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              fecha,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      _fotoPerfil.startsWith('http')
                          ? NetworkImage(_fotoPerfil)
                          : AssetImage(_fotoPerfil) as ImageProvider,
                ),
                const SizedBox(width: 16),
                Text(
                  _nombreUsuario,
                  style: const TextStyle(
                    fontFamily: 'ADLaMDisplay',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.directions_car, 'Mis Viajes', () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ViajesRecientes()),
            );
          }),
          _drawerItem(Icons.star, 'Favoritos', () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FavoritosScreen()),
            );
          }),
          _drawerItem(Icons.message, 'Mensajes', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListaMensajesScreen()),
            );
          }),
          _drawerItem(Icons.flag, 'Mis Reportes', () {
            Navigator.pop(context);
          }),
          _drawerItem(Icons.settings, 'Configuración', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
            );
          }),
          ListTile(
            leading: const Icon(Icons.help, color: Colors.green),
            title: const Text(
              'Ayuda',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () => _showAyudaDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            onTap: () => _cerrarSesion(),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(
              Icons.home,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PaginaPrincipal()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.directions_car,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const InfoViajes()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final conductorId = prefs.getInt('conductor_id');
              if (conductorId == null) {
                _showNoPermisosDialog();
                return;
              }
              final url = Uri.parse('$_baseUrl/conductor_estado/$conductorId/');
              final response = await http.get(url);
              if (!mounted) return;
              if (response.statusCode == 200 &&
                  jsonDecode(response.body)['activo'] == true) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OfercerViaje()),
                );
              } else {
                _showNoPermisosDialog();
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.group,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ViajesRecientes()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.person,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InfoPerfil()),
            ),
          ),
        ],
      ),
    );
  }

  void _showAyudaDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Ayuda'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Universidad FIME'),
                Text('Unidad de Soporte Técnico'),
                SizedBox(height: 8),
                Text('Teléfono: +52 81 1234 5678'),
                Text('Correo: soporte@fime.universidad.mx'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  void _showNoPermisosDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Permiso denegado'),
            content: const Text(
              'No tienes permisos de conductor. ¿Quieres enviar una solicitud para ser conductor?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FormularioConductores(usuarioId: 0),
                    ),
                  );
                },
                child: const Text('Enviar solicitud'),
              ),
            ],
          ),
    );
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => PaginaPrincipal()),
      (_) => false,
    );
  }
}
