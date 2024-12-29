import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('No cameras found', 'No cameras available on device');
    }
    runApp(MyApp(cameras: cameras));
  } catch (e) {
    print('Failed to initialize cameras: $e');
    runApp(const MyApp(cameras: []));
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No cameras available'),
          ),
        ),
      );
    }
    return MaterialApp(
      home: FaceDetectionScreen(cameras: cameras),
    );
  }
}

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FaceDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _FaceDetectionScreenState createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _initializeCamera();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
      ),
    );
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      print('Camera permission denied');
    }
  }

  void _initializeCamera() {
    if (widget.cameras.isEmpty) return;
    
    _controller = CameraController(
      widget.cameras[1], // Use front camera
      ResolutionPreset.medium,
    );
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      _startImageStream();
    }).catchError((error) {
      print('Error initializing camera: $error');
    });
  }

  void _startImageStream() {
    _controller.startImageStream((image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }

      final inputImage = InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      try {
        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isNotEmpty) {
          print('Found ${faces.length} faces');
        }
      } catch (e) {
        print('Error detecting faces: $e');
      }

      _isDetecting = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Face Detection')),
      body: CameraPreview(_controller),
    );
  }
}