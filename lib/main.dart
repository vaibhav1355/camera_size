import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'dart:ui' as ui;

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

  double assignedWidth = 300;
  double assignedHeight = 300;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high, // Change resolution preset here
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
                builder: (context) => TransformPictureScreen(
                  imagePath: image.path,
                  assignedWidth: assignedWidth,
                  assignedHeight: assignedHeight,
                ),
              ),
            );
          } catch (e) {
            print('Error taking picture: $e');
          }
        },
        child: Icon(Icons.camera_alt),
      ),
    );
  }

  Widget cameraWidget(context) {
    return Center(
      child: ClipRRect(
        child: SizedOverflowBox(
          size: Size(assignedWidth, assignedHeight),
          alignment: Alignment.center,
          child: CameraPreview(_controller),
        ),
      ),
    );
  }
}

class TransformPictureScreen extends StatelessWidget {
  final String imagePath;
  final double assignedWidth;
  final double assignedHeight;

  const TransformPictureScreen({
    super.key,
    required this.imagePath,
    required this.assignedWidth,
    required this.assignedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transform the Picture')),
      body: Center(
        child: FutureBuilder<File>(
          future: _cropAndLoadImageFile(imagePath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                final file = snapshot.data!;
                print('Cropped image file loaded: ${file.path}');
                return Transform(
                  transform: Matrix4.rotationY(3.14),
                  alignment: Alignment.center,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                  ),
                );
              } else {
                print('Error: ${snapshot.error}');
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

  Future<File> _cropAndLoadImageFile(String path) async {
    final file = File(path);

    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final widthOfImage = image.width;
      final heightOfImage = image.height;

      print('Original Image dimensions: width = $widthOfImage, height = $heightOfImage');

      final width = assignedWidth.toInt();
      final height = assignedHeight.toInt();

      final double aspectRatio = widthOfImage / heightOfImage;
      final double targetAspectRatio = width / height.toDouble();

      int cropWidth, cropHeight, originX, originY;

      if (aspectRatio > targetAspectRatio) {
        cropHeight = heightOfImage;
        cropWidth = (heightOfImage * targetAspectRatio).toInt();
      } else {
        cropWidth = widthOfImage;
        cropHeight = (widthOfImage / targetAspectRatio).toInt();
      }

      originX = ((widthOfImage - cropWidth) / 2).toInt();
      originY = ((heightOfImage - cropHeight) / 2).toInt();

      print('Cropping parameters: originX = $originX, originY = $originY, width = $cropWidth, height = $cropHeight');

      final croppedFile = await FlutterNativeImage.cropImage(
        file.path,
        originX,
        originY,
        cropWidth,
        cropHeight,
      );
      return croppedFile;
    } else {
      throw Exception('File does not exist');
    }
  }
}
