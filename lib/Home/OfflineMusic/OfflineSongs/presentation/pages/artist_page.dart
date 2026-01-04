import 'package:flutter/material.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

import '../../../../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';

class ArtistPage extends StatefulWidget {
  final ArtistModel artist;
  final Color color;
  final Color colortext;

  const ArtistPage({
    Key? key,
    required this.artist,
    required this.color,
    required this.colortext,
  }) : super(key: key);

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

enum SongSort { az, za, durationHigh, durationLow, newest, oldest }

class _ArtistPageState extends State<ArtistPage> {
  final _audio = GlobalAudioController();
  final _audioQuery = OnAudioQuery();

  List<SongModel> _songs = [];
  List<SongModel> _filtered = [];

  bool _loading = true;

  final TextEditingController _search = TextEditingController();
  SongSort _sort = SongSort.az;

  @override
  void initState() {
    super.initState();
    _getSongs();
    _search.addListener(_applyFilterSort);
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilterSort);
    _search.dispose();
    super.dispose();
  }

  Future<void> _getSongs() async {
    final songs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ARTIST_ID,
      widget.artist.id,
    );

    // remove songs less than 10 seconds
    songs.removeWhere((s) => (s.duration ?? 0) < 10000);

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });

    _applyFilterSort();
  }

  void _applyFilterSort() {
    final q = _search.text.trim().toLowerCase();

    List<SongModel> list = List<SongModel>.from(_songs);

    if (q.isNotEmpty) {
      list = list.where((s) {
        final title = (s.title).toLowerCase();
        final artist = (s.artist ?? "").toLowerCase();
        final album = (s.album ?? "").toLowerCase();
        return title.contains(q) || artist.contains(q) || album.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      final at = (a.title).toLowerCase();
      final bt = (b.title).toLowerCase();
      final ad = a.duration ?? 0;
      final bd = b.duration ?? 0;

      // dateAdded is available in SongModel (android); if null fallback
      final aa = a.dateAdded ?? 0;
      final ba = b.dateAdded ?? 0;

      switch (_sort) {
        case SongSort.az:
          return at.compareTo(bt);
        case SongSort.za:
          return bt.compareTo(at);
        case SongSort.durationHigh:
          return bd.compareTo(ad);
        case SongSort.durationLow:
          return ad.compareTo(bd);
        case SongSort.newest:
          return ba.compareTo(aa);
        case SongSort.oldest:
          return aa.compareTo(ba);
      }
    });

    if (!mounted) return;
    setState(() => _filtered = list);
  }

  String _sortLabel(SongSort s) {
    switch (s) {
      case SongSort.az:
        return "A - Z";
      case SongSort.za:
        return "Z - A";
      case SongSort.durationHigh:
        return "Long → Short";
      case SongSort.durationLow:
        return "Short → Long";
      case SongSort.newest:
        return "Newest";
      case SongSort.oldest:
        return "Oldest";
    }
  }

  IconData _sortIcon(SongSort s) {
    switch (s) {
      case SongSort.az:
        return Icons.sort_by_alpha_rounded;
      case SongSort.za:
        return Icons.sort_by_alpha_rounded;
      case SongSort.durationHigh:
        return Icons.timelapse_rounded;
      case SongSort.durationLow:
        return Icons.timelapse_rounded;
      case SongSort.newest:
        return Icons.new_releases_rounded;
      case SongSort.oldest:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.colortext;
    final bg = widget.color;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    bg.withOpacity(0.95),
                    bg.withOpacity(0.78),
                    Colors.black.withOpacity(0.65),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_ios_rounded,
                        color: textColor,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.artist.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.play_arrow_rounded,
                        color: Colors.white,
                        onTap: (_loading || _filtered.isEmpty)
                            ? null
                            : () => _audio.playSongs(_filtered, 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _ArtistArtwork(
                        artistId: widget.artist.id,
                        borderColor: textColor.withOpacity(0.18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loading
                                  ? "Loading..."
                                  : "${_songs.length} Songs",
                              style: TextStyle(
                                color: textColor.withOpacity(0.75),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ✅ Search + Sort row
                            Row(
                              children: [
                                Expanded(
                                  child: _SearchField(
                                    controller: _search,
                                    textColor: textColor,
                                    hint: "Search song / album...",
                                    onClear: () {
                                      _search.clear();
                                      _applyFilterSort();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _SortButton(
                                  textColor: textColor,
                                  icon: _sortIcon(_sort),
                                  label: _sortLabel(_sort),
                                  onTap: () => _openSortSheet(textColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ List
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : _filtered.isEmpty
                  ? Center(
                child: Text(
                  "No songs found",
                  style: TextStyle(
                    color: textColor.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final song = _filtered[index];
                  return _SongTile(
                    song: song,
                    textColor: textColor,
                    onTap: () => _audio.playSongs(_filtered, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSortSheet(Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              _SortTile(
                title: "A - Z",
                selected: _sort == SongSort.az,
                onTap: () {
                  setState(() => _sort = SongSort.az);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
              _SortTile(
                title: "Z - A",
                selected: _sort == SongSort.za,
                onTap: () {
                  setState(() => _sort = SongSort.za);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
              _SortTile(
                title: "Long → Short",
                selected: _sort == SongSort.durationHigh,
                onTap: () {
                  setState(() => _sort = SongSort.durationHigh);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
              _SortTile(
                title: "Short → Long",
                selected: _sort == SongSort.durationLow,
                onTap: () {
                  setState(() => _sort = SongSort.durationLow);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
              _SortTile(
                title: "Newest",
                selected: _sort == SongSort.newest,
                onTap: () {
                  setState(() => _sort = SongSort.newest);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
              _SortTile(
                title: "Oldest",
                selected: _sort == SongSort.oldest,
                onTap: () {
                  setState(() => _sort = SongSort.oldest);
                  _applyFilterSort();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- UI widgets ----------

class _ArtistArtwork extends StatelessWidget {
  final int artistId;
  final Color borderColor;

  const _ArtistArtwork({
    required this.artistId,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            QueryArtworkWidget(
              id: artistId,
              type: ArtworkType.ARTIST,
              artworkQuality: FilterQuality.high,
              nullArtworkWidget: Container(
                color: Colors.white.withOpacity(0.08),
                child: const Icon(Icons.person, size: 40, color: Colors.white70),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final Color textColor;

  const _SongTile({
    required this.song,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: QueryArtworkWidget(
                    id: song.id,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Container(
                      color: Colors.white.withOpacity(0.08),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${song.artist ?? "Unknown"} • ${song.album ?? "Unknown"}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withOpacity(0.6),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final Color textColor;
  final String hint;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.textColor,
    required this.hint,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor, fontSize: 13),
        cursorColor: textColor.withOpacity(0.8),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textColor.withOpacity(0.55)),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded,
              color: textColor.withOpacity(0.75), size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
            onPressed: onClear,
            icon: Icon(Icons.close_rounded,
                color: textColor.withOpacity(0.75), size: 18),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final Color textColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SortButton({
    required this.textColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SortTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(selected ? 1 : 0.75),
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: Colors.white)
          : const Icon(Icons.circle_outlined, color: Colors.white24),
    );
  }
}
