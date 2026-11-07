import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _popped = false;
  bool _torchOn = false;
  double _scaleStart = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_popped) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw == null) return;
    _popped = true;
    Navigator.pop(context, _normalizar(raw));
  }

  /// Códigos que iniciam com "0" (ex.: EAN-13 de UPC-A) — ignora o(s) zero(s)
  /// inicial(is) e lê a partir do primeiro dígito diferente de zero.
  String _normalizar(String raw) {
    if (!raw.startsWith('0')) return raw;
    final semZeros = raw.replaceFirst(RegExp(r'^0+'), '');
    return semZeros.isEmpty ? raw : semZeros;
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStart = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_scaleStart * details.scale).clamp(1.0, 8.0);
    if (newZoom != _currentZoom) {
      _currentZoom = newZoom;
      _controller.setZoomScale((_currentZoom - 1) / 7);
      setState(() {});
    }
  }

  Future<void> _toggleLanterna() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final vfWidth = w * 0.85;
            const vfHeight = 200.0;
            final vfRect = Rect.fromLTWH(
              (w - vfWidth) / 2,
              (h - vfHeight) / 2 - 30,
              vfWidth,
              vfHeight,
            );
            return Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.pop(context);
                    });
                    return const Center(
                      child: Text(
                        'Não foi possível acessar a câmera',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
                CustomPaint(
                  size: Size(w, h),
                  painter: _DimHolePainter(vfRect, 16),
                ),
                Positioned.fromRect(
                  rect: vfRect,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: vfRect.top - 30,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Escanear código de barras',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: vfRect.bottom + 8,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'Centralize o código para escanear',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
                Positioned(
                  left: (w - vfWidth) / 2,
                  bottom: 32,
                  child: SizedBox(
                    width: vfWidth,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _toggleLanterna,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: _torchOn
                            ? Colors.white
                            : Colors.transparent,
                      ),
                      child: Text(
                        'Lanterna',
                        style: TextStyle(
                          color: _torchOn ? Colors.black : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_currentZoom > 1.0)
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DimHolePainter extends CustomPainter {
  final Rect hole;
  final double radius;
  _DimHolePainter(this.hole, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter old) =>
      old.hole != hole || old.radius != radius;
}
