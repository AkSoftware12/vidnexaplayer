// Native aur Banner ads ke pools.
// Screen khulne se PEHLE ads load karke rakhte hain, taaki screen par turant
// (0 ms) ad mil jaye. Pehli Kotlin app ka "NativeAdManager" yahi karta hai.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

const Duration _viewAdExpiry = Duration(hours: 1);

class _Pooled<T extends Ad> {
  final T ad;
  final DateTime loadedAt;
  _Pooled(this.ad) : loadedAt = DateTime.now();
  bool get expired => DateTime.now().difference(loadedAt) > _viewAdExpiry;
}

/// Base pool: buffer bhar ke rakhna, expiry, retry with backoff.
abstract class _AdPool<T extends Ad> {
  final String tag;
  _AdPool(this.tag);

  final List<_Pooled<T>> _ready = [];
  int _loading = 0;
  int _failStreak = 0;
  Timer? _retryTimer;

  /// Widgets isko sunte hain: ready ads ki ginti.
  final ValueNotifier<int> available = ValueNotifier<int>(0);

  bool get enabled;
  int get target;
  int get prefetchThreshold => 1;

  /// Ek ad load karo; success par onLoaded(ad), fail par onFailed().
  void loadOne(void Function(T ad) onLoaded, void Function() onFailed);

  void fill() {
    if (!enabled || !Ads.config.adsAllowed || !Ads.sdkReady) return;
    _dropExpired();
    while (_ready.length + _loading < target) {
      _loading++;
      var settled = false;
      loadOne((ad) {
        // Banners auto-refresh and call onAdLoaded again for the same ad;
        // pooling it twice would put one ad in two AdWidgets.
        if (settled) return;
        settled = true;
        _loading--;
        _failStreak = 0;
        _ready.add(_Pooled<T>(ad));
        available.value = _ready.length;
        Ads.log(tag, 'Ready: ${_ready.length}');
      }, () {
        if (settled) return;
        settled = true;
        _loading--;
        _failStreak++;
        _scheduleRetry();
      });
    }
  }

  /// Ready ad do (ya null). Ad ab caller ka hai; wahi dispose karega.
  T? take() {
    _dropExpired();
    if (_ready.isEmpty) {
      fill();
      return null;
    }
    final p = _ready.removeAt(0);
    available.value = _ready.length;
    if (_ready.length <= prefetchThreshold) fill();
    return p.ad;
  }

  void _dropExpired() {
    _ready.removeWhere((p) {
      if (p.expired) {
        p.ad.dispose();
        return true;
      }
      return false;
    });
    available.value = _ready.length;
  }

  void _scheduleRetry() {
    if (_failStreak > 3 || (_retryTimer?.isActive ?? false)) return;
    final delay = Duration(seconds: 10 * (1 << (_failStreak - 1))); // 10s, 20s, 40s
    Ads.log(tag, 'Load fail #$_failStreak, retry in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, fill);
  }

  /// Foreground / net wapas aane par: retry counter reset karke phir bharo.
  void refresh() {
    _failStreak = 0;
    fill();
  }

  void disposeAll() {
    _retryTimer?.cancel();
    for (final p in _ready) {
      p.ad.dispose();
    }
    _ready.clear();
    available.value = 0;
  }
}

// ============================================================================
// NATIVE
// ============================================================================
class NativeAdPool extends _AdPool<NativeAd> {
  NativeAdPool._(this.type) : super('Native/${type.name}');

  static final Map<TemplateType, NativeAdPool> _pools = {};
  static NativeAdPool of(TemplateType type) =>
      _pools.putIfAbsent(type, () => NativeAdPool._(type));
  static Iterable<NativeAdPool> get all => _pools.values;

  /// App ke theme ke hisaab se style yahan badlo (colors, corner radius).
  static NativeTemplateStyle Function(TemplateType type) styleBuilder =
      (type) => NativeTemplateStyle(templateType: type, cornerRadius: 12);

  final TemplateType type;

  @override
  bool get enabled => Ads.config.nativeEnabled;

  @override
  int get target => Ads.config.nativeBufferTarget.clamp(0, Ads.config.nativeMaxBuffer);

  @override
  int get prefetchThreshold => Ads.config.nativePrefetchThreshold;

  String get _unitId =>
      type == TemplateType.small ? Ads.config.nativeSmallUnitId : Ads.config.nativeUnitId;

  @override
  void loadOne(void Function(NativeAd ad) onLoaded, void Function() onFailed) {
    NativeAd(
      adUnitId: _unitId,
      request: Ads.request(),
      nativeTemplateStyle: styleBuilder(type),
      nativeAdOptions: NativeAdOptions(videoOptions: VideoOptions(startMuted: true)),
      listener: NativeAdListener(
        onAdLoaded: (ad) => onLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          Ads.log(tag, 'Failed: ${error.message}');
          ad.dispose();
          onFailed();
        },
        onAdClicked: (_) => Ads.skipNextResume = true,
      ),
    ).load();
  }
}

// ============================================================================
// BANNER (adaptive)
// ============================================================================
class BannerAdPool extends _AdPool<BannerAd> {
  BannerAdPool._() : super('Banner');
  static final BannerAdPool instance = BannerAdPool._();

  AdSize? _size;

  /// Banner ki height pehle se pata ho to jagah reserve kar sakte ho (jump nahi hoga).
  AdSize? get size => _size;

  @override
  bool get enabled => Ads.config.bannerEnabled;

  @override
  int get target => Ads.config.bannerBufferSize;

  @override
  int get prefetchThreshold => 0;

  // Standard 320x50. The "large anchored adaptive" size was far taller than
  // a bottom bar should be and reserved empty space under shorter creatives.
  Future<AdSize> _resolveSize() async => _size ??= AdSize.banner;

  @override
  void loadOne(void Function(BannerAd ad) onLoaded, void Function() onFailed) {
    _resolveSize().then((size) {
      BannerAd(
        adUnitId: Ads.config.bannerUnitId,
        size: size,
        request: Ads.request(),
        listener: BannerAdListener(
          onAdLoaded: (ad) => onLoaded(ad as BannerAd),
          onAdFailedToLoad: (ad, error) {
            Ads.log(tag, 'Failed: ${error.message}');
            ad.dispose();
            onFailed();
          },
          onAdClicked: (_) => Ads.skipNextResume = true,
        ),
      ).load();
    });
  }
}

/// Sab view-ad pools ek saath.
class ViewAdPools {
  /// Jo native size app mein sabse pehle dikhta hai, sirf wahi preload karo
  /// (zyada pools = zyada requests). Baaki size pehli baar take() par bharega.
  static void fillAll({List<TemplateType> nativeTypes = const [TemplateType.medium]}) {
    for (final t in nativeTypes) {
      NativeAdPool.of(t).fill();
    }
    BannerAdPool.instance.fill();
  }

  static void refreshAll() {
    for (final p in NativeAdPool.all) {
      p.refresh();
    }
    BannerAdPool.instance.refresh();
  }
}
