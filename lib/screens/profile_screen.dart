
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Matrix Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Joined December 2025',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrowthCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(color: (isDark ? Colors.black : Colors.black).withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(context, 'M', 0.3),
                _buildBar(context, 'T', 0.5),
                _buildBar(context, 'W', 0.4),
                _buildBar(context, 'T', 0.75, isFaint: true),
                _buildBar(context, 'F', 0.9, isToday: true),
                _buildBar(context, 'S', 0.1),
                _buildBar(context, 'S', 0.1),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Words', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('124', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onBackground)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total XP', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('3,450', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onBackground)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, double heightPct, {bool isFaint = false, bool isToday = false}) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isToday)
          Text(day, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 10))
        else
          Text(day, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.0), fontSize: 10)),
        
        const SizedBox(height: 4),
        
        Container(
          width: 36,
          height: 80 * heightPct,
          decoration: BoxDecoration(
            color: isToday 
                ? theme.primaryColor 
                : (isFaint ? theme.primaryColor.withValues(alpha: 0.4) : theme.dividerColor),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            boxShadow: isToday ? [
              BoxShadow(
                 color: theme.primaryColor.withValues(alpha: 0.4),
                 blurRadius: 15,
                 spreadRadius: 0,
              )
            ] : null,
          ),
          child: isToday ? Stack(
            clipBehavior: Clip.none,
            children: [
               Positioned(
                 top: -3,
                 left: 0, right: 0,
                 child: Center(child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
               )
            ],
          ) : null,
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentMode = themeProvider.themeMode;
    final theme = Theme.of(context);

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
        children: [
          _buildThemeOption(context, 'System', ThemeMode.system, currentMode, themeProvider),
          Divider(height: 1, color: theme.dividerColor),
          _buildThemeOption(context, 'Light Mode', ThemeMode.light, currentMode, themeProvider),
          Divider(height: 1, color: theme.dividerColor),
          _buildThemeOption(context, 'Dark Mode', ThemeMode.dark, currentMode, themeProvider),
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
