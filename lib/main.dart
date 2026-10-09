import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'screens/licence_screen.dart'; // Nouveau fichier
import 'screens/country_selection_screen.dart';
import 'services/project_country_service.dart';
import 'services/database_service.dart';
import 'services/supabase_sync_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la base de données
  await DatabaseService().init();

  runApp(const MyApp());

  // Le cloud ne doit jamais retarder l'ouverture de l'application.
  unawaited(_initializeCloudServices());
}

Future<void> _initializeCloudServices() async {
  await SupabaseSyncService().initialize();
  SupabaseSyncService().startAutomaticSync(() async {
    await SupabaseSyncService().syncAll(
      DatabaseService().getAllPlacettes(),
      DatabaseService().getAllArbres(),
    );
  });
  SupabaseSyncService().syncAllSilently(
    DatabaseService().getAllPlacettes(),
    DatabaseService().getAllArbres(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Land.Tree Survey',
      theme: AppTheme.light,
      home: const SplashScreen(), // Écran de vérification de licence
    );
  }
}

// Écran de vérification de licence
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLicenceStatus();
  }

  Future<void> _checkLicenceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final licenceAccepted = prefs.getBool('licenceAccepted') ?? false;
    final projectCountry = await ProjectCountryService.getCountry();

    if (mounted) {
      if (licenceAccepted && projectCountry != null) {
        // Licence déjà acceptée → Accéder directement à l'application
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (!licenceAccepted) {
        // Licence non acceptée → Afficher l'écran de licence
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LicenceScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CountrySelectionScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.forestDark, AppColors.forest, AppColors.leaf],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, 14)),
                    ],
                  ),
                  child: Image.asset('assets/logos/logo_cse.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 28),
                const Text(
                  'LAND.TREE SURVEY',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collecte dendrométrique de terrain',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(.78)),
                ),
                const SizedBox(height: 36),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
