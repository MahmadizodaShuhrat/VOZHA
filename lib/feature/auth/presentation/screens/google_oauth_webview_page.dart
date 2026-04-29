import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens Google OAuth URL in an in-app WebView and intercepts the redirect.
///
/// Why WebView instead of Chrome Custom Tab or external browser:
/// Chrome blocks all 302 redirects from HTTPS to custom URI schemes (app://).
/// WebView doesn't have this restriction — we catch the redirect ourselves.
///
/// Flow:
///   1. WebView loads Google OAuth URL
///   2. User picks account → Google redirects to server
///   3. Server redirects to app://com.vozhaomuz?code=AUTH_CODE
///   4. NavigationDelegate intercepts the app:// navigation
///   5. Returns the auth code via Navigator.pop()
class GoogleOAuthWebViewPage extends StatefulWidget {
  final String authUrl;

  const GoogleOAuthWebViewPage({super.key, required this.authUrl});

  @override
  State<GoogleOAuthWebViewPage> createState() => _GoogleOAuthWebViewPageState();
}

class _GoogleOAuthWebViewPageState extends State<GoogleOAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🌐 WebView navigation: ${request.url}');

            // Intercept the app:// redirect — this is the OAuth callback
            if (request.url.startsWith('app://com.vozhaomuz')) {
              debugPrint('🟢 WebView: Intercepted OAuth callback!');
              final uri = Uri.parse(request.url);
              final code = uri.queryParameters['code'];
              debugPrint('🟢 WebView: auth code = ${code?.length ?? 0} chars');

              // Return the code to the caller
              Navigator.of(context).pop(code);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            debugPrint('🌐 WebView page started: $url');
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            debugPrint('🌐 WebView page finished: $url');
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('🔴 WebView error: ${error.description}');
          },
        ),
      )
      // Set user agent to look like Chrome browser (not WebView)
      // Google blocks OAuth from embedded WebViews that have "wv" in user agent.
      // We use a standard Chrome mobile user agent.
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.6099.230 Mobile Safari/537.36',
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign-In'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null), // cancelled
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
