import 'dart:async';
import 'dart:convert';

import 'package:fimeride_front/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum ViajeEnCursoRol { conductor, pasajero }

class ViajeEnProcesoScreen extends StatefulWidget {
  const ViajeEnProcesoScreen({
    super.key,
    required this.rol,
    required this.rolId,
    this.debugMockIfNoTrip = false,
    this.onViajeCerrado,
  });

  final ViajeEnCursoRol rol;
  final int rolId;
  final bool debugMockIfNoTrip;
  final Future<void> Function()? onViajeCerrado;

  @override
  State<ViajeEnProcesoScreen> createState() => _ViajeEnProcesoScreenState();
}

class _ViajeEnProcesoScreenState extends State<ViajeEnProcesoScreen> {
  static const Duration _tripPollFast = Duration(seconds: 10);
  static const Duration _tripPollSlow = Duration(seconds: 45);

  final Distance _distance = const Distance();

  Timer? _pollTimer;
  StreamSubscription<Position>? _positionSubscription;
  bool _isLoading = true;
  bool _hadActiveTrip = false;
  bool _closingScreen = false;
  bool _isPollingTrip = false;
  Duration _tripPollInterval = _tripPollSlow;
  bool _isSendingLocation = false;
  bool _locationDenied = false;
  String? _errorMessage;
  String? _mapboxToken;
  Map<String, dynamic>? _viaje;
  LatLng? _manualStopPoint;
  List<LatLng> _routePoints = <LatLng>[];
  List<String> _instructions = <String>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _mapboxToken = mapboxAccessToken ?? await fetchMapboxToken();
    if (mapboxAccessToken == null && _mapboxToken != null) {
      mapboxAccessToken = _mapboxToken;
    }

    await _loadTrip(showLoader: true);
    _programarSiguientePollTrip();

    if (widget.rol == ViajeEnCursoRol.conductor) {
      await _startLocationTracking();
    }
  }

  void _programarSiguientePollTrip() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_tripPollInterval, () async {
      await _loadTrip();
      if (!mounted || _closingScreen) return;
      _programarSiguientePollTrip();
    });
  }

  Future<void> _loadTrip({bool showLoader = false}) async {
    if (!mounted || _isPollingTrip) return;

    _isPollingTrip = true;

    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final roleSegment = widget.rol == ViajeEnCursoRol.conductor ? 'conductor' : 'pasajero';
      final url = Uri.parse(
        'https://fimeride.onrender.com/api/viajes/$roleSegment/${widget.rolId}/en_curso/',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          throw Exception(
            'El backend desplegado no tiene el endpoint de viaje en curso. Actualiza Render con el último backend.',
          );
        }
        final body = response.body.trim();
        if (body.isNotEmpty) {
          throw Exception(
            'No se pudo obtener el viaje en curso (${response.statusCode}): $body',
          );
        }
        throw Exception('No se pudo obtener el viaje en curso (${response.statusCode}).');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respuesta inválida del servidor');
      }

      if (decoded['hay_viaje'] != true) {
        if (widget.debugMockIfNoTrip) {
          final mockTrip = _buildMockTrip();
          final routeSnapshot = await _buildRouteSnapshot(mockTrip);
          if (!mounted) return;
          setState(() {
            _hadActiveTrip = true;
            _viaje = mockTrip;
            _routePoints = routeSnapshot.points;
            _instructions = routeSnapshot.instructions;
            _isLoading = false;
            _errorMessage = null;
          });
          return;
        }

        _tripPollInterval = _tripPollSlow;
        if (_hadActiveTrip) {
          await _closeScreen('El viaje terminó.');
          return;
        }

        if (!mounted) return;
        setState(() {
          _viaje = null;
          _routePoints = <LatLng>[];
          _instructions = <String>[];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      final viaje = decoded['viaje'];
      if (viaje is! Map<String, dynamic>) {
        throw Exception('El viaje en curso no contiene datos válidos');
      }

      _tripPollInterval = _tripPollFast;

      final routeSnapshot = await _buildRouteSnapshot(viaje);
      if (!mounted) return;

      setState(() {
        _hadActiveTrip = true;
        _viaje = viaje;
        _routePoints = routeSnapshot.points;
        _instructions = routeSnapshot.instructions;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _isPollingTrip = false;
    }
  }

  Map<String, dynamic> _buildMockTrip() {
    if (widget.rol == ViajeEnCursoRol.pasajero) {
      return <String, dynamic>{
        'viaje_id': -900,
        'inicio': 'Monterrey Centro',
        'destino': 'FIME',
        'conductor': {
          'nombre': 'Conductor Debug',
          'vehiculo': 'Nissan Versa 2022',
          'placas': 'DBG-9012',
        },
        'origen': {'lat': 25.6866, 'lng': -100.3161},
        'destino_final': {'lat': 25.7250, 'lng': -100.3134},
        'conductor_posicion': {'lat': 25.7000, 'lng': -100.3150},
        'tu_asignacion': {
          'asignacion_id': -901,
          'destino': {'lat': 25.7200, 'lng': -100.3140},
          'distancia_a_tu_parada_metros': 180,
          'parada_solicitada': false,
          'parada': null,
        },
        'pasajeros': [
          {'nombre': 'Tú', 'estado': 'en_vehiculo'},
          {'nombre': 'Pasajero B', 'estado': 'pendiente_abordar'},
        ],
        'parada_activa': null,
      };
    }

    return <String, dynamic>{
      'viaje_id': -910,
      'inicio': 'Monterrey Centro',
      'destino': 'FIME',
      'conductor': {
        'nombre': 'Conductor Debug',
        'vehiculo': 'Toyota Corolla 2020',
        'placas': 'DBG-1234',
      },
      'origen': {'lat': 25.6866, 'lng': -100.3161},
      'destino_final': {'lat': 25.7250, 'lng': -100.3134},
      'conductor_posicion': {'lat': 25.7060, 'lng': -100.3149},
      'pasajeros': [
        {'nombre': 'Pasajero A', 'estado': 'en_vehiculo'},
        {'nombre': 'Pasajero B', 'estado': 'bajo_del_vehiculo'},
      ],
      'parada_activa': {
        'nombre': 'Pasajero A',
        'ubicacion': {'lat': 25.7180, 'lng': -100.3142},
      },
      'tu_asignacion': null,
    };
  }

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _locationDenied = true;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _locationDenied = true;
      });
      return;
    }

    final currentPosition = await Geolocator.getCurrentPosition();
    await _sendConductorLocation(currentPosition);

    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 15,
      ),
    ).listen((position) async {
      await _sendConductorLocation(position);
    });

    if (!mounted) return;
    setState(() {
      _locationDenied = false;
    });
  }

  Future<void> _sendConductorLocation(Position position) async {
    if (_isSendingLocation) return;

    final viajeId = _asInt(_viaje?['viaje_id']);
    if (viajeId == null) return;

    _isSendingLocation = true;
    try {
      final url = Uri.parse(
        'https://fimeride.onrender.com/api/viajes/$viajeId/ubicacion_conductor/',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['viaje_finalizado'] == true) {
          await _closeScreen('Llegaste al destino final.');
        }
      }
    } catch (_) {
      // El polling continuará actualizando el estado del viaje.
    } finally {
      _isSendingLocation = false;
    }
  }

  Future<void> _closeScreen(String message) async {
    if (_closingScreen) return;
    _closingScreen = true;
    _pollTimer?.cancel();
    await _positionSubscription?.cancel();
    await widget.onViajeCerrado?.call();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await Navigator.of(context).maybePop();
  }

  Future<_RouteSnapshot> _buildRouteSnapshot(Map<String, dynamic> viaje) async {
    final current = _readPoint(viaje['conductor_posicion']) ?? _readPoint(viaje['origen']);
    final destination = widget.rol == ViajeEnCursoRol.conductor
        ? _readPoint(viaje['destino_final'])
      : (_manualStopPoint ?? _readPoint((viaje['tu_asignacion'] as Map<String, dynamic>?)?['destino']));
    final stopReference = widget.rol == ViajeEnCursoRol.conductor
        ? _readStopReference(viaje['parada_activa'] as Map<String, dynamic>?)
        : _readPassengerStopReference((viaje['tu_asignacion'] as Map<String, dynamic>?)?['parada']);

    final waypoints = <LatLng>[];
    if (current != null) {
      waypoints.add(current);
    }
    if (stopReference != null && current != null && !_samePoint(current, stopReference)) {
      waypoints.add(stopReference);
    }
    if (destination != null && (waypoints.isEmpty || !_samePoint(waypoints.last, destination))) {
      waypoints.add(destination);
    }

    if (waypoints.length < 2 || (_mapboxToken?.isEmpty ?? true)) {
      return const _RouteSnapshot(points: <LatLng>[], instructions: <String>[]);
    }

    final coordinates = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coordinates'
      '?alternatives=false&steps=true&geometries=geojson&language=es&overview=full'
      '&access_token=$_mapboxToken',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      return const _RouteSnapshot(points: <LatLng>[], instructions: <String>[]);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = decoded['routes'] as List<dynamic>? ?? <dynamic>[];
    if (routes.isEmpty) {
      return const _RouteSnapshot(points: <LatLng>[], instructions: <String>[]);
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinatesList = geometry?['coordinates'] as List<dynamic>? ?? <dynamic>[];
    final points = coordinatesList
        .whereType<List<dynamic>>()
        .where((coordinate) => coordinate.length >= 2)
        .map((coordinate) => LatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            ))
        .toList();

    final instructions = <String>[];
    final legs = route['legs'] as List<dynamic>? ?? <dynamic>[];
    for (final leg in legs.whereType<Map<String, dynamic>>()) {
      final steps = leg['steps'] as List<dynamic>? ?? <dynamic>[];
      for (final step in steps.whereType<Map<String, dynamic>>()) {
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        final instruction = maneuver?['instruction']?.toString();
        if (instruction == null || instruction.isEmpty) continue;
        final distanceMeters = (step['distance'] as num?)?.toDouble() ?? 0;
        instructions.add('$instruction • ${_formatDistance(distanceMeters)}');
      }
    }

    return _RouteSnapshot(points: points, instructions: instructions.take(8).toList());
  }

  Future<void> _requestStop() async {
    final tuAsignacion = _viaje?['tu_asignacion'] as Map<String, dynamic>?;
    final asignacionId = _asInt(tuAsignacion?['asignacion_id']);
    if (asignacionId == null) return;

    try {
      final url = Uri.parse(
        'https://fimeride.onrender.com/api/asignaciones/$asignacionId/solicitar_parada/',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{
          if (_manualStopPoint != null) 'lat': _manualStopPoint!.latitude,
          if (_manualStopPoint != null) 'lng': _manualStopPoint!.longitude,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo solicitar la parada');
      }

      await _loadTrip();
      if (!mounted) return;
      await _showStopStatusDialog();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _updateStopStatus(String action) async {
    final tuAsignacion = _viaje?['tu_asignacion'] as Map<String, dynamic>?;
    final asignacionId = _asInt(tuAsignacion?['asignacion_id']);
    if (asignacionId == null) return;

    try {
      final url = Uri.parse(
        'https://fimeride.onrender.com/api/asignaciones/$asignacionId/estado_parada/',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accion': action}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudo actualizar el estado de la parada');
      }

      await _loadTrip();
      if (!mounted) return;
      if (action == 'baje_del_vehiculo') {
        await _closeScreen('Tu viaje terminó.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showStopStatusDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Estado de la parada'),
          content: const Text(
            'Cuando ocurra la parada, confirma si bajaste del vehículo o si no se realizó.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateStopStatus('no_realizo_parada');
              },
              child: const Text('No realizo parada'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _updateStopStatus('baje_del_vehiculo');
              },
              child: const Text('Baje del vehiculo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReportDialog() async {
    final viajeId = _asInt(_viaje?['viaje_id']);
    final asunto = 'Reporte FimeRide - Viaje ${viajeId ?? ''}'.trim();
    const telefonoSoporte = '+528112345678';
    const correoSoporte = 'soporte@fime.universidad.mx';
    final descripcionController = TextEditingController();
    String categoria = 'conduccion';
    String canal = 'correo';

    Future<void> enviarReporte() async {
      final descripcion = descripcionController.text.trim();
      if (descripcion.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe una breve descripción del reporte.')),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');
      if (usuarioId == null || viajeId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar usuario o viaje para reportar.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('https://fimeride.onrender.com/api/reportes/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
          'viaje_id': viajeId,
          'rol_reportante': widget.rol == ViajeEnCursoRol.conductor ? 'conductor' : 'pasajero',
          'categoria': categoria,
          'canal_preferido': canal,
          'descripcion': descripcion,
        }),
      );

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte enviado y registrado con éxito.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar el reporte: ${response.body}')),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reportar viaje con soporte'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Universidad FIME'),
                    const Text('Unidad de Soporte Técnico'),
                    const SizedBox(height: 8),
                    const Text('Teléfono: +52 81 1234 5678'),
                    const Text('Correo: soporte@fime.universidad.mx'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: categoria,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: const [
                        DropdownMenuItem(value: 'conduccion', child: Text('Conducción')), 
                        DropdownMenuItem(value: 'seguridad', child: Text('Seguridad')), 
                        DropdownMenuItem(value: 'vehiculo', child: Text('Vehículo')), 
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => categoria = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: canal,
                      decoration: const InputDecoration(labelText: 'Canal preferido'),
                      items: const [
                        DropdownMenuItem(value: 'correo', child: Text('Correo')), 
                        DropdownMenuItem(value: 'telefono', child: Text('Teléfono')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => canal = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descripcionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del reporte',
                        hintText: 'Escribe qué ocurrió durante el viaje.',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await enviarReporte();
              },
              child: const Text('Guardar reporte'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: 'soporte@fime.universidad.mx'),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Correo copiado al portapapeles.')),
                );
              },
              child: const Text('Copiar correo'),
            ),
            TextButton(
              onPressed: () async {
                await enviarReporte();
                final uri = Uri.parse('tel:$telefonoSoporte');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Llamar'),
            ),
            TextButton(
              onPressed: () async {
                await enviarReporte();
                final uri = Uri(
                  scheme: 'mailto',
                  path: correoSoporte,
                  queryParameters: <String, String>{
                    'subject': asunto,
                  },
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Enviar correo'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );

    descripcionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConductor = widget.rol == ViajeEnCursoRol.conductor;

    return Scaffold(
      appBar: AppBar(
        title: Text(isConductor ? 'Viaje en curso del conductor' : 'Tu viaje en curso'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState(theme)
              : _viaje == null
                  ? _buildEmptyState(theme)
                  : RefreshIndicator(
                      onRefresh: _loadTrip,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (_locationDenied && isConductor) _buildLocationWarning(theme),
                          _buildHeroCard(theme, isConductor),
                          const SizedBox(height: 16),
                          _buildMapCard(theme, isConductor),
                          const SizedBox(height: 16),
                          if (isConductor) _buildInstructionsCard(theme),
                          if (!isConductor) _buildPassengerInfo(theme),
                          if (isConductor) _buildPassengersCard(theme),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildLocationWarning(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        'Activa ubicación y permisos para actualizar la ruta del pasajero en tiempo real.',
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, bool isConductor) {
    final conductor = _viaje?['conductor'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final tuAsignacion = _viaje?['tu_asignacion'] as Map<String, dynamic>?;
    final distanciaParada = _asInt(tuAsignacion?['distancia_a_tu_parada_metros']);
    final estado = isConductor
        ? ((_viaje?['parada_activa'] != null) ? 'Hay una parada solicitada' : 'Ruta hacia destino final')
        : (tuAsignacion?['parada_solicitada'] == true ? 'Parada solicitada' : 'Sigues en ruta');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6E4F), Color(0xFF139A43)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _viaje?['inicio']?.toString() ?? 'Origen',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            _viaje?['destino']?.toString() ?? 'Destino',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Estado', estado),
              _pill('Conductor', conductor['nombre']?.toString() ?? 'Sin nombre'),
              _pill('Vehículo', conductor['vehiculo']?.toString() ?? 'Sin vehículo'),
              _pill('Placas', conductor['placas']?.toString() ?? 'Sin placas'),
              if (!isConductor && distanciaParada != null)
                _pill('Distancia a tu parada', _formatDistance(distanciaParada.toDouble())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(ThemeData theme, bool isConductor) {
    final current = _readPoint(_viaje?['conductor_posicion']) ?? _readPoint(_viaje?['origen']);
    final destination = isConductor
        ? _readPoint(_viaje?['destino_final'])
        : (_manualStopPoint ?? _readPoint((_viaje?['tu_asignacion'] as Map<String, dynamic>?)?['destino']));
    final stopReference = isConductor
        ? _readStopReference(_viaje?['parada_activa'] as Map<String, dynamic>?)
        : _readPassengerStopReference((_viaje?['tu_asignacion'] as Map<String, dynamic>?)?['parada']);

    final markers = <Marker>[];
    if (current != null) {
      markers.add(
        Marker(
          point: current,
          width: 52,
          height: 52,
          builder: (_) => const Icon(Icons.directions_car, color: Colors.green, size: 36),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          point: destination,
          width: 52,
          height: 52,
          builder: (_) => const Icon(Icons.location_pin, color: Colors.red, size: 38),
        ),
      );
    }
    if (!isConductor && _manualStopPoint != null) {
      markers.add(
        Marker(
          point: _manualStopPoint!,
          width: 52,
          height: 52,
          builder: (_) => const Icon(Icons.place, color: Colors.blue, size: 34),
        ),
      );
    }
    if (stopReference != null) {
      markers.add(
        Marker(
          point: stopReference,
          width: 52,
          height: 52,
          builder: (_) => const Icon(Icons.flag_circle, color: Colors.orange, size: 34),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isConductor ? 'Ruta e indicaciones' : 'Ruta con ubicación del conductor',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                options: MapOptions(
                  center: current ?? destination ?? LatLng(25.6866, -100.3161),
                  zoom: 14,
                  onLongPress: isConductor
                      ? null
                      : (_, point) {
                          setState(() {
                            _manualStopPoint = point;
                          });
                          _loadTrip();
                        },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 5,
                          color: const Color(0xFF0B6E4F),
                        ),
                      ],
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
          if (!isConductor) ...[
            const SizedBox(height: 12),
            Text(
              'Mantén presionado el mapa para marcar una parada intermedia.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            _buildPassengerActions(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildPassengerActions(ThemeData theme) {
    final tuAsignacion = _viaje?['tu_asignacion'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final stopRequested = tuAsignacion['parada_solicitada'] == true;
    final currentPoint = _readPoint(_viaje?['conductor_posicion']) ?? _readPoint(_viaje?['origen']);
    final selectedPoint = _manualStopPoint;
    final selectedDistance = selectedPoint != null && currentPoint != null
      ? _distance.as(LengthUnit.Meter, currentPoint, selectedPoint)
      : null;
    final canRequestStop = selectedDistance != null
      ? selectedDistance <= 200 && !stopRequested
      : tuAsignacion['puede_solicitar_parada'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stopRequested)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_circle, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu parada ya fue enviada al conductor.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: _showStopStatusDialog,
                  child: const Text('Ver estado'),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showReportDialog,
                icon: const Icon(Icons.report_gmailerrorred),
                label: const Text('Reportar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: stopRequested
                    ? _showStopStatusDialog
                    : canRequestStop
                        ? _requestStop
                        : null,
                icon: const Icon(Icons.flag),
                label: Text(stopRequested ? 'Estado de parada' : 'Terminar mi viaje'),
              ),
            ),
          ],
        ),
        if (!canRequestStop && !stopRequested)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              selectedDistance != null
                  ? 'Faltan ${_formatDistance(selectedDistance)} para la parada marcada.'
                  : 'Se habilita cuando falten 200 m o menos para tu punto de bajada.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ),
      ],
    );
  }

  Widget _buildPassengerInfo(ThemeData theme) {
    final conductor = _viaje?['conductor'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información del conductor',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _infoRow(Icons.person_outline, conductor['nombre']?.toString() ?? 'Sin nombre'),
          _infoRow(Icons.directions_car_filled_outlined, conductor['vehiculo']?.toString() ?? 'Sin vehículo'),
          _infoRow(Icons.pin_outlined, conductor['placas']?.toString() ?? 'Sin placas'),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(ThemeData theme) {
    final stop = _viaje?['parada_activa'] as Map<String, dynamic>?;
    final fallbackInstructions = <String>[
      'Continúa 300 m por la vialidad principal',
      'Mantente a la derecha para seguir hacia el destino',
      'Reduce velocidad al aproximarte al punto de descenso',
    ];
    final shownInstructions = _instructions.isEmpty ? fallbackInstructions : _instructions;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indicaciones en tiempo real',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (stop != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Parada activa para ${stop['nombre'] ?? 'pasajero'}. Aparece señalada en el mapa.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_instructions.isEmpty)
            Text(
              'Mostrando indicaciones de ejemplo mientras llega la ruta en tiempo real.',
              style: theme.textTheme.bodyMedium,
            ),
          ...shownInstructions.map(
            (instruction) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.turn_slight_right, size: 18, color: Color(0xFF0B6E4F)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(instruction)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengersCard(ThemeData theme) {
    final passengers = (_viaje?['pasajeros'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pasajeros del viaje',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...passengers.map((passenger) {
            final state = passenger['estado']?.toString() ?? 'pendiente_abordar';
            final chip = switch (state) {
              'en_vehiculo' => _statusChip('En vehículo', Colors.green.shade700),
              'bajo_del_vehiculo' => _statusChip('Ya bajó', Colors.blueGrey.shade600),
              _ => _statusChip('Pendiente', Colors.orange.shade700),
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: passenger['foto_perfil'] != null
                            ? NetworkImage(passenger['foto_perfil'].toString())
                            : null,
                        child: passenger['foto_perfil'] == null
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          passenger['nombre']?.toString() ?? 'Pasajero',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      chip,
                    ],
                  ),
                  if (passenger['parada_solicitada'] == true) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Solicitó una parada intermedia.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 42),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'No se pudo cargar el viaje.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadTrip(showLoader: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              'No hay un viaje en curso para este perfil.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0B6E4F)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  LatLng? _readPoint(dynamic source) {
    if (source is! Map<String, dynamic>) return null;
    final lat = _asDouble(source['lat']);
    final lng = _asDouble(source['lng']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _readStopReference(Map<String, dynamic>? stop) {
    if (stop == null) return null;
    final parada = stop['parada'];
    if (parada is! Map<String, dynamic>) return null;
    final lat = _asDouble(parada['referencia_lat']);
    final lng = _asDouble(parada['referencia_lng']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _readPassengerStopReference(Map<String, dynamic>? stop) {
    if (stop == null) return null;
    final lat = _asDouble(stop['referencia_lat']);
    final lng = _asDouble(stop['referencia_lng']);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool _samePoint(LatLng left, LatLng right) {
    return _distance.as(LengthUnit.Meter, left, right) < 3;
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }
}

class _RouteSnapshot {
  const _RouteSnapshot({required this.points, required this.instructions});

  final List<LatLng> points;
  final List<String> instructions;
}