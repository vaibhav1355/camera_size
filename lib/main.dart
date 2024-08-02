import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.last;

  runApp(
    MaterialApp(
      home: TakePictureScreen(camera: firstCamera),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return cameraWidget(context);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            final image = await _controller.takePicture();
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TransformPictureScreen(imagePath: image.path),
              ),
            );
          } catch (e) {
            print('Error taking picture: $e');
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  Widget cameraWidget(context) {
    return Center(
      child: ClipRRect(
        child: SizedOverflowBox(
          size: const Size(300, 300), // aspect is 1:1
          alignment: Alignment.center,
          child: CameraPreview(_controller),
        ),
      ),
    );
  }
}

class TransformPictureScreen extends StatelessWidget {
  final String imagePath;

  const TransformPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transform the Picture')),
      body: Center(
        child: FutureBuilder<File>(
          future: _loadImageFile(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                final file = snapshot.data!;
                print('Image file loaded: ${file.path}');

                return Transform(
                  transform: Matrix4.rotationY(3.14),
                  alignment: Alignment.center,
                  child: Image.file(
                    file,
                    width: 300,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                );
              } else {
                print('Error: ${snapshot.error}'); // Debug print
                return const Center(child: Text('Error loading image'));
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Future<File> _loadImageFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return file;
    } else {
      throw Exception('File does not exist');
    }
  }
}
