import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'formulario_conductores.dart'; 
import 'formulario_actualizar_datos.dart';
import 'terminos_condiciones.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  _ConfiguracionScreenState createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  // Datos del usuario
  String _nombre = '';
  String _matricula = '';
  String _fotoPerfil = 'assets/image/icono-perfil.png';
  int? _usuarioId;
  int? _conductorId;
  bool _isConductor = false;
  bool _isActive = false;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usuarioId = prefs.getInt('usuario_id');
      _nombre = prefs.getString('nombre') ?? 'Usuario';
      _matricula = prefs.getString('matricula') ?? '';
      _fotoPerfil = prefs.getString('foto_perfil') ?? 'assets/image/icono-perfil.png';
      _conductorId = prefs.getInt('conductor_id');
      _isConductor = _conductorId != null;
    });

    if (_isConductor && _conductorId != null) {
      await _fetchConductorStatus();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchConductorStatus() async {
    final url = Uri.parse("https://fimeride.onrender.com/api/conductor_estado/$_conductorId/");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _isActive = data['activo'] ?? false);
      } else {
        _showErrorSnackbar('No se pudo obtener el estado de conductor');
      }
    } catch (e) {
      _showErrorSnackbar('Error de conexión');
    }
  }

  Future<void> _toggleActive(bool newValue) async {
    if (_conductorId == null) return;
    setState(() => _isActive = newValue);
    final url = Uri.parse("https://fimeride.onrender.com/api/conductor_estado/$_conductorId/");
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'activo': newValue}),
      );
      if (response.statusCode != 200) {
        setState(() => _isActive = !newValue);
        _showErrorSnackbar('No se pudo actualizar el estado');
      }
    } catch (e) {
      setState(() => _isActive = !newValue);
      _showErrorSnackbar('Error de conexión');
    }
  }

  // ==================== NUEVO: selección de imagen con cámara/galería ====================
  Future<void> _handleImageSelection() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Tomar foto"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  _uploadPhoto(File(pickedFile.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Seleccionar de la galería"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  _uploadPhoto(File(pickedFile.path));
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Subir la imagen al backend
  Future<void> _uploadPhoto(File imageFile) async {
    if (_usuarioId == null) {
      _showErrorSnackbar('Usuario no identificado');
      return;
    }

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.parse("https://fimeride.onrender.com/api/usuarios/$_usuarioId/foto/");
      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('foto', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        final nuevaUrl = json['foto_perfil'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('foto_perfil', nuevaUrl);
        setState(() => _fotoPerfil = nuevaUrl);
        _showSuccessSnackbar('Foto de perfil actualizada');
      } else {
        throw Exception('Error al subir la imagen');
      }
    } catch (e) {
      _showErrorSnackbar('Error al cambiar la foto');
    } finally {
      Navigator.of(context).pop(); // Cerrar diálogo de carga
    }
  }

  void _solicitarSerConductor() {
    if (_usuarioId == null) {
      _showErrorSnackbar('No se pudo identificar al usuario');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioConductores(usuarioId: _usuarioId!),
      ),
    ).then((_) => _loadUserData());
  }

  // Snackbars
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  // Diálogo de ayuda
  void _showAyudaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color.fromARGB(255, 0, 87, 54),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildProfileSection(),
                const Divider(height: 32, thickness: 1),
                if (_isConductor) _buildConductorSection(),
                if (!_isConductor) _buildRequestConductorButton(),
                const Divider(height: 32, thickness: 1),
                _buildSecuritySection(),
                const Divider(height: 32, thickness: 1),
                _buildAboutSection(),
              ],
            ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _handleImageSelection,  // <--- Aquí usamos el nuevo método
            child: CircleAvatar(
              radius: 50,
              backgroundImage: _fotoPerfil.startsWith('http')
                  ? NetworkImage(_fotoPerfil)
                  : AssetImage(_fotoPerfil) as ImageProvider,
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: Color.fromARGB(255, 0, 87, 54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _nombre,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 0, 87, 54),
            ),
          ),
          if (_matricula.isNotEmpty)
            Text(
              _matricula,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          const SizedBox(height: 8),
          const Text(
            'Toca la foto para cambiarla',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConductorSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modo Conductor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 87, 54)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Disponible para viajes'),
            subtitle: Text(_isActive
                ? 'Los pasajeros pueden solicitarte'
                : 'No aparecerás en la búsqueda de viajes'),
            value: _isActive,
            onChanged: _toggleActive,
            activeColor: const Color.fromARGB(255, 0, 87, 54),
          ),
          const SizedBox(height: 8),
          const Text(
            'Al estar disponible, los pasajeros podrán ver tus viajes y solicitarte. '
            'Puedes desactivarlo cuando no quieras recibir solicitudes.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestConductorButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton.icon(
        onPressed: _solicitarSerConductor,
        icon: const Icon(Icons.drive_eta),
        label: const Text('Solicitar ser conductor'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 0, 87, 54),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seguridad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 87, 54)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const formulario_actualizar_datos())
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acerca de',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 87, 54)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión 1.0.0'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Ayuda'),
            onTap: () => _showAyudaDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind),
            title: const Text('Términos y condiciones'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const terminos_condiciones()),
              );
            }
          ),
        ],
      ),
    );
  }
}