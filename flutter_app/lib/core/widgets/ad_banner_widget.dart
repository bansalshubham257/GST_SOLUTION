import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../services/ad_service.dart';

class AdBannerWidget extends ConsumerStatefulWidget {
  const AdBannerWidget({super.key});

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdIfNeeded();
    });
  }

  void _loadAdIfNeeded() {
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final shouldShow = user != null && user.showAds;

    if (shouldShow && _bannerAd == null) {
      _loadAd();
    } else if (!shouldShow && _bannerAd != null) {
      _bannerAd!.dispose();
      _bannerAd = null;
      _adLoaded = false;
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _adLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _adLoaded = false;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      final user = next.valueOrNull?.user;
      final shouldShow = user != null && user.showAds;

      if (shouldShow && _bannerAd == null) {
        _loadAd();
      } else if (!shouldShow && _bannerAd != null) {
        _bannerAd!.dispose();
        _bannerAd = null;
        _adLoaded = false;
      }
    });

    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (user == null || !user.showAds || !_adLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
