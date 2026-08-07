import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:takt/l10n/app_localizations.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/capped_width.dart';
import '../widgets/auth_sync_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    await SyncService().syncNow();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synced with cloud successfully! ☁️'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n?.titleSettings.toUpperCase() ?? 'SETTINGS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.0,
            color: inkColor,
          ),
        ),
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: inkColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: CappedWidth(
          maxWidth: 700,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. ACCOUNT & CLOUD SYNC CARD
              _buildSectionTitle(context, l10n?.sectionAccountSync ?? 'ACCOUNT & SYNC', rustAccent),
              _buildAccountSyncCard(context, inkColor, cardBg, rustAccent),
              const SizedBox(height: 20),

              // 2. APPEARANCE CARD
              _buildSectionTitle(context, l10n?.sectionAppearance.toUpperCase() ?? 'APPEARANCE', rustAccent),
              _buildAppearanceCard(context, themeProvider, inkColor, cardBg, rustAccent),
              const SizedBox(height: 20),

              // 3. LEARNING PREFERENCES CARD
              _buildSectionTitle(context, l10n?.sectionLearningPreferences ?? 'LEARNING PREFERENCES', rustAccent),
              _buildLearningPreferencesCard(context, l10n, inkColor, cardBg, rustAccent),
              const SizedBox(height: 20),

              // 4. DATA & STORAGE CARD
              _buildSectionTitle(context, l10n?.sectionDataStorage ?? 'DATA & STORAGE', rustAccent),
              _buildDataStorageCard(context, inkColor, cardBg, rustAccent),
              const SizedBox(height: 20),

              // 5. ABOUT CARD
              _buildSectionTitle(context, l10n?.sectionAbout ?? 'ABOUT', rustAccent),
              _buildAboutCard(context, inkColor, cardBg, rustAccent),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color rustAccent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: rustAccent,
        ),
      ),
    );
  }

  Widget _buildAccountSyncCard(
    BuildContext context,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    final auth = AuthService();
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.username ?? 'Learner',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: inkColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.email ?? 'Offline guest session',
                      style: TextStyle(
                        fontSize: 12,
                        color: inkColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: auth.isAuthenticated
                      ? const Color(0xFF2C5E3B).withValues(alpha: 0.15)
                      : inkColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: auth.isAuthenticated
                        ? const Color(0xFF2C5E3B).withValues(alpha: 0.4)
                        : inkColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      auth.isAuthenticated ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 13,
                      color: auth.isAuthenticated ? const Color(0xFF2C5E3B) : inkColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      auth.isAuthenticated ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: auth.isAuthenticated ? const Color(0xFF2C5E3B) : inkColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: inkColor.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n?.labelLastSynced ?? 'Last synced'}: ${l10n?.labelJustNow ?? 'just now'}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: inkColor.withValues(alpha: 0.6),
                ),
              ),
              Row(
                children: [
                  if (!auth.isAuthenticated)
                    TextButton(
                      onPressed: () => AuthSyncDialog.show(context),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Sign In'),
                    ),
                  FilledButton.icon(
                    onPressed: _isSyncing ? null : _handleSync,
                    style: FilledButton.styleFrom(
                      backgroundColor: rustAccent,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: Text(l10n?.actionSyncNow ?? 'Sync Now'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    ThemeProvider themeProvider,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Theme Mode
          ListTile(
            title: Text(l10n?.labelAppTheme ?? 'App Theme', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_getThemeModeName(themeProvider.themeMode)),
            leading: Icon(Icons.brightness_6_rounded, color: rustAccent),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemeDialog(context, themeProvider),
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Color Palette
          ListTile(
            title: Text(l10n?.labelColorPalette ?? 'Color Palette', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _getThemeColorPreview(themeProvider.colorTheme),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                Text(_getColorThemeName(themeProvider.colorTheme)),
              ],
            ),
            leading: Icon(Icons.color_lens_rounded, color: rustAccent),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showColorThemeDialog(context, themeProvider),
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Typography Font
          ListTile(
            title: Text(l10n?.labelTypography ?? 'Typography', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(themeProvider.fontFamily),
            leading: Icon(Icons.font_download_rounded, color: rustAccent),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showFontDialog(context, themeProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPreferencesCard(
    BuildContext context,
    AppLocalizations? l10n,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // CEFR Target Level
          Consumer<ProfileService>(
            builder: (context, profileService, _) {
              return ListTile(
                title: Text(l10n?.labelTargetLevel ?? 'Target Level (CEFR)', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Level ${profileService.targetLevel}'),
                leading: Icon(Icons.military_tech_rounded, color: rustAccent),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showProficiencyLevelDialog(context, profileService),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Daily Word Goal
          Consumer<ProfileService>(
            builder: (context, profileService, _) {
              return ListTile(
                title: Text(l10n?.labelDailyGoal ?? 'Daily Word Goal', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  l10n?.labelWordsPerDay(profileService.dailyWordGoalCount) ??
                      '${profileService.dailyWordGoalCount} words/day',
                ),
                leading: Icon(Icons.style_rounded, color: rustAccent),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDailyWordGoalDialog(context, profileService),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Sound Effects & Pack
          Consumer<SoundService>(
            builder: (context, soundService, _) {
              return Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n?.labelSoundEffects ?? 'Sound Effects', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Audio cues for correct/incorrect reviews'),
                    secondary: Icon(Icons.volume_up_rounded, color: rustAccent),
                    value: soundService.enabled,
                    onChanged: (val) => soundService.setEnabled(val),
                  ),
                  if (soundService.enabled) ...[
                    Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      title: const Text('Sound Style', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        SoundService.availablePacks[soundService.soundPack] ?? 'Marimba (Duolingo Style)',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSoundPackDialog(context, soundService),
                    ),
                  ],
                ],
              );
            },
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Streak Reminders Notification
          Consumer<NotificationService>(
            builder: (context, notificationService, _) {
              return SwitchListTile(
                title: Text(l10n?.labelStreakReminders ?? 'Streak Reminders', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l10n?.labelDailyReminderSubtitle ?? 'A daily nudge if you haven\'t practiced yet'),
                secondary: Icon(Icons.notifications_active_outlined, color: rustAccent),
                value: notificationService.enabled,
                onChanged: (val) async {
                  final ok = await notificationService.setEnabled(val);
                  if (!ok && val && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notification permission was denied — enable it in system settings to turn this on.',
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataStorageCard(
    BuildContext context,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: const _DictionaryDatabaseTile(),
    );
  }

  Widget _buildAboutCard(
    BuildContext context,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Version', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('1.0.0 · Bauhaus Modernist Edition'),
            leading: Icon(Icons.info_outline_rounded, color: rustAccent),
          ),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  String _getColorThemeName(AppColorTheme theme) {
    switch (theme) {
      case AppColorTheme.classic:
        return 'Classic Red';
      case AppColorTheme.retroTeal:
        return 'Retro Teal';
      case AppColorTheme.retroBlue:
        return 'Retro Blue';
      case AppColorTheme.retroGold:
        return 'Retro Gold';
      case AppColorTheme.retroRust:
        return 'Retro Rust';
      case AppColorTheme.modernist:
        return 'Modernist (Warm Grey & Red)';
      case AppColorTheme.retroPurple:
        return 'Amethyst Violet (Gender Neutral)';
      case AppColorTheme.slateGrey:
        return 'Slate Grey (Minimalist Monochrome)';
    }
  }

  Color _getThemeColorPreview(AppColorTheme theme) {
    switch (theme) {
      case AppColorTheme.classic:
        return const Color(0xFFEA2A33);
      case AppColorTheme.retroTeal:
        return const Color(0xFF2BBAA5);
      case AppColorTheme.retroBlue:
        return const Color(0xFF005F73);
      case AppColorTheme.retroGold:
        return const Color(0xFFEE9B00);
      case AppColorTheme.retroRust:
        return const Color(0xFFBB3E03);
      case AppColorTheme.modernist:
        return const Color(0xFFEC3013);
      case AppColorTheme.retroPurple:
        return const Color(0xFF7C3AED);
      case AppColorTheme.slateGrey:
        return const Color(0xFF64748B);
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioOption<ThemeMode>(
              context,
              'System Default',
              ThemeMode.system,
              provider.themeMode,
              (val) => provider.setThemeMode(val!),
            ),
            _buildRadioOption<ThemeMode>(
              context,
              'Light Mode',
              ThemeMode.light,
              provider.themeMode,
              (val) => provider.setThemeMode(val!),
            ),
            _buildRadioOption<ThemeMode>(
              context,
              'Dark Mode',
              ThemeMode.dark,
              provider.themeMode,
              (val) => provider.setThemeMode(val!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSoundPackDialog(BuildContext context, SoundService soundService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Sound Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SoundService.availablePacks.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              secondary: IconButton(
                icon: const Icon(Icons.volume_up_rounded),
                tooltip: 'Preview sound',
                onPressed: () => soundService.previewSoundPack(entry.key),
              ),
              value: entry.key,
              groupValue: soundService.soundPack,
              onChanged: (val) {
                if (val != null) {
                  soundService.setSoundPack(val, preview: true);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDailyWordGoalDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Daily Word Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [3, 5, 10, 15].map((count) {
            return _buildRadioOption<int>(
              context,
              '$count words / day',
              count,
              profileService.dailyWordGoalCount,
              (val) => profileService.setDailyWordGoalCount(val!),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showColorThemeDialog(BuildContext context, ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Select Palette'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppColorTheme.values.map((theme) {
              return RadioListTile<AppColorTheme>(
                title: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _getThemeColorPreview(theme),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getColorThemeName(theme),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                value: theme,
                groupValue: provider.colorTheme,
                onChanged: (val) {
                  if (val != null) {
                    provider.setColorTheme(val);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFontDialog(BuildContext context, ThemeProvider provider) {
    final fonts = [
      'Spline Sans',
      'Lora',
      'Roboto',
      'Merriweather',
      'Open Sans',
      'Lexend',
      'Montserrat',
      'Lato',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Select Typography'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final fontKey = fonts[index];

              return RadioListTile<String>(
                title: Text(
                  fontKey,
                  style: AppTheme.getButtonTextStyle(
                    fontKey,
                    fontWeight: FontWeight.normal,
                  ).copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
                value: fontKey,
                groupValue: provider.fontFamily,
                onChanged: (val) {
                  if (val != null) {
                    provider.setFontFamily(val);
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption<T>(
    BuildContext context,
    String title,
    T value,
    T groupValue,
    ValueChanged<T?> onChanged,
  ) {
    return RadioListTile<T>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: (val) {
        onChanged(val);
        Navigator.pop(context);
      },
    );
  }

  void _showProficiencyLevelDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
    final levels = [
      ('A1', 'Beginner', 'Basic everyday phrases and essential vocabulary'),
      ('A2', 'Elementary', 'Routine conversations and simple descriptive language'),
      ('B1', 'Intermediate', 'Connected texts, expressions, and nuanced everyday topics'),
      ('B2', 'Upper Intermediate', 'Complex texts, abstract ideas, and fluent conversation'),
      ('C1', 'Advanced', 'Specialized domain vocabulary, idioms, and subtle nuance'),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('Select Proficiency Level'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: levels.map((lvl) {
                final isSelected = profileService.targetLevel == lvl.$1;
                return RadioListTile<String>(
                  value: lvl.$1,
                  groupValue: profileService.targetLevel,
                  title: Text('${lvl.$1} · ${lvl.$2}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lvl.$3, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onChanged: (val) {
                    if (val != null) {
                      profileService.setTargetLevel(val);
                      Navigator.pop(ctx);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _DictionaryDatabaseTile extends StatefulWidget {
  const _DictionaryDatabaseTile();

  @override
  State<_DictionaryDatabaseTile> createState() => _DictionaryDatabaseTileState();
}

class _DictionaryDatabaseTileState extends State<_DictionaryDatabaseTile> {
  final DictionaryService _dictService = DictionaryService();
  String _version = "v3.0";
  String _size = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final s = await _dictService.getDatabaseSizeFormatted();
    if (mounted) {
      setState(() {
        _size = s;
      });
    }

    final v = await _dictService.getDatabaseVersion();
    if (mounted) {
      setState(() {
        _version = v;
      });
    }

    await _dictService.checkForDatabaseUpdate();
  }

  Future<void> _handleUpdateOrRedownload() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting dictionary database download...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await _dictService.redownloadDatabase();
      await _loadMetadata();

      if (mounted) {
        final err = _dictService.downloadErrorNotifier.value;
        if (err != null && err.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dictionary database updated successfully! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    return ValueListenableBuilder<bool>(
      valueListenable: _dictService.isDownloadingNotifier,
      builder: (context, isDownloading, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _dictService.hasUpdateNotifier,
          builder: (context, hasUpdate, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: _dictService.isCheckingNotifier,
              builder: (context, isChecking, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: _dictService.latestVersionNotifier,
                  builder: (context, latestTag, _) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: rustAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.storage_rounded,
                                  color: rustAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Offline German Dictionary',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: inkColor,
                                            ),
                                          ),
                                        ),
                                        if (hasUpdate) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: rustAccent,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'UPDATE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isChecking
                                          ? 'Checking for update...'
                                          : hasUpdate && latestTag != null
                                          ? 'Installed: $_version • Latest: $latestTag'
                                          : 'Installed: $_version • Size: $_size',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: inkColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status: Downloaded & Ready',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: inkColor.withValues(alpha: 0.6),
                                ),
                              ),
                              if (isDownloading || isChecking)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                )
                              else if (hasUpdate)
                                FilledButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: rustAccent,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  icon: const Icon(Icons.system_update_rounded, size: 14),
                                  label: const Text('Update Now'),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  icon: const Icon(Icons.download_rounded, size: 14),
                                  label: const Text('Re-download'),
                                ),
                            ],
                          ),
                          if (isDownloading) ...[
                            const SizedBox(height: 12),
                            ValueListenableBuilder<double>(
                              valueListenable: _dictService.downloadProgressNotifier,
                              builder: (context, progress, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        minHeight: 5,
                                        color: rustAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      progress > 0
                                          ? 'Downloading update... ${(progress * 100).toStringAsFixed(0)}%'
                                          : 'Connecting to GitHub...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: rustAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
