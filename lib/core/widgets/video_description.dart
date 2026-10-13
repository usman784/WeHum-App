import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// "Video description": the text under a YouTube video, collapsed to a few lines. Links in it are tappable and open in an
/// in-app browser view (a web view with its own Done button), never in a different app.
class VideoDescription extends StatefulWidget {
  const VideoDescription(this.text, {super.key, this.collapsedLines = 4});
  final String text;
  final int collapsedLines;
  @override
  State<VideoDescription> createState() => _VideoDescriptionState();
}

class _VideoDescriptionState extends State<VideoDescription> {
  bool open = false;
  final _taps = <TapGestureRecognizer>[];

  static final _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
  static const _trailing = '.,;:!?)]}\'"';

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  /// Plain text with the links as tappable spans. Punctuation that ends a sentence is not part of the link.
  List<InlineSpan> _spans(AppColors c, TextStyle base) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _url.allMatches(widget.text)) {
      var link = m.group(0)!;
      while (link.isNotEmpty && _trailing.contains(link[link.length - 1])) {
        link = link.substring(0, link.length - 1);
      }
      if (m.start > at) out.add(TextSpan(text: widget.text.substring(at, m.start)));
      final tap = TapGestureRecognizer()..onTap = () => openInApp(link);
      _taps.add(tap);
      out.add(TextSpan(text: link, recognizer: tap, style: base.copyWith(color: c.emberText, decoration: TextDecoration.underline, decorationColor: c.emberText)));
      at = m.start + link.length;
    }
    if (at < widget.text.length) out.add(TextSpan(text: widget.text.substring(at)));
    return out;
  }

  static Future<void> openInApp(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = AppText.bodySmall.copyWith(color: c.textBody, height: 1.45);
    return Container(
      key: const Key('video-description'),
      width: double.infinity, padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true, expanded: open, label: 'Video description',
          child: InkWell(
            key: const Key('video-description-toggle'), onTap: () => setState(() => open = !open),
            child: SizedBox(height: 40, child: Row(children: [
              Expanded(child: Text('Video description', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.textSecondary),
            ])),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic, alignment: Alignment.topCenter,
          child: Text.rich(TextSpan(style: base, children: _spans(c, base)), key: const Key('video-description-text'), maxLines: open ? null : widget.collapsedLines, overflow: open ? TextOverflow.visible : TextOverflow.ellipsis),
        ),
        InkWell(
          onTap: () => setState(() => open = !open),
          child: SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: Text(open ? 'Show less' : 'Show more', style: AppText.bodySmall.copyWith(color: c.emberText, fontWeight: FontWeight.w700)))),
        ),
      ]),
    );
  }
}
