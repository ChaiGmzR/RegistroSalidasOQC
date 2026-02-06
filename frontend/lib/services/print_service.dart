import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintConfig {
  String? printerName;
  PaperOrientation orientation;
  PaperSize paperSize;
  double marginTop;
  double marginBottom;
  double marginLeft;
  double marginRight;

  PrintConfig({
    this.printerName,
    this.orientation = PaperOrientation.portrait,
    this.paperSize = PaperSize.letter,
    this.marginTop = 10,
    this.marginBottom = 10,
    this.marginLeft = 10,
    this.marginRight = 10,
  });

  Map<String, dynamic> toJson() => {
        'printerName': printerName,
        'orientation': orientation.index,
        'paperSize': paperSize.index,
        'marginTop': marginTop,
        'marginBottom': marginBottom,
        'marginLeft': marginLeft,
        'marginRight': marginRight,
      };

  factory PrintConfig.fromJson(Map<String, dynamic> json) => PrintConfig(
        printerName: json['printerName'],
        orientation: PaperOrientation.values[json['orientation'] ?? 0],
        paperSize: PaperSize.values[json['paperSize'] ?? 0],
        marginTop: (json['marginTop'] ?? 10).toDouble(),
        marginBottom: (json['marginBottom'] ?? 10).toDouble(),
        marginLeft: (json['marginLeft'] ?? 10).toDouble(),
        marginRight: (json['marginRight'] ?? 10).toDouble(),
      );
}

enum PaperOrientation { portrait, landscape }

enum PaperSize {
  letter, // 8.5 x 11 in
  legal, // 8.5 x 14 in
  a4, // 210 x 297 mm
  a5, // 148 x 210 mm
  halfLetter, // 5.5 x 8.5 in
  custom,
}

extension PaperSizeExtension on PaperSize {
  String get displayName {
    switch (this) {
      case PaperSize.letter:
        return 'Carta (8.5" x 11")';
      case PaperSize.legal:
        return 'Oficio (8.5" x 14")';
      case PaperSize.a4:
        return 'A4 (210 x 297 mm)';
      case PaperSize.a5:
        return 'A5 (148 x 210 mm)';
      case PaperSize.halfLetter:
        return 'Media Carta (5.5" x 8.5")';
      case PaperSize.custom:
        return 'Personalizado';
    }
  }

  PdfPageFormat get pdfFormat {
    switch (this) {
      case PaperSize.letter:
        return PdfPageFormat.letter;
      case PaperSize.legal:
        return PdfPageFormat.legal;
      case PaperSize.a4:
        return PdfPageFormat.a4;
      case PaperSize.a5:
        return PdfPageFormat.a5;
      case PaperSize.halfLetter:
        return const PdfPageFormat(
            5.5 * PdfPageFormat.inch, 8.5 * PdfPageFormat.inch);
      case PaperSize.custom:
        return PdfPageFormat.letter;
    }
  }
}

class PrintService {
  static PrintConfig _config = PrintConfig();
  static const String _configFileName = 'print_config.json';

  static PrintConfig get config => _config;

  static Future<void> loadConfig() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_configFileName');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final json = jsonDecode(jsonString);
        _config = PrintConfig.fromJson(json);
      }
    } catch (e) {
      print('Error loading print config: $e');
    }
  }

  static Future<void> saveConfig(PrintConfig config) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_configFileName');

      await file.writeAsString(jsonEncode(config.toJson()));
      _config = config;
    } catch (e) {
      print('Error saving print config: $e');
    }
  }

  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('Error getting printers: $e');
      return [];
    }
  }

  // Clase para datos de caja con fecha LQC
  static List<Map<String, String>> boxCodesToMapList(List<String> boxCodes) {
    return boxCodes.map((code) => {'boxCode': code, 'lqcDate': ''}).toList();
  }

  static Future<bool> printRejectionTicket({
    required String rejectionFolio,
    required String exitFolio,
    required String partNumber,
    required String partDescription,
    required int quantity,
    required String operatorName,
    required String operatorId,
    required String observations,
    required List<Map<String, String>> boxesData, // [{boxCode, lqcDate}]
    required DateTime rejectionDate,
  }) async {
    try {
      // Load logo image
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/ImagenLogo1.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (e) {
        print('Error loading logo: $e');
      }

      final pdf = await _buildRejectionPdf(
        rejectionFolio: rejectionFolio,
        exitFolio: exitFolio,
        partNumber: partNumber,
        partDescription: partDescription,
        quantity: quantity,
        operatorName: operatorName,
        operatorId: operatorId,
        observations: observations,
        boxesData: boxesData,
        rejectionDate: rejectionDate,
        logoImage: logoImage,
      );

      // Print the document
      if (_config.printerName != null) {
        final printers = await getAvailablePrinters();
        final printer = printers.firstWhere(
          (p) => p.name == _config.printerName,
          orElse: () => printers.first,
        );

        return await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => pdf.save(),
        );
      } else {
        // Show print dialog if no printer configured
        return await Printing.layoutPdf(
          onLayout: (format) => pdf.save(),
        );
      }
    } catch (e) {
      print('Error printing rejection ticket: $e');
      return false;
    }
  }

  static PdfPageFormat _getPageFormat() {
    PdfPageFormat format = _config.paperSize.pdfFormat;

    // Aplicar márgenes (siempre orientación vertical)
    format = format.copyWith(
      marginTop: _config.marginTop * PdfPageFormat.mm,
      marginBottom: _config.marginBottom * PdfPageFormat.mm,
      marginLeft: _config.marginLeft * PdfPageFormat.mm,
      marginRight: _config.marginRight * PdfPageFormat.mm,
    );

    return format;
  }

  static Future<pw.Document> _buildRejectionPdf({
    required String rejectionFolio,
    required String exitFolio,
    required String partNumber,
    required String partDescription,
    required int quantity,
    required String operatorName,
    required String operatorId,
    required String observations,
    required List<Map<String, String>> boxesData,
    required DateTime rejectionDate,
    pw.MemoryImage? logoImage,
  }) async {
    final pdf = pw.Document();

    // Get page format based on config
    PdfPageFormat format = _getPageFormat();

    // Generate QR data
    final qrData =
        'RECHAZO:$rejectionFolio|FOLIO:$exitFolio|PN:$partNumber|QTY:$quantity';

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Logo a la izquierda, título centrado
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo a la izquierda
                    if (logoImage != null)
                      pw.Image(logoImage, width: 90, height: 32),
                    if (logoImage != null) pw.SizedBox(width: 10),
                    // Título centrado
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'MATERIAL RECHAZADO - OQC',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'ILSAN ELECTRONICS',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Main content with QR
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side - Info
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Folio Rechazo:', rejectionFolio),
                        _buildInfoRow('Folio Salida:', exitFolio),
                        _buildInfoRow('Fecha:', _formatDate(rejectionDate)),
                        _buildInfoRow('Hora:', _formatTime(rejectionDate)),
                        pw.SizedBox(height: 8),
                        _buildInfoRow('Número de Parte:', partNumber),
                        _buildInfoRow('Descripción:', partDescription),
                        _buildInfoRow('Cantidad:', '$quantity piezas'),
                        pw.SizedBox(height: 8),
                        _buildInfoRow('Operador:', operatorName),
                        _buildInfoRow('No. Empleado:', operatorId),
                      ],
                    ),
                  ),
                  // Right side - QR
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.dataMatrix(),
                          data: qrData,
                          width: 70,
                          height: 70,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          rejectionFolio,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Box codes table section - Layout de 3 columnas
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(6),
                      color: PdfColors.grey300,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CAJAS RECHAZADAS',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            '(Información del sistema)',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Multi-column layout for boxes
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: _buildBoxesMultiColumn(boxesData),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Observations
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OBSERVACIONES:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      observations.isEmpty ? 'Sin observaciones' : observations,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Signature areas for rejection
              pw.Text(
                'FIRMAS DE RECHAZO:',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSignatureAreaSimple('Inspector OQC'),
                  _buildSignatureAreaSimple('Manufactura'),
                  _buildSignatureAreaSimple('Calidad'),
                ],
              ),
              pw.SizedBox(height: 70),

              // Signature areas for release
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LIBERACIÓN DEL MATERIAL:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildSignatureAreaWithDate('Manufactura'),
                        _buildSignatureAreaWithDate('Calidad'),
                        _buildSignatureAreaWithDate('OQC'),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer
              pw.Spacer(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Documento generado automáticamente',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Destino: CONTENCIÓN',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Firma simple sin fecha/hora para sección de rechazo
  static pw.Widget _buildSignatureAreaSimple(String title) {
    return pw.Container(
      width: 120,
      child: pw.Column(
        children: [
          pw.Container(
            width: 110,
            height: 30,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide()),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(title,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureAreaWithDate(String title) {
    return pw.Container(
      width: 120,
      child: pw.Column(
        children: [
          pw.Container(
            width: 110,
            height: 30,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide()),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(title,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Fecha: ', style: const pw.TextStyle(fontSize: 7)),
              pw.Container(
                width: 50,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text('____/____/____',
                    style: const pw.TextStyle(fontSize: 6)),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Hora: ', style: const pw.TextStyle(fontSize: 7)),
              pw.Container(
                width: 50,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
                child: pw.Text('____:____',
                    style: const pw.TextStyle(fontSize: 6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Construir layout de cajas en múltiples columnas (máx 5 por columna)
  static pw.Widget _buildBoxesMultiColumn(List<Map<String, String>> boxesData) {
    const int itemsPerColumn = 5;
    final int totalItems = boxesData.length;
    final int numColumns = (totalItems / itemsPerColumn).ceil().clamp(1, 3);

    // Dividir los datos en columnas
    List<List<Map<String, String>>> columns = [];
    for (int i = 0; i < numColumns; i++) {
      int start = i * itemsPerColumn;
      int end = (start + itemsPerColumn).clamp(0, totalItems);
      if (start < totalItems) {
        columns.add(boxesData.sublist(start, end));
      }
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: columns.asMap().entries.map((colEntry) {
        final colIndex = colEntry.key;
        final colData = colEntry.value;
        final baseIndex = colIndex * itemsPerColumn;

        return pw.Expanded(
          child: pw.Padding(
            padding: pw.EdgeInsets.only(
              right: colIndex < columns.length - 1 ? 8 : 0,
            ),
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(18),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FixedColumnWidth(35),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text('#',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 6)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text('Código',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 6)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text('Pzas',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 6)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text('No. Parte',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 6)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(2),
                      child: pw.Text('LQC',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 6)),
                    ),
                  ],
                ),
                // Data rows
                ...colData.asMap().entries.map((entry) {
                  final idx = baseIndex + entry.key + 1;
                  final box = entry.value;
                  final lqcDate = box['lqcDate'] ?? '';
                  final quantity = box['quantity'] ?? '';
                  final partNumber = box['partNumber'] ?? '';
                  // Formatear fecha LQC (solo mostrar fecha y hora corta)
                  String formattedLqc = '';
                  if (lqcDate.isNotEmpty) {
                    try {
                      final dateStr = lqcDate
                          .replaceAll('T', ' ')
                          .replaceAll('Z', '')
                          .split('.')[0];
                      final parts = dateStr.split(' ');
                      if (parts.length >= 2) {
                        final datePart = parts[0].split('-');
                        final timePart = parts[1].split(':');
                        if (datePart.length >= 3 && timePart.length >= 2) {
                          formattedLqc =
                              '${datePart[2]}/${datePart[1]} ${timePart[0]}:${timePart[1]}';
                        }
                      }
                    } catch (e) {
                      formattedLqc = lqcDate.length > 10
                          ? lqcDate.substring(0, 10)
                          : lqcDate;
                    }
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text('$idx',
                            style: const pw.TextStyle(fontSize: 6)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(box['boxCode'] ?? '',
                            style: const pw.TextStyle(fontSize: 6)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(quantity,
                            style: const pw.TextStyle(fontSize: 6)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(partNumber,
                            style: const pw.TextStyle(fontSize: 5)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text(formattedLqc,
                            style: const pw.TextStyle(fontSize: 5)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
