import 'dart:async';
import 'dart:convert';

import 'package:fimeride_front/configuracion_screen.dart';
import 'package:fimeride_front/fimehub_home.dart';
import 'package:fimeride_front/fimehub_login.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/info_perfil.dart';
import 'package:fimeride_front/info_viajes.dart';
import 'package:fimeride_front/lista_mensajes_screen.dart';
import 'package:fimeride_front/pantalla_favoritos.dart';
import 'package:fimeride_front/chat_screen.dart';
import 'package:fimeride_front/local_notification_service.dart';
import 'package:fimeride_front/preinicio_viaje_screen.dart';
import 'package:fimeride_front/viaje_en_curso.dart';
import 'package:fimeride_front/viaje_alert_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ofercer_viaje.dart';
import 'viajes_recientes.dart';

class PaginaPrincipal extends StatefulWidget {
  const PaginaPrincipal({super.key});

  @override
  _PaginaPrincipalState createState() => _PaginaPrincipalState();
}

class _PaginaPrincipalState extends State<PaginaPrincipal> with WidgetsBindingObserver {
  static const Duration _monitorPollFast = Duration(seconds: 10);
  static const Duration _monitorPollSlow = Duration(minutes: 1);

  // DEBUG_REMOVE_START: cambia a false o borra este bloque para quitar herramientas debug.
  static const bool _debugToolsEnabled = true;
  // DEBUG_REMOVE_END

  bool _isConductor = false;
  bool _isConductorEnabled = false;
  List<dynamic> _viajes = [];
  List<dynamic> _asignaciones = [];
  String _fotoPerfil = 'assets/image/icono-perfil'; // Imagen predeterminada
  String _nombreUsuario = 'Usuario';
  ViajeAlertService? _viajeAlertService;
  Timer? _viajeEnCursoTimer;
  bool _preinicioConductorMostrado = false;
  bool _viajeEnCursoVisible = false;
  bool _monitorViajeEnCursoActivo = true;
  bool _isPollingViajeEnCurso = false;
  Duration _monitorIntervalActual = _monitorPollSlow;
  DateTime? _bloquearAutoAperturaHasta;
  int? _conductorId;
  int? _pasajeroId;
  final Set<int> _preinicioPasajeroMostrados = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConductorStatus();
    _fetchViajes();
    _fetchUsuarioInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initAlertasViaje();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viajeAlertService?.stop();
    _viajeEnCursoTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _monitorViajeEnCursoActivo = state == AppLifecycleState.resumed;
    if (_monitorViajeEnCursoActivo) {
      _pollViajeEnCurso();
      _programarMonitorViajeEnCurso();
    } else {
      _viajeEnCursoTimer?.cancel();
    }
  }

  Future<void> _initAlertasViaje() async {
    final prefs = await SharedPreferences.getInstance();
    final conductorId = prefs.getInt('conductor_id');
    final pasajeroId = prefs.getInt('pasajero_id');

    _conductorId = conductorId;
    _pasajeroId = pasajeroId;

    _viajeAlertService = ViajeAlertService(
      conductorId: conductorId,
      pasajeroId: pasajeroId,
      onConductorPopup: _mostrarPopupConductor,
      onConductorPreinicio: _mostrarPreinicioConductor,
      onPasajeroPopup: _mostrarPopupPasajero,
      onPasajeroConductorConfirmado: _mostrarAvisoConfirmacionConductor,
    );
    await _viajeAlertService?.start();
    _initMonitorViajeEnCurso();
  }

  void _initMonitorViajeEnCurso() {
    _monitorIntervalActual = _monitorPollSlow;
    _pollViajeEnCurso();
    _programarMonitorViajeEnCurso();
  }

  void _programarMonitorViajeEnCurso() {
    _viajeEnCursoTimer?.cancel();
    _viajeEnCursoTimer = Timer.periodic(_monitorIntervalActual, (_) {
      _pollViajeEnCurso();
    });
  }

  void _actualizarFrecuenciaMonitor(bool hayViajeActivo) {
    final nuevoIntervalo = hayViajeActivo ? _monitorPollFast : _monitorPollSlow;
    if (nuevoIntervalo == _monitorIntervalActual) return;

    _monitorIntervalActual = nuevoIntervalo;
    if (_monitorViajeEnCursoActivo) {
      _programarMonitorViajeEnCurso();
    }
  }

  (ViajeEnCursoRol, int)? _rolPreferido() {
    if (_isConductor && _conductorId != null) {
      return (ViajeEnCursoRol.conductor, _conductorId!);
    }
    if (!_isConductor && _pasajeroId != null) {
      return (ViajeEnCursoRol.pasajero, _pasajeroId!);
    }
    if (_conductorId != null) {
      return (ViajeEnCursoRol.conductor, _conductorId!);
    }
    if (_pasajeroId != null) {
      return (ViajeEnCursoRol.pasajero, _pasajeroId!);
    }
    return null;
  }

  Future<bool> _hayViajeEnCurso(ViajeEnCursoRol rol, int rolId) async {
    final roleSegment = rol == ViajeEnCursoRol.conductor ? 'conductor' : 'pasajero';
    final url = Uri.parse(
      'https://fimeride.onrender.com/api/viajes/$roleSegment/$rolId/en_curso/',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> && decoded['hay_viaje'] == true;
  }

  Future<void> _pollViajeEnCurso() async {
    if (!mounted || !_monitorViajeEnCursoActivo || _viajeEnCursoVisible || _isPollingViajeEnCurso) {
      return;
    }
    if (_bloquearAutoAperturaHasta != null && DateTime.now().isBefore(_bloquearAutoAperturaHasta!)) {
      return;
    }

    _isPollingViajeEnCurso = true;
    bool hayViajeActivo = false;
    try {
      final preferido = _rolPreferido();
      if (preferido == null) return;

      final (rol, rolId) = preferido;
      final hayViaje = await _hayViajeEnCurso(rol, rolId);
      hayViajeActivo = hayViaje;
      if (hayViaje) {
        await _abrirViajeEnCurso(rol, rolId);
        return;
      }

      // Si no hay viaje en el rol preferido, intenta el otro rol una vez.
      if (rol == ViajeEnCursoRol.conductor && _pasajeroId != null) {
        final hayViajePasajero = await _hayViajeEnCurso(ViajeEnCursoRol.pasajero, _pasajeroId!);
        hayViajeActivo = hayViajePasajero;
        if (hayViajePasajero) {
          await _abrirViajeEnCurso(ViajeEnCursoRol.pasajero, _pasajeroId!);
        }
      } else if (rol == ViajeEnCursoRol.pasajero && _conductorId != null) {
        final hayViajeConductor = await _hayViajeEnCurso(ViajeEnCursoRol.conductor, _conductorId!);
        hayViajeActivo = hayViajeConductor;
        if (hayViajeConductor) {
          await _abrirViajeEnCurso(ViajeEnCursoRol.conductor, _conductorId!);
        }
      }
    } catch (_) {
      // El monitor seguirá intentando en el siguiente ciclo.
    } finally {
      _actualizarFrecuenciaMonitor(hayViajeActivo);
      _isPollingViajeEnCurso = false;
    }
  }

  Future<void> _abrirViajeEnCurso(ViajeEnCursoRol rol, int rolId) async {
    if (!mounted || _viajeEnCursoVisible) return;

    _viajeEnCursoVisible = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViajeEnProcesoScreen(
          rol: rol,
          rolId: rolId,
          onViajeCerrado: () async {
            await _viajeAlertService?.forceRefresh();
          },
        ),
      ),
    );
    _viajeEnCursoVisible = false;
    _bloquearAutoAperturaHasta = DateTime.now().add(const Duration(seconds: 20));
  }

  Future<void> _mostrarPopupConductor(Map<String, dynamic> viaje) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmacion de viaje'),
          content: Text(
            'Tiene un viaje proximo en 15 minutos ${viaje['inicio']} -> ${viaje['destino']} ${viaje['hora_salida']}.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _accionConductorViaje(viaje['id'], 'cancelar');
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _accionConductorViaje(viaje['id'], 'confirmar');
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarPopupPasajero(Map<String, dynamic> viaje, {required bool esHoraSalida}) async {
    if (!mounted) return;

    final mensajeBase =
        'Tienes un viaje proximo: ${viaje['inicio']} -> ${viaje['destino']} ${viaje['hora_salida']}. '
        'Tienes 5 minutos despues de la hora de salida para subir al vehiculo.';

    if (!esHoraSalida) {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return AlertDialog(
            title: const Text('Recordatorio de viaje'),
            content: Text(mensajeBase),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          );
        },
      );
      return;
    }

    final viajeId = viaje['viaje_id'] as int;
    if (_preinicioPasajeroMostrados.contains(viajeId)) return;
    _preinicioPasajeroMostrados.add(viajeId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreinicioPasajeroScreen(
          data: viaje,
          onConfirmarAbordo: () async {
            await _confirmarAbordo(viaje['asignacion_id']);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _mostrarAvisoConfirmacionConductor(Map<String, dynamic> viaje) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Viaje confirmado'),
          content: Text(
            'El conductor del viaje de ${viaje['inicio']} a ${viaje['destino']} a las ${viaje['hora_salida']} confirmo el viaje de hoy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarPreinicioConductor(Map<String, dynamic> preinicio) async {
    if (!mounted || _preinicioConductorMostrado) return;
    _preinicioConductorMostrado = true;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreinicioConductorScreen(
          data: preinicio,
          onRefresh: () async {
            await _viajeAlertService?.forceRefresh();
          },
          onViajeIniciado: () async {
            if (_conductorId != null) {
              await _abrirViajeEnCurso(ViajeEnCursoRol.conductor, _conductorId!);
            }
          },
        ),
      ),
    );

    _preinicioConductorMostrado = false;
  }

  Future<void> _confirmarAbordo(int asignacionId) async {
    final url = Uri.parse('https://fimeride.onrender.com/api/asignaciones/$asignacionId/abordo/');
    await http.patch(url, headers: {'Content-Type': 'application/json'});
    await _viajeAlertService?.forceRefresh();
  }

  Future<void> _accionConductorViaje(int viajeId, String accion) async {
    final url = Uri.parse('https://fimeride.onrender.com/api/viajes/$viajeId/accion_conductor/');
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accion': accion}),
    );
    await _viajeAlertService?.forceRefresh();
  }

  Future<void> _forzarViajeEnCursoTemporal(ViajeEnCursoRol rol, int rolId) async {
    try {
      final roleSegment = rol == ViajeEnCursoRol.conductor ? 'conductor' : 'pasajero';
      final url = Uri.parse(
        'https://fimeride.onrender.com/api/viajes/$roleSegment/$rolId/forzar_en_curso/',
      );
      await http.post(url, headers: {'Content-Type': 'application/json'});
    } catch (_) {
      // Si falla el forzado, la vista igual intentará abrir con el estado real.
    }
  }

  // DEBUG_REMOVE_START
  Future<void> _debugForzarConductorPopupYNotificacion() async {
    final viaje = {
      'id': -100,
      'inicio': 'Monterrey Centro',
      'destino': 'FIME',
      'hora_salida': '08:00',
    };

    await LocalNotificationService.show(
      id: 91001,
      title: 'DEBUG Conductor',
      body: 'Forzando notificacion de conductor',
    );

    await _mostrarPopupConductor(viaje);
  }

  Future<void> _debugForzarPasajeroPopupYNotificacion() async {
    final viaje = {
      'asignacion_id': -200,
      'viaje_id': -201,
      'inicio': 'Monterrey Centro',
      'destino': 'FIME',
      'hora_salida': '08:00',
      'confirmado_por_conductor': true,
    };

    await LocalNotificationService.show(
      id: 91002,
      title: 'DEBUG Pasajero',
      body: 'Forzando notificacion de pasajero',
    );

    await _mostrarPopupPasajero(viaje, esHoraSalida: false);
  }

  Future<void> _debugAbrirPreinicioConductor() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreinicioConductorScreen(
          data: {
            'viaje_id': -300,
            'inicio': 'Monterrey Centro',
            'destino': 'FIME',
            'hora_salida': '08:00',
            'conductor_nombre': 'Debug Conductor',
            'vehiculo': 'Toyota Corolla 2020',
            'placas_vehiculo': 'DBG-1234',
            'origen_lat': 25.6866,
            'origen_lng': -100.3161,
            'destino_lat': 25.7250,
            'destino_lng': -100.3134,
            'pasajeros': [
              {'asignacion_id': -1, 'nombre': 'Pasajero A', 'abordo_confirmado': true},
              {'asignacion_id': -2, 'nombre': 'Pasajero B', 'abordo_confirmado': false},
            ],
            'puede_iniciar': false,
            'puede_esperar_5_mas': true,
          },
          onRefresh: () async {},
        ),
      ),
    );
  }

  Future<void> _debugAbrirPreinicioPasajero() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreinicioPasajeroScreen(
          data: {
            'asignacion_id': -400,
            'viaje_id': -401,
            'inicio': 'Monterrey Centro',
            'destino': 'FIME',
            'hora_salida': '08:00',
          },
          onConfirmarAbordo: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DEBUG: abordaje confirmado (simulado).')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _debugForzarVistaViajeEnCursoConductor() async {
    final conductorIdDebug = _conductorId ?? 17;
    if (_conductorId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DEBUG: usando conductor_id placeholder (17).')),
      );
    }

    await _forzarViajeEnCursoTemporal(ViajeEnCursoRol.conductor, conductorIdDebug);
    if (!mounted || _viajeEnCursoVisible) return;
    _viajeEnCursoVisible = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViajeEnProcesoScreen(
          rol: ViajeEnCursoRol.conductor,
          rolId: conductorIdDebug,
          debugMockIfNoTrip: true,
          onViajeCerrado: () async {
            await _viajeAlertService?.forceRefresh();
          },
        ),
      ),
    );
    _viajeEnCursoVisible = false;
  }

  Future<void> _debugForzarVistaViajeEnCursoPasajero() async {
    final pasajeroIdDebug = _pasajeroId ?? 18;
    if (_pasajeroId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DEBUG: usando pasajero_id placeholder (18).')),
      );
    }

    await _forzarViajeEnCursoTemporal(ViajeEnCursoRol.pasajero, pasajeroIdDebug);
    if (!mounted || _viajeEnCursoVisible) return;
    _viajeEnCursoVisible = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViajeEnProcesoScreen(
          rol: ViajeEnCursoRol.pasajero,
          rolId: pasajeroIdDebug,
          debugMockIfNoTrip: true,
          onViajeCerrado: () async {
            await _viajeAlertService?.forceRefresh();
          },
        ),
      ),
    );
    _viajeEnCursoVisible = false;
  }

  void _openDebugTripTools() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Debug Viajes (temporal)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugForzarConductorPopupYNotificacion();
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Conductor: notificacion + popup'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugForzarPasajeroPopupYNotificacion();
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Pasajero: notificacion + popup'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugAbrirPreinicioConductor();
                  },
                  icon: const Icon(Icons.route),
                  label: const Text('Abrir preinicio conductor'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugAbrirPreinicioPasajero();
                  },
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Abrir preinicio pasajero'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugForzarVistaViajeEnCursoConductor();
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Forzar viaje en curso (Conductor)'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _debugForzarVistaViajeEnCursoPasajero();
                  },
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Forzar viaje en curso (Pasajero)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // DEBUG_REMOVE_END

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
  floatingActionButton: _debugToolsEnabled
      ? FloatingActionButton.small(
          heroTag: 'debug_tools_fab',
          onPressed: _openDebugTripTools,
          backgroundColor: const Color.fromARGB(255, 0, 87, 54),
          child: const Icon(Icons.bug_report, color: Colors.white),
        )
      : null,
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
                            heroTag: 'menu_drawer_fab',
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
                          activeThumbColor: Colors.white,
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

                                  if (conductor['id'] == null) {
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
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const FimeHubHome()),
                        (route) => false,
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
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final usuarioId = prefs.getInt('usuario_id');
              Navigator.of(context).pop();
              if (usuarioId == null) {
                _showErrorDialog(context, "No se pudo obtener tu usuario. Vuelve a iniciar sesión.");
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FormularioConductores(usuarioId: usuarioId)),
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
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const FimeHubLogin()),
    (route) => false,
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