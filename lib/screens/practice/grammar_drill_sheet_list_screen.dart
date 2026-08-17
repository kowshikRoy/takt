import 'package:flutter/material.dart';
import '../../models/grammar_drill.dart';
import '../../services/grammar_drill_service.dart';
import '../../widgets/capped_width.dart';
import 'grammar_drill_sheet_screen.dart';

class GrammarDrillSheetListScreen extends StatefulWidget {
  final GrammarDrillTopic topic;

  const GrammarDrillSheetListScreen({super.key, required this.topic});

  @override
  State<GrammarDrillSheetListScreen> createState() => _GrammarDrillSheetListScreenState();
}

class _GrammarDrillSheetListScreenState extends State<GrammarDrillSheetListScreen> {
  final GrammarDrillService _service = GrammarDrillService();
  final Map<String, double?> _scores = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    setState(() => _isLoading = true);
    for (final sheet in widget.topic.sheets) {
      _scores[sheet.id] = await _service.getBestScore(sheet.id);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          widget.topic.title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: CappedWidth(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.topic.sheets.length,
                itemBuilder: (context, index) => _buildSheetTile(context, widget.topic.sheets[index]),
              ),
      ),
    );
  }

  Widget _buildSheetTile(BuildContext context, GrammarDrillSheet sheet) {
    final colorScheme = Theme.of(context).colorScheme;
    final score = _scores[sheet.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GrammarDrillSheetScreen(sheet: sheet)),
            );
            _loadScores();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sheet.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sheet.questions.length} questions',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(score * 100).round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
