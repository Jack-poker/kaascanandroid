enum AdType { image, gif, lottie, widget }

class AdItem {
  final String? id;
  final AdType type;
  final String? url;
  final String? title;
  final String? subtitle;
  final String? actionUrl;
  final Map<String, dynamic>? extraData;
  bool isReady;

  AdItem({
    this.id,
    required this.type,
    this.url,
    this.title,
    this.subtitle,
    this.actionUrl,
    this.extraData,
    this.isReady = false,
  });

  factory AdItem.fromJson(Map<String, dynamic> json) {
    AdType type;
    String typeStr = json['type']?.toString().toLowerCase() ?? 'widget';
    
    switch (typeStr) {
      case 'image':
        type = AdType.image;
        break;
      case 'gif':
        type = AdType.gif;
        break;
      case 'lottie':
        type = AdType.lottie;
        break;
      default:
        type = AdType.widget;
    }

    return AdItem(
      id: json['id']?.toString(),
      type: type,
      url: json['url'],
      title: json['title'],
      subtitle: json['subtitle'],
      actionUrl: json['action_url'],
      extraData: json['extra_data'],
      isReady: type == AdType.widget, // Widgets are always ready
    );
  }
}
