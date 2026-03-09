import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:kaascan/models/ad_item.dart';

class AdsController extends GetxController {
  final ads = <AdItem>[].obs;
  final isLoading = true.obs;
  
  // The user mentioned ads are fetched from n8n url
  final String adsUrl = "https://automation.kaascan.com/webhook/ads";

  @override
  void onInit() {
    super.onInit();
    fetchAds();
  }

  Future<void> fetchAds() async {
    print("🚀 ADS: Starting fetch from $adsUrl");
    try {
      isLoading.value = true;
      final response = await http.get(Uri.parse(adsUrl)).timeout(const Duration(seconds: 10));
      
      print("🚀 ADS: Response Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print("🚀 ADS: Data received: $decoded");
        List<dynamic> data = [];
        
        if (decoded is List) {
          data = decoded;
        } else if (decoded is Map) {
          data = decoded['ads'] ?? decoded['data'] ?? decoded['items'] ?? [];
          if (data.isEmpty && (decoded.containsKey('type') || decoded.containsKey('url'))) {
            data = [decoded];
          }
        }

        final fetchedAds = data.map((json) => AdItem.fromJson(json)).toList();
        
        if (fetchedAds.isEmpty) {
          print("🚀 ADS: No ads found in response, loading internal fallbacks.");
          _loadFallbacks();
        } else {
          ads.value = fetchedAds;
          _preloadAssets();
        }
      } else {
        _loadFallbacks();
      }
    } catch (e) {
      print("🚀 ADS: Error fetching ads: $e");
      _loadFallbacks();
    } finally {
      isLoading.value = false;
    }
  }

  void _loadFallbacks() {
    ads.value = [
      AdItem(
        type: AdType.image,
        url: "https://images.unsplash.com/photo-1543269865-cbf427effbad?q=80&w=1000&auto=format&fit=crop",
        title: "Digital Schooling",
        subtitle: "Join the revolution in education.",
        isReady: true,
      ),
      AdItem(
        type: AdType.image,
        url: "https://images.unsplash.com/photo-1509062522246-3755977927d7?q=80&w=1000&auto=format&fit=crop",
        title: "Secure Payments",
        subtitle: "KaaScan protects every transaction.",
        isReady: true,
      ),
    ];
  }

  void _preloadAssets() {
    for (var ad in ads) {
      if (ad.type == AdType.image || ad.type == AdType.gif) {
        _preloadImage(ad);
      } else if (ad.type == AdType.lottie) {
        _preloadLottie(ad);
      }
    }
  }

  void _preloadImage(AdItem ad) async {
    if (ad.url == null) return;
    try {
      final image = NetworkImage(ad.url!);
      // We don't have Get.context easily here, but we can use WidgetsBinding
      final ImageStream stream = image.resolve(ImageConfiguration.empty);
      stream.addListener(ImageStreamListener((info, synchronousCall) {
        ad.isReady = true;
        ads.refresh();
      }, onError: (exception, stackTrace) {
        print("Failed to preload image: $exception");
      }));
    } catch (e) {
      print("Error preloading image: $e");
    }
  }

  void _preloadLottie(AdItem ad) {
    if (ad.url == null) return;
    // For Lottie, we'll mark it as ready immediately for now, 
    // or we could use Lottie.network directly which handles loading states.
    ad.isReady = true;
    ads.refresh();
  }

  List<AdItem> get readyAds => ads.where((ad) => ad.isReady).toList();
}
