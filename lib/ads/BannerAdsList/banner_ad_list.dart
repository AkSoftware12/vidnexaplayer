import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_open_ad_manager.dart';
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/misc_strings.dart';

/// ✅ Common list widget: inserts a banner after every [itemsPerAd] items.
///
/// Each ad slot renders an [AdaptiveBannerAd], which owns and disposes its own
/// [BannerAd]. The previous version kept a `Map<int, BannerAd>` in the State and
/// started loads from inside `build()` — a side effect during layout, and a
/// recycled `ListView` row could mount a second `AdWidget` pointing at the same
/// already-mounted ad, which throws
/// "This AdWidget is already in the Widget tree".
class InlineBannerList<T> extends StatelessWidget {
  const InlineBannerList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.adUnitId = AdUnits.banner,
    this.itemsPerAd = 6,
    this.physics = const NeverScrollableScrollPhysics(),
    this.shrinkWrap = true,
    this.padding = EdgeInsets.zero,
    this.showSponsoredLabel = true,
  }) : assert(itemsPerAd > 0, 'itemsPerAd must be greater than zero');

  final List<T> items;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;

  final String adUnitId;
  final int itemsPerAd;

  final ScrollPhysics physics;
  final bool shrinkWrap;
  final EdgeInsets padding;
  final bool showSponsoredLabel;

  /// One ad row per [itemsPerAd] content rows.
  int get _interval => itemsPerAd + 1;

  bool _isAdIndex(int listIndex) => (listIndex + 1) % _interval == 0;

  int _adSlotFromIndex(int listIndex) => listIndex ~/ _interval;

  int _dataIndexFromListIndex(int listIndex) =>
      listIndex - (listIndex ~/ _interval);

  /// Total rows. A trailing ad with no items after it is dropped, which used to
  /// happen whenever `items.length` was an exact multiple of `itemsPerAd`.
  int get _itemCount {
    if (items.isEmpty) return 0;
    final ads = (items.length - 1) ~/ itemsPerAd;
    return items.length + ads;
  }

  Widget _adTile(int slot, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSponsoredLabel)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: Text(
                MiscStrings.t(lang, 'ads_sponsored'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              child: AdaptiveBannerAd(
                // A stable key keeps one ad per slot across rebuilds.
                key: ValueKey('inline_ad_$slot'),
                adUnitId: adUnitId,
                bare: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: _itemCount,
      itemBuilder: (context, listIndex) {
        if (_isAdIndex(listIndex)) {
          return _adTile(_adSlotFromIndex(listIndex), lang);
        }

        final dataIndex = _dataIndexFromListIndex(listIndex);
        if (dataIndex < 0 || dataIndex >= items.length) {
          return const SizedBox.shrink();
        }
        return itemBuilder(context, dataIndex, items[dataIndex]);
      },
    );
  }
}
