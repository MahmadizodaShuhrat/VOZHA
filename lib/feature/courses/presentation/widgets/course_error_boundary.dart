import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Catches build-time exceptions in a single child widget and shows
/// a small friendly card instead of the default red error screen.
/// Lets a malformed game / quiz / video keep the rest of the lesson
/// usable instead of taking the whole tab down.
///
/// Note: Flutter's render tree only surfaces synchronous build/layout
/// errors here. Async failures should still be handled inside the
/// failing widget itself (e.g. `FutureBuilder`'s error branch).
class CourseErrorBoundary extends StatefulWidget {
  final Widget child;

  /// Optional builder invoked instead of the default fallback when an
  /// error is caught. Useful when a specific section needs custom
  /// recovery UI.
  final Widget Function(BuildContext, FlutterErrorDetails)? fallback;

  const CourseErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  State<CourseErrorBoundary> createState() => _CourseErrorBoundaryState();
}

class _CourseErrorBoundaryState extends State<CourseErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
    // The previous handler still gets called (so Crashlytics, etc.
    // keep working). We just intercept it locally to render a nicer
    // fallback for THIS subtree.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      if (!mounted) return;
      setState(() => _error = details);
    };
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    if (err == null) return widget.child;
    if (widget.fallback != null) return widget.fallback!(context, err);
    return _DefaultFallback(error: err, onRetry: () {
      setState(() => _error = null);
    });
  }
}

class _DefaultFallback extends StatelessWidget {
  final FlutterErrorDetails error;
  final VoidCallback onRetry;
  const _DefaultFallback({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFDB022).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE48B0B), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'course_error_boundary_title'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'course_error_boundary_message'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('course_error_boundary_retry'.tr()),
          ),
        ],
      ),
    );
  }
}
