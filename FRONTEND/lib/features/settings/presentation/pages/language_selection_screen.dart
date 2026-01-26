import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/language_provider.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  AppLanguage? _tempSelectedLanguage;

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(languageProvider);
    final selectedLanguage = _tempSelectedLanguage ?? currentLanguage;
    final hasChanges = _tempSelectedLanguage != null &&
        _tempSelectedLanguage != currentLanguage;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Language Selection',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Select your preferred language',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ...AppLanguage.values.map((language) {
                  final isSelected = selectedLanguage == language;
                  return _LanguageTile(
                    language: language,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _tempSelectedLanguage = language;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          // Save button that appears when language is changed
          if (hasChanges)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _saveLanguage(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _saveLanguage(BuildContext context) {
    if (_tempSelectedLanguage != null) {
      ref.read(languageProvider.notifier).setLanguage(_tempSelectedLanguage!);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Language changed to ${_tempSelectedLanguage!.displayName}',
            style: GoogleFonts.outfit(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      setState(() {
        _tempSelectedLanguage = null;
      });
    }
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.language,
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
          ),
        ),
        title: Text(
          language.displayName,
          style: GoogleFonts.outfit(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 18,
            color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
                size: 28,
              )
            : Icon(
                Icons.circle_outlined,
                color: Colors.grey[400],
                size: 28,
              ),
      ),
    );
  }
}
