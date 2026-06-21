import 'dart:io';

class AdService {
  AdService._();

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1394062189372273/1924411598';
    }
    return 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get videoAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-1394062189372273/4407104708';
    }
    return 'ca-app-pub-3940256099942544/2177258514';
  }
}
