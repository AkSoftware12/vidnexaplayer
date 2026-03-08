import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ✅ Common list widget: Every [itemsPerAd] items ke baad banner insert
/// - Slot wise new BannerAd (no "already in widget tree" error)
/// - Works with shrinkWrap + never scroll too
class InlineBannerList<T> extends StatefulWidget {
  const InlineBannerList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.adUnitId,
    this.itemsPerAd = 6, // ✅ after how many items
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
    this.padding = EdgeInsets.zero,
    this.showSponsoredLabel = true,
  });

  final List<T> items;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;

  final String adUnitId;
  final int itemsPerAd;

  final ScrollPhysics physics;
  final bool shrinkWrap;
  final EdgeInsets padding;
  final bool showSponsoredLabel;

  @override
  State<InlineBannerList<T>> createState() => _InlineBannerListState<T>();
}

class _InlineBannerListState<T> extends State<InlineBannerList<T>> {
  final Map<int, BannerAd> _ads = {};
  final Set<int> _loading = {};

  int get _interval => widget.itemsPerAd + 1; // e.g. 6 items + 1 ad row

  bool _isAdIndex(int listIndex) => (listIndex + 1) % _interval == 0;

  int _adSlotFromIndex(int listIndex) => listIndex ~/ _interval;

  int _dataIndexFromListIndex(int listIndex) => listIndex - (listIndex ~/ _interval);

  int get _itemCount => widget.items.length + (widget.items.length ~/ widget.itemsPerAd);

  void _loadAdForSlot(int slot) {
    if (_ads.containsKey(slot) || _loading.contains(slot)) return;
    _loading.add(slot);

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner, // ✅ simple banner (safe)
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _ads[slot] = ad as BannerAd;
          _loading.remove(slot);
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loading.remove(slot);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    for (final ad in _ads.values) {
      ad.dispose();
    }
    _ads.clear();
    _loading.clear();
    super.dispose();
  }

  Widget _adTile(int slot) {
    _loadAdForSlot(slot);
    final ad = _ads[slot];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showSponsoredLabel)
            const Padding(
              padding: EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                "Sponsored",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x0A000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: ad == null
                  ? const SizedBox(height: 50)
                  : SizedBox(
                key: ValueKey('inline_ad_$slot'), // ✅ unique per slot
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: widget.key,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      itemCount: _itemCount,
      itemBuilder: (context, listIndex) {
        if (_isAdIndex(listIndex)) {
          final slot = _adSlotFromIndex(listIndex);
          return _adTile(slot);
        }

        final dataIndex = _dataIndexFromListIndex(listIndex);
        final item = widget.items[dataIndex];
        return widget.itemBuilder(context, dataIndex, item);
      },
    );
  }
}
