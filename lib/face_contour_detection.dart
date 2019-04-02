import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_face_contour_detection/face_contour_painter.dart';
import 'package:flutter_face_contour_detection/utils.dart';

class FaceContourDetectionScreen extends StatefulWidget {
  @override
  _FaceContourDetectionScreenState createState() =>
      _FaceContourDetectionScreenState();
}

class _FaceContourDetectionScreenState
    extends State<FaceContourDetectionScreen> {
  final FaceDetector faceDetector = FirebaseVision.instance.faceDetector(
      FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableContours: true,
          enableTracking: false));
  List<Face> faces;
  CameraController _camera;
  bool cameraEnabled = true;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    print(rotation);

    _camera = CameraController(
      description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );
    await _camera.initialize();

    print("initialize Camera");
    print(description.lensDirection);
    print(_camera.description.lensDirection);

    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      detect(image, faceDetector.processImage, rotation).then(
        (dynamic result) {
          setState(() {
            faces = result;
          });

          _isDetecting = false;
        },
      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  Widget _buildResults() {
    const Text noResultsText = const Text('No results!');

    if (faces == null || _camera == null || !_camera.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;

    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );

    if (faces is! List<Face>) return noResultsText;
    painter = FaceContourPainter(imageSize, faces, _direction);

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30.0,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(_camera),
                _buildResults(),
                Positioned(
                  bottom: 0.0,
                  left: 0.0,
                  right: 0.0,
                  child: Container(
                    color: Colors.white,
                    height: 50.0,
                    child: ListView(
                      children: faces
                          .map((face) =>
                              Text(face.boundingBox.center.toString()))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _toggleCameraDirection() async {
    if (_direction == CameraLensDirection.back) {
      _direction = CameraLensDirection.front;
    } else {
      _direction = CameraLensDirection.back;
    }

    await _camera.stopImageStream();
    await _camera.dispose();

    setState(() {
      _camera = null;
    });

    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flutter Face Contour Detection"),
        actions: <Widget>[
//          Center(child: Text(faces.length.toString() ?? '0')),
          IconButton(
              icon:
                  Icon(cameraEnabled ? Icons.visibility : Icons.visibility_off),
              onPressed: () {
                setState(() {
                  cameraEnabled = !cameraEnabled;
                });
              })
        ],
      ),
      body: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30.0,
                ),
              ),
            )
          : LiveCameraWithFaceDetection(
              faces: faces,
              camera: _camera,
              cameraEnabled: cameraEnabled,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleCameraDirection,
        child: _direction == CameraLensDirection.back
            ? const Icon(Icons.camera_front)
            : const Icon(Icons.camera_rear),
      ),
    );
  }
}

class LiveCameraWithFaceDetection extends StatelessWidget {
  final List<Face> faces;
  final CameraController camera;
  final bool cameraEnabled;

  const LiveCameraWithFaceDetection(
      {Key key, this.faces, this.camera, this.cameraEnabled = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    print(camera.description.lensDirection);
    return Container(
      constraints: const BoxConstraints.expand(),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          cameraEnabled
              ? CameraPreview(camera)
              : Container(
                  color: Colors.black,
                ),
          (faces != null && camera.value.isInitialized)
              ? CustomPaint(
                  painter: FaceContourPainter(
                      Size(
                        camera.value.previewSize.height,
                        camera.value.previewSize.width,
                      ),
                      faces,
                      camera.description.lensDirection),
                )
              : const Text('No results!'),
        ],
      ),
    );
  }
}
