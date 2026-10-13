import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../mock/mock_chat_upload_files.dart';

class UploadFileModal extends StatelessWidget {
  final Function(String fileName) onFileSelected;

  const UploadFileModal({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Document or File',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...mockChatUploadFiles.map((file) {
            final isItinerary = file['style'] == 'itinerary';
            final color = isItinerary ? Colors.deepPurple : Colors.teal;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isItinerary
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_rounded,
                  color: color,
                ),
              ),
              title: Text(
                file['name']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(file['description']!),
              onTap: () {
                onFileSelected(file['message']!);
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
