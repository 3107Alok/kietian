import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../controllers/recognition_controller.dart';
import '../services/sound_service.dart';

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
  String _message = "Select All Details Then Align Face";
  
  String? _selectedSubject;
  String? _selectedBranch;
  String? _selectedTimeSlot;

  final List<String> _subjects = ['Math', 'OS', 'DBMS', 'Java'];
  final List<String> _branches = ['CS', 'CSE', 'CSIT'];

  @override
  void initState() {
    super.initState();
    _selectedTimeSlot = _getCurrentTimeSlot();
    _initializeCamera();
  }

  String _getCurrentTimeSlot() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Convert to 12-hour format string for display
    String formatPad(int h) {
      final hh = h % 12 == 0 ? 12 : h % 12;
      return hh.toString().padLeft(2, '0');
    }
    
    final ampm = now.hour >= 12 ? "PM" : "AM";
    final ampmNext = (now.hour + 1) >= 12 ? "PM" : "AM";
    
    // Format according to user preference or existing data pattern
    // User examples: "1-2 pm slot"
    return "${formatPad(hour)}:00 $ampm - ${formatPad(hour + 1)}:00 $ampmNext";
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
      // Re-calculate the slot right before marking to ensure accuracy
      _selectedTimeSlot = _getCurrentTimeSlot();

      // Stop stream before taking picture
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      if (!mounted) return;
      final image = await _controller!.takePicture();
      final controller = context.read<RecognitionController>();
      
      if (_selectedSubject == null || _selectedBranch == null) {
        setState(() => _message = "Please select Subject and Branch");
        _startStream();
        return;
      }

      final result = await controller.markAttendance(
        File(image.path), 
        _selectedSubject!, 
        _selectedBranch!,
        _selectedTimeSlot!
      );
      
      if (!mounted) return;
      setState(() => _message = result ?? "Wait...");
      
      if (result != null && result.contains("Verified")) {
          SoundService().playAttendanceSound();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
      } else {
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
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('FACE SCANNER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CameraPreview(_controller!),
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
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedSubject,
                          label: 'Subject',
                          items: _subjects,
                          onChanged: (val) => setState(() => _selectedSubject = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedBranch,
                          label: 'Branch',
                          items: _branches,
                          onChanged: (val) => setState(() => _selectedBranch = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ACTIVE SLOT', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                            const SizedBox(height: 4),
                            Text(_selectedTimeSlot ?? 'Detecting...', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _message.toUpperCase(),
                      key: ValueKey(_message),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message.contains('Verified') ? const Color(0xFF10B981) : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
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
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 12,
                            shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          ),
                          child: controller.isBusy 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                            : const Text('START AUTHENTICATION', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
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
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1E293B),
          elevation: 16,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6366F1)),
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
        ),
      ],
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
    const double scanWidth = 280;
    const double scanHeight = 400;

    return Stack(
      alignment: Alignment.center,
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

        // Scanning Overlay Frame (Glassy)
        Container(
          width: scanWidth,
          height: scanHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          ),
        ),

        // Animated Scanning Line
        _RepeatingScannerLine(width: scanWidth, height: scanHeight),

        // Decorative corners
        SizedBox(
          width: scanWidth + 10,
          height: scanHeight + 10,
          child: Stack(
            children: [
              _buildCorner(Alignment.topLeft),
              _buildCorner(Alignment.topRight),
              _buildCorner(Alignment.bottomLeft),
              _buildCorner(Alignment.bottomRight),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 50,
        height: 50,
        child: CustomPaint(
          painter: _CornerPainter(alignment),
        ),
      ),
    );
  }
}

class _RepeatingScannerLine extends StatefulWidget {
  final double width;
  final double height;
  const _RepeatingScannerLine({required this.width, required this.height});

  @override
  State<_RepeatingScannerLine> createState() => _RepeatingScannerLineState();
}

class _RepeatingScannerLineState extends State<_RepeatingScannerLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: (widget.height * _controller.value),
          child: Container(
            width: widget.width - 10,
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF6366F1).withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  _CornerPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const length = 25.0;
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
      ..strokeWidth = 2.5
      ..color = const Color(0xFF10B981); // Emerald for detection

    for (final face in faces) {
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(15)),
        paint,
      );

      // Techy corners on box
      final dotPaint = Paint()..color = const Color(0xFF10B981);
      canvas.drawCircle(rect.topLeft, 4, dotPaint);
      canvas.drawCircle(rect.topRight, 4, dotPaint);
      canvas.drawCircle(rect.bottomLeft, 4, dotPaint);
      canvas.drawCircle(rect.bottomRight, 4, dotPaint);
    }
  }

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
  }) {
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
