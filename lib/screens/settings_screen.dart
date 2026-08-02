import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';
import '../services/dictionary_service.dart';
import '../services/profile_service.dart';
import '../services/sound_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(context, 'Appearance'),

          // Theme Mode Selector
          ListTile(
            title: const Text('App Theme'),
            subtitle: Text(_getThemeModeName(themeProvider.themeMode)),
            leading: Icon(
              Icons.brightness_6_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemeDialog(context, themeProvider),
          ),

          // Color Theme Selector
          ListTile(
            title: const Text('Color Palette'),
            subtitle: Text(_getColorThemeName(themeProvider.colorTheme)),
            leading: Icon(
              Icons.color_lens_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showColorThemeDialog(context, themeProvider),
          ),

          const Divider(indent: 16, endIndent: 16),

          // Font Family Selector
          ListTile(
            title: const Text('Typography'),
            subtitle: Text(themeProvider.fontFamily),
            leading: Icon(
              Icons.font_download_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showFontDialog(context, themeProvider),
          ),

          const Divider(indent: 16, endIndent: 16),

          _buildSectionHeader(context, 'Practice & Learning'),
          Consumer<ProfileService>(
            builder: (context, profileService, _) {
              return ListTile(
                title: const Text('Daily Word Goal'),
                subtitle: Text(
                  '${profileService.dailyWordGoalCount} new words per day',
                ),
                leading: Icon(
                  Icons.style_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showDailyWordGoalDialog(context, profileService),
              );
            },
          ),
          Consumer<SoundService>(
            builder: (context, soundService, _) {
              return SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Correct/incorrect and level-up cues'),
                secondary: Icon(
                  Icons.volume_up_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                value: soundService.enabled,
                onChanged: (val) => soundService.setEnabled(val),
              );
            },
          ),
          Consumer<NotificationService>(
            builder: (context, notificationService, _) {
              return SwitchListTile(
                title: const Text('Streak Reminders'),
                subtitle: const Text(
                  'A daily nudge (~8pm) if you haven\'t practiced yet',
                ),
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
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

          const Divider(indent: 16, endIndent: 16),

          _buildSectionHeader(context, 'Dictionary & Offline Data'),
          const _DictionaryDatabaseTile(),

          const SizedBox(height: 32),
          _buildSectionHeader(context, 'About'),

          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
            leading: Icon(
              Icons.info_outline_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
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
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        title: const Text('Select Palette'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppColorTheme.values.map((theme) {
              return RadioListTile<AppColorTheme>(
                title: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getThemeColorPreview(theme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_getColorThemeName(theme)),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
    }
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
}

class _DictionaryDatabaseTile extends StatefulWidget {
  const _DictionaryDatabaseTile();

  @override
  State<_DictionaryDatabaseTile> createState() =>
      _DictionaryDatabaseTileState();
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
    final colorScheme = Theme.of(context).colorScheme;

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
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasUpdate
                              ? colorScheme.primary.withValues(alpha: 0.3)
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.storage_rounded,
                                  color: colorScheme.primary,
                                  size: 22,
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
                                            'Offline Dictionary',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        if (hasUpdate) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'UPDATE AVAILABLE',
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
                                    const SizedBox(height: 4),
                                    Text(
                                      isChecking
                                          ? 'Checking for update...'
                                          : hasUpdate && latestTag != null
                                          ? 'Installed: $_version • Latest: $latestTag'
                                          : 'Installed Version: $_version',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_zip_rounded,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Size: $_size',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              if (isDownloading || isChecking)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else if (hasUpdate)
                                FilledButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.system_update_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Update Now'),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: _handleUpdateOrRedownload,
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Re-download'),
                                ),
                            ],
                          ),
                          if (isDownloading) ...[
                            const SizedBox(height: 12),
                            ValueListenableBuilder<double>(
                              valueListenable:
                                  _dictService.downloadProgressNotifier,
                              builder: (context, progress, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      progress > 0
                                          ? 'Downloading database update... ${(progress * 100).toStringAsFixed(0)}%'
                                          : 'Connecting to GitHub...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w500,
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
