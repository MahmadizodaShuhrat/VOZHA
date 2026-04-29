import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';

class WordsBox extends StatefulWidget {
  final String? word;
  final double? width;
  final double? height;
  final String? transcription;
  final String? translation;
  final Color? topColorContainer;
  final Color? backButtonColor;
  final String? topTextContainer;
  final TextStyle? topTextStyleContainer;
  final Widget? topWordContainer;
  final double? topWidthContainer;
  final Color? topWordColorContainer;
  final bool? isIcon;
  final void Function()? onPressed;
  final Widget child;
  final String? audioPath;
  final bool isVolume;
  const WordsBox({
    super.key,
    this.transcription,
    this.translation,
    this.width,
    this.height,
    this.word,
    this.topColorContainer,
    this.backButtonColor,
    this.topTextContainer,
    this.topTextStyleContainer,
    this.topWordContainer,
    this.topWidthContainer,
    this.isIcon,
    required this.onPressed,
    required this.child,
    required this.isVolume,
    this.topWordColorContainer,
    this.audioPath,
  });

  @override
  State<WordsBox> createState() => _WordsBoxState();
}

class _WordsBoxState extends State<WordsBox> {
  final player = AudioPlayer();

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          bottom: BorderSide(
            color: widget.isVolume ? Colors.white : Color(0xFFEEF2F6),
            width: 6,
          ),
          right: BorderSide(
            color: widget.isVolume ? Colors.white : Color(0xFFEEF2F6),
            width: 2,
          ),
          left: BorderSide(
            color: widget.isVolume ? Colors.white : Color(0xFFEEF2F6),
            width: 2,
          ),
          top: BorderSide(
            color: widget.isVolume ? Colors.white : Color(0xFFEEF2F6),
            width: 2,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: widget.topWidthContainer,
            width: MediaQuery.of(context).size.width - 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              color: widget.topColorContainer ?? Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.topTextContainer != null)
                  Text(
                    "${widget.topTextContainer}",
                    style: widget.topTextStyleContainer ??
                        AppTextStyles.whiteTextStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff697586),
                        ),
                  ),
                (widget.topWordContainer != null && widget.isIcon == false)
                    ? IconButton(
                        onPressed: () {
                          playSound(widget.audioPath!);
                        },
                        icon: Icon(
                          Icons.volume_up,
                          color: Color(0xFF2E90FA),
                          size: 40,
                        ),
                      )
                    : (widget.topWordContainer != null)
                    ? widget.topWordContainer!
                    : SizedBox.shrink(),
              ],
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

final _soundPlayer = AudioPlayer();

Future<void> playSound(String audioPath) async {
  await _soundPlayer.play(AssetSource(audioPath));
}
