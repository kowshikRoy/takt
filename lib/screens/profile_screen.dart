
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../services/vocabulary_service.dart';
import '../services/profile_service.dart';
import '../models/saved_word.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 750;
            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 32),
                          Text(
                            'Appearance',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildAppearanceSection(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Growth',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGrowthCard(context),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  Text(
                    'Your Growth',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildGrowthCard(context),
                  const SizedBox(height: 32),
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAppearanceSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profileService, _) {
        return Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).cardColor, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
                image: const DecorationImage(
                  image: AssetImage('assets/images/profile.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profileService.displayName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Display Name',
                        onPressed: () => _showEditNameDialog(context, profileService),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileService.joinDateFormatted,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, ProfileService profileService) {
    final controller = TextEditingController(text: profileService.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              profileService.updateDisplayName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<ProfileService>(
      builder: (context, profileService, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: FutureBuilder<List<SavedWord>>(
            future: Provider.of<VocabularyService>(context, listen: false).getSavedWords(),
            builder: (context, snapshot) {
              final words = snapshot.data ?? [];
              final wordsCount = words.length;
              final totalXp = profileService.calculateTotalXp(wordsCount);
              final curStreak = profileService.currentStreak;

              return Column(
                children: [
                  _buildHeatmapCalendar(context, words),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Words',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$wordsCount',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Current Streak',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$curStreak Days 🔥',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total XP',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$totalXp',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeatmapCalendar(BuildContext context, List<SavedWord> words) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final Map<String, int> dailyCounts = {};
    for (final w in words) {
      final key = '${w.createdAt.year}-${w.createdAt.month}-${w.createdAt.day}';
      dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
    }

    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('12-Week Activity Heatmap', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
            Row(
              children: [
                Text('Less ', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                _buildHeatmapSquare(context, 0, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 1, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 2, primaryColor),
                const SizedBox(width: 3),
                _buildHeatmapSquare(context, 3, primaryColor),
                Text(' More', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 12,
            itemBuilder: (context, colIndex) {
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (rowIndex) {
                    final daysAgo = (11 - colIndex) * 7 + (6 - rowIndex);
                    final date = now.subtract(Duration(days: daysAgo));
                    final key = '${date.year}-${date.month}-${date.day}';
                    final count = dailyCounts[key] ?? 0;
                    return Tooltip(
                      message: '$count words on ${date.month}/${date.day}',
                      child: _buildHeatmapSquare(context, count, primaryColor),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapSquare(BuildContext context, int count, Color primaryColor) {
    Color color;
    if (count == 0) {
      color = Theme.of(context).dividerColor.withValues(alpha: 0.15);
    } else if (count == 1) {
      color = primaryColor.withValues(alpha: 0.35);
    } else if (count == 2) {
      color = primaryColor.withValues(alpha: 0.65);
    } else {
      color = primaryColor;
    }
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeMode;
    final currentTheme = themeProvider.colorTheme;
    final currentFont = themeProvider.fontFamily;
    final theme = Theme.of(context);

    final colorThemes = [
      {'label': 'Retro Teal', 'enum': AppColorTheme.retroTeal, 'color': const Color(0xFF2BBAA5)},
      {'label': 'Classic Red', 'enum': AppColorTheme.classic, 'color': const Color(0xFFEA2A33)},
      {'label': 'Retro Blue', 'enum': AppColorTheme.retroBlue, 'color': const Color(0xFF005F73)},
      {'label': 'Retro Gold', 'enum': AppColorTheme.retroGold, 'color': const Color(0xFFEE9B00)},
      {'label': 'Retro Rust', 'enum': AppColorTheme.retroRust, 'color': const Color(0xFFBB3E03)},
    ];

    final fonts = [
      'Spline Sans',
      'Lora',
      'Roboto',
      'Merriweather',
      'Lexend',
      'Montserrat',
      'Lato',
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 2, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Theme Mode
          _buildThemeOption(context, 'System', ThemeMode.system, currentMode, themeProvider),
          Divider(height: 1, color: theme.dividerColor),
          _buildThemeOption(context, 'Light Mode', ThemeMode.light, currentMode, themeProvider),
          Divider(height: 1, color: theme.dividerColor),
          _buildThemeOption(context, 'Dark Mode', ThemeMode.dark, currentMode, themeProvider),
          Divider(height: 1, color: theme.dividerColor),

          // 2. Color Palette
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Color Palette',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: colorThemes.map((ct) {
                final isSelected = currentTheme == ct['enum'];
                final color = ct['color'] as Color;
                final label = ct['label'] as String;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: CircleAvatar(backgroundColor: color, radius: 8),
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) => themeProvider.setColorTheme(ct['enum'] as AppColorTheme),
                    selectedColor: color.withValues(alpha: 0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor),

          // 3. Typography
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Typography',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: fonts.map((f) {
                final isSelected = currentFont == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => themeProvider.setFontFamily(f),
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, ThemeMode mode, ThemeMode currentGroupValue, ThemeProvider provider) {
    final isSelected = mode == currentGroupValue;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => provider.setThemeMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.primaryColor)
            else 
               Icon(Icons.circle_outlined, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }
}
