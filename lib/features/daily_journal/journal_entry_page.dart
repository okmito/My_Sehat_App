import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _controller = JournalEditingController();
    _controller.addListener(_onTextChanged);
    _updateSignatureController(); // Initialize and add listener
    _loadEntry();
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
      if (_entry!.drawings.isNotEmpty) {
        final existingPoints = _entry!.drawings.first.points
            .map((d) => Point(Offset(d.dx, d.dy), PointType.tap, 1.0))
            .toList();
        _signatureController = SignatureController(
          points: existingPoints,
          penStrokeWidth: _entry!.drawings.first.strokeWidth,
          penColor: Color(_entry!.drawings.first.color),
          exportBackgroundColor: Colors.transparent,
        );
        _penWidth = _entry!.drawings.first.strokeWidth;
        _penColor = Color(_entry!.drawings.first.color);
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
      stickers: _entry!.stickers,
      drawings: [
        JournalDrawing(
          points: _signatureController.points
              .map((p) => OffsetData(p.offset.dx, p.offset.dy))
              .toList(),
          color: _penColor.toARGB32(),
          strokeWidth: _penWidth,
          brushType: "Pen",
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

  void _showStickerPanel() {
    final stickerAssets = [
      'assets/stickers/cats/neko.png',
      'assets/stickers/dogs/pug.png',
      'assets/stickers/cats/love.png',
      'assets/stickers/dogs/sit.png',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          children: [
            Text("Stickers",
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: stickerAssets.length,
                itemBuilder: (context, index) => InkWell(
                  onTap: () {
                    _addSticker(stickerAssets[index], 100, 200);
                    Navigator.pop(context);
                  },
                  child: Image.asset(stickerAssets[index], fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSticker(String path, double dx, double dy) {
    if (_entry == null) return;
    final newSticker = JournalSticker(assetPath: path, dx: dx, dy: dy);
    setState(() {
      _entry!.stickers.add(newSticker);
    });
    _saveEntry();
  }

  void _moveSticker(JournalSticker sticker, Offset delta) {
    setState(() {
      final index = _entry!.stickers.indexOf(sticker);
      if (index != -1) {
        _entry!.stickers[index] = JournalSticker(
          assetPath: sticker.assetPath,
          dx: sticker.dx + delta.dx,
          dy: sticker.dy + delta.dy,
        );
      }
    });
    _saveEntry();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Mocking insertion at cursor by placing as a "sticker/layer" for now
      _addSticker(image.path, 50, 300);
    }
  }

  void _showSketchTools() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
            ],
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
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _brushTypeIcon(Icons.edit, 3.0, "Pen", setModalState),
                  _brushTypeIcon(Icons.brush, 8.0, "Water", setModalState),
                  _brushTypeIcon(
                      Icons.more_horiz, 2.0, "Dotted", setModalState),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.line_weight),
                  Expanded(
                    child: Slider(
                      value: _penWidth,
                      min: 1,
                      max: 30,
                      onChanged: (val) {
                        setState(() {
                          _penWidth = val;
                        });
                        setModalState(() {});
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
                    _colorOption(Colors.black, setModalState),
                    _colorOption(Colors.red, setModalState),
                    _colorOption(Colors.blue, setModalState),
                    _colorOption(Colors.green, setModalState),
                    _colorOption(Colors.orange, setModalState),
                    _colorOption(Colors.purple, setModalState),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text("Clear Canvas"),
                onPressed: () => setState(() => _signatureController.clear()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brushTypeIcon(
      IconData icon, double width, String label, StateSetter setModalState) {
    final isSelected = _penWidth == width;
    return InkWell(
      onTap: () {
        setState(() {
          _penWidth = width;
          _isSketchMode = true;
        });
        setModalState(() {});
        _updateSignatureController();
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: isSelected ? Colors.orange : Colors.grey[200],
            child: Icon(icon, color: isSelected ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _colorOption(Color color, StateSetter setModalState) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () {
          setState(() {
            _penColor = color;
          });
          setModalState(() {});
          _updateSignatureController();
        },
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: _penColor == color
                ? Border.all(color: Colors.orange, width: 2)
                : null,
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
      penColor: _penColor,
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
            icon: Icon(_isSketchMode ? Icons.brush : Icons.edit_note,
                color: _isSketchMode ? Colors.orange : Colors.black),
            onPressed: () {
              setState(() => _isSketchMode = !_isSketchMode);
              if (_isSketchMode) _showSketchTools();
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
                        enabled: !_isSketchMode, // Disable typing when drawing
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
                // Sketch Overlay covering the whole Column
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_isSketchMode,
                    child: Container(
                      color: _isSketchMode ? Colors.transparent : null,
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                // Stickers & Images Overlay (Above drawing)
                ..._entry!.stickers.map((sticker) => Positioned(
                      left: sticker.dx,
                      top: sticker.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            _moveSticker(sticker, details.delta),
                        child: _buildStickerImage(sticker),
                      ),
                    )),
              ],
            ),
          ),
        ],
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
