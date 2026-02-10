import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> otroUsuario;
  final int idViaje;

  ChatScreen({required this.otroUsuario, required this.idViaje});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _mensajeController = TextEditingController();
  final List<Map<String, dynamic>> _mensajes = [];
  late int _usuarioLogueadoId;

  @override
  void initState() {
  super.initState();
  _inicializarChat();
}

  Future<void> _inicializarChat() async {
  await _cargarUsuarioLogueado(); // Espera a que se cargue el usuario logueado
  _cargarMensajes(); // Luego carga los mensajes
}

  Future<void> _cargarUsuarioLogueado() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usuarioLogueadoId = prefs.getInt('usuario_id') ?? 0;
      print('Usuario logueado ID: $_usuarioLogueadoId');
    });
  }

  Future<void> _cargarMensajes() async {
  final url = Uri.parse(
      'https://fimeride.onrender.com/api/mensajes/$_usuarioLogueadoId/${widget.otroUsuario['id']}/${widget.idViaje}/');
  print('URL para cargar mensajes: $url');

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      // Imprime los datos recibidos para depuración
      print('Datos recibidos del backend: $data');

      setState(() {
        _mensajes.clear();
        _mensajes.addAll(data.map((mensaje) {
          final esEnviadoPorUsuario = mensaje['enviado_por'] == _usuarioLogueadoId;
          print('Mensaje: ${mensaje['mensaje']}, esEnviadoPorUsuario: $esEnviadoPorUsuario');
          return {
            'mensaje': mensaje['mensaje'],
            'fecha_envio': mensaje['fecha_envio'],
            'es_enviado_por_usuario': esEnviadoPorUsuario,
          };
        }).toList());

        // Imprime el estado actualizado de _mensajes
        print('_mensajes actualizado: $_mensajes');
      });
    } else {
      print('Error al cargar mensajes: ${response.statusCode}');
    }
  } catch (e) {
    print('Error al conectar con la API: $e');
  }
}

  Future<void> _enviarMensaje() async {
  final mensaje = _mensajeController.text.trim();
  if (mensaje.isNotEmpty) {
    print('Mensaje no vacío, enviando...');
    final url = Uri.parse('https://fimeride.onrender.com/api/mensajes/');
    final body = jsonEncode({
      'enviado_por': _usuarioLogueadoId,
      'recibido_por': widget.otroUsuario['id'],
      'id_viaje': widget.idViaje,
      'mensaje': mensaje,
    });

    // Imprime el cuerpo del POST
    print('Cuerpo del POST: $body');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('Código de estado: ${response.statusCode}');
      print('Cuerpo de la respuesta: ${response.body}');
      if (response.statusCode == 201) {
        // Limpia los mensajes actuales y la entrada de texto
        setState(() {
          _mensajes.clear();
          _mensajeController.clear();
        });

        // Vuelve a cargar todos los mensajes
        await _cargarMensajes();
      } else {
        print('Error al enviar mensaje: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al conectar con la API: $e');
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 87, 54),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
  backgroundImage: widget.otroUsuario['foto_perfil'] != null
      ? NetworkImage(widget.otroUsuario['foto_perfil'])
      : AssetImage('assets/images/default_profile.png') as ImageProvider,
),
                const SizedBox(width: 8),
                Text(widget.otroUsuario['nombre']),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Viaje ID: ${widget.idViaje}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
  reverse: true,
  itemCount: _mensajes.length,
  itemBuilder: (context, index) {
    final mensaje = _mensajes[index];
    final esEnviadoPorUsuario = mensaje['es_enviado_por_usuario'] ?? false;

    // Imprime el valor de esEnviadoPorUsuario para depuración
    print('Mensaje: ${mensaje['mensaje']}, esEnviadoPorUsuario: $esEnviadoPorUsuario');

    return Align(
      alignment: esEnviadoPorUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: esEnviadoPorUsuario ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: esEnviadoPorUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              mensaje['mensaje'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              mensaje['fecha_envio'],
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  },
)
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color.fromARGB(255, 0, 87, 54)),
                  onPressed: _enviarMensaje,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}