import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';

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
            leading: Icon(Icons.brightness_6_rounded, color: colorScheme.onSurfaceVariant),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showThemeDialog(context, themeProvider),
          ),

          // Color Theme Selector
          ListTile(
            title: const Text('Color Palette'),
            subtitle: Text(_getColorThemeName(themeProvider.colorTheme)),
            leading: Icon(Icons.color_lens_rounded, color: colorScheme.onSurfaceVariant),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showColorThemeDialog(context, themeProvider),
          ),
          
          const Divider(indent: 16, endIndent: 16),
          
          // Font Family Selector
          ListTile(
            title: const Text('Typography'),
            subtitle: Text(themeProvider.fontFamily),
            leading: Icon(Icons.font_download_rounded, color: colorScheme.onSurfaceVariant),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showFontDialog(context, themeProvider),
          ),

          const SizedBox(height: 32),
          _buildSectionHeader(context, 'About'),
          
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
            leading: Icon(Icons.info_outline_rounded, color: colorScheme.onSurfaceVariant),
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
      case ThemeMode.system: return 'System Default';
      case ThemeMode.light: return 'Light Mode';
      case ThemeMode.dark: return 'Dark Mode';
    }
  }

  String _getColorThemeName(AppColorTheme theme) {
    switch (theme) {
      case AppColorTheme.classic: return 'Classic Red';
      case AppColorTheme.retroTeal: return 'Retro Teal';
      case AppColorTheme.retroBlue: return 'Retro Blue';
      case AppColorTheme.retroGold: return 'Retro Gold';
      case AppColorTheme.retroRust: return 'Retro Rust';
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
      case AppColorTheme.classic: return const Color(0xFFEA2A33);
      case AppColorTheme.retroTeal: return const Color(0xFF2BBAA5);
      case AppColorTheme.retroBlue: return const Color(0xFF005F73);
      case AppColorTheme.retroGold: return const Color(0xFFEE9B00);
      case AppColorTheme.retroRust: return const Color(0xFFBB3E03);
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
      'Lato'
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
                    fontWeight: FontWeight.normal
                  ).copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
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

  Widget _buildRadioOption<T>(BuildContext context, String title, T value, T groupValue, ValueChanged<T?> onChanged) {
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
