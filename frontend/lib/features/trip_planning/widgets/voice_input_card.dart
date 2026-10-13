import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Encapsulates the voice recording area, visual waveform indicator, and transcript input box.
class VoiceInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final bool isTranscribing;
  final VoidCallback? onTakeQuiz;

  const VoiceInputCard({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.onToggleRecording,
    this.isTranscribing = false,
    this.onTakeQuiz,
  });

  @override
  Widget build(BuildContext context) {
    const primaryGreen = AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: isTranscribing ? null : onToggleRecording,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isRecording ? Colors.red.shade400 : primaryGreen,
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Talk about your travel preference',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTranscribing ? 'Turning your voice into text...' : (isRecording ? 'Listening... tap to stop' : 'Tap the mic to start recording'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isRecording ? Colors.red.shade400 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Audio Waveform Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(15, (index) {
              final heights = [10.0, 18.0, 28.0, 16.0, 36.0, 22.0, 40.0, 18.0, 32.0, 24.0, 38.0, 14.0, 26.0, 18.0, 12.0];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 3.5,
                height: heights[index % heights.length],
                decoration: BoxDecoration(
                  color: isRecording ? Colors.red.shade300 : primaryGreen.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Transcript Input Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              minLines: 2,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark, height: 1.4),
              decoration: const InputDecoration(
                hintText: 'Transcript will appear here...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (onTakeQuiz != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTakeQuiz,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Not sure what to say? Take a quick quiz'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
