// main.dart (UI + Upload + Play & Download Result)
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Video AI Editor',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

// API SERVICE
class ApiService {
  static const baseUrl = "http://YOUR_SERVER_IP:8000";

  static Future<String> uploadVideo(File videoFile, String platform) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse("$baseUrl/process-video/"),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', videoFile.path),
    );

    request.fields['platform'] = platform.toLowerCase();
    var response = await request.send();
    var respStr = await response.stream.bytesToString();
    var jsonData = json.decode(respStr);
    return "$baseUrl/${jsonData['video_url']}";
  }

  static Future<String> downloadVideo(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = "${dir.path}/edited_video.mp4";
    final res = await http.get(Uri.parse(url));
    final file = File(filePath);
    await file.writeAsBytes(res.bodyBytes);
    return filePath;
  }
}

// ================= HOME SCREEN =================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Video AI Editor')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_camera_back, size: 120),
            const SizedBox(height: 20),
            const Text(
              'Create Social Media Videos in Seconds',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlatformScreen()),
                );
              },
              child: const Text('Start Editing'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= PLATFORM SELECTION =================
class PlatformScreen extends StatelessWidget {
  const PlatformScreen({super.key});

  Widget platformButton(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UploadScreen(platform: title)),
          );
        },
        child: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Platform')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            platformButton(context, 'tiktok'),
            platformButton(context, 'youtube'),
            platformButton(context, 'instagram'),
            platformButton(context, 'snapchat'),
          ],
        ),
      ),
    );
  }
}

// ================= UPLOAD SCREEN =================
class UploadScreen extends StatefulWidget {
  final String platform;
  const UploadScreen({super.key, required this.platform});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final picker = ImagePicker();
  File? selectedVideo;
  bool uploading = false;

  Future pickVideo() async {
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        selectedVideo = File(video.path);
      });
    }
  }

  Future uploadVideo() async {
    if (selectedVideo == null) return;
    setState(() => uploading = true);

    String resultUrl = await ApiService.uploadVideo(
      selectedVideo!,
      widget.platform,
    );

    setState(() => uploading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(videoUrl: resultUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Video (${widget.platform})')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload_file, size: 120),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: pickVideo,
              child: const Text('Pick Video'),
            ),
            const SizedBox(height: 20),
            if (selectedVideo != null)
              ElevatedButton(
                onPressed: uploading ? null : uploadVideo,
                child: uploading
                    ? const CircularProgressIndicator()
                    : const Text('Upload & Process'),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= RESULT SCREEN =================
class ResultScreen extends StatefulWidget {
  final String videoUrl;
  const ResultScreen({super.key, required this.videoUrl});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late VideoPlayerController controller;
  bool downloading = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  Future downloadVideo() async {
    setState(() => downloading = true);
    await ApiService.downloadVideo(widget.videoUrl);
    setState(() => downloading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Video saved to device')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Video is Ready 🎉')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (controller.value.isInitialized)
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => controller.value.isPlaying
                  ? controller.pause()
                  : controller.play(),
              child: const Text('Play / Pause'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: downloading ? null : downloadVideo,
              child: downloading
                  ? const CircularProgressIndicator()
                  : const Text('Download Video'),
            ),
          ],
        ),
      ),
    );
  }
}
