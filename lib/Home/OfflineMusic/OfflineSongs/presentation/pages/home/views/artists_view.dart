import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:videoplayer/Utils/color.dart';

import '../../artist_page.dart';

class ArtistsView extends StatefulWidget {
  final Color color;
  final Color colortext;

  const ArtistsView({super.key, required this.color, required this.colortext});

  @override
  State<ArtistsView> createState() => _ArtistsViewState();
}

enum ArtistSort { az, za, mostSongs, leastSongs }

class _ArtistsViewState extends State<ArtistsView> {
  final _audioQuery = OnAudioQuery();
  final _search = TextEditingController();

  ArtistSort _sort = ArtistSort.az;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ArtistModel> _applySearchSort(List<ArtistModel> list) {
    final q = _search.text.trim().toLowerCase();

    var filtered = list;
    if (q.isNotEmpty) {
      filtered = list
          .where((a) => (a.artist).toLowerCase().contains(q))
          .toList();
    }

    filtered.sort((a, b) {
      final at = a.artist.toLowerCase();
      final bt = b.artist.toLowerCase();
      final ac = a.numberOfTracks ?? 0;
      final bc = b.numberOfTracks ?? 0;

      switch (_sort) {
        case ArtistSort.az:
          return at.compareTo(bt);
        case ArtistSort.za:
          return bt.compareTo(at);
        case ArtistSort.mostSongs:
          return bc.compareTo(ac);
        case ArtistSort.leastSongs:
          return ac.compareTo(bc);
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color;
    final textColor = widget.colortext;

    return Container(
      color: bg,
      child: FutureBuilder<List<ArtistModel>>(
        future: _audioQuery.queryArtists(
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                snap.error.toString(),
                style: TextStyle(color: textColor),
              ),
            );
          }

          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }

          final raw = snap.data!;
          if (raw.isEmpty) {
            return Center(
              child: Text(
                "Nothing found!",
                style: TextStyle(color: textColor.withOpacity(0.75)),
              ),
            );
          }

          final list = _applySearchSort(raw);

          return Column(
            children: [
              // ✅ Top bar (Search + Sort)

          Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _search,
                          textColor: textColor,
                          hint: "Search artists...",
                          onChanged: (_) => setState(() {}),
                          onClear: () => setState(() => _search.clear()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _SortButton(
                        label: _sortLabel(_sort),
                        onTap: () => _openSortSheet(textColor),
                      ),
                    ],
                  ),
                ),


              // ✅ Grid
              Expanded(
                child: AnimationLimiter(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0 ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,


                      childAspectRatio: 0.88,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final artist = list[index];

                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 500),
                        columnCount: 2,
                        child: SlideAnimation(
                          verticalOffset: 40,
                          child: FadeInAnimation(
                            child: _ArtistCard(
                              artist: artist,
                              textColor: textColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtistPage(
                                      artist: artist,
                                      color: Theme.of(context).colorScheme.background,
                                      colortext: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _sortLabel(ArtistSort s) {
    switch (s) {
      case ArtistSort.az:
        return "A-Z";
      case ArtistSort.za:
        return "Z-A";
      case ArtistSort.mostSongs:
        return "Most";
      case ArtistSort.leastSongs:
        return "Least";
    }
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
                selected: _sort == ArtistSort.az,
                onTap: () => setState(() => _sort = ArtistSort.az),
              ),
              _SortTile(
                title: "Z - A",
                selected: _sort == ArtistSort.za,
                onTap: () => setState(() => _sort = ArtistSort.za),
              ),
              _SortTile(
                title: "Most Songs",
                selected: _sort == ArtistSort.mostSongs,
                onTap: () => setState(() => _sort = ArtistSort.mostSongs),
              ),
              _SortTile(
                title: "Least Songs",
                selected: _sort == ArtistSort.leastSongs,
                onTap: () => setState(() => _sort = ArtistSort.leastSongs),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() => setState(() {}));
  }
}

// ---------------- UI Widgets ----------------

class _ArtistCard extends StatelessWidget {
  final ArtistModel artist;
  final Color textColor;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.artist,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final songs = artist.numberOfTracks ?? 0;

    return Material(
      color: Colors.white.withOpacity(1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(1),
                Colors.white.withOpacity(1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      QueryArtworkWidget(
                        id: artist.id,
                        type: ArtworkType.ARTIST,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: Container(
                          color: Colors.white.withOpacity(0.08),
                          child: Image.asset('assets/music_folder.png', fit: BoxFit.cover),
                        ),
                      ),
                      // overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.28),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                artist.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 6),

              // songs chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  "$songs songs",
                  style: TextStyle(
                    color: textColor.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final Color textColor;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.textColor,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 35,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
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
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColorSelect.maineColor2,
      child: Material(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
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
