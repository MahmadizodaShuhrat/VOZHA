import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Edit word page — mirrors Unity UIEditWord.
class EditWordPage extends StatefulWidget {
  final String wordOriginal;
  final String wordTranslation;
  final String wordTranscription;

  const EditWordPage({
    super.key,
    required this.wordOriginal,
    required this.wordTranslation,
    this.wordTranscription = '',
  });

  @override
  State<EditWordPage> createState() => _EditWordPageState();
}

class _EditWordPageState extends State<EditWordPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrlWord;
  late final TextEditingController _ctrlTranslation;
  late final TextEditingController _ctrlTranscription;
  final FocusNode _transcriptionFocus = FocusNode();

  File? _image;
  String? _audioPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _pulseController;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // IPA keys — 3 rows like Unity
  static const _row1 = ['iː', 'ɪ', 'e', 'æ', 'ɑː', 'ɒ', 'ɔː', 'ʊ', 'uː', 'ʌ'];
  static const _row2 = ['ɜː', 'ə', 'd', 'ð', 'g', 'v', 's', 'z', 'ʃ', 'r'];
  static const _row3 = ['ʒ', 'tʃ', 'dʒ', 'h', 'm', 'n', 'ŋ', 'l', 'w', 'j'];

  bool _showKeys = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ctrlWord = TextEditingController(text: widget.wordOriginal);
    _ctrlTranslation = TextEditingController(text: widget.wordTranslation);
    _ctrlTranscription = TextEditingController(text: widget.wordTranscription);

    _ctrlWord.addListener(_rebuild);
    _ctrlTranslation.addListener(_rebuild);
    _ctrlTranscription.addListener(_rebuild);
    _transcriptionFocus.addListener(() {
      setState(() => _showKeys = _transcriptionFocus.hasFocus);
    });
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _ctrlWord.dispose();
    _ctrlTranslation.dispose();
    _ctrlTranscription.dispose();
    _transcriptionFocus.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _ctrlWord.text.trim().length >= 2 &&
      _ctrlTranslation.text.trim().length >= 2 &&
      _audioPath != null;

  // ── Actions ──

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (f != null) setState(() => _image = File(f.path));
  }

  Future<void> _toggleRecord() async {
    HapticFeedback.lightImpact();
    if (_isRecording) {
      _recordTimer?.cancel();
      _pulseController.stop();
      _pulseController.reset();
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
        if (path != null) _audioPath = path;
      });
    } else {
      if (!(await Permission.microphone.request()).isGranted) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
        });
        _pulseController.repeat();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
      }
    }
  }

  Future<void> _pickAudio() async {
    HapticFeedback.lightImpact();
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r != null && r.files.single.path != null)
      setState(() => _audioPath = r.files.single.path);
  }

  void _insertKey(String s) {
    final c = _ctrlTranscription;
    final pos = c.selection.baseOffset.clamp(0, c.text.length);
    c.text = c.text.substring(0, pos) + s + c.text.substring(pos);
    c.selection = TextSelection.collapsed(offset: pos + s.length);
  }

  void _backspace() {
    if (_ctrlTranscription.text.isNotEmpty) {
      _ctrlTranscription.text = _ctrlTranscription.text.substring(
        0,
        _ctrlTranscription.text.length - 1,
      );
      _ctrlTranscription.selection = TextSelection.collapsed(
        offset: _ctrlTranscription.text.length,
      );
    }
  }

  void _save() {
    if (!_canSave) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context, {
      'english': _ctrlWord.text.trim(),
      'translation': _ctrlTranslation.text.trim(),
      'transcription': _ctrlTranscription.text.trim(),
      if (_image != null) 'imagePath': _image!.path,
      if (_audioPath != null) 'audioPath': _audioPath!,
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.arrow_back_ios, size: 22),
                  ),
                  Expanded(
                    child: Text(
                      'add_photo_sound'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // Card with 3D depth
                    SizedBox(
                      child: Stack(
                        children: [
                          // Depth shadow layer
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCDD5DF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          // Top white card
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE8ECF0),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Photo area
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: double.infinity,
                                    height: 220,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: _image != null
                                        ? Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        16,
                                                      ),
                                                      topRight: Radius.circular(
                                                        16,
                                                      ),
                                                    ),
                                                child: Image.file(
                                                  _image!,
                                                  width: double.infinity,
                                                  height: 220,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: GestureDetector(
                                                  onTap: () => setState(
                                                    () => _image = null,
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black45,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Center(
                                            child: Text.rich(
                                              TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2196F3),
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${'add_photo'.tr()} ',
                                                  ),
                                                  const TextSpan(
                                                    text: '+',
                                                    style: TextStyle(
                                                      fontSize: 22,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                // Divider
                                Container(
                                  height: 1,
                                  color: const Color(0xFFEEF2F6),
                                ),
                                // Inputs
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    children: [
                                      _input(
                                        _ctrlWord,
                                        'enter_word_original'.tr(),
                                      ),
                                      const SizedBox(height: 10),
                                      _input(
                                        _ctrlTranslation,
                                        'enter_translation'.tr(),
                                      ),
                                      const SizedBox(height: 10),
                                      _input(
                                        _ctrlTranscription,
                                        'enter_transcription'.tr(),
                                        focusNode: _transcriptionFocus,
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Audio section (hidden when keyboard is open)
                    if (!_showKeys) ...[
                      const SizedBox(height: 24),
                      _buildAudioSection(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // IPA keyboard pinned to bottom
            if (_showKeys)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _buildKeyboard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    FocusNode? focusNode,
    bool readOnly = false,
  }) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      showCursor: true,
      focusNode: focusNode,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color.fromARGB(255, 65, 67, 69),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF84CAFF), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ── IPA Keyboard (Unity style — grid rows) ──

  Widget _buildKeyboard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _keyRow(_row1),
          const SizedBox(height: 6),
          _keyRow(_row2),
          const SizedBox(height: 6),
          _keyRow(_row3),
          const SizedBox(height: 6),
          // Space + Hide + Backspace row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _keyButton(
                  'space'.tr(),
                  onTap: () => _insertKey(' '),
                  isWide: true,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _depthKey(
                  onTap: () => _transcriptionFocus.unfocus(),
                  child: const Icon(
                    Icons.keyboard_hide_outlined,
                    size: 20,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _depthKey(
                  onTap: _backspace,
                  child: const Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (k) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _keyButton(k, onTap: () => _insertKey(k)),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _keyButton(
    String label, {
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return _depthKey(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: isWide ? 13 : 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF333333),
        ),
      ),
    );
  }

  /// Key with 3D depth like MyButton
  Widget _depthKey({required VoidCallback onTap, required Widget child}) {
    const depth = 3.0;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: SizedBox(
        height: 48 + depth,
        child: Stack(
          children: [
            // Shadow/depth layer
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFCDD5DF),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            // Top face
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Audio section ──

  Widget _buildAudioSection() {
    if (_audioPath != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                if (_isPlaying) {
                  await _player.stop();
                  setState(() => _isPlaying = false);
                } else {
                  setState(() => _isPlaying = true);
                  await _player.play(DeviceFileSource(_audioPath!));
                  _player.onPlayerComplete.listen((_) {
                    if (mounted) setState(() => _isPlaying = false);
                  });
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _isPlaying
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4CAF50),
                child: Icon(
                  _isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _audioPath!.split(Platform.pathSeparator).last,
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _player.stop();
                setState(() {
                  _audioPath = null;
                  _isPlaying = false;
                });
              },
              child: const Icon(
                Icons.delete,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Mic button with pulse + 3D depth
        GestureDetector(
          onTap: _toggleRecord,
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing rings when recording
                if (_isRecording) ...[
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 130 + (40 * _pulseController.value),
                        height: 130 + (40 * _pulseController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(
                            alpha: 0.08 * (1.0 - _pulseController.value),
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 130 + (20 * _pulseController.value),
                        height: 130 + (20 * _pulseController.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(
                            alpha: 0.12 * (1.0 - _pulseController.value),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                // 3D depth mic button
                AnimatedScale(
                  scale: _isRecording ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutSine,
                  child: SizedBox(
                    width: 104,
                    height: 104 + 4,
                    child: Stack(
                      children: [
                        // Depth shadow
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF1976D2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Top face
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF42A5F5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Timer or label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isRecording
              ? Text(
                  '${_formatTime(_recordSeconds)}  •  ${'recording'.tr()}',
                  key: const ValueKey('rec'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                )
              : Text(
                  'add_pronunciation'.tr(),
                  key: const ValueKey('idle'),
                  style: AppTextStyles.bigTextStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickAudio,
          child: Text(
            'pick_audio_file'.tr(),
            style: AppTextStyles.bigTextStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  // ── Save button ──

  Widget _buildSaveButton() {
    return MyButton(
      width: double.infinity,
      height: 52,
      borderRadius: 14,
      depth: _canSave ? 4 : 0,
      buttonColor: const Color(0xFF42A5F5),
      backButtonColor: const Color(0xFF1976D2),
      // isEnabled: _canSave,
      onPressed: _canSave ? _save : null,
      child: Text(
        'save'.tr(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
