import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/database/data_base_helper.dart';

/// A beautiful word flashcard widget for the swipe card stack.
///
/// Displays: image (from disk), word, transcription, translation.
/// Audio button is handled externally by SwipeCardStack overlay
/// to avoid gesture arena conflicts with pan/swipe gestures.
class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onPlayAudio;

  const WordCard({super.key, required this.word, this.onPlayAudio});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        word.photoPath != null &&
        word.photoPath!.isNotEmpty &&
        File(word.photoPath!).existsSync();

    final screenHeight = MediaQuery.of(context).size.height;
    // Динамическая высота изображения — 38% экрана, мин 180, макс 350
    final imageHeight = (screenHeight * 0.38).clamp(180.0, 350.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Image section ───────────────────────────────────
        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: Container(
              height: imageHeight,
              width: double.infinity,
              color: const Color(0xFFF8FAFF),
              child: Image.file(
                File(word.photoPath!),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: imageHeight,
                  color: const Color(0xFFF2F4F7),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 48,
                      color: Color(0xFF98A2B3),
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          // No image — beautiful placeholder with gradient + icon
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: Container(
              height: imageHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8F0FE),
                    Color(0xFFF0E6FF),
                    Color(0xFFE8F0FE),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        size: 40,
                        color: Color(0xFF2E90FA),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Text section ────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              children: [
                // Word
                Text(
                  word.displayWord,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D2939),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),

                // Transcription
                if (word.transcription.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      word.transcription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF98A2B3),
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Divider
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E7EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),

                // Translation
                Text(
                  word.translation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475467),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
