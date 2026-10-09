import 'package:material_ui/material_ui.dart';

import 'app_open_ad_manager.dart';

/// A compact native ad for use as one row inside a scrolling list.
///
/// Kept alive: a lazily built list disposes rows that scroll off screen, and
/// without this every scroll past the slot and back would request a fresh ad.
class ListNativeAd extends StatefulWidget {
  const ListNativeAd({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  State<ListNativeAd> createState() => _ListNativeAdState();
}

class _ListNativeAdState extends State<ListNativeAd>
    with AutomaticKeepAliveClientMixin {
  late final Widget _ad = AppOpenAdManager().nativeCompactWidget();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(padding: widget.padding, child: _ad);
  }
}
