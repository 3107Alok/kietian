import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  SoundService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  Future<void> playRegistrationSound() async {
    speak("Student Registered Successfully");
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/registered.mp3'));
    } catch (e) {
      debugPrint('Registration sound file might be missing: $e');
    }
  }

  Future<void> playAttendanceSound() async {
    speak("Attendance Marked");
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/attendance_marked.mp3'));
    } catch (e) {
      debugPrint('Attendance sound file might be missing: $e');
    }
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) return;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  void dispose() {
    _player.dispose();
    _tts.stop();
  }
}
