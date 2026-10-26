import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  /// First-frame colour of assets/splash_screen.mp4. Keep in sync with
  /// `splash_background` in android/app/src/main/res/values/colors.xml.
  static const background = Color(0xFF2F7DBE);

  final Widget nextScreen;

  /// Startup work that runs while the video plays; the next screen opens
  /// only after it finishes.
  final Future<void>? ready;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.ready,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(
      'assets/splash_screen.mp4',
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();

      if (!mounted) return;

      setState(() {});

      _controller.addListener(_videoListener);

      await _controller.play();
    } catch (e) {
      debugPrint('Splash video error: $e');

      // If video fails, continue to the app.
      _goToNextScreen();
    }
  }

  void _videoListener() {
    if (!_controller.value.isInitialized) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (position >= duration) {
      _goToNextScreen();
    }
  }

  Future<void> _goToNextScreen() async {
    if (_navigated || !mounted) return;

    _navigated = true;

    // Usually long done by the time the video ends.
    try {
      await widget.ready;
    } catch (e) {
      debugPrint('Startup init error: $e');
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => widget.nextScreen,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash colour (not white) while the video loads, matching the
    // Android launch screen before it.
    return Scaffold(
      backgroundColor: SplashScreen.background,
      body: SizedBox.expand(
        child: _controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}