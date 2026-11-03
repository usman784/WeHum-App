import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/states.dart';
import 'library_pages.dart' show SessionRow, openSessionDetail;

/// You → Favourites: the meditations the member has hearted, newest first. Members only (the route is wrapped in `MembersOnly`).
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final FavoritesService _favorites = Get.find();

  @override
  void initState() {
    super.initState();
    _favorites.load(); // newest from the server (another device may have added some)
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppScaffold(
      title: 'Favourites', stitch: true,
      body: Obx(() {
        final items = _favorites.items.toList();
        if (items.isEmpty) {
          if (_favorites.failed.value) {
            return EmptyState(
              key: const Key('favorites-error'), title: 'Could not load your favourites', icon: Icons.cloud_off_rounded,
              body: 'Check your connection and try again.', ctaLabel: 'Try again', onCta: _favorites.load,
            );
          }
          if (!_favorites.loaded.value) return const Center(child: CircularProgressIndicator());
          return const EmptyState(
            key: Key('favorites-empty'), title: 'No favourites yet', icon: Icons.favorite_border_rounded,
            body: 'Tap the heart on a meditation to keep it here.',
          );
        }
        return ListView(
          key: const Key('favorites-list'), padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24),
          children: [
            for (final s in items)
              Row(key: Key('fav-${s.id}'), children: [
                Expanded(child: SessionRow(s: s, onTap: () => openSessionDetail(s))),
                IconButton(
                  key: Key('fav-remove-${s.id}'), tooltip: 'Remove from favourites',
                  icon: Icon(Icons.favorite_rounded, color: c.emberText),
                  onPressed: () => _favorites.toggle(s),
                ),
              ]),
          ],
        );
      }),
    );
  }
}
