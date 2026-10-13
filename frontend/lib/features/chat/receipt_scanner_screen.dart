import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../services/expense_service.dart';
import 'scanned_receipt_screen.dart';

class ReceiptScannerScreen extends StatefulWidget {
  final String groupId;

  const ReceiptScannerScreen({super.key, required this.groupId});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  static const int _maxBytes = 6 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();
  final ExpenseService _expenseService = ExpenseService();
  bool _reading = false;

  String _mimeFor(XFile file) {
    final declared = file.mimeType;
    if (declared != null && declared.startsWith('image/')) return declared;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scan(ImageSource source) async {
    if (_reading) return;
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _say("Couldn't open the photo picker.");
      return;
    }
    if (file == null || !mounted) return; // cancelled

    setState(() => _reading = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxBytes) {
        _say('That photo is too large (6 MB max). Try a smaller one.');
        return;
      }
      final receipt = await _expenseService.scanReceiptPhoto(
        groupId: widget.groupId,
        imageBase64: base64Encode(bytes),
        mimeType: _mimeFor(file),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ScannedReceiptScreen(
            groupId: widget.groupId,
            initialReceipt: receipt,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say("Couldn't read that receipt. Please try again.");
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryGreen, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 80,
                      color: Colors.white38,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Take a photo of the whole receipt\nor choose one from your gallery',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!ExpenseService.isSavedGroup(widget.groupId))
              Positioned(
                top: 70,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This is a sample chat, so the receipt shown will be sample data. '
                    'Open the group chat of one of your own trips to scan real receipts.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Positioned(
              top: 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _scan(ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.photo_library, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _scan(ImageSource.camera),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: AppTheme.primaryGreen,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(width: 80),
                ],
              ),
            ),
            if (_reading)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryGreen),
                        SizedBox(height: 16),
                        Text(
                          'Reading your receipt...',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
