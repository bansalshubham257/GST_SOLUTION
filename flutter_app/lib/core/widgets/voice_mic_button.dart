// lib/core/widgets/voice_mic_button.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated mic button — pulses red while listening, purple while idle.
class VoiceMicButton extends StatefulWidget {
  final bool isListening;
  final bool isInitializing;
  final VoidCallback onTap;
  final double size;
  final Color? idleColor;

  const VoiceMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.isInitializing = false,
    this.size = 44,
    this.idleColor,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ring = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(VoiceMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isListening && old.isListening) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final activeColor = Colors.red.shade600;
    final idleColor = widget.idleColor ?? AppColors.primary;

    if (widget.isInitializing) {
      return SizedBox(
        width: s,
        height: s,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          return SizedBox(
            width: s * 1.8,
            height: s * 1.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ripple ring (only when listening)
                if (widget.isListening)
                  Transform.scale(
                    scale: _ring.value,
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activeColor.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                // Button
                Transform.scale(
                  scale: widget.isListening ? _scale.value : 1.0,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      color: widget.isListening ? activeColor : idleColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isListening ? activeColor : idleColor)
                              .withOpacity(0.35),
                          blurRadius: widget.isListening ? 14 : 8,
                          spreadRadius: widget.isListening ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: s * 0.44,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Voice Status Banner ──────────────────────────────────────────────────────

/// A small listening / transcript status bar to embed in forms.
class VoiceStatusBanner extends StatelessWidget {
  final String status;
  final String transcript;
  final bool isListening;

  const VoiceStatusBanner({
    super.key,
    required this.status,
    required this.transcript,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isListening
            ? Colors.red.shade50
            : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isListening
              ? Colors.red.shade200
              : AppColors.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
            size: 18,
            color: isListening ? Colors.red.shade600 : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              transcript.isNotEmpty ? transcript : status,
              style: TextStyle(
                fontSize: 13,
                color: isListening
                    ? Colors.red.shade700
                    : AppColors.textSecondaryLight,
                fontStyle:
                    transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

