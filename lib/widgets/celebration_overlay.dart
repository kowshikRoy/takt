import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import '../services/profile_service.dart';

/// Wraps the app shell and reacts to celebration-worthy events (level-ups,
/// streak milestones) with a confetti burst + mascot dialog, regardless of
/// which tab is active. See design doc §5 "Celebrations".
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  const CelebrationOverlay({super.key, required this.child});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late final ConfettiController _confettiController;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _celebrate(String title, String message) {
    if (_dialogShowing) return;
    _dialogShowing = true;
    _confettiController.play();
    showDialog(
      context: context,
      builder: (ctx) => _CelebrationDialog(title: title, message: message),
    ).then((_) => _dialogShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GamificationService, ProfileService>(
      builder: (context, gamification, profile, _) {
        if (gamification.justLeveledUp) {
          gamification.acknowledgeLevelUp();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _celebrate('Level Up!', "You've reached Level ${gamification.level}!");
          });
        }
        if (profile.justHitStreakXpMilestone) {
          profile.acknowledgeStreakMilestone();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _celebrate('Streak Milestone!', '${profile.currentStreak} days in a row. Keep it going!');
          });
        }

        return Stack(
          children: [
            widget.child,
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 28,
                  maxBlastForce: 22,
                  minBlastForce: 10,
                  gravity: 0.25,
                  colors: const [Colors.amber, Colors.pinkAccent, Colors.lightBlueAccent, Colors.greenAccent],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CelebrationDialog extends StatelessWidget {
  final String title;
  final String message;

  const _CelebrationDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/cat.png', width: 72, height: 72)
              .animate()
              .scale(duration: 450.ms, curve: Curves.elasticOut, begin: const Offset(0.3, 0.3)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nice!'),
          ),
        ),
      ],
    );
  }
}
