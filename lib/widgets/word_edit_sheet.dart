import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/dictionary_service.dart';
import '../theme/books_modernist_style.dart';

/// Modal bottom sheet for editing an existing dictionary entry or creating
/// a brand new one. In edit mode the word itself is locked (editing the
/// headword would just create a second, disconnected entry); in create
/// mode it's the one required field alongside at least one definition.
class WordEditSheet extends StatefulWidget {
  final String? initialWord;
  final Map<String, dynamic>? initialData;
  final bool isNew;

  const WordEditSheet({
    super.key,
    this.initialWord,
    this.initialData,
    this.isNew = false,
  });

  /// Returns the saved word string on success, or null if the sheet was
  /// dismissed without saving.
  static Future<String?> show(
    BuildContext context, {
    String? word,
    Map<String, dynamic>? data,
    bool isNew = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          WordEditSheet(initialWord: word, initialData: data, isNew: isNew),
    );
  }

  @override
  State<WordEditSheet> createState() => _WordEditSheetState();
}

class _WordEditSheetState extends State<WordEditSheet> {
  final DictionaryService _dictionaryService = DictionaryService();

  late final TextEditingController _wordController;
  late final TextEditingController _ipaController;
  late final TextEditingController _imageUrlController;
  String? _pos;
  String? _gender;

  final List<TextEditingController> _definitionControllers = [];
  final List<TextEditingController> _exampleDeControllers = [];
  final List<TextEditingController> _exampleEnControllers = [];

  bool _isSaving = false;
  String? _errorText;

  static const _posOptions = [
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'preposition',
    'conjunction',
    'interjection',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    _wordController = TextEditingController(
      text: widget.initialWord ?? data?['word']?.toString() ?? '',
    );
    _ipaController = TextEditingController(text: data?['ipa']?.toString());
    _imageUrlController = TextEditingController(
      text: data?['custom_image_url']?.toString(),
    );

    final rawPos = data?['pos']?.toString().toLowerCase().trim();
    _pos = _posOptions.contains(rawPos) ? rawPos : null;

    final rawGender = data?['gender']?.toString().toLowerCase().trim();
    _gender = (rawGender == 'm' || rawGender == 'f' || rawGender == 'n')
        ? rawGender
        : null;

    final defs = (data?['definitions'] as List?) ?? [];
    for (final d in defs) {
      _definitionControllers.add(TextEditingController(text: d.toString()));
    }
    if (_definitionControllers.isEmpty) {
      _definitionControllers.add(TextEditingController());
    }

    final examples = (data?['examples'] as List?) ?? [];
    for (final ex in examples) {
      if (ex is Map) {
        _exampleDeControllers.add(
          TextEditingController(text: ex['de']?.toString() ?? ''),
        );
        _exampleEnControllers.add(
          TextEditingController(text: ex['en']?.toString() ?? ''),
        );
      }
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _ipaController.dispose();
    _imageUrlController.dispose();
    for (final c in _definitionControllers) {
      c.dispose();
    }
    for (final c in _exampleDeControllers) {
      c.dispose();
    }
    for (final c in _exampleEnControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addDefinitionField() {
    setState(() => _definitionControllers.add(TextEditingController()));
  }

  void _removeDefinitionField(int index) {
    setState(() {
      _definitionControllers.removeAt(index).dispose();
    });
  }

  void _addExampleField() {
    setState(() {
      _exampleDeControllers.add(TextEditingController());
      _exampleEnControllers.add(TextEditingController());
    });
  }

  void _removeExampleField(int index) {
    setState(() {
      _exampleDeControllers.removeAt(index).dispose();
      _exampleEnControllers.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    final word = _wordController.text.trim();
    final definitions = _definitionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (word.isEmpty) {
      setState(() => _errorText = 'Enter the German word.');
      return;
    }
    if (definitions.isEmpty) {
      setState(() => _errorText = 'Add at least one definition.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final examples = <Map<String, String?>>[];
    for (var i = 0; i < _exampleDeControllers.length; i++) {
      final de = _exampleDeControllers[i].text.trim();
      if (de.isNotEmpty) {
        examples.add({'de': de, 'en': _exampleEnControllers[i].text.trim()});
      }
    }

    final savedId = await _dictionaryService.saveUserWordEdit(
      word: word,
      pos: _pos,
      gender: _pos == 'noun' ? _gender : null,
      ipa: _ipaController.text.trim().isEmpty
          ? null
          : _ipaController.text.trim(),
      definitions: definitions,
      examples: examples,
      customImageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
    );

    if (!mounted) return;

    if (savedId == null) {
      setState(() {
        _isSaving = false;
        _errorText = 'Could not save — please try again.';
      });
      return;
    }

    Navigator.of(context).pop(word);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isNew ? 'Add New Word' : 'Edit Word',
                    style: BooksModernist.heading(
                      size: 18,
                      color: colorScheme.onSurface,
                      context: context,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel(context, 'WORD'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _wordController,
                      enabled: widget.isNew,
                      decoration: _fieldDecoration(
                        context,
                        'e.g. Gesellschaft',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildPosDropdown(context)),
                        if (_pos == 'noun') ...[
                          const SizedBox(width: 12),
                          Expanded(child: _buildGenderDropdown(context)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel(context, 'IPA (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ipaController,
                      decoration: _fieldDecoration(
                        context,
                        'e.g. /ɡəˈzɛlʃaft/',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel(context, 'DEFINITIONS'),
                    const SizedBox(height: 6),
                    ..._definitionControllers.asMap().entries.map(
                      (entry) => _buildRemovableField(
                        context,
                        controller: entry.value,
                        hint: 'Definition',
                        onRemove: _definitionControllers.length > 1
                            ? () => _removeDefinitionField(entry.key)
                            : null,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addDefinitionField,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add definition'),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionLabel(context, 'EXAMPLE SENTENCES (OPTIONAL)'),
                    const SizedBox(height: 6),
                    ..._exampleDeControllers.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: entry.value,
                                      decoration: _fieldDecoration(
                                        context,
                                        'German sentence',
                                        dense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        _removeExampleField(entry.key),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _exampleEnControllers[entry.key],
                                decoration: _fieldDecoration(
                                  context,
                                  'English translation',
                                  dense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addExampleField,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add example'),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionLabel(context, 'IMAGE URL (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _imageUrlController,
                      decoration: _fieldDecoration(context, 'https://…'),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_imageUrlController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: _imageUrlController.text.trim(),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isNew ? 'Create Word' : 'Save Changes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context,
    String hint, {
    bool dense = false,
  }) {
    return InputDecoration(
      hintText: hint,
      isDense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 10 : 14,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _buildRemovableField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: _fieldDecoration(context, hint),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  Widget _buildPosDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _pos,
      decoration: _fieldDecoration(context, 'Part of speech'),
      items: _posOptions
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(p[0].toUpperCase() + p.substring(1)),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _pos = value),
    );
  }

  Widget _buildGenderDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: _fieldDecoration(context, 'Gender'),
      items: const [
        DropdownMenuItem(value: 'm', child: Text('der (m)')),
        DropdownMenuItem(value: 'f', child: Text('die (f)')),
        DropdownMenuItem(value: 'n', child: Text('das (n)')),
      ],
      onChanged: (value) => setState(() => _gender = value),
    );
  }
}
