import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/saved_word.dart';
import '../services/vocabulary_service.dart';
import '../theme/books_modernist_style.dart';

class EditWordDialog extends StatefulWidget {
  final Map<String, dynamic> wordData;
  final String? contextSentence;
  final VoidCallback? onSaved;

  const EditWordDialog({
    super.key,
    required this.wordData,
    this.contextSentence,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> wordData,
    String? contextSentence,
    VoidCallback? onSaved,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EditWordDialog(
        wordData: wordData,
        contextSentence: contextSentence,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EditWordDialog> createState() => _EditWordDialogState();
}

class _EditWordDialogState extends State<EditWordDialog> {
  late TextEditingController _wordController;
  late TextEditingController _defController;
  late TextEditingController _ipaController;
  late TextEditingController _noteController;

  String? _selectedGender;
  String _selectedPos = 'noun';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final word = widget.wordData['word']?.toString() ?? '';
    final defs = widget.wordData['definitions'];
    String initialDef = '';
    if (defs is List && defs.isNotEmpty) {
      initialDef = defs.first.toString();
    } else if (widget.wordData['definition'] != null) {
      initialDef = widget.wordData['definition'].toString();
    } else if (widget.wordData['primaryDefinition'] != null) {
      initialDef = widget.wordData['primaryDefinition'].toString();
    }

    _wordController = TextEditingController(text: word);
    _defController = TextEditingController(text: initialDef);
    _ipaController = TextEditingController(text: widget.wordData['ipa']?.toString() ?? '');
    _noteController = TextEditingController(text: widget.wordData['contextNote']?.toString() ?? '');

    _selectedGender = widget.wordData['gender']?.toString();
    if (_selectedGender != 'm' && _selectedGender != 'f' && _selectedGender != 'n') {
      _selectedGender = null;
    }

    final rawPos = widget.wordData['pos']?.toString().toLowerCase() ?? 'noun';
    if (rawPos.contains('verb')) {
      _selectedPos = 'verb';
    } else if (rawPos.contains('adj')) {
      _selectedPos = 'adj';
    } else if (rawPos.contains('adv')) {
      _selectedPos = 'adv';
    } else if (rawPos.contains('prep')) {
      _selectedPos = 'prep';
    } else {
      _selectedPos = 'noun';
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _defController.dispose();
    _ipaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wordText = _wordController.text.trim();
    final defText = _defController.text.trim();
    if (wordText.isEmpty || defText.isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final vocabService = VocabularyService();
      final existing = await vocabService.getSavedWordByWord(wordText);

      final updated = SavedWord(
        id: wordText.toLowerCase().trim(),
        word: wordText,
        baseForm: widget.wordData['base_form']?.toString() ?? wordText,
        pos: _selectedPos,
        gender: _selectedPos == 'noun' ? _selectedGender : null,
        primaryDefinition: defText,
        definitions: [defText],
        ipa: _ipaController.text.trim().isNotEmpty ? _ipaController.text.trim() : null,
        contextSentence: widget.contextSentence ?? existing?.contextSentence,
        sourceTitle: widget.wordData['sourceTitle']?.toString() ?? existing?.sourceTitle,
        category: existing?.category ?? VocabCategory.learning,
        source: 'user_edited',
      );

      await vocabService.upsertWord(updated);
      widget.onSaved?.call();

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    final wordText = _wordController.text.trim();
    if (wordText.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove from Study Deck?"),
        content: Text("Are you sure you want to remove '$wordText' from your Study Deck?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSaving = true);
      final vocabService = VocabularyService();
      await vocabService.removeWord(wordText);
      widget.onSaved?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            "Edit in Study Deck",
            style: BooksModernist.heading(size: 17, context: context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(
                labelText: "German Word",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _defController,
              decoration: const InputDecoration(
                labelText: "English Meaning",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPos,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Part of Speech",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'noun', child: Text("Noun")),
                      DropdownMenuItem(value: 'verb', child: Text("Verb")),
                      DropdownMenuItem(value: 'adj', child: Text("Adjective")),
                      DropdownMenuItem(value: 'adv', child: Text("Adverb")),
                      DropdownMenuItem(value: 'prep', child: Text("Preposition")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPos = val);
                    },
                  ),
                ),
                if (_selectedPos == 'noun') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedGender,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Gender / Article",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text("None")),
                        DropdownMenuItem(value: 'm', child: Text("der (m)")),
                        DropdownMenuItem(value: 'f', child: Text("die (f)")),
                        DropdownMenuItem(value: 'n', child: Text("das (n)")),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedGender = val);
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ipaController,
              decoration: const InputDecoration(
                labelText: "Pronunciation (IPA, Optional)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isSaving ? null : _delete,
          icon: Icon(Icons.delete_outline_rounded, size: 16, color: colorScheme.error),
          label: Text("Remove", style: TextStyle(color: colorScheme.error)),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Cancel"),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text("Save"),
        ),
      ],
    );
  }
}
