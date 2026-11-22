import 'dart:typed_data';

/// Inverted index hash -> times for one episode, built once and reused by
/// every template and every pair.
///
/// Open addressing over a [Uint64List] of keys, then the times of each
/// hash packed in one [Uint32List] (CSR layout: [_offsets] has one more
/// entry than there are distinct hashes). Times keep the landmark order,
/// so votes come out in the same order as with the old map of lists.
///
/// A hash seen more than [maxHits] times keeps its count but no times.
class OlafHashIndex {
  OlafHashIndex._(
    this._keys,
    this._slots,
    this._mask,
    this._counts,
    this._offsets,
    this._times,
    this._entries,
    this.maxHits,
  );

  /// [hashAt] and [timeAt] are read for `0 <= i < count`, in that order.
  factory OlafHashIndex.build(
    int count, {
    required int Function(int index) hashAt,
    required int Function(int index) timeAt,
    required int maxHits,
  }) {
    var capacity = 16;
    while (capacity < count * 2) {
      capacity <<= 1;
    }
    final mask = capacity - 1;
    final keys = Uint64List(capacity);
    final slots = Int32List(capacity);
    final entries = Int32List(count);
    final counts = Int32List(count);
    var distinct = 0;
    for (var i = 0; i < count; i++) {
      final hash = hashAt(i);
      var slot = _mix(hash) & mask;
      while (true) {
        final id = slots[slot];
        if (id == 0) {
          keys[slot] = hash;
          slots[slot] = ++distinct;
          entries[i] = distinct - 1;
          break;
        }
        if (keys[slot] == hash) {
          entries[i] = id - 1;
          break;
        }
        slot = (slot + 1) & mask;
      }
      counts[entries[i]]++;
    }
    final offsets = Int32List(distinct + 1);
    for (var id = 0; id < distinct; id++) {
      final n = counts[id];
      offsets[id + 1] = offsets[id] + (n > maxHits ? 0 : n);
    }
    final times = Uint32List(offsets[distinct]);
    final cursor = Int32List.fromList(offsets.sublist(0, distinct));
    for (var i = 0; i < count; i++) {
      final id = entries[i];
      if (counts[id] > maxHits) continue;
      times[cursor[id]++] = timeAt(i);
    }
    return OlafHashIndex._(
      keys,
      slots,
      mask,
      Int32List.sublistView(counts, 0, distinct),
      offsets,
      times,
      entries,
      maxHits,
    );
  }

  final Uint64List _keys;
  final Int32List _slots;
  final int _mask;
  final Int32List _counts;
  final Int32List _offsets;
  final Uint32List _times;
  final Int32List _entries;
  final int maxHits;

  /// Times of hashes that may vote, all lists concatenated.
  Uint32List get times => _times;

  bool get isEmpty => _times.isEmpty;

  /// Id of [hash], or -1 when the episode does not contain it.
  int find(int hash) {
    var slot = _mix(hash) & _mask;
    while (true) {
      final id = _slots[slot];
      if (id == 0) return -1;
      if (_keys[slot] == hash) return id - 1;
      slot = (slot + 1) & _mask;
    }
  }

  /// Id of the hash of landmark [index], without a lookup.
  int idOfLandmark(int index) => _entries[index];

  int countOf(int id) => _counts[id];

  /// Times of [id] are `times[start(id)]` up to `times[end(id)]`, exclusive.
  int start(int id) => _offsets[id];

  int end(int id) => _offsets[id + 1];

  /// Bytes held by the typed arrays.
  int get sizeInBytes =>
      _keys.lengthInBytes +
      _slots.lengthInBytes +
      _counts.lengthInBytes +
      _offsets.lengthInBytes +
      _times.lengthInBytes +
      _entries.lengthInBytes;

  static int _mix(int hash) {
    final h = (hash ^ (hash >>> 31)) * 0x9E3779B97F4A7C15;
    return h ^ (h >>> 29);
  }
}
