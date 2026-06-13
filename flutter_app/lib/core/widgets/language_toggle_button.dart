// lib/core/widgets/language_toggle_button.dart
//
// A reusable language toggle that reads/writes the global [appLanguageProvider].
// Drop it anywhere — changes propagate to all voice features automatically.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

// ─── Compact pill toggle (used in AppBar) ────────────────────────────────────

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isHindi = lang == AppLanguage.hindi;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(appLanguageProvider.notifier).state =
              isHindi ? AppLanguage.english : AppLanguage.hindi;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHindi
                ? const Color(0xFFFF6B35).withOpacity(0.12)
                : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHindi
                  ? const Color(0xFFFF6B35).withOpacity(0.5)
                  : AppColors.primary.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isHindi ? '🇮🇳' : '🇬🇧',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                isHindi ? 'हि' : 'EN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isHindi
                      ? const Color(0xFFFF6B35)
                      : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Expanded language selector card (used on Dashboard) ─────────────────────

class VoiceLanguageCard extends ConsumerWidget {
  const VoiceLanguageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mic_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Language',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Used for all voice inputs in the app',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Segmented toggle — EN | हिंदी
          _SegmentedLangToggle(
            current: lang,
            onChanged: (l) =>
                ref.read(appLanguageProvider.notifier).state = l,
          ),
        ],
      ),
    );
  }
}

// ─── Inline Language Row (used inside voice-fill bottom sheets) ──────────────
/// A compact labeled language selector: "🌐 Voice Language  [🇬🇧 EN] [🇮🇳 हि]"
/// Drop inside any voice sheet to give per-sheet language control.
class VoiceLanguageRow extends ConsumerWidget {
  const VoiceLanguageRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.language_rounded,
              size: 16, color: AppColors.textSecondaryLight),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Voice Language',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          // Segmented EN / हि selector
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: AppLanguage.values.map((l) {
                final selected = l == lang;
                final isHindi = l == AppLanguage.hindi;
                return GestureDetector(
                  onTap: () =>
                      ref.read(appLanguageProvider.notifier).state = l,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isHindi
                              ? const Color(0xFFFF6B35)
                              : AppColors.primary)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      isHindi ? '🇮🇳 हि' : '🇬🇧 EN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}


class _SegmentedLangToggle extends StatelessWidget {
  final AppLanguage current;
  final ValueChanged<AppLanguage> onChanged;

  const _SegmentedLangToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppLanguage.values.map((lang) {
          final isSelected = lang == current;
          return GestureDetector(
            onTap: () => onChanged(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang == AppLanguage.hindi ? '🇮🇳' : '🇬🇧',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lang.shortLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? (lang == AppLanguage.hindi
                              ? const Color(0xFFFF6B35)
                              : AppColors.primary)
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

