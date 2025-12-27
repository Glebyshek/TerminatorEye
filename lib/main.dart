import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'vision_screen.dart'; // Файл с камерой (код ниже)
import 'vision_screen.dart';
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // Темная тема лучше для батареи и глаз
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  // ФУНКЦИЯ ДОЛЖНА БЫТЬ ТУТ (Внутри класса, но вне build)
  Future<void> _openMap() async {
    const String query = "аптека"; 
    final Uri url = Uri.parse('geo:0,0?q=$query');
    final Uri dgisUrl = Uri.parse('dgis://2gis.ru/search/$query');

    try {
      // Пытаемся запустить geo-интент (выбор карт)
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else if (await canLaunchUrl(dgisUrl)) {
        await launchUrl(dgisUrl);
      } else {
        // Если совсем ничего нет, открываем браузер
        final Uri webUrl = Uri.parse('https://www.google.com/maps/search/$query');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Ошибка карт: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vision Assistant")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Кнопка Видения
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VisionScreen(cameras: cameras),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt, size: 40),
                label: const Text("Режим Видения", style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
          // Кнопка Навигации
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _openMap, // Просто передаем имя функции
                icon: const Icon(Icons.map, size: 40),
                label: const Text("Навигация", style: TextStyle(fontSize: 24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}