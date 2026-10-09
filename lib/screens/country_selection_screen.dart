import 'package:flutter/material.dart';

import '../home_screen.dart';
import '../services/project_country_service.dart';
import '../theme/app_theme.dart';

/// Configuration locale, légère et entièrement hors ligne du pays du projet.
class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  static const _countries = ['Sénégal', 'Kenya', 'Ghana', 'Cameroun', 'Autre'];
  final _otherController = TextEditingController();
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCountryPopup());
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _openCountryPopup() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            CircleAvatar(
              backgroundColor: Color(0xFFE7F1E9),
              child: Icon(Icons.public_rounded, color: AppColors.forest),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Pays du projet',
                  style: TextStyle(color: AppColors.forestDark)),
            ),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'Sélectionnez le pays de collecte. Ce choix est enregistré '
                  'une seule fois et adapte les listes de terrain.',
                  style: TextStyle(height: 1.4, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Pays *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _countries
                      .map((country) => DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          ))
                      .toList(),
                  onChanged: (value) {
                    updateDialog(() => _selected = value);
                    setState(() => _selected = value);
                  },
                ),
                if (_selected == 'Autre') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _otherController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom du pays *',
                      hintText: 'Exemple : Côte d’Ivoire',
                      prefixIcon: Icon(Icons.edit_location_alt_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Row(children: [
                  Icon(Icons.offline_bolt_outlined,
                      size: 17, color: AppColors.leaf),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text('Aucune connexion Internet n’est nécessaire.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () => _validate(dialogContext, updateDialog),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('VALIDER LE PAYS'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _validate(
    BuildContext dialogContext,
    StateSetter updateDialog,
  ) async {
    final country = _selected == 'Autre'
        ? _otherController.text.trim()
        : (_selected ?? '');
    if (country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir le pays.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
          context: dialogContext,
          builder: (confirmationContext) => AlertDialog(
            title: const Text('Confirmation définitive'),
            content: Text(
              'Confirmez-vous « $country » comme pays de ce projet ? '
              'Ce choix ne pourra pas être changé depuis l’application.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmationContext, false),
                child: const Text('Vérifier'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(confirmationContext, true),
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    updateDialog(() => _saving = true);
    await ProjectCountryService.setCountryOnce(country);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.sand,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.eco_rounded,
                        size: 76, color: AppColors.forest),
                    const SizedBox(height: 18),
                    const Text(
                      'Configuration du projet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Land.Tree Survey prépare les référentiels adaptés à votre pays.',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.4, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _openCountryPopup,
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                      label: const Text('CHOISIR LE PAYS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
