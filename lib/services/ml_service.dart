import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MLService {
  Interpreter? _interpreter;
  late FaceDetector _faceDetector;

  bool _isModelLoaded = false;
  bool get isModelLoaded => _isModelLoaded;

  Future<void> initialize() async {
    // Initialize Face Detector
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    // Initialize TFLite Interpreter
    await _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Trying multiple path variations to be absolutely sure
      final List<String> pathsToTry = [
        'assets/models/facenet.tflite',
        'models/facenet.tflite',
      ];

      for (String path in pathsToTry) {
        try {
          debugPrint('ML: Attempting to load model from $path...');
          _interpreter = await Interpreter.fromAsset(path);
          _isModelLoaded = true;
          debugPrint('ML: Model Loaded Successfully from $path');
          break;
        } catch (e) {
          debugPrint('ML: Failed to load from $path: $e');
        }
      }

      if (!_isModelLoaded) {
        debugPrint('CRITICAL: All model load attempts failed.');
      }
    } catch (e) {
      debugPrint('CRITICAL: Unexpected error during model loading: $e');
      _isModelLoaded = false;
    }
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    return await _faceDetector.processImage(inputImage);
  }

  // Preprocess image and generate embedding
  Future<List<double>> getEmbedding(File imageFile, Face face) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model not loaded. Please restart the app or check assets.');
    }

    // 1. Read image
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) throw Exception('Failed to decode captured image.');
    
    // Fix orientation
    originalImage = img.bakeOrientation(originalImage);

    // 2. Safe Cropping Logic
    Rect boundingBox = face.boundingBox;
    int left = max(0, boundingBox.left.toInt());
    int top = max(0, boundingBox.top.toInt());
    int width = min(boundingBox.width.toInt(), originalImage.width - left);
    int height = min(boundingBox.height.toInt(), originalImage.height - top);

    img.Image croppedFace = img.copyCrop(
      originalImage,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    // 3. Resize to 160x160 exactly
    img.Image resizedFace = img.copyResize(croppedFace, width: 160, height: 160);

    // 4. Convert and Normalize: (pixel - 128) / 128
    final input = Float32List(1 * 160 * 160 * 3);
    int pixelIndex = 0;
    
    // Faster and safer iteration for image v4
    for (var pixel in resizedFace) {
      // Using .r, .g, .b which returns 0-255 for Uint8 images
      input[pixelIndex++] = (pixel.r - 128.0) / 128.0;
      input[pixelIndex++] = (pixel.g - 128.0) / 128.0;
      input[pixelIndex++] = (pixel.b - 128.0) / 128.0;
    }

    // 5. Explicitly shaped output tensor [1, 128]
    // Using a nested list for compatibility with interpreter.run
    var output = List.generate(1, (_) => List<double>.filled(128, 0.0));

    // 6. Run inference using reshaped input [1, 160, 160, 3]
    try {
      final reshapedInput = input.reshape([1, 160, 160, 3]);
      _interpreter!.run(reshapedInput, output);
    } catch (e) {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      throw Exception('Inference Failed: $e. Model Input: $inputShape, Output: $outputShape');
    }

    // 7. Generate result
    final List<double> result = List<double>.from(output[0]);
    
    // 8. Strict Validation
    bool isAllZeros = result.every((element) => element == 0);
    if (result.length != 128) {
      throw Exception('Dimension Mismatch: Model returned ${result.length} dimensions, expected 128. Output Shape: ${_interpreter!.getOutputTensor(0).shape}');
    }
    
    if (isAllZeros) {
      throw Exception('Invalid Embedding: Model returned all zeros. Check input/normalization.');
    }

    debugPrint('EMBEDDING PRODUCED: Size=${result.length}');
    return result;
  }

  double compareEmbeddings(List<double> emb1, List<double> emb2) {
    if (emb1.isEmpty || emb2.isEmpty) return 0.0;
    if (emb1.length != emb2.length) return 0.0;
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      dotProduct += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }
    
    if (norm1 == 0 || norm2 == 0) return 0.0;
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  void dispose() {
    _faceDetector.close();
    _interpreter?.close();
  }
}
