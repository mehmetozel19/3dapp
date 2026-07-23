import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io' show File;

class AIClassifier {
  Interpreter? _interpreter;
  final List<String> labels = ['backyard', 'bathroom', 'bedroom', 'frontyard', 'kitchen', 'livingRoom'];

  Future<void> loadModel() async {
    try {
      // DÜZELTME: Doğru asset yolu verildi
      _interpreter = await Interpreter.fromAsset('assets/room_model.tflite');
    } catch (e) {
      print("Model yüklenirken hata oluştu: $e");
    }
  }

  Future<String> classifyImage(String imagePath) async {
    if (_interpreter == null) await loadModel();
    if (imagePath.isEmpty || !File(imagePath).existsSync()) return 'Pano';

    // 1. Resmi yükle ve boyutlandır (224x224)
    final rawImage = File(imagePath).readAsBytesSync();
    final image = img.decodeImage(rawImage);
    if (image == null) return 'Pano';

    final resized = img.copyResize(image, width: 224, height: 224);

    // 2. Input Tensor (x, y yani k, j sırasına dikkat edilerek)
    var input = List.generate(1, (i) => List.generate(224, (j) => List.generate(224, (k) => [
      resized.getPixel(k, j).r / 255.0, // Normalizasyon
      resized.getPixel(k, j).g / 255.0,
      resized.getPixel(k, j).b / 255.0
    ])));

    // 3. Çıktı için yer aç
    var output = List.filled(1 * 6, 0.0).reshape([1, 6]);

    // 4. Tahmin et
    _interpreter!.run(input, output);

    // 5. En yüksek değeri bul (Argmax)
    List<double> results = output[0];
    int maxIdx = results.indexOf(results.reduce((a, b) => a > b ? a : b));

    return labels[maxIdx];
  }

  void dispose() {
    _interpreter?.close();
  }
}