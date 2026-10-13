import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ChatInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onMediaTap;
  final VoidCallback? onFileTap;
  final VoidCallback? onPollTap;
  final VoidCallback? onExpensesTap;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.onMediaTap,
    this.onFileTap,
    this.onPollTap,
    this.onExpensesTap,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  bool _showAttachmentMenu = false;

  void _toggleAttachmentMenu() {
    setState(() {
      _showAttachmentMenu = !_showAttachmentMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Expandable WhatsApp-style Attachment Options Panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: _showAttachmentMenu ? 80.0 : 0.0,
          color: AppTheme.backgroundWhite,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: _showAttachmentMenu ? 1.0 : 0.0,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Media',
                      color: const Color(0xFF1E88E5),
                      onTap: () {
                        _toggleAttachmentMenu();
                        widget.onMediaTap?.call();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'File',
                      color: const Color(0xFF5E35B1),
                      onTap: () {
                        _toggleAttachmentMenu();
                        widget.onFileTap?.call();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.poll_rounded,
                      label: 'Poll',
                      color: const Color(0xFFFB8C00),
                      onTap: () {
                        _toggleAttachmentMenu();
                        widget.onPollTap?.call();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Expenses',
                      color: const Color(0xFF43A047),
                      onTap: () {
                        _toggleAttachmentMenu();
                        widget.onExpensesTap?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom Typing Bar Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.backgroundWhite,
            border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
          ),
          child: Row(
            children: [
              // Green Circular Plus (+) Button matching screenshot
              GestureDetector(
                onTap: _toggleAttachmentMenu,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _showAttachmentMenu ? 0.125 : 0.0, // Rotates to 'X' when open
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text Field Input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                    ),
                    fillColor: AppTheme.surfaceSecondary,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
              const SizedBox(width: 4),

              // Send Button
              IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
                onPressed: widget.onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}