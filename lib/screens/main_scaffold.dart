import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'dictionary_screen.dart';
import '../services/auth_service.dart';
import '../widgets/auth_sync_dialog.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 1});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const DiscoverScreen(),
    const DictionaryScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    final bool useExtendedRail = screenWidth >= 900;

    if (isDesktop) {
      final items = [
        {'icon': Icons.home_outlined, 'selectedIcon': Icons.home_rounded, 'label': 'Home'},
        {'icon': Icons.school_outlined, 'selectedIcon': Icons.school_rounded, 'label': 'Learn'},
        {'icon': Icons.menu_book_outlined, 'selectedIcon': Icons.menu_book_rounded, 'label': 'Dictionary'},
        {'icon': Icons.person_outline, 'selectedIcon': Icons.person_rounded, 'label': 'Profile'},
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
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: useExtendedRail ? MainAxisAlignment.start : MainAxisAlignment.center,
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
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final isSelected = _selectedIndex == index;
                        final item = items[index];
                        final icon = isSelected ? (item['selectedIcon'] as IconData) : (item['icon'] as IconData);
                        final label = item['label'] as String;

                        return InkWell(
                          onTap: () => _onItemTapped(index),
                          borderRadius: BorderRadius.circular(28),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: useExtendedRail ? 18 : 0,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: useExtendedRail
                                ? Row(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 22,
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
                    padding: const EdgeInsets.only(bottom: 24.0, left: 12.0, right: 12.0),
                    child: Consumer<AuthService>(
                      builder: (context, auth, _) {
                        if (useExtendedRail) {
                          return SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(
                                  color: auth.isAuthenticated
                                      ? Colors.green.withValues(alpha: 0.5)
                                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              icon: Icon(
                                auth.isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                                color: auth.isAuthenticated ? Colors.green : Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              label: Text(
                                auth.isAuthenticated ? 'Cloud Synced' : 'Sync Account',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: auth.isAuthenticated ? Colors.green : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              onPressed: () => AuthSyncDialog.show(context),
                            ),
                          );
                        }
                        return IconButton(
                          icon: Icon(
                            auth.isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                            color: auth.isAuthenticated ? Colors.green : Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: _screens[_selectedIndex],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).cardColor,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).unselectedWidgetColor,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'Learn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Dictionary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
