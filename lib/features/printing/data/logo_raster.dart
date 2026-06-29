import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Loads the bundled shop logo and prepares it as a grayscale raster sized for a
/// thermal printer. Returns null if the asset can't be loaded or decoded, so the
/// receipt builder can fall back to a plain text header.
class LogoRaster {
  const LogoRaster();

  static const String _asset = 'assets/logo/psg_logo.png';

  Future<img.Image?> load({required int targetWidth}) async {
    try {
      final data = await rootBundle.load(_asset);
      final decoded = img.decodeImage(data.buffer.asUint8List());
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: targetWidth);
      return img.grayscale(resized);
    } catch (_) {
      return null;
    }
  }
}
