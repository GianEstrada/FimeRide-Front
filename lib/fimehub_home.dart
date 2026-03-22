import 'dart:async';
import 'package:fimeride_front/fimehub_login.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:fimeride_front/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FimeHubHome extends StatefulWidget {
  const FimeHubHome({super.key});

  @override
  _FimeHubHomeState createState() => _FimeHubHomeState();
}

class _FimeHubHomeState extends State<FimeHubHome> {
  String _nombre = 'Usuario';
  String _matricula = '';

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
      gradientColors: [Color.fromARGB(255, 0, 162, 100), Color.fromARGB(255, 0, 87, 54)],
      icon: Icons.hub,
    ),
    _SlideData(
      title: 'Noticias FIME',
      subtitle: 'Próximamente: información reciente de la facultad',
      gradientColors: [Color.fromARGB(255, 0, 130, 180), Color.fromARGB(255, 0, 65, 100)],
      icon: Icons.newspaper,
    ),
    _SlideData(
      title: 'Servicios Universitarios',
      subtitle: 'Todo en un solo lugar',
      gradientColors: [Color.fromARGB(255, 80, 0, 160), Color.fromARGB(255, 40, 0, 90)],
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaginaPrincipal()),
    );
    // Al volver de FimeRide, restauramos el estado del hub
    if (mounted) setState(() => _launchingApp = false);
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
                          color: i == _carouselPage
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
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _launchingApp
                    ? _buildNavPreview(sw) // 👉 fondo transformado en menú de FimeRide
                    : _buildAppGrid(sw),   // 👉 grid de apps del hub
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
                colors: [
                  const Color.fromARGB(255, 0, 162, 100),
                  accentColor,
                ],
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
            children: navItems.map((item) {
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
