import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:takt/l10n/app_localizations.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'dictionary_screen.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/vocabulary_service.dart';
import '../services/haptic_service.dart';
import '../theme/breakpoints.dart';
import '../widgets/auth_sync_dialog.dart';
import '../widgets/celebration_overlay.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    VocabularyService().refreshAndRepairSavedWords();
    VocabularyService().cleanupInflectedFormEntries();
    _screens = [
      HomeScreen(onOpenLearnTab: () => _onItemTapped(1)),
      const DiscoverScreen(),
      DictionaryScreen(onBackToHome: () => _onItemTapped(0)),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Trigger sync per design doc §6: "app resume" (a no-op if not logged in).
    if (state == AppLifecycleState.resumed) {
      SyncService().syncNow();
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      AppHaptics.selection();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0 && _selectedIndex != 2) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: CelebrationOverlay(child: _buildScaffold(context)),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final WindowClass windowClass = WindowClass.of(context);
    final bool isDesktop = windowClass.isAtLeastMedium;
    final bool useExtendedRail = windowClass.isAtLeastExpanded;

    if (isDesktop) {
      final l10n = AppLocalizations.of(context);
      final items = [
        {
          'icon': Icons.home_outlined,
          'selectedIcon': Icons.home_rounded,
          'label': l10n?.navHome ?? 'Home',
        },
        {
          'icon': Icons.school_outlined,
          'selectedIcon': Icons.school_rounded,
          'label': l10n?.navLearn ?? 'Learn',
        },
        {
          'icon': Icons.menu_book_outlined,
          'selectedIcon': Icons.menu_book_rounded,
          'label': l10n?.navDictionary ?? 'Dictionary',
        },
        {
          'icon': Icons.person_outline,
          'selectedIcon': Icons.person_rounded,
          'label': l10n?.navProfile ?? 'Profile',
        },
      ];

      return Scaffold(
        body: Row(
          children: [
            // Google Photos style desktop navigation drawer
            Container(
              width: useExtendedRail ? 250 : 88,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  // App Header Logo
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24.0,
                      horizontal: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: useExtendedRail
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_circle_rounded,
                          size: 34,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        if (useExtendedRail) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Takt',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sidebar Options List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final isSelected = _selectedIndex == index;
                        final item = items[index];
                        final icon = isSelected
                            ? (item['selectedIcon'] as IconData)
                            : (item['icon'] as IconData);
                        final label = item['label'] as String;

                        return InkWell(
                          onTap: () => _onItemTapped(index),
                          borderRadius: BorderRadius.circular(4),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: useExtendedRail ? 18 : 0,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: useExtendedRail
                                ? Row(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 22,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        size: 24,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Cloud Sync Button
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24.0,
                      left: 12.0,
                      right: 12.0,
                    ),
                    child: Consumer<AuthService>(
                      builder: (context, auth, _) {
                        if (useExtendedRail) {
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                  color: auth.isAuthenticated
                                      ? Colors.green.withValues(alpha: 0.5)
                                      : Theme.of(context).colorScheme.outline
                                            .withValues(alpha: 0.3),
                                ),
                              ),
                              icon: Icon(
                                auth.isAuthenticated
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_queue_rounded,
                                color: auth.isAuthenticated
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                auth.isAuthenticated
                                    ? 'Cloud Synced'
                                    : 'Sync Account',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: auth.isAuthenticated
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              onPressed: () => AuthSyncDialog.show(context),
                            ),
                          );
                        }
                        return IconButton(
                          icon: Icon(
                            auth.isAuthenticated
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_queue_rounded,
                            color: auth.isAuthenticated
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                            size: 26,
                          ),
                          tooltip: 'Cloud Sync & Account',
                          onPressed: () => AuthSyncDialog.show(context),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: windowClass.isAtLeastLarge ? 1400 : 1100,
                    ),
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _screens,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildModernistBottomBar(context),
    );
  }

  Widget _buildModernistBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navItems = [
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l10n?.navHome ?? 'Home',
      ),
      (
        icon: Icons.school_outlined,
        selectedIcon: Icons.school_rounded,
        label: l10n?.navLearn ?? 'Learn',
      ),
      (
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
        label: l10n?.navDictionary ?? 'Dictionary',
      ),
      (
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: l10n?.navProfile ?? 'Profile',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1917) : const Color(0xFFFAF6F0),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.45),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(index),
                  splashColor: colorScheme.primary.withValues(alpha: 0.08),
                  highlightColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            size: 22,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            letterSpacing: 0.2,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
  }
}
