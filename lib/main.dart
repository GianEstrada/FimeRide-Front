import 'dart:io';

import 'package:fimeride_front/login.dart';
import 'package:flutter/material.dart';
import 'api_service.dart'; // Archivo donde está la función fetchMapboxToken

String? mapboxAccessToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mapboxAccessToken = await fetchMapboxToken();
  runApp(MyApp());
}



class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: mapboxAccessToken == null
          ? Scaffold(
              body: Center(
                child: Text("Cargando token de Mapbox..."),
              ),
            )
          : PantallaInicio(),
    );
  }
}