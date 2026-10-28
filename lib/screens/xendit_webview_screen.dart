import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class XenditWebViewScreen extends StatefulWidget {
  final String invoiceUrl;

  const XenditWebViewScreen({super.key, required this.invoiceUrl});

  @override
  State<XenditWebViewScreen> createState() => _XenditWebViewScreenState();
}

class _XenditWebViewScreenState extends State<XenditWebViewScreen> {
  WebViewController? _controller;
  bool _isLoadingPage = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _launchInBrowser();
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoadingPage = true;
                  _loadError = null;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoadingPage = false);
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() {
                  _isLoadingPage = false;
                  _loadError = error.description;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.invoiceUrl));
    }
  }

  Future<void> _launchInBrowser() async {
    try {
      final launched = await launchUrl(
        Uri.parse(widget.invoiceUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Could not open the Xendit checkout URL.');
      }
      if (mounted) {
        setState(() => _isLoadingPage = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingPage = false;
          _loadError = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xendit Checkout'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _loadError == null
                          ? Icons.open_in_browser
                          : Icons.error_outline,
                      size: 64,
                      color: _loadError == null
                          ? Colors.indigo
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _loadError == null
                          ? 'Xendit Checkout opened in a new browser tab.'
                          : 'Could not open Xendit Checkout.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError ??
                          'Choose a payment method on Xendit and complete checkout. '
                              'Then click "Done" here to check your order status.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _launchInBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open Xendit Checkout'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoadingPage)
                  const Center(child: CircularProgressIndicator()),
                if (_loadError != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load Xendit Checkout: $_loadError',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
