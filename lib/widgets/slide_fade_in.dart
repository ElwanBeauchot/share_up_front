import 'package:flutter/material.dart';

class SlideFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const SlideFadeIn({
    super.key,
    required this.child,
    required this.delay,
  });

  @override
  State<SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<SlideFadeIn> {
  bool _show = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(-0.06, 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
