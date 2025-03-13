import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VisionService {
  final String apiKey = 'AIzaSyCqz04AI-I8k1HudRFto9EiotUs4v_4OKA'; // ใส่ API Key ของคุณที่นี่
  final String removeBgApiKey = 'TGEhMxYybQXMWWKeiSawWin8'; // ใส่ API Key ของ remove.bg ที่นี่ Acc jokuyveeolo

  Future<String> detectText(File image) async {
    // Convert image to base64
    final base64Image = base64Encode(image.readAsBytesSync());

    // Request payload
    final Map<String, dynamic> requestBody = {
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {
              "type": "TEXT_DETECTION",
              "maxResults": 1,
            }
          ]
        }
      ]
    };

    // API URL for Google Vision
    final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');

    // Send the request to Google Cloud Vision API
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      // Parse the response
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final String detectedText = responseData['responses'][0]['fullTextAnnotation']['text'] ?? '';
      return detectedText;
    } else {
      throw Exception('Failed to load data: ${response.body}');
    }
  }

  Future<File> removeBackground(File image) async {
    final url = Uri.parse('https://api.remove.bg/v1.0/removebg');

    final request = http.MultipartRequest('POST', url)
      ..headers['X-Api-Key'] = removeBgApiKey
      ..files.add(await http.MultipartFile.fromPath('image_file', image.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final bytes = await response.stream.toBytes();
      final tempFile = File('${Directory.systemTemp.path}/no_bg.png');
      await tempFile.writeAsBytes(bytes);
      return tempFile; // ส่งกลับไฟล์ที่ลบพื้นหลัง
    } else {
      throw Exception('Failed to remove background: ${response.statusCode}');
    }
  }
}
