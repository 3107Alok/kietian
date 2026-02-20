import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/recognition_controller.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  CameraController? _controller;
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  bool _isProcessing = false;
  List<Face> _faces = [];
  bool _isCameraReady = false;

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

  void _register() async {
    if (_nameController.text.isEmpty || _rollController.text.isEmpty) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop stream before taking picture to avoid "failed precondition"
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      if (!mounted) return;
      final image = await _controller!.takePicture();
      final controller = context.read<RecognitionController>();
      
      final error = await controller.registerStudent(
        _nameController.text,
        _rollController.text,
        File(image.path),
      );

      if (!mounted) return;
      if (error == null) {
          // Force refresh students list
          await controller.fetchStudents();
          if (!mounted) return;
          
          _showSuccessDialog(_nameController.text);
      } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          // Restart stream if registration failed
          _startStream();
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSuccessDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF4E4EBA))),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.greenAccent),
            SizedBox(width: 10),
            Text('SUCCESS', style: TextStyle(color: Colors.white, letterSpacing: 2)),
          ],
        ),
        content: Text('$name has been registered successfully.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF4E4EBA), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
        title: const Text('ENROLL STUDENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Camera Preview with Scanning Frame
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width - 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: CameraPreview(_controller!),
                  ),
                ),
                // Scanning Overlay
                _ScannerOverlay(
                  faces: _faces, 
                  cameraSize: _controller?.value.previewSize,
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // Registration Form
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _rollController,
                    label: 'Roll Number',
                    icon: Icons.badge_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Consumer<RecognitionController>(
              builder: (context, controller, _) {
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: controller.isBusy ? null : _register,
                    icon: const Icon(Icons.camera_enhance_rounded),
                    label: Text(
                      controller.isBusy ? 'REGISTERING...' : 'CAPTURE & ENROLL',
                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E4EBA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: Colors.indigo.withValues(alpha: 0.4),
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.indigoAccent),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF4E4EBA), width: 2),
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final List<Face> faces;
  final Size? cameraSize;
  
  const _ScannerOverlay({
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

        // Scanning Overlay Frame
        Container(
          width: (MediaQuery.of(context).size.width - 48) * 0.8,
          height: (MediaQuery.of(context).size.width - 48) * 0.8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4E4EBA).withValues(alpha: 0.4), width: 1),
          ),
        ),

        // Decorative corners
        Positioned.fill(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: (MediaQuery.of(context).size.width - 48) * 0.82,
              height: (MediaQuery.of(context).size.width - 48) * 0.82,
              child: Stack(
                children: [
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerPainter(alignment),
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

    final length = 20.0;
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
