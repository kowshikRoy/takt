import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/matching_pairs_service.dart';
import '../../services/sound_service.dart';
import '../../services/haptic_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/capped_width.dart';

enum _Side { left, right }

class _Tile {
  final String pairId;
  final String text;

  const _Tile({required this.pairId, required this.text});
}

class MatchingPairsPracticeScreen extends StatefulWidget {
  const MatchingPairsPracticeScreen({super.key});

  @override
  State<MatchingPairsPracticeScreen> createState() => _MatchingPairsPracticeScreenState();
}

class _MatchingPairsPracticeScreenState extends State<MatchingPairsPracticeScreen> {
  final MatchingPairsService _service = MatchingPairsService();

  List<MatchingPairWord> _pairs = [];
  List<_Tile> _leftTiles = [];
  List<_Tile> _rightTiles = [];

  String? _selectedLeftId;
  String? _selectedRightId;
  final Set<String> _matchedPairIds = {};
  String? _errorLeftId;
  String? _errorRightId;

  int _mistakeCount = 0;
  int _matchAttempts = 0;
  bool _isLoading = true;
  bool _isSessionCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  Future<void> _loadRound() async {
    setState(() => _isLoading = true);
    final pairs = await _service.buildRound();
    if (!mounted) return;

    // Each pair's German/English side is keyed by the pair's index so a
    // pairId uniquely identifies "this specific pair", not just its text —
    // safe even if two rounds happened to share a word.
    final random = Random();
    final left = <_Tile>[
      for (var i = 0; i < pairs.length; i++) _Tile(pairId: 'pair_$i', text: pairs[i].german),
    ]..shuffle(random);
    final right = <_Tile>[
      for (var i = 0; i < pairs.length; i++) _Tile(pairId: 'pair_$i', text: pairs[i].english),
    ]..shuffle(random);

    setState(() {
      _pairs = pairs;
      _leftTiles = left;
      _rightTiles = right;
      _selectedLeftId = null;
      _selectedRightId = null;
      _matchedPairIds.clear();
      _errorLeftId = null;
      _errorRightId = null;
      _mistakeCount = 0;
      _matchAttempts = 0;
      _isSessionCompleted = false;
      _isLoading = false;
    });
  }

  void _onTileTap(_Side side, _Tile tile) {
    if (_matchedPairIds.contains(tile.pairId)) return;
    if (_errorLeftId != null || _errorRightId != null) return; // ignore taps mid error-flash

    AppHaptics.selection();

    setState(() {
      if (side == _Side.left) {
        _selectedLeftId = tile.pairId;
      } else {
        _selectedRightId = tile.pairId;
      }
    });

    if (_selectedLeftId != null && _selectedRightId != null) {
      _resolveSelection();
    }
  }

  void _resolveSelection() {
    _matchAttempts++;
    final isMatch = _selectedLeftId == _selectedRightId;

    if (isMatch) {
      SoundService().playCorrect();
      AppHaptics.success();
      setState(() {
        _matchedPairIds.add(_selectedLeftId!);
        _selectedLeftId = null;
        _selectedRightId = null;
      });
      if (_matchedPairIds.length == _pairs.length) {
        _completeSession();
      }
    } else {
      _mistakeCount++;
      SoundService().playIncorrect();
      AppHaptics.error();
      setState(() {
        _errorLeftId = _selectedLeftId;
        _errorRightId = _selectedRightId;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() {
          _errorLeftId = null;
          _errorRightId = null;
          _selectedLeftId = null;
          _selectedRightId = null;
        });
      });
    }
  }

  void _completeSession() {
    SoundService().playLevelUp();
    ProfileService().recordActivityToday(review: true);
    setState(() => _isSessionCompleted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CappedWidth(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isSessionCompleted
                  ? _buildCompletionScreen(context)
                  : Column(
                      children: [
                        _buildHeader(context),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'MATCH UP',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap a German word, then its English meaning.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: _leftTiles
                                            .map((t) => _buildTile(context, _Side.left, t))
                                            .toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: _rightTiles
                                            .map((t) => _buildTile(context, _Side.right, t))
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _Side side, _Tile tile) {
    final isMatched = _matchedPairIds.contains(tile.pairId);
    final isSelected = side == _Side.left
        ? _selectedLeftId == tile.pairId
        : _selectedRightId == tile.pairId;
    final isError = side == _Side.left
        ? _errorLeftId == tile.pairId
        : _errorRightId == tile.pairId;

    Color background = Theme.of(context).cardColor;
    Color border = Theme.of(context).dividerColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;
    double borderWidth = 1;

    if (isMatched) {
      background = Colors.green[50]!;
      border = Colors.green;
      textColor = Colors.green[800]!;
    } else if (isError) {
      background = Colors.red[50]!;
      border = Colors.red;
      textColor = Colors.red[800]!;
      borderWidth = 2;
    } else if (isSelected) {
      background = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
      border = Theme.of(context).colorScheme.primary;
      borderWidth = 2;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: isMatched ? null : () => _onTileTap(side, tile),
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 56),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border, width: borderWidth),
            ),
            child: Text(
              tile.text,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final double progress = _pairs.isEmpty ? 0 : _matchedPairIds.length / _pairs.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-8, 0),
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 24,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                color: Theme.of(context).colorScheme.primary,
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              '${_matchedPairIds.length}/${_pairs.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(BuildContext context) {
    final int accuracy = _matchAttempts == 0
        ? 100
        : ((_pairs.length / _matchAttempts) * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'Board Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You matched all ${_pairs.length} pairs.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_mistakeCount',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mistakes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  Column(
                    children: [
                      Text(
                        '$accuracy%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accuracy',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loadRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text(
                  'Practice Again',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
