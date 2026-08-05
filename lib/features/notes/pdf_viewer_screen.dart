import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PDFViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final bool isLocal;

  const PDFViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.isLocal = false,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _pdfReady = false;
  bool _isDownloading = false;
  String _errorMessage = '';
  String? _localFilePath;
  double _downloadProgress = 0.0;
  PDFViewController? _pdfController;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _launchPdfWeb();
    } else {
      _checkLocalFile();
    }
  }

  Future<void> _launchPdfWeb() async {
    final url = Uri.parse(widget.pdfUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not open PDF in browser.";
        });
      }
    }
  }

  Future<void> _checkLocalFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = '';
    });
    try {
      final dir = await getApplicationDocumentsDirectory();
      String? localPath;

      if (widget.isLocal) {
        if (await File(widget.pdfUrl).exists()) {
          localPath = widget.pdfUrl;
        }
      }

      if (localPath == null) {
        final metaFile = File('${dir.path}/downloads_meta.txt');
        if (await metaFile.exists()) {
          final lines = await metaFile.readAsLines();
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            final parts = line.split('|||');
            if (parts.length >= 3) {
              final noteId = parts[0];
              final title = parts[1];
              final metaPdfUrl = parts[2];

              if (metaPdfUrl == widget.pdfUrl) {
                final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
                final path1 = '${dir.path}/${sanitizedTitle}_$noteId.pdf';
                final path2 = '${dir.path}/$noteId.pdf';
                if (await File(path1).exists()) {
                  localPath = path1;
                  break;
                } else if (await File(path2).exists()) {
                  localPath = path2;
                  break;
                }
              }
            }
          }
        }
      }

      if (localPath == null) {
        if (await File(widget.pdfUrl).exists()) {
          localPath = widget.pdfUrl;
        }
      }

      if (localPath != null) {
        if (mounted) {
          setState(() {
            _localFilePath = localPath;
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
        }
        return;
      }

      bool isOffline = false;
      try {
        final lookup = await InternetAddress.lookup('example.com')
            .timeout(const Duration(seconds: 3));
        if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) {
          isOffline = true;
        }
      } catch (_) {
        isOffline = true;
      }

      if (isOffline) {
        if (mounted) {
          setState(() {
            _errorMessage = "This PDF is not available offline.\nPlease connect to the internet and download it first.";
            _isDownloading = false;
          });
        }
        return;
      }

      await _downloadPDFForViewing();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "This PDF is not available offline.\nPlease connect to the internet and download it first.";
          _isDownloading = false;
        });
      }
    }
  }

  /// Downloads remote PDF to a temp file for rendering
  Future<void> _downloadPDFForViewing() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = '';
    });

    try {
      String finalUrl = widget.pdfUrl;
      if (finalUrl.isEmpty) {
        throw Exception('This file could not be loaded. Please try again later.');
      }

      if (finalUrl.contains('res.cloudinary.com') && !finalUrl.contains('/fl_attachment/')) {
        finalUrl = finalUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
      }

      final request = http.Request('GET', Uri.parse(finalUrl));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        throw Exception('This file could not be loaded. (Error ${response.statusCode})');
      }
      
      final contentLength = response.contentLength ?? 0;

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/viewer_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = received / contentLength;
          });
        }
      }

      await sink.close();

      if (mounted) {
        setState(() {
          _localFilePath = file.path;
          _isDownloading = false;
          _downloadProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final msg = e.toString();
          if (msg.contains('SocketException') ||
              msg.contains('ClientException') ||
              msg.contains('Failed host lookup') ||
              msg.contains('Connection failed')) {
            _errorMessage = "This PDF is not available offline.\nPlease connect to the internet and download it first.";
          } else {
            String displayMsg = msg;
            if (displayMsg.startsWith('Exception: ')) {
              displayMsg = displayMsg.substring(11);
            }
            _errorMessage = displayMsg.contains('could not be loaded')
                ? displayMsg
                : 'Could not load PDF: $displayMsg';
          }
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1a1a2e),
      appBar: AppBar(
        backgroundColor: const Color(0xff1a1a2e),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTextStyles.headingSmall
                  .copyWith(color: Colors.white, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_pdfReady)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: AppTextStyles.bodySmall
                    .copyWith(color: Colors.white60, fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (_pdfReady) ...[
            IconButton(
              icon: const Icon(Icons.first_page_rounded),
              onPressed: () => _pdfController?.setPage(0),
              tooltip: 'First Page',
            ),
            IconButton(
              icon: const Icon(Icons.last_page_rounded),
              onPressed: () =>
                  _pdfController?.setPage(_totalPages - 1),
              tooltip: 'Last Page',
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _pdfReady ? _buildPageNavBar() : null,
    );
  }

  Widget _buildBody() {
    // Error state
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 72, color: AppColors.error),
              const SizedBox(height: 20),
              Text(
                'Failed to Load PDF',
                style:
                    AppTextStyles.headingMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style:
                    AppTextStyles.bodyMedium.copyWith(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _errorMessage = '');
                  if (kIsWeb) {
                    _launchPdfWeb();
                  } else {
                    _checkLocalFile();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded, size: 72, color: AppColors.accent),
            const SizedBox(height: 20),
            Text(
              'PDF opened in new tab!',
              style: AppTextStyles.headingMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _launchPdfWeb,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Again'),
            ),
          ],
        ),
      );
    }

    // Downloading/loading state
    if (_isDownloading || _localFilePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated PDF icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded,
                    size: 52, color: AppColors.accent),
              ),
              const SizedBox(height: 28),
              Text(
                'Loading PDF...',
                style:
                    AppTextStyles.headingSmall.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _downloadProgress > 0
                    ? '${(_downloadProgress * 100).toStringAsFixed(0)}% downloaded'
                    : 'Preparing document...',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // PDF rendering
    return Stack(
      children: [
        PDFView(
          filePath: _localFilePath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          defaultPage: _currentPage,
          onRender: (pages) {
            if (mounted) {
              setState(() {
                _totalPages = pages ?? 0;
                _pdfReady = true;
              });
            }
          },
          onViewCreated: (controller) {
            _pdfController = controller;
          },
          onError: (error) {
            if (mounted) {
              setState(() => _errorMessage = error.toString());
            }
          },
          onPageError: (page, error) {
            if (mounted) {
              setState(() => _errorMessage = 'Error on page $page: $error');
            }
          },
          onPageChanged: (page, total) {
            if (mounted) {
              setState(() {
                _currentPage = page ?? 0;
                _totalPages = total ?? 0;
              });
            }
          },
        ),

        // Loading overlay while PDF renders
        if (!_pdfReady)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
      ],
    );
  }

  Widget _buildPageNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xff1a1a2e),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous page
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 32),
            onPressed: _currentPage > 0
                ? () => _pdfController?.setPage(_currentPage - 1)
                : null,
          ),

          // Page progress bar
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        _totalPages > 0 ? (_currentPage + 1) / _totalPages : 0,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          // Next page
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 32),
            onPressed: _currentPage < _totalPages - 1
                ? () => _pdfController?.setPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
