import 'dart:convert';
import 'package:fimeride_front/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ListaMensajesScreen extends StatefulWidget {
  const ListaMensajesScreen({super.key});

  @override
  _ListaMensajesScreenState createState() => _ListaMensajesScreenState();
}

class _ListaMensajesScreenState extends State<ListaMensajesScreen> {
  List<dynamic> mensajesActivos = [];

  @override
  void initState() {
    super.initState();
    _cargarChatsActivos();
  }

  Future<void> _cargarChatsActivos() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioLogueadoId = prefs.getInt('usuario_id') ?? 0;

    final url = Uri.parse('https://fimeride.onrender.com/api/mensajes/$usuarioLogueadoId/');
    print('URL para cargar chats activos: $url');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          mensajesActivos = data;
        });
      } else {
        print('Error al cargar chats activos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al conectar con la API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mensajes')),
      body: mensajesActivos.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: mensajesActivos.length,
              itemBuilder: (context, index) {
                final mensaje = mensajesActivos[index];
                final esEnviadoPorUsuario = mensaje['es_enviado_por_usuario'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(mensaje['otro_usuario']['foto_perfil'] ?? ''),
                  ),
                  title: Text(mensaje['otro_usuario']['nombre']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viaje ID: ${mensaje['id_viaje']}'),
                      Container(
                        color: esEnviadoPorUsuario ? Colors.green[100] : Colors.white,
                        padding: EdgeInsets.all(8.0),
                        child: Text(mensaje['mensaje']),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otroUsuario: mensaje['otro_usuario'],
                          idViaje: mensaje['id_viaje'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}