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
import '../services/tts_service.dart';
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
            fontSize: 14,
            letterSpacing: 0.9,
            color: inkColor,
          ),
        ),
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: inkColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: CappedWidth(
          maxWidth: 700,
          child: ListTileTheme.merge(
            dense: true,
            titleTextStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: inkColor,
            ),
            subtitleTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: inkColor.withValues(alpha: 0.6),
            ),
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
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color rustAccent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
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

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        fontSize: 14,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                      size: 12,
                      color: auth.isAuthenticated ? const Color(0xFF2C5E3B) : inkColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      auth.isAuthenticated ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 10,
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
          const SizedBox(height: 12),
          Divider(height: 1, color: inkColor.withValues(alpha: 0.12)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l10n?.labelLastSynced ?? 'Last synced'}: ${l10n?.labelJustNow ?? 'just now'}',
                style: TextStyle(
                  fontSize: 11,
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
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      child: const Text('Sign In'),
                    ),
                  FilledButton.icon(
                    onPressed: _isSyncing ? null : _handleSync,
                    style: FilledButton.styleFrom(
                      backgroundColor: rustAccent,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, size: 14),
                    label: Text(l10n?.actionSyncNow ?? 'Sync Now'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Theme Mode
          ListTile(
            title: Text(l10n?.labelAppTheme ?? 'App Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
            subtitle: Text(_getThemeModeName(themeProvider.themeMode), style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
            leading: Icon(Icons.brightness_6_rounded, color: rustAccent, size: 20),
            trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
            onTap: () => _showThemeDialog(context, themeProvider),
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Color Palette
          ListTile(
            title: Text(l10n?.labelColorPalette ?? 'Color Palette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
            subtitle: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _getThemeColorPreview(themeProvider.colorTheme),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(_getColorThemeName(themeProvider.colorTheme), style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
              ],
            ),
            leading: Icon(Icons.color_lens_rounded, color: rustAccent, size: 20),
            trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
            onTap: () => _showColorThemeDialog(context, themeProvider),
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Typography Font
          ListTile(
            title: Text(l10n?.labelTypography ?? 'Typography', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
            subtitle: Text(themeProvider.fontFamily, style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
            leading: Icon(Icons.font_download_rounded, color: rustAccent, size: 20),
            trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
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
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
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
                title: Text(l10n?.labelTargetLevel ?? 'Target Level (CEFR)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Level ', style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final cefrColors = AppTheme.getCefrColors(profileService.targetLevel, isDark: isDark);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: cefrColors.background,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: cefrColors.border, width: 0.8),
                          ),
                          child: Text(
                            profileService.targetLevel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cefrColors.foreground),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                leading: Icon(Icons.military_tech_rounded, color: rustAccent, size: 20),
                trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
                onTap: () => _showProficiencyLevelDialog(context, profileService),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // Daily Word Goal
          Consumer<ProfileService>(
            builder: (context, profileService, _) {
              return ListTile(
                title: Text(l10n?.labelDailyGoal ?? 'Daily Word Goal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                subtitle: Text(
                  l10n?.labelWordsPerDay(profileService.dailyWordGoalCount) ??
                      '${profileService.dailyWordGoalCount} words/day',
                  style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6)),
                ),
                leading: Icon(Icons.style_rounded, color: rustAccent, size: 20),
                trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
                onTap: () => _showDailyWordGoalDialog(context, profileService),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),

          // German Voice (TTS)
          Consumer<TtsService>(
            builder: (context, ttsService, _) {
              final selectedVoice = ttsService.selectedVoice;
              final voiceSubtitle = selectedVoice == null
                  ? '${l10n?.labelSystemDefaultVoice ?? 'System Default'} (de-DE)'
                  : '${selectedVoice.label} · ${selectedVoice.regionLabel}';

              return ListTile(
                title: Text(
                  l10n?.labelGermanVoice ?? 'German Voice (TTS)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor),
                ),
                subtitle: Text(
                  voiceSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6)),
                ),
                leading: Icon(Icons.record_voice_over_rounded, color: rustAccent, size: 20),
                trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
                onTap: () => _showGermanVoiceDialog(context, ttsService),
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
                    title: Text(l10n?.labelSoundEffects ?? 'Sound Effects', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                    subtitle: Text('Audio cues for correct/incorrect reviews', style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
                    secondary: Icon(Icons.volume_up_rounded, color: rustAccent, size: 20),
                    value: soundService.enabled,
                    onChanged: (val) => soundService.setEnabled(val),
                  ),
                  if (soundService.enabled) ...[
                    Divider(height: 1, indent: 56, color: inkColor.withValues(alpha: 0.1)),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 56, right: 16),
                      title: Text('Sound Style', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                      subtitle: Text(
                        SoundService.availablePacks[soundService.soundPack] ?? 'Marimba (Duolingo Style)',
                        style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6)),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: inkColor.withValues(alpha: 0.4), size: 18),
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
                title: Text(l10n?.labelStreakReminders ?? 'Streak Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
                subtitle: Text(
                  l10n?.labelDailyReminderSubtitle ?? 'A daily nudge if you haven\'t practiced yet',
                  style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6)),
                ),
                secondary: Icon(Icons.notifications_active_outlined, color: rustAccent, size: 20),
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
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
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
    return Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text('Version', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor)),
            subtitle: Text('1.0.0 · Bauhaus Modernist Edition', style: TextStyle(fontSize: 12, color: inkColor.withValues(alpha: 0.6))),
            leading: Icon(Icons.info_outline_rounded, color: rustAccent, size: 20),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
        ),
        title: Text(
          'SELECT THEME',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
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
              foregroundColor: rustAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGermanVoiceDialog(BuildContext context, TtsService ttsService) {
    ttsService.getGermanVoices();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    showDialog(
      context: context,
      builder: (ctx) {
        return ChangeNotifierProvider.value(
          value: ttsService,
          child: Consumer<TtsService>(
            builder: (dialogCtx, tts, _) {
              final availableVoices = tts.availableVoices;
              final isLoading = tts.isLoadingVoices;
              final selectedVoice = tts.selectedVoice;

              return AlertDialog(
                backgroundColor: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
                ),
                titlePadding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
                title: Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded, color: rustAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n?.titleSelectGermanVoice ?? 'Select German Voice',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: inkColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 18, color: inkColor),
                      tooltip: 'Refresh voices',
                      onPressed: () => tts.getGermanVoices(forceRefresh: true),
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. System Default Option
                          RadioListTile<String?>(
                            dense: true,
                            value: null,
                            groupValue: selectedVoice?.name,
                            title: Text(
                              l10n?.labelSystemDefaultVoice ?? 'System Default',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: inkColor,
                              ),
                            ),
                            subtitle: Text(
                              l10n?.subtitleSystemDefaultVoice ?? 'Default speech engine (de-DE)',
                              style: TextStyle(
                                fontSize: 11,
                                color: inkColor.withValues(alpha: 0.6),
                              ),
                            ),
                            secondary: IconButton(
                              icon: Icon(
                                tts.isPlayingPreview &&
                                        tts.previewingVoiceKey == '__system_default__'
                                    ? Icons.stop_circle_rounded
                                    : Icons.volume_up_rounded,
                                color: rustAccent,
                                size: 18,
                              ),
                              tooltip: 'Preview voice',
                              onPressed: () {
                                if (tts.isPlayingPreview &&
                                    tts.previewingVoiceKey == '__system_default__') {
                                  tts.stop();
                                } else {
                                  tts.previewVoice(null);
                                }
                              },
                            ),
                            onChanged: (_) {
                              tts.setVoice(null);
                              Navigator.pop(ctx);
                            },
                          ),

                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Text(
                              'AVAILABLE GERMAN VOICES (${availableVoices.length})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: rustAccent,
                              ),
                            ),
                          ),
                          Divider(height: 6, color: inkColor.withValues(alpha: 0.12)),

                          // 2. Voices List / Loading / Empty State
                          if (isLoading && availableVoices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: rustAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Scanning German voices...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: inkColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (availableVoices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                l10n?.msgNoVoicesDetected ??
                                    'Using system default voice. No additional voices found on this device.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: inkColor.withValues(alpha: 0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ...availableVoices.map((voice) {
                              final isSelected = selectedVoice?.name == voice.name;
                              final isPlayingThis = tts.isPlayingPreview &&
                                  tts.previewingVoiceKey == voice.name;

                              return RadioListTile<String?>(
                                dense: true,
                                value: voice.name,
                                groupValue: selectedVoice?.name,
                                selected: isSelected,
                                title: Text(
                                  voice.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: inkColor,
                                  ),
                                ),
                                subtitle: Text(
                                  voice.details,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: inkColor.withValues(alpha: 0.6),
                                  ),
                                ),
                                secondary: IconButton(
                                  icon: Icon(
                                    isPlayingThis
                                        ? Icons.stop_circle_rounded
                                        : Icons.volume_up_rounded,
                                    color: rustAccent,
                                    size: 18,
                                  ),
                                  tooltip: 'Preview voice',
                                  onPressed: () {
                                    if (isPlayingThis) {
                                      tts.stop();
                                    } else {
                                      tts.previewVoice(voice);
                                    }
                                  },
                                ),
                                onChanged: (_) {
                                  tts.setVoice(voice);
                                  Navigator.pop(ctx);
                                },
                              );
                            }),

                          const SizedBox(height: 6),
                          Divider(height: 12, color: inkColor.withValues(alpha: 0.12)),

                          // 3. Speech Rate Control
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n?.labelSpeechRate ?? 'Speech Speed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: inkColor,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    (0.4, '0.8x'),
                                    (0.5, '1.0x'),
                                    (0.6, '1.2x'),
                                  ].map((opt) {
                                    final isCur = (tts.speechRate - opt.$1).abs() < 0.05;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: InkWell(
                                        onTap: () => tts.setSpeechRate(opt.$1),
                                        borderRadius: BorderRadius.circular(3),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCur
                                                ? rustAccent
                                                : inkColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            opt.$2,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isCur ? Colors.white : inkColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      tts.stop();
                      Navigator.pop(ctx);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: rustAccent,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showSoundPackDialog(BuildContext context, SoundService soundService) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
        ),
        title: Text(
          'SOUND STYLE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SoundService.availablePacks.entries.map((entry) {
            return RadioListTile<String>(
              dense: true,
              title: Text(entry.value, style: TextStyle(color: inkColor, fontSize: 13)),
              secondary: IconButton(
                icon: Icon(Icons.volume_up_rounded, color: rustAccent, size: 18),
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
              foregroundColor: rustAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
        ),
        title: Text(
          'DAILY WORD GOAL',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
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
              foregroundColor: rustAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showColorThemeDialog(BuildContext context, ThemeProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
        ),
        title: Text(
          'SELECT PALETTE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppColorTheme.values.map((thm) {
              return RadioListTile<AppColorTheme>(
                dense: true,
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getThemeColorPreview(thm),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getColorThemeName(thm),
                        style: TextStyle(color: inkColor, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                value: thm,
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
              foregroundColor: rustAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFontDialog(BuildContext context, ThemeProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

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
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
        ),
        title: Text(
          'SELECT TYPOGRAPHY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkColor,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: fonts.length,
            itemBuilder: (context, index) {
              final fontKey = fonts[index];

              return RadioListTile<String>(
                dense: true,
                title: Text(
                  fontKey,
                  style: AppTheme.getButtonTextStyle(
                    fontKey,
                    fontWeight: FontWeight.normal,
                  ).copyWith(color: inkColor, fontSize: 13),
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
              foregroundColor: rustAccent,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);

    return RadioListTile<T>(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title, style: TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.w500)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

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
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: inkColor.withValues(alpha: 0.18), width: 1),
          ),
          title: Text(
            'SELECT PROFICIENCY LEVEL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: inkColor,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: levels.map((lvl) {
                final isSelected = profileService.targetLevel == lvl.$1;
                return RadioListTile<String>(
                  dense: true,
                  value: lvl.$1,
                  groupValue: profileService.targetLevel,
                  title: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final cefrColors = AppTheme.getCefrColors(lvl.$1, isDark: isDark);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cefrColors.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cefrColors.border, width: 0.8),
                            ),
                            child: Text(
                              lvl.$1,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cefrColors.foreground,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lvl.$2,
                        style: TextStyle(fontWeight: FontWeight.bold, color: inkColor, fontSize: 13),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    lvl.$3,
                    style: TextStyle(fontSize: 11, color: inkColor.withValues(alpha: 0.6)),
                  ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: rustAccent,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Close'),
            ),
          ],
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
    final v = await _dictService.getDatabaseVersion();
    if (mounted) {
      setState(() {
        _size = s;
        _version = v;
      });
    }

    await _dictService.checkForDatabaseUpdate();

    if (mounted) {
      final updatedV = await _dictService.getDatabaseVersion();
      final updatedS = await _dictService.getDatabaseSizeFormatted();
      setState(() {
        _version = updatedV;
        _size = updatedS;
      });
    }
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
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: rustAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.storage_rounded,
                                  color: rustAccent,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: inkColor,
                                            ),
                                          ),
                                        ),
                                        if (hasUpdate) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: rustAccent,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: const Text(
                                              'UPDATE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
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
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Status: Downloaded & Ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: inkColor.withValues(alpha: 0.6),
                                ),
                              ),
                              if (isDownloading || isChecking)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                  ),
                                )
                              else if (hasUpdate)
                                FilledButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: rustAccent,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.system_update_rounded, size: 13),
                                  label: const Text('Update Now'),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.download_rounded, size: 13),
                                  label: const Text('Re-download'),
                                ),
                            ],
                          ),
                          if (isDownloading) ...[
                            const SizedBox(height: 10),
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
                                        minHeight: 4,
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
