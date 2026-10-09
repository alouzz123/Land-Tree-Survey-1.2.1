import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'country_selection_screen.dart';

/// Écran de licence affiché à la première installation de l'application.
class LicenceScreen extends StatefulWidget {
  const LicenceScreen({super.key});

  @override
  State<LicenceScreen> createState() => _LicenceScreenState();
}

class _LicenceScreenState extends State<LicenceScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _accepted = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _forestGreen = Color(0xFF2E5D3A);
  static const Color _midGreen = Color(0xFF4A7C59);
  static const Color _lightGreen = Color(0xFF7BA368);
  static const Color _earthBrown = Color(0xFF5C3A21);
  static const Color _sandBeige = Color(0xFFF5F0E6);
  static const Color _goldAccent = Color(0xFFD4A056);
  static const Color _textDark = Color(0xFF1A2E1F);
  static const Color _textMuted = Color(0xFF6B7B6E);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _scrollController.addListener(() {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= max - 40 && !_hasScrolledToBottom) {
        setState(() => _hasScrolledToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    if (!_accepted) return;

    // Enregistrer l'acceptation dans SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('licenceAccepted', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CountrySelectionScreen()),
      );
    }
  }

  void _onDecline() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _sandBeige,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Quitter l\'application',
          style: TextStyle(
            color: _earthBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Vous devez accepter les conditions d\'utilisation pour utiliser Land Tree Survey. '
          'L\'application va se fermer.',
          style: TextStyle(color: _textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Annuler', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _earthBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text(
              'Quitter',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = isTablet ? size.width * 0.08 : 20.0;

    return Scaffold(
      backgroundColor: _sandBeige,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Column(
            children: [
              // ── En-tête ──────────────────────────────────────────────────
              _buildHeader(hPad, isTablet),

              // ── Corps : texte de la licence ──────────────────────────────
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _forestGreen.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _forestGreen.withOpacity(0.07),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Titre intérieur
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_forestGreen, _midGreen],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.article_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'CONDITIONS GÉNÉRALES D\'UTILISATION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 14 : 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bandeau "faites défiler"
                      if (!_hasScrolledToBottom)
                        Container(
                          color: _goldAccent.withOpacity(0.12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: _goldAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Veuillez faire défiler pour lire l\'intégralité des conditions',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _earthBrown.withOpacity(0.85),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Texte de la licence
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          child: _buildLicenceText(isTablet),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Pied : checkbox + boutons ─────────────────────────────────
              _buildFooter(hPad, isTablet),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Widgets de composition
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(double hPad, bool isTablet) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 12),
      child: Row(
        children: [
          // Identité de l'application
          Container(
            width: isTablet ? 220 : 160,
            height: isTablet ? 76 : 58,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _forestGreen.withOpacity(0.3)),
            ),
            child: Image.asset(
              'assets/logos/logo_land_tree.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.forest,
                color: _forestGreen,
                size: 42,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Land Tree Survey',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: _forestGreen,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Licence d\'utilisation · Version 1.0 · 2025–2028',
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 11,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double hPad, bool isTablet) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 16),
      child: Column(
        children: [
          // Checkbox d'acceptation
          InkWell(
            onTap: _hasScrolledToBottom
                ? () => setState(() => _accepted = !_accepted)
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _accepted,
                      onChanged: _hasScrolledToBottom
                          ? (v) => setState(() => _accepted = v ?? false)
                          : null,
                      activeColor: _forestGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'J\'ai lu et j\'accepte les conditions générales d\'utilisation '
                      'de l\'application Land Tree Survey dans le cadre du projet GALILEO '
                      '(2025–2028).',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 12,
                        color: _hasScrolledToBottom ? _textDark : _textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Boutons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onDecline,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _earthBrown.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Refuser',
                    style: TextStyle(
                      color: _earthBrown.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 15 : 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      (_accepted && _hasScrolledToBottom) ? _onAccept : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _forestGreen,
                    disabledBackgroundColor: _forestGreen.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: (_accepted && _hasScrolledToBottom) ? 3 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: (_accepted && _hasScrolledToBottom)
                            ? Colors.white
                            : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Accepter et continuer',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (_accepted && _hasScrolledToBottom)
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 15 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Contenu de la licence (version abrégée pour l'application)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLicenceText(bool isTablet) {
    final titleSize = isTablet ? 15.0 : 13.5;
    final bodySize = isTablet ? 13.5 : 12.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _introBlock(bodySize),
        const SizedBox(height: 20),
        _section(
            '1. OBJET ET CHAMP D\'APPLICATION',
            titleSize,
            [
              _para(
                'La présente licence régit l\'utilisation de l\'application mobile '
                '« Land Tree Survey » (ci-après « l\'Application »), développée par '
                'Al Housseynou NIANG, doctorant au Centre de Suivi Écologique (CSE) '
                'de Dakar, dans le cadre de sa thèse de doctorat.',
                bodySize,
              ),
              _para(
                'L\'Application est développée en partenariat avec le projet GALILEO, '
                'financé par l\'Union européenne (Convention de subvention n° 101181623).',
                bodySize,
              ),
            ],
            bodySize),
        _section(
            '2. DURÉE DE LA LICENCE',
            titleSize,
            [
              _para(
                'La présente licence est accordée pour une durée déterminée de '
                'trois (3) ans, courant du 1er janvier 2025 au 31 décembre 2028.',
                bodySize,
              ),
              _bullet('Date de début : 1er janvier 2025', bodySize),
              _bullet('Date d\'expiration : 31 décembre 2028', bodySize),
            ],
            bodySize),
        _section(
            '3. UTILISATEURS AUTORISÉS',
            titleSize,
            [
              _para(
                'L\'Application est réservée aux personnes suivantes :',
                bodySize,
              ),
              _bullet(
                'Les membres de l\'équipe de recherche de la thèse',
                bodySize,
              ),
              _bullet(
                'Les agents de terrain désignés par le CSE et les partenaires '
                'du projet GALILEO',
                bodySize,
              ),
              _bullet(
                'Toute personne expressément autorisée par écrit par Al Housseynou NIANG',
                bodySize,
              ),
            ],
            bodySize),
        _section(
            '4. FINALITÉ ET UTILISATION AUTORISÉE',
            titleSize,
            [
              _para(
                'L\'Application est conçue exclusivement pour la collecte de '
                'données dendrométriques de terrain dans le cadre du projet GALILEO.',
                bodySize,
              ),
              _para(
                'Toute utilisation à des fins commerciales, personnelles non '
                'autorisées ou étrangères aux objectifs de la thèse est '
                'formellement interdite.',
                bodySize,
                bold: true,
              ),
            ],
            bodySize),
        _section(
            '5. PROPRIÉTÉ INTELLECTUELLE',
            titleSize,
            [
              _para(
                'L\'Application, son code source, ses interfaces, ses algorithmes '
                'et ses bases de données constituent des œuvres intellectuelles '
                'dont la propriété est partagée entre :',
                bodySize,
              ),
              _bullet('Al Housseynou NIANG — auteur principal', bodySize),
              _bullet('Le Centre de Suivi Écologique (CSE)', bodySize),
              _bullet('Le projet GALILEO', bodySize),
            ],
            bodySize),
        _section(
            '6. CONFIDENTIALITÉ ET PROTECTION DES DONNÉES',
            titleSize,
            [
              _para(
                'Les données de terrain collectées sont des données scientifiques '
                'sensibles. L\'utilisateur s\'engage à ne pas les divulguer à '
                'des tiers non autorisés.',
                bodySize,
              ),
            ],
            bodySize),
        _section(
            '7. STOCKAGE LOCAL ET SAUVEGARDE CLOUD',
            titleSize,
            [
              _para(
                'Afin de permettre la collecte sur le terrain, l\'Application '
                'reste pleinement utilisable en mode hors ligne. Les informations '
                'saisies sont d\'abord enregistrées de manière sécurisée sur '
                'l\'appareil utilisé.',
                bodySize,
              ),
              _para(
                'Dès qu\'une connexion Internet est disponible, les données '
                'collectées sont automatiquement sauvegardées dans une infrastructure '
                'cloud sécurisée et administrée dans le cadre du projet. Cette '
                'opération ne nécessite aucune action particulière de l\'utilisateur.',
                bodySize,
              ),
              _para(
                'Cette sauvegarde concerne notamment les informations relatives aux '
                'placettes, aux arbres, aux coordonnées géographiques, aux observations '
                'et, lorsqu\'elles sont collectées, aux photographies. Elle a pour '
                'finalité la sécurisation, la centralisation et l\'alimentation de la '
                'base scientifique du projet.',
                bodySize,
              ),
              _para(
                'L\'accès aux données sauvegardées est réservé aux administrateurs et '
                'aux membres autorisés de l\'équipe du projet.',
                bodySize,
                bold: true,
              ),
            ],
            bodySize),
        _section(
            '8. RESTRICTIONS D\'UTILISATION',
            titleSize,
            [
              _para('L\'utilisateur s\'interdit expressément de :', bodySize),
              _bullet(
                'Modifier, décompiler ou procéder à l\'ingénierie inverse',
                bodySize,
              ),
              _bullet('Distribuer, vendre ou louer l\'Application', bodySize),
              _bullet(
                'Utiliser l\'Application à des fins commerciales',
                bodySize,
              ),
            ],
            bodySize),
        _section(
            '9. RESPONSABILITÉS ET GARANTIES',
            titleSize,
            [
              _para(
                'L\'Application est fournie « en l\'état », dans le contexte '
                'd\'un projet de recherche académique. L\'utilisateur reconnaît '
                'utiliser l\'Application sous sa propre responsabilité.',
                bodySize,
              ),
            ],
            bodySize),
        _section(
            '10. CONTACT',
            titleSize,
            [
              _para(
                'Pour toute question relative à cette licence, veuillez contacter :',
                bodySize,
              ),
              _contactLine('Doctorant', 'Al Housseynou NIANG', bodySize),
              _contactLine('Institution',
                  'Centre de Suivi Écologique (CSE), Dakar', bodySize),
              _contactLine('Projet', 'GALILEO', bodySize),
            ],
            bodySize),
        const SizedBox(height: 20),
        _legalFooter(bodySize),
      ],
    );
  }

  // ── Helpers de mise en forme ───────────────────────────────────────────────

  Widget _introBlock(double bodySize) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _forestGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _forestGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: _forestGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'LICENCE D\'UTILISATION — Land Tree Survey',
                style: TextStyle(
                  color: _forestGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: bodySize,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Application mobile de collecte de données dendrométriques de terrain\n'
            'Développée dans le cadre du projet de thèse GALILEO · CSE Dakar · 2025–2028\n'
            'Financé par l\'Union Européenne · Grant Agreement n° 101181623',
            style: TextStyle(
              color: _textDark,
              fontSize: bodySize - 0.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    double titleSize,
    List<Widget> children,
    double bodySize,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _earthBrown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border(
                left: BorderSide(color: _goldAccent, width: 3),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleSize,
                color: _earthBrown,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _para(String text, double size, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          color: _textDark,
          height: 1.6,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget _bullet(String text, double size) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _lightGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: size, color: _textDark, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactLine(String label, String value, double size) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: size, color: _textDark, height: 1.5),
          children: [
            TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _legalFooter(double bodySize) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _textDark.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _textMuted.withOpacity(0.2)),
      ),
      child: Text(
        'Les opinions et points de vue exprimés dans cette application '
        'sont ceux des auteurs uniquement et ne reflètent pas nécessairement '
        'ceux de l\'Union européenne ou de l\'Agence exécutive de recherche '
        'européenne (REA).\n\n'
        '© 2025 Al Housseynou NIANG / Centre de Suivi Écologique (CSE) — '
        'Tous droits réservés dans le cadre du projet GALILEO.',
        style: TextStyle(
          fontSize: bodySize - 1,
          color: _textMuted,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
