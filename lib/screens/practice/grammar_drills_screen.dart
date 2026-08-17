import 'package:flutter/material.dart';
import '../../models/grammar_drill.dart';
import '../../services/grammar_drill_service.dart';
import '../../widgets/capped_width.dart';
import 'grammar_drill_sheet_list_screen.dart';

class GrammarDrillsScreen extends StatefulWidget {
  const GrammarDrillsScreen({super.key});

  @override
  State<GrammarDrillsScreen> createState() => _GrammarDrillsScreenState();
}

class _GrammarDrillsScreenState extends State<GrammarDrillsScreen> {
  final GrammarDrillService _service = GrammarDrillService();
  List<GrammarDrillTopic> _topics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.loadAssetTopics();
    if (!mounted) return;
    setState(() {
      _topics = _service.getTopics();
      _isLoading = false;
    });
  }

  IconData _iconForTopic(GrammarDrillTopicId id) {
    switch (id) {
      case GrammarDrillTopicId.verbConjugation:
        return Icons.sync_alt_rounded;
      case GrammarDrillTopicId.casesPrepositions:
        return Icons.rule_rounded;
      case GrammarDrillTopicId.pronouns:
        return Icons.person_outline_rounded;
    }
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
          'Grammar Drills',
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
                itemCount: _topics.length,
                itemBuilder: (context, index) => _buildTopicCard(context, _topics[index]),
              ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, GrammarDrillTopic topic) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheetCount = topic.sheets.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GrammarDrillSheetListScreen(topic: topic)),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(_iconForTopic(topic.id), color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topic.description,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$sheetCount ${sheetCount == 1 ? 'sheet' : 'sheets'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
