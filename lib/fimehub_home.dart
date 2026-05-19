import 'dart:async';
import 'package:fimeride_front/fimehub_login.dart';
import 'package:fimeride_front/live_face_match_gate.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:fimeride_front/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FimeHubHome extends StatefulWidget {
  const FimeHubHome({super.key});

  @override
  _FimeHubHomeState createState() => _FimeHubHomeState();
}

class _FimeHubHomeState extends State<FimeHubHome> {
  String _nombre = 'Usuario';
  String _matricula = '';
  int? _usuarioId;

  final PageController _carouselController = PageController();
  int _carouselPage = 0;
  Timer? _carouselTimer;

  // true mientras se ejecuta la animación de transformación hacia el nav de la app
  bool _launchingApp = false;

  // Slides del carrusel (en el futuro serán noticias de la FIME)
  final List<_SlideData> _slides = [
    _SlideData(
      title: 'Bienvenido a FimeHub',
      subtitle: 'Tu plataforma de aplicaciones FIME',
      gradientColors: [
        Color.fromARGB(255, 0, 162, 100),
        Color.fromARGB(255, 0, 87, 54),
      ],
      icon: Icons.hub,
    ),
    _SlideData(
      title: 'Noticias FIME',
      subtitle: 'Próximamente: información reciente de la facultad',
      gradientColors: [
        Color.fromARGB(255, 0, 130, 180),
        Color.fromARGB(255, 0, 65, 100),
      ],
      icon: Icons.newspaper,
    ),
    _SlideData(
      title: 'Servicios Universitarios',
      subtitle: 'Todo en un solo lugar',
      gradientColors: [
        Color.fromARGB(255, 80, 0, 160),
        Color.fromARGB(255, 40, 0, 90),
      ],
      icon: Icons.school,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startCarousel();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombre = prefs.getString('nombre') ?? 'Usuario';
      _matricula = prefs.getString('matricula') ?? '';
      _usuarioId = prefs.getInt('usuario_id');
    });
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_carouselPage + 1) % _slides.length;
      _carouselController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Abre FimeRide: primero transforma el área de apps en el menú inferior de
  /// FimeRide (animación de 350 ms) y luego navega a PaginaPrincipal.
  Future<void> _openFimeRide() async {
    setState(() => _launchingApp = true);
    // Inicializa el token de Mapbox necesario para las pantallas de mapa.
    mapboxAccessToken ??= await fetchMapboxToken();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final accesoPermitido = await _runFimeRideFaceMatchGate();
    if (!accesoPermitido) {
      if (mounted) setState(() => _launchingApp = false);
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaginaPrincipal()),
    );
    // Al volver de FimeRide, restauramos el estado del hub
    if (mounted) setState(() => _launchingApp = false);
  }

  Future<bool> _runFimeRideFaceMatchGate() async {
    if (_usuarioId == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontro usuario para validar identidad'),
        ),
      );
      return false;
    }

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveFaceMatchGate(usuarioId: _usuarioId!),
      ),
    );
    return ok == true;
  }

  void _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const FimeHubLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      // ── AppBar con gradiente + nombre + matrícula ──────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 0, 162, 100),
                Color.fromARGB(255, 0, 87, 54),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Logo FimeHub
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/image/Fimehub.png',
                      height: 44,
                      width: 44,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Datos del usuario
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombre.split(' ').first,
                          style: TextStyle(
                            fontFamily: 'ADLaMDisplay',
                            color: Colors.white,
                            fontSize: sw * 0.048,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_matricula.isNotEmpty)
                          Text(
                            _matricula.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'ADLaMDisplay',
                              color: Colors.white.withOpacity(0.85),
                              fontSize: sw * 0.033,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Botón cerrar sesión
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Cerrar sesión',
                    onPressed: _cerrarSesion,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      backgroundColor: const Color(0xFFF5F5F5),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── Carrusel de noticias ──────────────────────────────────────────
          SizedBox(
            height: sh * 0.27,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _carouselController,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _carouselPage = i),
                  itemBuilder: (_, i) => _buildSlide(_slides[i], sw),
                ),
                // Indicadores de página
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _carouselPage ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              i == _carouselPage
                                  ? Colors.white
                                  : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Encabezado de la sección de apps ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'APLICACIONES',
              style: TextStyle(
                fontFamily: 'ADLaMDisplay',
                color: const Color.fromARGB(255, 0, 87, 54),
                fontSize: sw * 0.042,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Área de apps / menú inferior animado ────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder:
                    (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                child:
                    _launchingApp
                        ? _buildNavPreview(
                          sw,
                        ) // 👉 fondo transformado en menú de FimeRide
                        : _buildAppGrid(sw), // 👉 grid de apps del hub
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Slide del carrusel ────────────────────────────────────────────────────
  Widget _buildSlide(_SlideData slide, double sw) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: slide.gradientColors.last.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculo decorativo de fondo
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 20,
            bottom: 20,
            child: Icon(
              slide.icon,
              size: sw * 0.18,
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          // Texto del slide
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  style: TextStyle(
                    fontFamily: 'ADLaMDisplay',
                    color: Colors.white,
                    fontSize: sw * 0.052,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slide.subtitle,
                  style: TextStyle(
                    fontFamily: 'ADLaMDisplay',
                    color: Colors.white.withOpacity(0.88),
                    fontSize: sw * 0.033,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid de iconos de apps ────────────────────────────────────────────────
  Widget _buildAppGrid(double sw) {
    return GridView.count(
      key: const ValueKey('appgrid'),
      crossAxisCount: 4,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 0.82,
      physics: const BouncingScrollPhysics(),
      children: [
        _buildAppIcon(
          name: 'FimeRide',
          assetPath: 'assets/image/FimeRideLogo.png',
          accentColor: const Color.fromARGB(255, 0, 87, 54),
          onTap: _openFimeRide,
          sw: sw,
        ),
      ],
    );
  }

  // ── Ícono de app individual ───────────────────────────────────────────────
  Widget _buildAppIcon({
    required String name,
    required String assetPath,
    required Color accentColor,
    required VoidCallback onTap,
    required double sw,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color.fromARGB(255, 0, 162, 100), accentColor],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(sw * 0.025),
            child: Image.asset(
              assetPath,
              width: sw * 0.115,
              height: sw * 0.115,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'ADLaMDisplay',
              color: const Color.fromARGB(255, 0, 87, 54),
              fontSize: sw * 0.028,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Menú inferior de FimeRide como preview de la transformación ───────────
  // Se muestra durante la animación antes de navegar; el "fondo de la lista
  // de apps" se convierte visualmente en el menú inferior de FimeRide.
  Widget _buildNavPreview(double sw) {
    const navColor = Color.fromARGB(255, 0, 87, 54);
    final navItems = [
      _NavItem(Icons.home, 'Inicio'),
      _NavItem(Icons.directions_car, 'Viajes'),
      _NavItem(Icons.add_circle_outline, 'Ofrecer'),
      _NavItem(Icons.group, 'Pasajeros'),
      _NavItem(Icons.person, 'Perfil'),
    ];

    return Container(
      key: const ValueKey('navpreview'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(
          color: const Color.fromARGB(255, 0, 162, 100).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: sw * 0.045, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Indicador visual de carga
          SizedBox(
            height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                backgroundColor: Colors.green.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(navColor),
              ),
            ),
          ),
          SizedBox(height: sw * 0.04),
          Text(
            'Abriendo FimeRide',
            style: TextStyle(
              fontFamily: 'ADLaMDisplay',
              color: navColor,
              fontSize: sw * 0.038,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: sw * 0.05),
          // Iconos del menú inferior de FimeRide
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                navItems.map((item) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: navColor, size: sw * 0.07),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: navColor.withOpacity(0.8),
                          fontSize: sw * 0.025,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Modelos de datos ligeros ──────────────────────────────────────────────────

class _SlideData {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final IconData icon;
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.icon,
  });
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _FaceMatchPreviewDialog extends StatelessWidget {
  const _FaceMatchPreviewDialog();

  Future<void> _openCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image == null || !context.mounted) return;

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ComparandoDialog(),
      );

      if (accepted == true && context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la camara')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 480 ? 420.0 : size.width * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBFFF5), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 54,
              color: Color(0xFF007A4C),
            ),
            const SizedBox(height: 10),
            const Text(
              'Verificacion facial',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'ADLaMDisplay',
                fontSize: 24,
                color: Color(0xFF005736),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Diseno Frontend (sin comparacion con backend por ahora)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF4A6A5C)),
            ),
            const SizedBox(height: 18),
            _buildStep(
              icon: Icons.badge_outlined,
              title: '1. Sube tu identificacion',
              subtitle: 'Foto del INE/credencial con buena iluminacion.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              icon: Icons.face_retouching_natural,
              title: '2. Toma tu selfie',
              subtitle:
                  'Mira de frente y evita accesorios que cubran tu rostro.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              icon: Icons.analytics_outlined,
              title: '3. Face Match',
              subtitle:
                  'Aqui se mostrara el porcentaje de similitud (proximamente).',
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _openCamera(context),
              icon: const Icon(Icons.photo_camera_front_outlined),
              label: const Text('Abrir camara (UI)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF005736),
                side: const BorderSide(color: Color(0xFF005736)),
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFD9F6E8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF007A4C), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F3C30),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF4E675C), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparandoDialog extends StatefulWidget {
  const _ComparandoDialog();

  @override
  State<_ComparandoDialog> createState() => _ComparandoDialogState();
}

class _ComparandoDialogState extends State<_ComparandoDialog> {
  bool _aceptado = false;

  @override
  void initState() {
    super.initState();
    _runFlow();
  }

  Future<void> _runFlow() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _aceptado = true);

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child:
                  _aceptado
                      ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('accepted'),
                        size: 58,
                        color: Color(0xFF0B8A54),
                      )
                      : const SizedBox(
                        key: ValueKey('loading'),
                        width: 46,
                        height: 46,
                        child: CircularProgressIndicator(strokeWidth: 4),
                      ),
            ),
            const SizedBox(height: 16),
            Text(
              _aceptado ? 'Aceptado' : 'Comparando...',
              style: const TextStyle(
                fontFamily: 'ADLaMDisplay',
                fontSize: 22,
                color: Color(0xFF005736),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
