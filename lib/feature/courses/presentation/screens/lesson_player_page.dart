import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:vozhaomuz/feature/courses/data/models/course_fixture.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

/// Lesson player — plays the video associated with a [CourseLesson].
///
/// Supports both `video.url` (HTTP, used by fixtures and the upcoming
/// backend) and `video.assetPath` (bundled asset). Once the video
/// finishes (or the user taps Continue), `onCompleted` is invoked so
/// the caller can move into the words/games flow.
///
/// Controls are deliberately minimal: tap-to-show overlay with
/// play/pause, scrub bar, position/duration, and a fullscreen toggle.
/// We don't pull in `chewie` to keep the dep surface small and the
/// look fully on-brand.
class LessonPlayerPage extends ConsumerStatefulWidget {
  final CourseLesson lesson;

  /// Optional override fired after the user taps the bottom button.
  /// When omitted, the player handles continuation itself: lessons
  /// with `words[]` push [GamePage] (loading the words into
  /// [learningWordsProvider] first), and lessons without words just
  /// pop back to the course detail page.
  final VoidCallback? onCompleted;

  const LessonPlayerPage({super.key, required this.lesson, this.onCompleted});

  @override
  ConsumerState<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends ConsumerState<LessonPlayerPage> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _initError = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final video = widget.lesson.video;
    if (video == null || (video.url == null && video.assetPath == null)) {
      _initError = true;
      return;
    }

    final controller = video.assetPath != null
        ? VideoPlayerController.asset(video.assetPath!)
        : VideoPlayerController.networkUrl(Uri.parse(video.url!));

    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
      // Auto-hide controls 2.5 s after playback starts.
      _scheduleHideControls();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _initError = true);
    });

    controller.addListener(_onTick);
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    // Detect end-of-video: position has reached duration and the
    // controller stopped playing.
    final pos = c.value.position;
    final dur = c.value.duration;
    if (!_completed && dur > Duration.zero && pos >= dur) {
      _completed = true;
      if (mounted) setState(() {});
    }
  }

  void _scheduleHideControls() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      if (_controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    HapticFeedback.lightImpact();
    if (c.value.isPlaying) {
      c.pause();
    } else {
      // If at end, restart from 0.
      if (c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
      }
      c.play();
      _scheduleHideControls();
    }
    setState(() {});
  }

  /// Default "Continue" handler. After the simplification of the
  /// flow (vocabulary intro removed at the user's request), this just
  /// returns to the previous screen — typically the lesson hub —
  /// where the user picks the final test or another sub-lesson.
  void _continueLesson() {
    _controller?.pause();
    Navigator.of(context).maybePop();
  }

  void _seekRelative(Duration delta) {
    final c = _controller;
    if (c == null) return;
    final next = c.value.position + delta;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (next > c.value.duration ? c.value.duration : next);
    c.seekTo(clamped);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(child: _videoStage()),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded,
                color: Colors.white, size: 24),
          ),
          Expanded(
            child: Text(
              widget.lesson.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _videoStage() {
    if (_initError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'lesson_video_failed'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (_showControls) _controlsOverlay(c),
        ],
      ),
    );
  }

  Widget _controlsOverlay(VideoPlayerController c) {
    final isPlaying = c.value.isPlaying;
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Column(
        children: [
          // Center play / pause + skip controls.
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _circleButton(
                  Icons.replay_10_rounded,
                  size: 26,
                  onTap: () => _seekRelative(const Duration(seconds: -10)),
                ),
                _circleButton(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 36,
                  big: true,
                  onTap: _togglePlayPause,
                ),
                _circleButton(
                  Icons.forward_10_rounded,
                  size: 26,
                  onTap: () => _seekRelative(const Duration(seconds: 10)),
                ),
              ],
            ),
          ),
          // Scrub bar + duration row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF2E90FA),
                    bufferedColor: Color(0x66FFFFFF),
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(c.value.position),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _fmt(c.value.duration),
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon,
      {required double size,
      required VoidCallback onTap,
      bool big = false}) {
    final dim = big ? 64.0 : 44.0;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: dim,
          height: dim,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: big
                ? const Color(0xFF2E90FA)
                : Colors.white.withValues(alpha: 0.15),
            boxShadow: big
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E90FA).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(color: Color(0xFF111827)),
      child: SafeArea(
        top: false,
        child: MyButton(
          width: double.infinity,
          depth: 4,
          borderRadius: 14,
          buttonColor: const Color(0xFF2E90FA),
          backButtonColor: const Color(0xFF1570EF),
          padding: const EdgeInsets.symmetric(vertical: 12),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (widget.onCompleted != null) {
              widget.onCompleted!();
              return;
            }
            _continueLesson();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _completed
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _completed
                    ? 'lesson_finished_button'.tr()
                    : 'lesson_continue_button'.tr(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
