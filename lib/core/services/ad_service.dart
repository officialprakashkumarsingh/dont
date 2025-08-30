import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  static AdService get instance => _instance;
  
  AdService._internal();

  // AdMob IDs
  static const String _rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Test ID for rewarded video
      : 'ca-app-pub-3394897715416901/4102565339'; // Production rewarded ad ID
      
  static const String _interstitialAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712' // Test ID for interstitial
      : 'ca-app-pub-3394897715416901/2314438965'; // Production interstitial ad ID

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  Function? _onRewardEarned;
  Function? _onAdDismissed;
  
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  
  // Track if user has watched ad this session
  static const String _adWatchedKey = 'ad_watched_timestamp';
  
  // Track extension feature usage
  int _extensionFeatureUseCount = 0;
  static const int _extensionAdFrequency = 3;
  
  // Track message count
  int _messageCount = 0;
  static const int _messageAdFrequency = 30;
  
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _setRewardedAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load rewarded ad: ${error.message}');
          _rewardedAd = null;
          _isRewardedAdReady = false;
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 30), () {
            _loadRewardedAd();
          });
        },
      ),
    );
  }

  void _setRewardedAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        _onAdDismissed?.call();
        _loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        _onAdDismissed?.call();
        _loadRewardedAd();
      },
    );
  }

  bool get isRewardedAdReady => _isRewardedAdReady;

  Future<bool> showRewardedAd({
    required Function onRewardEarned,
    Function? onAdDismissed,
  }) async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      return false;
    }

    _onRewardEarned = onRewardEarned;
    _onAdDismissed = onAdDismissed;

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        // Save timestamp when ad was watched
        final now = DateTime.now().millisecondsSinceEpoch;
        AppService.prefs.setInt(_adWatchedKey, now);
        _onRewardEarned?.call();
      },
    );

    return true;
  }

  // Check if user needs to watch ad (once per app session)
  bool needsToWatchAd() {
    final lastWatched = AppService.prefs.getInt(_adWatchedKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastWatch = (now - lastWatched) / (1000 * 60 * 60);
    
    // Require ad watch if more than 1 hour since last watch
    return hoursSinceLastWatch > 1;
  }

  // Check if user has premium features unlocked
  bool hasUnlockedPremiumFeatures() {
    return !needsToWatchAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _setInterstitialAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load interstitial ad: ${error.message}');
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 30), () {
            _loadInterstitialAd();
          });
        },
      ),
    );
  }

  void _setInterstitialAdCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        _loadInterstitialAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        _loadInterstitialAd();
      },
    );
  }

  // Track extension feature use and show ad if needed
  Future<void> onExtensionFeatureUsed() async {
    _extensionFeatureUseCount++;
    
    if (_extensionFeatureUseCount >= _extensionAdFrequency) {
      _extensionFeatureUseCount = 0; // Reset counter
      await showInterstitialAd();
    }
  }

  // Track message count and show rewarded ad if needed
  Future<void> onMessageSent() async {
    _messageCount++;
    
    if (_messageCount >= _messageAdFrequency && _isRewardedAdReady) {
      _messageCount = 0; // Reset counter
      
      // Auto-show rewarded ad after 30 messages
      await showRewardedAd(
        onRewardEarned: () {
          // User watched the ad, can give them a bonus or just continue
          print('User watched rewarded ad after 30 messages');
        },
      );
    }
  }

  Future<bool> showInterstitialAd() async {
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      return false;
    }

    await _interstitialAd!.show();
    return true;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}