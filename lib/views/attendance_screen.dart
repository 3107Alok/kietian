import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/recognition_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _controller;
  bool _isProcessing = false;
  List<Face> _faces = [];
  bool _isCameraReady = false;
  String _message = "Align your face within the frame";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _controller = CameraController(
      frontCamera, 
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();
    _startStream();

    if (mounted) setState(() => _isCameraReady = true);
  }

  void _processCameraImage(CameraImage image) async {
    try {
      final faces = await context.read<RecognitionController>().detectFacesFromStream(image, _controller!.description.sensorOrientation);
      if (mounted) {
        setState(() {
          _faces = faces;
        });
      }
    } catch (e) {
      debugPrint('Stream processing error: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      _isProcessing = false;
    }
  }

  void _scanFace() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop stream before taking picture
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      if (!mounted) return;
      final image = await _controller!.takePicture();
      final controller = context.read<RecognitionController>();
      final result = await controller.markAttendance(File(image.path));
      
      if (!mounted) return;
      setState(() => _message = result ?? "Wait...");
      
      if (result != null && result.contains("Attendance marked")) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
      } else {
        // Restart stream if attendance failed
        _startStream();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
      setState(() => _message = 'Error: $e');
    }
  }

  void _startStream() {
    if (_controller != null && !_controller!.value.isStreamingImages) {
      _controller!.startImageStream((image) {
        if (!_isProcessing) {
          _isProcessing = true;
          _processCameraImage(image);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4E4EBA))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('FACE SCANNER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CameraPreview(_controller!),
                    
                    // High-tech scanning overlay
                    _ScannerOverlay(
                      message: _message, 
                      faces: _faces, 
                      cameraSize: _controller?.value.previewSize,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(32.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _message.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _message.contains('Success') ? Colors.greenAccent : Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<RecognitionController>(
                  builder: (context, controller, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: controller.isBusy ? null : _scanFace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4E4EBA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 12,
                          shadowColor: Colors.indigo.withValues(alpha: 0.5),
                        ),
                        child: controller.isBusy 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('START AUTHENTICATION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      ),
                    );
                  }
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final String message;
  final List<Face> faces;
  final Size? cameraSize;
  
  const _ScannerOverlay({
    required this.message, 
    required this.faces, 
    this.cameraSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Real-time Bounding Boxes
        if (cameraSize != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceBoxPainter(
                faces: faces,
                imageSize: cameraSize!,
              ),
            ),
          ),
        // Pulsing frame
        Center(
          child: Container(
            width: 260,
            height: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFF4E4EBA).withValues(alpha: 0.4), width: 1),
            ),
          ),
        ),
        // Corners
        _buildCorner(Alignment.topLeft),
        _buildCorner(Alignment.topRight),
        _buildCorner(Alignment.bottomLeft),
        _buildCorner(Alignment.bottomRight),
        
        // Scan line effect could be added here with an animation
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Container(
          width: 270,
          height: 390,
          child: CustomPaint(
            painter: _CornerPainter(alignment),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  _CornerPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4E4EBA)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final length = 40.0;
    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, length);
      path.lineTo(0, 0);
      path.lineTo(length, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(size.width - length, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, length);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, size.height - length);
      path.lineTo(0, size.height);
      path.lineTo(length, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(size.width - length, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - length);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _FaceBoxPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  _FaceBoxPainter({required this.faces, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF4E4EBA);

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );

      // Decorative dots at corners
      final cornerPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(rect.topLeft, 4, cornerPaint);
      canvas.drawCircle(rect.topRight, 4, cornerPaint);
      canvas.drawCircle(rect.bottomLeft, 4, cornerPaint);
      canvas.drawCircle(rect.bottomRight, 4, cornerPaint);
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
    // Note: On Android, the preview size is often landscape, so we swap.
    final double scaleX = widgetSize.width / imageSize.height;
    final double scaleY = widgetSize.height / imageSize.width;

    return Rect.fromLTRB(
      (imageSize.height - rect.right) * scaleX, 
      rect.top * scaleY,
      (imageSize.height - rect.left) * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(_FaceBoxPainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
