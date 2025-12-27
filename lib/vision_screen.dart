import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VisionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const VisionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _VisionScreenState createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  CameraController? _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isBusy = false;
  String _lastWords = "Нажми и спроси...";
  String _assistantResponse = "Я вас слушаю";

  CameraImage? _lastImage; 
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("ru-RU");
    await _flutterTts.setPitch(1.0);
  }

  void _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(widget.cameras[0], ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    if (!mounted) return;

    _controller!.startImageStream((CameraImage image) {
      _lastImage = image; 
    });
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "ru_RU",
          onResult: (val) {
            setState(() => _lastWords = val.recognizedWords);
            if (val.finalResult) {
               setState(() => _isListening = false);
               _handleVoiceCommand(val.recognizedWords.toLowerCase());
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _handleVoiceCommand(String command) async {
    if (_lastImage == null) {
      _speak("Камера не готова");
      return;
    }

    setState(() => _isBusy = true);
    String responseText = "";

    if (command.contains("чит") || command.contains("текст") || command.contains("написано")) {
      await _speak("Читаю текст");
      responseText = await _runTextRecognition(_lastImage!);
    } else if (command.contains("вид") || command.contains("предмет") || command.contains("что это")) {
      responseText = "Вижу окружение, но детальное распознавание предметов в разработке.";
    } else {
      responseText = "Вы сказали: $command. Попробуйте спросить: что тут написано?";
    }

    setState(() {
      _assistantResponse = responseText;
      _isBusy = false;
    });
    _speak(responseText);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<String> _runTextRecognition(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return "Ошибка кадра";
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    return recognizedText.text.isEmpty ? "Текст не найден" : recognizedText.text;
  }

  @override
  void dispose() {
    _controller?.dispose();
    textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Зрение Терминатора")),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          if (_isBusy) const Center(child: CircularProgressIndicator()),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Вы: $_lastWords", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(_assistantResponse, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  FloatingActionButton.large(
                    backgroundColor: _isListening ? Colors.red : Colors.blue,
                    onPressed: _listen,
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = widget.cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}