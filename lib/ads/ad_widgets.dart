// Screen par ads dikhane wale widgets.
//
// HybridAdSlot: pool se turant ad leta hai. Ad nahi hai to house ad / placeholder
// dikhata hai, aur ad aate hi badal deta hai. Sequence: NATIVE -> BANNER -> HOUSE
// (pehli Kotlin app jaisa).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_config.dart';
import 'view_ad_pools.dart';

class _SlotContent {
  NativeAd? native;
  BannerAd? banner;
  HouseAd? house;

  bool get isReal => native != null || banner != null;

  void dispose() {
    native?.dispose();
    banner?.dispose();
    native = null;
    banner = null;
  }
}

/// List/feed ke liye: scroll karke wapas aane par wahi ad dikhe, naya na kha jaye.
/// Screen ke State.dispose() mein controller.dispose() zaroor call karo.
class FeedAdController {
  final Map<Object, _SlotContent> _cache = {};

  void dispose() {
    for (final c in _cache.values) {
      c.dispose();
    }
    _cache.clear();
  }
}

class HybridAdSlot extends StatefulWidget {
  const HybridAdSlot({
    super.key,
    this.sequence,
    this.templateType = TemplateType.medium,
    this.controller,
    this.slotKey,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// null = AdConfig.nativeSequence
  final List<AdKind>? sequence;
  final TemplateType templateType;
  final FeedAdController? controller;
  final Object? slotKey;
  final EdgeInsets padding;

  @override
  State<HybridAdSlot> createState() => _HybridAdSlotState();
}

class _HybridAdSlotState extends State<HybridAdSlot> {
  _SlotContent _content = _SlotContent();
  bool _done = false;
  Timer? _timeout;
  final List<ValueNotifier<int>> _listening = [];

  List<AdKind> get _seq => widget.sequence ?? Ads.config.nativeSequence;
  bool get _usesCache => widget.controller != null && widget.slotKey != null;

  @override
  void initState() {
    super.initState();
    if (!Ads.config.adsAllowed) {
      _done = true;
      return;
    }
    if (_usesCache) {
      final cache = widget.controller!._cache;
      final cached = cache[widget.slotKey!];
      if (cached != null) {
        _content = cached;
        if (cached.isReal) {
          _done = true;
          return;
        }
      } else {
        cache[widget.slotKey!] = _content;
      }
    }

    if (_tryTake()) {
      _done = true;
      return;
    }

    // Abhi koi ad ready nahi: house ad placeholder + pools ko suno
    if (_seq.contains(AdKind.house)) _content.house ??= Ads.nextHouseAd();
    for (final kind in _seq) {
      final n = _notifierFor(kind);
      if (n != null) {
        n.addListener(_onPoolChanged);
        _listening.add(n);
      }
    }
    _timeout = Timer(Duration(milliseconds: Ads.config.nativeWaitMs), () {
      _tryTake();
      _finish();
    });
  }

  ValueNotifier<int>? _notifierFor(AdKind kind) {
    switch (kind) {
      case AdKind.native:
        return NativeAdPool.of(widget.templateType).available;
      case AdKind.banner:
        return BannerAdPool.instance.available;
      case AdKind.house:
        return null;
    }
  }

  /// Sequence ke order mein pehla ready ad lo.
  bool _tryTake() {
    for (final kind in _seq) {
      switch (kind) {
        case AdKind.native:
          final ad = NativeAdPool.of(widget.templateType).take();
          if (ad != null) {
            _content.native = ad;
            return true;
          }
          break;
        case AdKind.banner:
          final ad = BannerAdPool.instance.take();
          if (ad != null) {
            _content.banner = ad;
            return true;
          }
          break;
        case AdKind.house:
          break;
      }
    }
    return false;
  }

  bool _checkPending = false;

  // Pool ka notifier kisi dusre widget ke build ke beech bhi badal sakta hai,
  // isliye kaam microtask mein (build ke baad) karte hain.
  void _onPoolChanged() {
    if (_checkPending) return;
    _checkPending = true;
    scheduleMicrotask(() {
      _checkPending = false;
      if (!mounted || _done) return;
      if (_tryTake()) _finish();
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _timeout?.cancel();
    for (final n in _listening) {
      n.removeListener(_onPoolChanged);
    }
    _listening.clear();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timeout?.cancel();
    for (final n in _listening) {
      n.removeListener(_onPoolChanged);
    }
    if (!_usesCache) _content.dispose();
    super.dispose();
  }

  double get _nativeHeight => widget.templateType == TemplateType.small ? 120 : 330;

  @override
  Widget build(BuildContext context) {
    final c = _content;
    Widget? child;

    if (c.native != null) {
      child = SizedBox(height: _nativeHeight, child: AdWidget(ad: c.native!));
    } else if (c.banner != null) {
      final s = c.banner!.size;
      // heightFactor: a plain Center expands to all the height it's offered,
      // which in a Scaffold.bottomNavigationBar is the whole screen.
      child = Center(
        heightFactor: 1,
        child: SizedBox(
          width: s.width.toDouble(),
          height: s.height.toDouble(),
          child: AdWidget(ad: c.banner!),
        ),
      );
    } else if (c.house != null) {
      child = HouseAdCard(ad: c.house!, compact: widget.templateType == TemplateType.small);
    } else if (!_done) {
      // Jagah pehle se reserve, taaki ad aane par layout na kude
      final bannerFirst = _seq.isNotEmpty && _seq.first == AdKind.banner;
      final h = bannerFirst
          ? (BannerAdPool.instance.size?.height.toDouble() ?? 50)
          : _nativeHeight;
      child = Container(
        height: h,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    if (child == null) return const SizedBox.shrink();
    return Padding(padding: widget.padding, child: child);
  }
}

/// Screen ke neeche fixed banner. Banner na mile to native(small), phir house ad.
class BottomBannerBar extends StatelessWidget {
  const BottomBannerBar({super.key, this.padding = EdgeInsets.zero});

  /// Applied only when an ad renders. Use it to keep the ad off tappable
  /// controls right next to it (e.g. a bottom tab bar), against mis-clicks.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!Ads.config.adsAllowed || !Ads.config.bannerEnabled) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: HybridAdSlot(
        sequence: Ads.config.bannerSequence,
        templateType: TemplateType.small,
        padding: padding,
      ),
    );
  }
}

/// Apni apps ka promo. Offline bhi dikhta hai (paisa nahi milta).
class HouseAdCard extends StatelessWidget {
  const HouseAdCard({super.key, required this.ad, this.compact = false});

  final HouseAd ad;
  final bool compact;

  Future<void> _open() async {
    final uri = Uri.tryParse(ad.targetUrl);
    if (uri == null) return;
    Ads.skipNextResume = true;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ad.iconAsset != null
                    ? Image.asset(ad.iconAsset!, width: 48, height: 48, fit: BoxFit.cover)
                    : Container(
                        width: 48,
                        height: 48,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('Ad',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onTertiary)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                      ),
                    ]),
                    if (ad.body.isNotEmpty)
                      Text(ad.body,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _open, child: Text(ad.callToAction)),
            ],
          ),
        ),
      ),
    );
  }
}

/// List mein ads ki position ka hisaab.
/// Example (start=2, interval=6): item, item, AD, 6 items, AD, 6 items, ...
class FeedAds {
  FeedAds._();

  static bool get _on => Ads.config.adsAllowed && Ads.config.nativeEnabled;
  static int get _start => Ads.config.feedStartPosition < 0 ? 0 : Ads.config.feedStartPosition;
  static int get _interval => Ads.config.feedInterval < 1 ? 1 : Ads.config.feedInterval;

  /// ListView.builder ka itemCount.
  static int itemCount(int contentCount) {
    if (!_on || contentCount < _start) return contentCount;
    final ads = ((contentCount - _start) ~/ _interval) + 1;
    return contentCount + ads;
  }

  static bool isAd(int index) =>
      _on && index >= _start && (index - _start) % (_interval + 1) == 0;

  /// Combined index -> aapki data list ka index.
  static int contentIndex(int index) {
    if (!_on || index <= _start) return index;
    final adsBefore = ((index - _start - 1) ~/ (_interval + 1)) + 1;
    return index - adsBefore;
  }
}
