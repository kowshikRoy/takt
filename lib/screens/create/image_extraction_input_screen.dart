import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../models/image_extraction_result.dart';
import '../../services/gemini_api_key_store.dart';
import '../../services/gemini_vision_service.dart';
import '../../widgets/capped_width.dart';
import 'image_extraction_review_screen.dart';

class ImageExtractionInputScreen extends StatefulWidget {
  const ImageExtractionInputScreen({super.key});

  @override
  State<ImageExtractionInputScreen> createState() => _ImageExtractionInputScreenState();
}

class _ImageExtractionInputScreenState extends State<ImageExtractionInputScreen> {
  final TextEditingController _urlController = TextEditingController();

  Uint8List? _pickedImageBytes;
  String? _pickedMimeType;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    setState(() => _errorMessage = null);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? (file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      setState(() {
        _pickedImageBytes = bytes;
        _pickedMimeType = mimeType;
        _urlController.clear();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not pick image: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    setState(() => _errorMessage = null);
    try {
      final reader = await ClipboardReader.readClipboard();
      Uint8List? bytes;
      String mimeType = 'image/png';
      if (reader.canProvide(Formats.png)) {
        await reader.getFile(Formats.png, (file) async {
          bytes = await file.readAll();
        });
        mimeType = 'image/png';
      } else if (reader.canProvide(Formats.jpeg)) {
        await reader.getFile(Formats.jpeg, (file) async {
          bytes = await file.readAll();
        });
        mimeType = 'image/jpeg';
      } else if (reader.canProvide(Formats.webp)) {
        await reader.getFile(Formats.webp, (file) async {
          bytes = await file.readAll();
        });
        mimeType = 'image/webp';
      } else if (reader.canProvide(Formats.gif)) {
        await reader.getFile(Formats.gif, (file) async {
          bytes = await file.readAll();
        });
        mimeType = 'image/gif';
      }

      if (bytes == null) {
        // Fallback: check if standard system clipboard has a text URL/data URI or image link copied
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.trim().startsWith('http')) {
          _urlController.text = data.text!.trim();
          setState(() {});
          return;
        }
        setState(() => _errorMessage = 'No image found on clipboard. You can also tap "Choose Photo from Gallery" below.');
        return;
      }
      setState(() {
        _pickedImageBytes = bytes;
        _pickedMimeType = mimeType;
        _urlController.clear();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not read the clipboard: $e');
    }
  }

  void _clearPickedImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedMimeType = null;
    });
  }

  bool get _canSubmit =>
      !_isLoading && (_pickedImageBytes != null || _urlController.text.trim().isNotEmpty);

  Future<void> _analyze() async {
    final apiKey = await GeminiApiKeyStore.getKey();
    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a Gemini API key in Settings to use this feature.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List imageBytes;
      String mimeType;
      if (_pickedImageBytes != null) {
        imageBytes = _pickedImageBytes!;
        mimeType = _pickedMimeType ?? 'image/png';
      } else {
        final fetched = await GeminiVisionService.fetchImageBytes(_urlController.text.trim());
        imageBytes = fetched.$1;
        mimeType = fetched.$2;
      }

      final ImageExtractionResult? result = await GeminiVisionService.analyzeImage(
        imageBytes: imageBytes,
        mimeType: mimeType,
        apiKey: apiKey,
      );

      if (!mounted) return;
      if (result == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not find any German learning content in this image.';
        });
        return;
      }

      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImageExtractionReviewScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Analysis failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Import from Image',
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: CappedWidth(
            maxWidth: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste a photo or screenshot of a vocabulary list, textbook page, '
                    'grammar table, dialogue, or notes — Gemini will pull out vocabulary '
                    'and reading content for you.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Paste Image from Clipboard'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Choose Photo from Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  if (_pickedImageBytes != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(_pickedImageBytes!, fit: BoxFit.contain),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded),
                          color: colorScheme.surface,
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: _isLoading ? null : _clearPickedImage,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colorScheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: colorScheme.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _urlController,
                    enabled: !_isLoading && _pickedImageBytes == null,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Paste an image URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: TextStyle(color: colorScheme.error, fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _analyze : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Analyzing image with Gemini...'),
                              ],
                            )
                          : const Text('Analyze Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
