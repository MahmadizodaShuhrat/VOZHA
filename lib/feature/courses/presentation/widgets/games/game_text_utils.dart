import 'package:flutter/material.dart';

/// Shared text parsing utilities for course game widgets.
/// Handles <b>, <u>, <i> tags and *DropElement*/*Input...* markers.

/// Parse text with HTML <b>/<u>/<i> tags into TextSpan with proper styling.
/// Returns a RichText widget instead of plain Text.
///
/// Example:
///   "The girl's <b>positive</b> words made me feel better."
///   → "The girl's " + **positive** + " words made me feel better."
TextSpan parseHtmlTags(String text, {TextStyle? baseStyle}) {
  // Ensure color is always set — RichText defaults to white if no color!
  const defaultStyle = TextStyle(
    fontSize: 15,
    color: Color(0xFF333333),
    height: 1.4,
  );
  final style = defaultStyle.merge(baseStyle);

  final spans = <InlineSpan>[];
  // Regex to match <b>...</b>, <u>...</u>, <i>...</i>
  final regex = RegExp(r'<(b|u|i)>(.*?)</\1>', caseSensitive: false);

  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    // Add text before the tag
    if (match.start > lastEnd) {
      spans.add(
        TextSpan(text: text.substring(lastEnd, match.start), style: style),
      );
    }

    final tag = match.group(1)!.toLowerCase();
    final content = match.group(2)!;

    TextStyle tagStyle;
    switch (tag) {
      case 'b':
        tagStyle = style.copyWith(fontWeight: FontWeight.w700);
        break;
      case 'u':
        tagStyle = style.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w700,
        );
        break;
      case 'i':
        tagStyle = style.copyWith(fontStyle: FontStyle.italic);
        break;
      default:
        tagStyle = style;
    }

    spans.add(TextSpan(text: content, style: tagStyle));
    lastEnd = match.end;
  }

  // Add remaining text
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: style));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text, style: style);
  }

  return TextSpan(children: spans);
}

/// Build a RichText widget from text with HTML tags.
Widget buildRichTextFromHtml(String text, {TextStyle? baseStyle}) {
  return RichText(text: parseHtmlTags(text, baseStyle: baseStyle));
}

/// Strip *DropElement* from source text, returning just the text part.
/// "spr *DropElement*." → "spr"
String stripDropElement(String text) {
  return text
      .replaceAll('*DropElement*', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
