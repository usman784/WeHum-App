import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

/// Username input with a live check (free? allowed?) and tappable suggestions, like Instagram. Calls [onChanged] with the
/// text and whether it is currently valid and free. Needs a session (a guest is enough).
class UsernameField extends StatefulWidget {
  const UsernameField({super.key, required this.onChanged, this.initial = '', this.seed = '', this.enabled = true, this.helper, this.fieldKey, this.autoFill = true});
  final void Function(String value, bool ok) onChanged;
  final String initial;
  /// A first name or e-mail the suggestions are built from.
  final String seed;
  final bool enabled;
  final String? helper;
  final Key? fieldKey;
  /// Fill an empty field with the first suggestion (sign-up). Editing an existing name never does.
  final bool autoFill;
  @override
  State<UsernameField> createState() => UsernameFieldState();
}

class UsernameFieldState extends State<UsernameField> {
  late final TextEditingController _text = TextEditingController(text: widget.initial);
  late final MeRepository _me = Get.find();
  Timer? _debounce;
  bool? _ok;
  bool _checking = false;
  String? _reason;
  List<String> _suggestions = const [];
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initial.isEmpty && widget.autoFill) {
      _loadSuggestions();
    } else {
      _ok = true; // what is saved is fine until the person edits it
    }
  }

  @override
  void didUpdateWidget(covariant UsernameField old) {
    super.didUpdateWidget(old);
    if (widget.initial != old.initial && _text.text != widget.initial) {
      _text.text = widget.initial;
      _ok = widget.initial.isNotEmpty ? true : null;
    }
    if (widget.autoFill && widget.initial.isEmpty && _text.text.isEmpty && widget.seed != old.seed && widget.seed.length >= 2) _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final s = await _me.suggestUsernames(widget.seed.isEmpty ? 'sitter' : widget.seed);
      if (!mounted) return;
      setState(() => _suggestions = s);
      if (widget.autoFill && _text.text.isEmpty && s.isNotEmpty) _use(s.first); // a good default, editable
    } catch (_) {/* offline: the person types one */}
  }

  void _use(String v) {
    _text.text = v;
    _text.selection = TextSelection.collapsed(offset: v.length);
    _check(v, immediate: true);
  }

  void _check(String v, {bool immediate = false}) {
    _debounce?.cancel();
    final value = v.trim().toLowerCase();
    if (value.isEmpty) {
      setState(() { _ok = null; _reason = null; _checking = false; });
      widget.onChanged('', false);
      return;
    }
    setState(() { _checking = true; _ok = null; });
    widget.onChanged(value, false);
    final gen = ++_gen;
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 450), () async {
      try {
        final r = await _me.checkUsername(value);
        if (!mounted || gen != _gen) return;
        setState(() { _checking = false; _ok = r.available; _reason = r.reason; if (r.suggestions.isNotEmpty) _suggestions = r.suggestions; });
        widget.onChanged(value, r.available);
      } catch (_) {
        if (!mounted || gen != _gen) return;
        setState(() { _checking = false; _ok = null; _reason = 'Couldn’t check right now'; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = _checking
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : _ok == true
            ? Icon(Icons.check_circle_rounded, color: c.success, size: 22, key: const Key('username-ok'))
            : _ok == false
                ? Icon(Icons.error_outline_rounded, color: c.dangerText, size: 22, key: const Key('username-bad'))
                : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        key: widget.fieldKey ?? const Key('username-field'), controller: _text, enabled: widget.enabled, onChanged: _check, autocorrect: false, enableSuggestions: false,
        textInputAction: TextInputAction.next, maxLength: 20, style: AppText.bodyLarge.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          labelText: 'Username', prefixText: '@', counterText: '', filled: true, fillColor: c.surfaceInput,
          helperText: _reason == null ? widget.helper : null, helperMaxLines: 2, errorText: _ok == false ? _reason : null, errorMaxLines: 2,
          suffixIcon: status == null ? null : Padding(padding: const EdgeInsets.all(14), child: status),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)),
        ),
      ),
      if (widget.enabled && _suggestions.isNotEmpty) ...[
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _suggestions.where((s) => s != _text.text.trim().toLowerCase()).take(4))
              ActionChip(
                key: Key('username-suggestion-$s'), label: Text('@$s', style: AppText.bodySmall.copyWith(color: c.textPrimary)), onPressed: () => _use(s),
                backgroundColor: c.surface, side: BorderSide(color: c.border), shape: const StadiumBorder(),
              ),
          ]),
        ),
      ],
    ]);
  }
}
