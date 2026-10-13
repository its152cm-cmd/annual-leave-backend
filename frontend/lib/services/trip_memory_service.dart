import '../mock/mock_trip_memories.dart';
import '../models/trip_memory.dart';

class TripMemoryService {
  static final Map<String, TripMemory> _memoriesByTripId = {
    for (final json in mockTripMemories)
      json['trip_id'] as String: TripMemory.fromJson(json),
  };

  Future<TripMemory> getTripMemory(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _memoriesByTripId.putIfAbsent(
      tripId,
      () => TripMemory(tripId: tripId, note: '', photos: const []),
    );
  }

  Future<TripMemory> saveNote(String tripId, String note) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final memory = _getOrCreate(tripId).copyWith(note: note);
    _memoriesByTripId[tripId] = memory;
    return memory;
  }

  Future<TripMemory> addPhotos(
    String tripId,
    List<TripMemoryPhoto> photos,
  ) async {
    if (photos.isEmpty) return getTripMemory(tripId);
    await Future.delayed(const Duration(milliseconds: 150));
    final current = _getOrCreate(tripId);
    final memory = current.copyWith(photos: [...current.photos, ...photos]);
    _memoriesByTripId[tripId] = memory;
    return memory;
  }

  TripMemory _getOrCreate(String tripId) {
    return _memoriesByTripId.putIfAbsent(
      tripId,
      () => TripMemory(tripId: tripId, note: '', photos: const []),
    );
  }
}
