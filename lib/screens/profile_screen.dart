import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/vocabulary_service.dart';
import '../services/profile_service.dart';
import '../services/gamification_service.dart';
import '../widgets/capped_width.dart';
import '../widgets/charts/modernist_vocab_chart.dart';
import '../widgets/charts/srs_retention_matrix_card.dart';
import '../widgets/charts/modernist_activity_heatmap.dart';
import '../l10n/app_localizations.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inkColor = isDark ? const Color(0xFFEDE8E1) : const Color(0xFF1E1B18);
    final cardBg = isDark ? const Color(0xFF221E1A) : const Color(0xFFF2EEE7);
    final rustAccent = isDark ? const Color(0xFFE05338) : const Color(0xFF8C2D19);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CappedWidth(
          maxWidth: 700,
          child: Consumer3<ProfileService, VocabularyService, GamificationService>(
            builder: (context, profileService, vocabService, gamification, _) {
              final words = vocabService.cachedSavedWords;

              if (profileService.justUsedStreakFreeze) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  profileService.acknowledgeStreakFreezeUsed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Image.asset(
                            'assets/images/cat.png',
                            width: 32,
                            height: 32,
                          ).animate().scale(
                            duration: 350.ms,
                            curve: Curves.elasticOut,
                            begin: const Offset(0.4, 0.4),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Streak Freeze used! Your streak is safe. ❄️',
                            ),
                          ),
                        ],
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                });
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Identity Header
                    _buildHeroHeader(context, profileService, gamification, inkColor, cardBg, rustAccent),
                    const SizedBox(height: 16),

                    // 2. 3 Quick Stat Metric Cards (Streak, Words Saved, Mastered)
                    _buildStatGrid(context, profileService, vocabService, inkColor, cardBg, rustAccent),
                    const SizedBox(height: 16),

                    // 3. Vocabulary Growth Interactive Graph
                    ModernistVocabChart(
                      savedWords: words,
                      accentColor: rustAccent,
                    ),
                    const SizedBox(height: 16),

                    // 4. Memory Retention (SRS) Breakdown
                    SrsRetentionMatrixCard(savedWords: words),
                    const SizedBox(height: 16),

                    // 5. 12-Week Activity Heatmap (GitHub Green Style & Full Width)
                    ModernistActivityHeatmap(
                      words: words,
                      activityDates: profileService.activityDates,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    ProfileService profileService,
    GamificationService gamification,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    final photoUrl = profileService.photoUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (Navigator.canPop(context)) ...[
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: inkColor),
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
          ],

          // Avatar with ring
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: rustAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              image: DecorationImage(
                image: (photoUrl != null &&
                        photoUrl.trim().isNotEmpty &&
                        photoUrl.startsWith('http'))
                    ? NetworkImage(photoUrl) as ImageProvider
                    : const AssetImage('assets/images/profile.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // User Info & Badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Level Badge + CEFR Badge + Display Name
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Level Circle Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rustAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: rustAccent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'LEVEL ${gamification.level}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: rustAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // CEFR Badge
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showLevelDialog(context, profileService),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: rustAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'CEFR ${profileService.targetLevel}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Display Name
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profileService.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: inkColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Name',
                          onPressed: () => _showEditNameDialog(context, profileService),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Join date
                Text(
                  profileService.joinDateFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    color: inkColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Settings Action Button
          IconButton(
            icon: Icon(Icons.settings_outlined, color: inkColor.withValues(alpha: 0.8)),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(
    BuildContext context,
    ProfileService profileService,
    VocabularyService vocabService,
    Color inkColor,
    Color cardBg,
    Color rustAccent,
  ) {
    final l10n = AppLocalizations.of(context);
    final curStreak = profileService.currentStreak;
    final savedCount = vocabService.cachedSavedCount;
    final masteredCount = vocabService.masteredCount;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Streak Card
          Expanded(
            child: _buildMetricCard(
              context,
              value: '$curStreak',
              suffix: profileService.streakFreezes > 0 ? ' ❄️' : '',
              label: l10n?.labelStreak.toUpperCase() ?? 'STREAK',
              color: const Color(0xFFD97706),
              cardBg: cardBg,
              inkColor: inkColor,
            ),
          ),
          const SizedBox(width: 8),

          // 2. Words Saved
          Expanded(
            child: _buildMetricCard(
              context,
              value: '$savedCount',
              label: l10n?.labelWordsSaved.toUpperCase() ?? 'WORDS SAVED',
              color: rustAccent,
              cardBg: cardBg,
              inkColor: inkColor,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Mastered
          Expanded(
            child: _buildMetricCard(
              context,
              value: '$masteredCount',
              label: l10n?.labelMastered.toUpperCase() ?? 'MASTERED',
              color: const Color(0xFF2C5E3B),
              cardBg: cardBg,
              inkColor: inkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String value,
    String suffix = '',
    required String label,
    required Color color,
    required Color cardBg,
    required Color inkColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: inkColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 26,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  if (suffix.isNotEmpty)
                    Text(
                      suffix,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 24,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  height: 1.15,
                  color: inkColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showEditNameDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
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

  void _showLevelDialog(
    BuildContext context,
    ProfileService profileService,
  ) {
    final levels = [
      ('A1', 'Beginner', 'Basic everyday phrases and essential vocabulary'),
      ('A2', 'Elementary', 'Routine conversations and simple descriptive language'),
      ('B1', 'Intermediate', 'Connected texts, expressions, and nuanced topics'),
      ('B2', 'Upper Intermediate', 'Complex texts, abstract ideas, and fluent speech'),
      ('C1', 'Advanced', 'Specialized domain vocabulary, idioms, and subtle nuance'),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('German Proficiency Level'),
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
