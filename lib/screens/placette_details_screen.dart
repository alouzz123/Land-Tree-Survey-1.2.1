import 'package:flutter/material.dart';

import '../formulaire_screen.dart';
import '../models/arbre.dart';
import '../models/placette.dart';
import '../services/database_service.dart';
import '../services/inventory_mode_service.dart';
import '../theme/app_theme.dart';
import 'formulaire_arbres_screen.dart';
import 'releve_simple_screen.dart';

class PlacetteDetailsScreen extends StatefulWidget {
  final Placette placette;

  const PlacetteDetailsScreen({super.key, required this.placette});

  @override
  State<PlacetteDetailsScreen> createState() =>
      _PlacetteDetailsScreenState();
}

class _PlacetteDetailsScreenState extends State<PlacetteDetailsScreen> {
  Placette? _placette;
  List<Arbre> _arbres = const [];

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  void _recharger() {
    if (!mounted) return;
    setState(() {
      _placette = DatabaseService().getPlacette(widget.placette.id) ??
          widget.placette;
      _arbres = DatabaseService().getArbresByPlacetteId(widget.placette.id);
    });
  }

  Future<bool> _confirmerModification() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Modifier la placette ?'),
            content: Text(
              'Voulez-vous réellement modifier la placette ${_placette!.id} ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modifier'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _modifierPlacette() async {
    final placette = _placette;
    if (placette == null || !await _confirmerModification() || !mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormulaireScreen(placetteAEditer: placette),
      ),
    );
    if (mounted) _recharger();
  }

  Future<void> _ouvrirInventaire() async {
    final placette = _placette;
    if (placette == null) return;
    final dernierMode = await InventoryModeService.get(placette.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => dernierMode == InventoryModeService.simple
            ? ReleveSimpleScreen(
                placetteId: placette.id,
                regionNom: placette.region,
              )
            : FormulaireArbresScreen(
                placetteId: placette.id,
                regionNom: placette.region,
              ),
      ),
    );
    if (mounted) _recharger();
  }

  @override
  Widget build(BuildContext context) {
    final placette = _placette;
    if (placette == null) {
      return const Scaffold(
        body: Center(child: Text('Placette introuvable')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.sand,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                placette.region,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                placette.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: AppColors.forest,
            labelColor: AppColors.forest,
            tabs: [
              const Tab(icon: Icon(Icons.info_outline), text: 'Placette'),
              Tab(icon: const Icon(Icons.forest), text: 'Arbres (${_arbres.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ongletPlacette(placette),
            _ongletArbres(),
          ],
        ),
      ),
    );
  }

  Widget _ongletPlacette(Placette placette) {
    final stats = DatabaseService().getStatistiquesArbres(placette.id);
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 360 ? 12 : 18),
      child: Column(
        children: [
          _card(
            title: 'Identification',
            icon: Icons.qr_code_rounded,
            children: [
              _ligne('Identifiant', placette.id),
              _ligne('Région', placette.region),
              _ligne('Superficie', '${placette.superficie} ha'),
              _ligne('Agent', placette.agent.isEmpty ? 'Non renseigné' : placette.agent),
              _ligne('Date', _formatDate(placette.dateCreation)),
            ],
          ),
          _card(
            title: 'Localisation et occupation',
            icon: Icons.location_on_outlined,
            children: [
              _ligne('Latitude', placette.latitude.toStringAsFixed(6)),
              _ligne('Longitude', placette.longitude.toStringAsFixed(6)),
              _ligne('Occupation du sol', placette.occupationSol),
              _ligne('Présence de culture', placette.presenceCulture ? 'Oui' : 'Non'),
              _ligne('Présence de feux', placette.presenceFeux ? 'Oui' : 'Non'),
            ],
          ),
          _card(
            title: 'Résultats enregistrés',
            icon: Icons.analytics_outlined,
            children: [
              _ligne('Nombre d’arbres', '${_arbres.length}'),
              _ligne('DAP moyen', '${(stats['dapMoyen'] as num).toStringAsFixed(2)} cm'),
              _ligne('Hauteur moyenne', '${(stats['hauteurMoyenne'] as num).toStringAsFixed(2)} m'),
              _ligne('Volume total', '${(stats['volumeTotal'] as num).toStringAsFixed(3)} m³'),
            ],
          ),
          if (placette.observations.trim().isNotEmpty)
            _card(
              title: 'Observations',
              icon: Icons.notes_rounded,
              children: [Text(placette.observations)],
            ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final buttons = [
                OutlinedButton.icon(
                  onPressed: _modifierPlacette,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('MODIFIER LA PLACETTE'),
                ),
                ElevatedButton.icon(
                  onPressed: _ouvrirInventaire,
                  icon: const Icon(Icons.forest),
                  label: const Text('OUVRIR L’INVENTAIRE'),
                ),
              ];
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [buttons[0], const SizedBox(height: 10), buttons[1]],
                    )
                  : Row(
                      children: [
                        Expanded(child: buttons[0]),
                        const SizedBox(width: 12),
                        Expanded(child: buttons[1]),
                      ],
                    );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ongletArbres() {
    if (_arbres.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forest_outlined, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('Aucun arbre inventorié'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _ouvrirInventaire,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un arbre'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _arbres.length + 1,
      itemBuilder: (context, index) {
        if (index == _arbres.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: ElevatedButton.icon(
              onPressed: _ouvrirInventaire,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('GÉRER L’INVENTAIRE'),
            ),
          );
        }
        final arbre = _arbres[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Text('${index + 1}')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arbre.nomScientifique,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(arbre.id, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _mesure('DAP', '${arbre.dap.toStringAsFixed(1)} cm'),
                    _mesure('Hauteur', '${arbre.hauteur.toStringAsFixed(2)} m'),
                    _mesure('Troncs', '${arbre.nombreTroncs}'),
                    _mesure('D. cumulé', '${arbre.diametreCumule.toStringAsFixed(1)} cm'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.forest),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _ligne(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600));
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 2), Text(value)],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 145, child: labelWidget),
              Expanded(child: Text(value)),
            ],
          );
        },
      ),
    );
  }

  Widget _mesure(String label, String value) {
    return Chip(label: Text('$label : $value'));
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
