import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VisionService {
  final String apiKey = 'AIzaSyCqz04AI-I8k1HudRFto9EiotUs4v_4OKA'; // ใส่ API Key ของคุณที่นี่

  /// ตรวจจับข้อความในภาพโดยใช้ Google Vision API
  Future<String> detectText(File image) async {
    try {
      final base64Image = base64Encode(await image.readAsBytes());

      final Map<String, dynamic> requestBody = {
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "TEXT_DETECTION", "maxResults": 1}
            ]
          }
        ]
      };

      final url = Uri.parse(
          'https://vision.googleapis.com/v1/images:annotate?key=$apiKey');

      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 10)); // ตั้ง Timeout 10 วินาที

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 👉 เพิ่ม log เพื่อตรวจสอบข้อมูล JSON ที่ได้รับ
        print("📜 API Response: ${jsonEncode(responseData)}");

        if (responseData['responses'] == null || responseData['responses'].isEmpty) {
          throw Exception("API ไม่คืนค่าข้อมูลที่ตรวจจับได้");
        }

        final detectedText = responseData['responses'][0]['textAnnotations']?[0]['description']?.toString() ?? '';

        return detectedText.isNotEmpty
            ? detectedText
            : "ไม่พบข้อความในภาพ";
      } else {
        throw Exception(
            'Google Vision API Error (${response.statusCode}): ${response.body}');
      }
    } catch (error) {
      throw Exception("เกิดข้อผิดพลาดในการตรวจจับข้อความ: $error");
    }
  }

  /// ลบพื้นหลังของภาพโดยใช้ API บนเซิร์ฟเวอร์ Node.js
  Future<File> removeBackground(File image) async {
    try {
      print("🔄 กำลังส่งไฟล์ไปยังเซิร์ฟเวอร์: ${image.path}");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.0.85:3000/remove-bg'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      var response = await request.send().timeout(const Duration(seconds: 30));

      print("✅ ได้รับสถานะจากเซิร์ฟเวอร์: ${response.statusCode}");

      if (response.statusCode == 200) {
        var tempDir = await getTemporaryDirectory();
        File newFile = File('${tempDir.path}/no_bg.png');
        var imageBytes = await response.stream.toBytes();
        await newFile.writeAsBytes(imageBytes);

        print("✅ บันทึกไฟล์ที่ลบพื้นหลังแล้ว: ${newFile.path}");
        return newFile;
      } else {
        throw Exception("Background removal failed: ${response.statusCode}");
      }
    } catch (error) {
      print("❌ เกิดข้อผิดพลาดในการลบพื้นหลัง: $error");
      throw Exception("เกิดข้อผิดพลาด: $error");
    }
  }
}
