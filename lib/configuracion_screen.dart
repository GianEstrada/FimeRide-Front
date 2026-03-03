import 'package:flutter/material.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Configuración"),
        backgroundColor: Color.fromARGB(255, 0, 87, 54),
      ),
      body: Center(
        child: Text("Pantalla de configuración en construcción."),
      ),
    );
  }
}