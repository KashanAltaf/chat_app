import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageDownloader {
  static Future<bool> downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return false;

      final directory = await getApplicationDocumentsDirectory();

      final fileName =
          'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(response.bodyBytes);
      return true;
    } catch (e) {
      return false;
    }
  }
}
