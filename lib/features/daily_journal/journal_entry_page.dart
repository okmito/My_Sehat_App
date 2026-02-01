import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'dart:io' show File;
import '../../../core/services/local_storage_service.dart';
import 'models/journal_entry_model.dart';
import 'widgets/font_selector.dart';

class JournalEntryPage extends ConsumerStatefulWidget {
  final String entryKey;

  const JournalEntryPage({super.key, required this.entryKey});

  @override
  ConsumerState<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends ConsumerState<JournalEntryPage> {
  late Box<JournalEntry> _journalBox;
  JournalEntry? _entry;
  late JournalEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );

  String _currentFont = 'Outfit';
  bool _isSketchMode = false;
  Timer? _autoSaveTimer;
  Color _penColor = Colors.black;
  double _penWidth = 3.0;
  String _brushType = "Pen";
  List<JournalDrawing> _completedStrokes = [];
  List<JournalSticker> _stickers = []; // Local mutable state for stickers
  Map<String, List<String>> _stickerCategories = {};
  bool _isLoadingStickers = false;

  // Gesture state
  double _initialScale = 1.0;
  double _initialRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = JournalEditingController();
    _controller.addListener(_onTextChanged);
    _updateSignatureController(); // Initialize and add listener
    _loadEntry();
    _indexStickers();
  }

  void _loadEntry() {
    final localStorage = ref.read(localStorageServiceProvider);
    _journalBox = localStorage.journalBox;
    _entry = _journalBox.get(widget.entryKey);

    if (_entry != null) {
      _controller.loadFromSegments(_entry!.segments);
      if (_entry!.segments.isNotEmpty) {
        _currentFont = _entry!.segments.last.fontFamily;
      }
      if (_entry!.stickers.isNotEmpty) {
        _stickers = List.from(_entry!.stickers);
      }
      if (_entry!.drawings.isNotEmpty) {
        _completedStrokes = List.from(_entry!.drawings);
        // We don't load into signature controller anymore, they are rendered by StrokesPainter
        // Just set the current pen properties from the last stroke if available (optional)
        if (_completedStrokes.isNotEmpty) {
          final last = _completedStrokes.last;
          _penColor = Color(last.color);
          _penWidth = last.strokeWidth;
          _brushType = last.brushType;
        }
        _updateSignatureController();
      }
    }
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _saveEntry);
  }

  Future<void> _saveEntry() async {
    if (_entry == null) return;

    final updatedSegments = _controller.toSegments();

    final updatedEntry = JournalEntry(
      id: _entry!.id,
      date: _entry!.date,
      segments: updatedSegments,
      isPrivate: _entry!.isPrivate,
      pin: _entry!.pin,
      stickers: _stickers,
      drawings: [
        ..._completedStrokes,
        if (_signatureController.isNotEmpty)
          JournalDrawing(
            points: _signatureController.points
                .map((p) => OffsetData(p.offset.dx, p.offset.dy))
                .toList(),
            color: _brushType == "Eraser"
                ? Colors.transparent.toARGB32()
                : _penColor.toARGB32(),
            strokeWidth: _penWidth,
            brushType: _brushType,
          )
      ],
    );

    await _journalBox.put(widget.entryKey, updatedEntry);
  }

  void _changeFont(String font) {
    setState(() {
      _currentFont = font;
      _controller.setCurrentFont(font);
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day;
    String suffix = 'th';
    if (day == 1 || day == 21 || day == 31) {
      suffix = 'st';
    } else if (day == 2 || day == 22) {
      suffix = 'nd';
    } else if (day == 3 || day == 23) {
      suffix = 'rd';
    }

    return "$day$suffix ${DateFormat('MMMM yyyy, hh:mm a').format(date)}";
  }

  Future<void> _indexStickers() async {
    setState(() => _isLoadingStickers = true);
    try {
      // Use the modern AssetManifest API which handles web/mobile differences better
      final AssetManifest assetManifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> assets = assetManifest.listAssets();

      final stickerPaths = assets
          .where((String key) =>
              key.contains('stickers/') && key.toLowerCase().endsWith('.png'))
          .toList();

      final Map<String, List<String>> categories = {};

      if (stickerPaths.isEmpty) {
        // Fallback for debugging if assets aren't found (e.g. during dev with issues)
        debugPrint("No stickers found via manifest. Using fallback list.");
        categories['Cats'] = [
          'assets/stickers/cats/aerobic.png',
          'assets/stickers/cats/angry.png',
          'assets/stickers/cats/arrogant.png',
          'assets/stickers/cats/checklist.png',
          'assets/stickers/cats/hamburger.png',
          'assets/stickers/cats/headphones.png',
          'assets/stickers/cats/love.png',
          'assets/stickers/cats/neko.png',
          'assets/stickers/cats/scratch.png',
          'assets/stickers/cats/sick.png',
          'assets/stickers/cats/smile.png',
          'assets/stickers/cats/yawn.png',
        ];
        categories['Dogs'] = [
          // Add dog stickers if available in directory, otherwise leave empty or add placeholders
        ];
        // Note: These fallback paths must actually exist to render.
        // If manifest returns empty, likely the assets aren't included in build or path is wrong.
      } else {
        for (final path in stickerPaths) {
          final parts = path.split('/');
          if (parts.length >= 3) {
            // Expecting: assets/stickers/Category/filename.png
            // parts: [assets, stickers, Category, filename.png]
            final category = parts[parts.length - 2];

            // Clean up category name
            String categoryKey = category;
            if (categoryKey.toLowerCase() == 'stickers') {
              categoryKey = "Misc";
            } else {
              categoryKey =
                  categoryKey[0].toUpperCase() + categoryKey.substring(1);
            }

            categories.putIfAbsent(categoryKey, () => []).add(path);
          } else {
            categories.putIfAbsent("Misc", () => []).add(path);
          }
        }
      }

      setState(() {
        _stickerCategories = categories;
        _isLoadingStickers = false;
      });
    } catch (e) {
      debugPrint("Error loading stickers: $e");
      // Don't leave it loading forever
      setState(() {
        _isLoadingStickers = false;
        // Fallback empty state handled by UI
      });
    }
  }

  void _showStickerPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.5,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Stickers",
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              if (_isLoadingStickers)
                const CircularProgressIndicator()
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _stickerCategories.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(entry.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                            itemCount: entry.value.length,
                            itemBuilder: (context, index) => InkWell(
                              onTap: () {
                                _addSticker(
                                    entry.value[index],
                                    MediaQuery.of(context).size.width / 2 - 50,
                                    MediaQuery.of(context).size.height / 2 -
                                        50);
                                Navigator.pop(context);
                              },
                              child: Image.asset(entry.value[index],
                                  fit: BoxFit.contain),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSticker(String path, double dx, double dy) {
    // We don't need _entry to be non-null to add to local list, but we need it for saving contextual data
    if (_entry == null) return;

    final newSticker = JournalSticker(
        assetPath: path, dx: dx, dy: dy, scale: 1.0, rotation: 0.0);
    setState(() {
      _stickers.add(newSticker);
    });
    _saveEntry();
  }

  void _updateSticker(JournalSticker oldSticker, JournalSticker newSticker) {
    final index = _stickers.indexOf(oldSticker);
    if (index != -1) {
      setState(() {
        _stickers[index] = newSticker;
      });
      _saveEntry(); // Debounce this if performance issues arise
    }
  }

  void _finishCurrentStroke() {
    if (_signatureController.isNotEmpty) {
      final points = _signatureController.points
          .map((p) => OffsetData(p.offset.dx, p.offset.dy))
          .toList();
      if (points.isNotEmpty) {
        final drawing = JournalDrawing(
          points: points,
          color: _penColor.toARGB32(),
          strokeWidth: _penWidth,
          brushType: _brushType,
        );
        setState(() {
          _completedStrokes.add(drawing);
          _signatureController.clear();
        });
        _saveEntry();
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Mocking insertion at cursor by placing as a "sticker/layer" for now
      _addSticker(image.path, 50, 300);
    }
  }

  Widget _buildBrushSelector() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Brush Tool 🖌️",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _isSketchMode = false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _brushTypeIcon(Icons.edit, "Pen"),
              _brushTypeIcon(Icons.brush, "Water"),
              _brushTypeIcon(Icons.more_horiz, "Dotted"),
              _brushTypeIcon(Icons.auto_fix_normal, "Eraser"), // Eraser Tool
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.line_weight, size: 20),
              Expanded(
                child: Slider(
                  value: _penWidth,
                  min: 1,
                  max: 20,
                  onChanged: (val) {
                    setState(() {
                      _penWidth = val;
                      // Update brush type defaults if needed, but keeping simple for now
                    });
                    _updateSignatureController();
                  },
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _colorOption(Colors.black),
                _colorOption(Colors.red),
                _colorOption(Colors.blue),
                _colorOption(Colors.green),
                _colorOption(Colors.orange),
                _colorOption(Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brushTypeIcon(IconData icon, String type) {
    final isSelected = _brushType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _brushType = type;
          // Set default widths for different brushes if desired
          if (type == "Water" && _penWidth < 5) _penWidth = 8.0;
          if (type == "Dotted" && _penWidth > 5) _penWidth = 2.0;
          if (type == "Eraser") {
            // Visual feedback for eraser mode (cursor/color) - managed by painter
            // We might want a default larger width for eraser
            if (_penWidth < 10) _penWidth = 15.0;
          }
        });
        _updateSignatureController();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: Colors.orange) : null,
            ),
            child: Icon(icon, color: isSelected ? Colors.orange : Colors.grey),
          ),
          Text(type,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _colorOption(Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _penColor = color;
          });
          _updateSignatureController();
        },
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: _penColor == color
                ? Border.all(color: Colors.orange, width: 2)
                : Border.all(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  void _updateSignatureController() {
    final points = _signatureController.isNotEmpty
        ? _signatureController.points
        : <Point>[];
    _signatureController.dispose(); // Clean up old one
    _signatureController = SignatureController(
      points: points,
      penStrokeWidth: _penWidth,
      penColor: _brushType == "Eraser"
          ? Colors.white.withValues(alpha: 0.5)
          : _penColor, // Visual feedback for eraser
      exportBackgroundColor: Colors.transparent,
    );
    _signatureController.addListener(_onTextChanged);
    // Force rebuild to ensure the new controller is picked up by the widget
    if (mounted) setState(() {});
  }

  void _showFontSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FontSelector(
        currentFont: _currentFont,
        onFontSelected: (font) {
          _changeFont(font);
          Navigator.pop(context);
        },
      ),
    );
  }

  static TextStyle getFontStyle(String fontName) {
    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.roboto(fontSize: 20, height: 1.6);
      case 'Lora':
        return GoogleFonts.lora(fontSize: 20, height: 1.6);
      case 'Dancing Script':
        return GoogleFonts.dancingScript(fontSize: 24, height: 1.4);
      case 'Caveat':
        return GoogleFonts.caveat(fontSize: 24, height: 1.4);
      default:
        return GoogleFonts.outfit(fontSize: 20, height: 1.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entry == null) {
      return const Scaffold(body: Center(child: Text("Entry not found")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Text("Tt",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            onPressed: () => _showFontSelector(),
          ),
          IconButton(
            icon: Icon(Icons.brush,
                color: _isSketchMode ? Colors.orange : Colors.black),
            onPressed: () {
              setState(() => _isSketchMode = !_isSketchMode);
              // Tools now show as overlay, no modal
            },
          ),
          IconButton(
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: () => _showStickerPanel(),
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _pickImage(),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _saveEntry(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Paper Background
          Positioned.fill(
            child: CustomPaint(
              painter: PaperPainter(),
            ),
          ),
          // Content
          SingleChildScrollView(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header - Top Left
                    Padding(
                      padding: const EdgeInsets.fromLTRB(45, 10, 20, 10),
                      child: Text(
                        _formatDate(_entry!.date),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        enabled:
                            true, // Allow typing even when drawing (optional, but requested "overlay text")
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 800), // Large scroll area
                  ],
                ),

                // Completed Strokes (History) - Rendered behind active stroke
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: StrokesPainter(_completedStrokes),
                    ),
                  ),
                ),

                // Active Sketch Overlay
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_isSketchMode,
                    child: Listener(
                      onPointerUp: (_) => _finishCurrentStroke(),
                      child: Container(
                        // Transparent container to catch touches if needed
                        color: Colors.transparent,
                        child: Signature(
                          controller: _signatureController,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Stickers & Images Overlay (Above drawing)
                ..._stickers.map((sticker) => Positioned(
                      left: sticker.dx,
                      top: sticker.dy,
                      child: _buildDraggableSticker(sticker),
                    )),
              ],
            ),
          ),

          // Floating Brush Selector Overlay
          if (_isSketchMode)
            Positioned(
              top: 20,
              right: 20,
              child: _buildBrushSelector(),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableSticker(JournalSticker sticker) {
    return GestureDetector(
      onScaleStart: (details) {
        _initialScale = sticker.scale;
        _initialRotation = sticker.rotation;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 2) {
          // Scale and Rotate
          _updateSticker(
              sticker,
              JournalSticker(
                assetPath: sticker.assetPath,
                dx: sticker.dx,
                dy: sticker.dy,
                scale: _initialScale * details.scale,
                rotation: _initialRotation + details.rotation,
              ));
        } else if (details.pointerCount == 1) {
          // Drag (Pan)
          // Use focalPointDelta for smoother dragging matching the finger
          _updateSticker(
              sticker,
              JournalSticker(
                assetPath: sticker.assetPath,
                dx: sticker.dx + details.focalPointDelta.dx,
                dy: sticker.dy + details.focalPointDelta.dy,
                scale: sticker.scale,
                rotation: sticker.rotation,
              ));
        }
      },
      child: Transform.rotate(
        angle: sticker.rotation,
        child: Transform.scale(
          scale: sticker.scale,
          child: _buildStickerImage(sticker),
        ),
      ),
    );
  }

  Widget _buildStickerImage(JournalSticker sticker) {
    if (sticker.assetPath.startsWith('assets/')) {
      return Image.asset(sticker.assetPath, width: 80, height: 80);
    } else if (kIsWeb ||
        sticker.assetPath.startsWith('http') ||
        sticker.assetPath.startsWith('blob:')) {
      // In web, the image picker returns a blob URL which works with Image.network
      return Image.network(
        sticker.assetPath,
        width: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
      );
    } else {
      // Mobile file path
      return Image.file(
        File(sticker.assetPath),
        width: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
      );
    }
  }
}

class JournalEditingController extends TextEditingController {
  String _currentFont = 'Outfit';
  List<_FontRange> _ranges = [];

  void loadFromSegments(List<JournalSegment> segments) {
    _ranges = [];
    String fullText = "";
    for (var segment in segments) {
      if (segment.type == 'text') {
        final start = fullText.length;
        fullText += segment.content;
        _ranges.add(_FontRange(segment.fontFamily, start, fullText.length));
      }
    }
    value = value.copyWith(
      text: fullText,
      selection: TextSelection.collapsed(offset: fullText.length),
    );
    if (_ranges.isNotEmpty) {
      _currentFont = _ranges.last.fontFamily;
    }
  }

  void setCurrentFont(String font) {
    _currentFont = font;
  }

  List<JournalSegment> toSegments() {
    if (text.isEmpty) return [];

    final result = <JournalSegment>[];
    _ranges.sort((a, b) => a.start.compareTo(b.start));

    int currentTextPos = 0;
    for (var range in _ranges) {
      if (range.start > currentTextPos) {
        result.add(JournalSegment(
          content: text.substring(currentTextPos, range.start),
          fontFamily: _currentFont,
          type: 'text',
        ));
      }

      final segmentEnd = range.end > text.length ? text.length : range.end;
      if (range.start < segmentEnd) {
        result.add(JournalSegment(
          content: text.substring(range.start, segmentEnd),
          fontFamily: range.fontFamily,
          type: 'text',
        ));
        currentTextPos = segmentEnd;
      }
    }

    if (currentTextPos < text.length) {
      result.add(JournalSegment(
        content: text.substring(currentTextPos),
        fontFamily: _currentFont,
        type: 'text',
      ));
    }

    return result;
  }

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<TextSpan> children = [];
    int lastPos = 0;
    _ranges.sort((a, b) => a.start.compareTo(b.start));

    for (var range in _ranges) {
      if (range.start > lastPos) {
        children.add(TextSpan(
          text: text.substring(lastPos, range.start),
          style: _JournalEntryPageState.getFontStyle(_currentFont),
        ));
      }

      final actualEnd = range.end > text.length ? text.length : range.end;
      if (range.start < actualEnd) {
        children.add(TextSpan(
          text: text.substring(range.start, actualEnd),
          style: _JournalEntryPageState.getFontStyle(range.fontFamily),
        ));
        lastPos = actualEnd;
      }
    }

    if (lastPos < text.length) {
      children.add(TextSpan(
        text: text.substring(lastPos),
        style: _JournalEntryPageState.getFontStyle(_currentFont),
      ));
    }

    return TextSpan(children: children, style: style);
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    if (newText.length > oldText.length) {
      // Text was added

      // Find the range that the new text falls into, or create a new one.
      bool extendedExistingRange = false;
      if (_ranges.isNotEmpty) {
        final lastRange = _ranges.last;
        if (lastRange.fontFamily == _currentFont) {
          _ranges[_ranges.length - 1] =
              _FontRange(_currentFont, lastRange.start, newText.length);
          extendedExistingRange = true;
        }
      }

      if (!extendedExistingRange) {
        _ranges.add(_FontRange(_currentFont, oldText.length, newText.length));
      }
    } else if (newText.length < oldText.length) {
      final int newLength = newText.length;
      _ranges = _ranges.where((r) => r.start < newLength).map((r) {
        return _FontRange(
            r.fontFamily, r.start, r.end > newLength ? newLength : r.end);
      }).toList();
    }

    super.value = newValue;
  }
}

class _FontRange {
  final String fontFamily;
  final int start;
  final int end;
  _FontRange(this.fontFamily, this.start, this.end);
}

class PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    const double lineSpacing = 32.0;
    for (double y = 60; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final marginPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.2)
      ..strokeWidth = 2.0;
    canvas.drawLine(const Offset(35, 0), Offset(35, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StrokesPainter extends CustomPainter {
  final List<JournalDrawing> strokes;

  StrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Create a transparency layer to allow eraser to work properly
    // without clearing the background paper
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.brushType == "Water") {
        paint.color = paint.color.withValues(alpha: 0.5);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      } else if (stroke.brushType == "Eraser") {
        paint.blendMode = BlendMode.clear;
        paint.color = Colors
            .transparent; // Color doesn't matter for clear, but good practice
      }

      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
      }

      if (stroke.brushType == "Dotted") {
        _drawDashedLine(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore(); // Merge the layer back onto the background
  }

  void _drawDashedLine(Canvas canvas, Path path, Paint paint) {
    final ui.PathMetrics pathMetrics = path.computeMetrics();
    for (ui.PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double nextDistance = distance + paint.strokeWidth; // Dot size
        canvas.drawPath(
          pathMetric.extractPath(distance, nextDistance),
          paint,
        );
        distance = nextDistance + paint.strokeWidth * 2; // Gap size
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokesPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
