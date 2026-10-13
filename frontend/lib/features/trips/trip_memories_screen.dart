import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/trip.dart';
import '../../models/trip_memory.dart';
import '../../services/trip_service.dart';
import '../../services/trip_memory_service.dart';

class TripMemoriesScreen extends StatefulWidget {
  const TripMemoriesScreen({super.key, required this.tripId, this.initialTrip});

  final String tripId;
  final Trip? initialTrip;

  @override
  State<TripMemoriesScreen> createState() => _TripMemoriesScreenState();
}

class _TripMemoriesScreenState extends State<TripMemoriesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TripMemoryService _memoryService = TripMemoryService();
  final TextEditingController _noteController = TextEditingController();
  TripMemory? _memory;
  Timer? _noteSaveTimer;
  late final Future<({Trip trip, TripMemory memory})> _pageFuture = _loadPage();

  Future<({Trip trip, TripMemory memory})> _loadPage() async {
    final trip =
        widget.initialTrip ??
        (await TripService().getTrips()).firstWhere(
          (trip) => trip.id == widget.tripId,
        );
    final memory = await _memoryService.getTripMemory(widget.tripId);
    return (trip: trip, memory: memory);
  }

  Future<void> _addPhotos() async {
    try {
      final selectedPhotos = await _imagePicker.pickMultiImage();
      if (selectedPhotos.isEmpty || !mounted) return;
      final photos = await Future.wait(
        selectedPhotos.map(
          (photo) async => TripMemoryPhoto(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fileName: photo.name,
            imageUrl: '',
            localBytes: await photo.readAsBytes(),
          ),
        ),
      );
      if (!mounted) return;
      final memory = await _memoryService.addPhotos(widget.tripId, photos);
      if (mounted) setState(() => _memory = memory);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add photos: ${error.message ?? error.code}'),
        ),
      );
    }
  }

  void _onNoteChanged(String note) {
    _noteSaveTimer?.cancel();
    _noteSaveTimer = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_saveNote(note)),
    );
  }

  Future<void> _saveNote(String note) async {
    try {
      final memory = await _memoryService.saveNote(widget.tripId, note);
      if (mounted) setState(() => _memory = memory);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save trip note: $error')),
      );
    }
  }

  @override
  void dispose() {
    _noteSaveTimer?.cancel();
    final memory = _memory;
    if (memory != null && _noteController.text != memory.note) {
      unawaited(_saveNote(_noteController.text));
    }
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Trip memories',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<({Trip trip, TripMemory memory})>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load this trip: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Trip not found.'));
          }

          final page = snapshot.data!;
          final trip = page.trip;
          if (_memory == null) {
            _memory = page.memory;
            _noteController.text = page.memory.note;
          }
          final photos = _memory?.photos ?? const <TripMemoryPhoto>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              _TripMemoryHeader(trip: trip),
              const SizedBox(height: 24),
              const Text(
                'Your memories',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep your favourite moments from this trip together.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (photos.isEmpty)
                _EmptyPhotoCollection(onAddPhotos: _addPhotos)
              else ...[
                _PhotoGrid(photos: photos),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add more photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Trip note',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                onChanged: _onNoteChanged,
                decoration: InputDecoration(
                  hintText:
                      'Write down a favourite moment from ${trip.destination}...',
                  filled: true,
                  fillColor: const Color(0xFFF3F3F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripMemoryHeader extends StatelessWidget {
  const _TripMemoryHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              trip.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.blueGrey.shade700,
                child: const Icon(
                  Icons.landscape_rounded,
                  color: Colors.white54,
                  size: 44,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.dateRange} • ${trip.duration}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotoCollection extends StatelessWidget {
  const _EmptyPhotoCollection({required this.onAddPhotos});

  final VoidCallback onAddPhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            color: AppTheme.primaryGreen,
            size: 38,
          ),
          const SizedBox(height: 10),
          const Text(
            'No photos yet',
            style: TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAddPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add photos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});

  final List<TripMemoryPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final bytes = photo.localBytes;
        final image = bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : photo.imageUrl.isNotEmpty
            ? Image.network(
                photo.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
              )
            : const _PhotoPlaceholder();
        return ClipRRect(borderRadius: BorderRadius.circular(14), child: image);
      },
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F3F7),
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_outlined,
        color: AppTheme.primaryGreen,
        size: 36,
      ),
    );
  }
}
