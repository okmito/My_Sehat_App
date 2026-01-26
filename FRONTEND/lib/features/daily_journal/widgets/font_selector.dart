import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontSelector extends StatelessWidget {
  final String currentFont;
  final Function(String) onFontSelected;

  const FontSelector({
    super.key,
    required this.currentFont,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fonts = ['Outfit', 'Roboto', 'Lora', 'Dancing Script', 'Caveat'];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[100],
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fonts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final fontName = fonts[index];
          final isSelected = fontName == currentFont;

          TextStyle style;
          switch (fontName) {
            case 'Roboto':
              style = GoogleFonts.roboto();
              break;
            case 'Lora':
              style = GoogleFonts.lora();
              break;
            case 'Dancing Script':
              style = GoogleFonts.dancingScript();
              break;
            case 'Caveat':
              style = GoogleFonts.caveat();
              break;
            default:
              style = GoogleFonts.outfit();
              break;
          }

          return Center(
            child: ChoiceChip(
              label: Text(fontName, style: style),
              selected: isSelected,
              onSelected: (_) => onFontSelected(fontName),
              selectedColor: Colors.orange.withOpacity(0.2),
              backgroundColor: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
