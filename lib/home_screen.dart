import 'package:flutter/material.dart';

import 'formulaire_screen.dart';
import 'screens/liste_placettes_screen.dart';
import 'services/database_service.dart';
import 'services/supabase_sync_service.dart';
import 'theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int get _placettes => DatabaseService().getCount();
  int get _arbres => DatabaseService().getTotalArbresCount();

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  Future<void> _synchroniser() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!SupabaseSyncService().isInitialized) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Le service cloud est temporairement indisponible. Vos données restent protégées sur l’appareil.',
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Synchronisation en cours…')),
    );
    try {
      await SupabaseSyncService().syncAll(
        DatabaseService().getAllPlacettes(),
        DatabaseService().getAllArbres(),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Toutes les données sont synchronisées.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      debugPrint('Erreur de synchronisation cloud : $error');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Sauvegarde cloud différée. Les données restent disponibles sur l’appareil et seront envoyées automatiquement plus tard.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 720;
    final isVerySmall = screenWidth < 360;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundDecoration()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 36 : (isVerySmall ? 12 : 20),
                        18,
                        isWide ? 36 : (isVerySmall ? 12 : 20),
                        34,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _TopBar(onSync: _synchroniser),
                          const SizedBox(height: 26),
                          const _HeroPanel(),
                          const SizedBox(height: 20),
                          _StatisticsRow(
                            placettes: _placettes,
                            arbres: _arbres,
                            isWide: isWide,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Actions rapides',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (isWide)
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionCard(
                                    primary: true,
                                    icon: Icons.add_location_alt_rounded,
                                    title: 'Nouvelle placette',
                                    description:
                                        'Démarrer une nouvelle collecte de terrain',
                                    onTap: () =>
                                        _openPage(const FormulaireScreen()),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _ActionCard(
                                    icon: Icons.map_outlined,
                                    title: 'Mes placettes',
                                    description:
                                        'Consulter les inventaires et les arbres',
                                    onTap: () => _openPage(
                                      const ListePlacettesScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _ActionCard(
                              primary: true,
                              icon: Icons.add_location_alt_rounded,
                              title: 'Nouvelle placette',
                              description:
                                  'Démarrer une nouvelle collecte de terrain',
                              onTap: () => _openPage(const FormulaireScreen()),
                            ),
                            const SizedBox(height: 12),
                            _ActionCard(
                              icon: Icons.map_outlined,
                              title: 'Mes placettes',
                              description:
                                  'Consulter les inventaires et les arbres',
                              onTap: () =>
                                  _openPage(const ListePlacettesScreen()),
                            ),
                          ],
                          const SizedBox(height: 20),
                          _CloudCard(onSync: _synchroniser),
                          const SizedBox(height: 24),
                          const _PartnerBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8F5EE), AppColors.sand],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -110,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage.withOpacity(0.16),
              ),
            ),
          ),
          Positioned(
            left: -70,
            top: 300,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final connected = SupabaseSyncService().isInitialized;
    final compact = MediaQuery.sizeOf(context).width < 390;
    final verySmall = MediaQuery.sizeOf(context).width < 360;
    return Row(
      children: [
        Container(
          width: verySmall ? 132 : 172,
          height: verySmall ? 46 : 58,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Image.asset(
            'assets/logos/logo_land_tree.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.park_rounded,
              color: AppColors.forest,
            ),
          ),
        ),
        const Spacer(),
        Tooltip(
          message: connected
              ? 'Sauvegarde cloud automatique activée'
              : 'Données protégées sur l’appareil',
          child: InkWell(
            onTap: onSync,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: connected
                    ? AppColors.success.withOpacity(0.10)
                    : AppColors.gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connected ? Icons.cloud_done_rounded : Icons.cloud_off,
                    size: 17,
                    color: connected ? AppColors.success : AppColors.earth,
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Auto cloud' : 'Mode local',
                      style: TextStyle(
                        color: connected ? AppColors.success : AppColors.earth,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 26, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forestDark, AppColors.leaf],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withOpacity(0.20),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INVENTAIRE FORESTIER',
                  style: TextStyle(
                    color: Color(0xFFD7E8DB),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  'Collecter mieux.\nComprendre le terrain.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 11),
                Text(
                  'Une collecte fiable, hors ligne et synchronisée.',
                  style: TextStyle(
                    color: Color(0xFFD7E8DB),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 390) ...[
          const SizedBox(width: 12),
          Container(
            width: 112,
            height: 138,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Image.asset(
              'assets/logos/logo_arbre.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.forest_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _StatisticsRow extends StatelessWidget {
  const _StatisticsRow({
    required this.placettes,
    required this.arbres,
    required this.isWide,
  });
  final int placettes;
  final int arbres;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(icon: Icons.grid_view_rounded, value: '$placettes', label: 'Placettes'),
      _StatCard(icon: Icons.park_rounded, value: '$arbres', label: 'Individus'),
      const _StatCard(
        icon: Icons.offline_bolt_rounded,
        value: '100 %',
        label: 'Hors ligne',
      ),
    ];
    if (MediaQuery.sizeOf(context).width < 360) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards
            .map((card) => SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 32) / 2,
                  child: card,
                ))
            .toList(),
      );
    }
    return Row(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          Expanded(child: cards[index]),
          if (index < cards.length - 1) SizedBox(width: isWide ? 14 : 8),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.leaf, size: 21),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : AppColors.forest;
    return Material(
      color: primary ? AppColors.forest : AppColors.cream,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: primary ? null : Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withOpacity(0.13)
                      : AppColors.forest.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: foreground, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primary ? Colors.white : AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: primary
                            ? Colors.white.withOpacity(0.72)
                            : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: foreground, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final connected = SupabaseSyncService().isInitialized;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: connected
            ? AppColors.success.withOpacity(0.08)
            : AppColors.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: connected
              ? AppColors.success.withOpacity(0.28)
              : AppColors.gold.withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: connected ? AppColors.success : AppColors.earth,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? 'Sauvegarde automatique activée'
                          : 'Sauvegarde cloud non configurée',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      connected
                          ? 'Chaque donnée saisie est conservée sur l’appareil puis sauvegardée automatiquement dans le cloud dès qu’Internet est disponible.'
                          : 'Les données restent enregistrées et protégées sur l’appareil jusqu’au retour du service cloud.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 16, color: AppColors.success),
                      SizedBox(width: 6),
                      Text(
                        'Aucune action nécessaire',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.sync_rounded, size: 17),
                  label: const Text('Vérifier'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerBar extends StatelessWidget {
  const _PartnerBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Text('Avec le soutien de',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 12,
            children: [
              Image.asset('assets/logos/logo_cse.png',
                  width: 72, height: 54, fit: BoxFit.contain),
              Image.asset('assets/logos/logo_galileo.png',
                  width: 112, height: 54, fit: BoxFit.contain),
              Image.asset('assets/logos/funded_by_eu.jpg',
                  width: 138, height: 42, fit: BoxFit.contain),
            ],
          ),
        ],
      ),
    );
  }
}
