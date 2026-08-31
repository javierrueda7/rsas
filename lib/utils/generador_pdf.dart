import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../datos/abono_poliza.dart';
import 'formatters.dart';

class GeneradorPdf {
  static final _df  = DateFormat('dd/MM/yyyy');
  static final _dft = DateFormat('dd/MM/yyyy HH:mm');

  // ── Colores corporativos ──────────────────────────────────────────────────
  static const _azul      = PdfColor.fromInt(0xFF1C4870);
  static const _azulClaro = PdfColor.fromInt(0xFF2E5F8C);
  static const _verde     = PdfColor.fromInt(0xFF1E9B4E);
  static const _gris      = PdfColor.fromInt(0xFF616161);
  static const _grisClaro = PdfColor.fromInt(0xFFF5F5F5);
  static const _blanco    = PdfColors.white;

  // ── Estilos de texto ──────────────────────────────────────────────────────
  static pw.TextStyle _h1()   => pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _azul);
  static pw.TextStyle _h2()   => pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _azul);
  static pw.TextStyle _bold() => pw.TextStyle(fontSize: 9,  fontWeight: pw.FontWeight.bold);
  static pw.TextStyle _body() => const pw.TextStyle(fontSize: 9);
  static pw.TextStyle _mono() => pw.TextStyle(fontSize: 9, font: pw.Font.courier());
  static pw.TextStyle _small()=> const pw.TextStyle(fontSize: 8, color: _gris);
  static pw.TextStyle _label()=> pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _gris);

  // ─────────────────────────────────────────────────────────────────────────
  // Descarga genérica
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> descargar({
    required Uint8List bytes,
    required String nombre,
  }) async {
    await FileSaver.instance.saveFile(
      name: nombre,
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FACTURA individual de un abono
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> factura({required AbonoPoliza abono}) async {
    final doc = pw.Document();
    final logo = await _cargarLogo();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => _headerEmpresa(logo),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _divider(),
        pw.SizedBox(height: 8),

        // Título + número + fecha
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('COMPROBANTE DE PAGO', style: _h1()),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: _azul,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (abono.numFactura != null)
                    pw.Text('N° ${abono.numFactura}',
                        style: pw.TextStyle(
                            color: _blanco,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11)),
                  pw.Text(
                    abono.fechaPago != null ? _df.format(abono.fechaPago!) : '—',
                    style: pw.TextStyle(color: _blanco, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // Datos cliente + datos póliza en dos columnas
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _bloqueInfo('DATOS DEL CLIENTE', [
              ('Cliente',     abono.nombreCliente ?? '—'),
              ('Documento',   '${abono.tipodocCliente ?? ''} ${abono.docCliente ?? '—'}'),
              ('Teléfono',    abono.telCliente ?? '—'),
              ('Correo',      abono.correoCliente ?? '—'),
              ('Dirección',   abono.dirCliente ?? '—'),
            ])),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _bloqueInfo('DATOS DE LA PÓLIZA', [
              ('N° Póliza',     abono.nroPoliza ?? '${abono.idPoliza}'),
              ('Aseguradora',   abono.nombreAseg ?? '—'),
              ('Ramo',          abono.nombreRamo ?? '—'),
              ('Producto',      abono.nombreProd ?? '—'),
              ('Bien asegurado',abono.bienAsegurado ?? '—'),
              if (abono.finiPoliza != null && abono.ffinPoliza != null)
                ('Vigencia', '${_df.format(abono.finiPoliza!)} – ${_df.format(abono.ffinPoliza!)}'),
            ])),
          ],
        ),
        pw.SizedBox(height: 16),

        // Tabla de detalle
        pw.Text('DETALLE DEL PAGO', style: _h2()),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _grisClaro, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            _tablaHeader(['Concepto', 'Vlr Prima Póliza', 'Abono / Comisión']),
            _tablaFila([
              'Prima de póliza',
              '\$ ${Fmt.money(abono.vlrprimaPoliza)}',
              '\$ ${Fmt.money(abono.vlrabonoprima)}',
            ]),
            if (abono.porccomision > 0)
              _tablaFila([
                'Comisión (${Fmt.percent(abono.porccomision, dec: 1)})',
                '',
                '\$ ${Fmt.money(abono.vlrcomision)}',
              ]),
            if (abono.porccomad > 0)
              _tablaFila([
                'Com. Adicional (${Fmt.percent(abono.porccomad, dec: 1)})',
                '',
                '\$ ${Fmt.money(abono.vlrcomad)}',
              ]),
            _tablaTotal([
              'TOTAL COMISIÓN',
              '',
              '\$ ${Fmt.money(abono.vlrcomision + abono.vlrcomad)}',
            ]),
          ],
        ),
        pw.SizedBox(height: 14),

        // Estado + reporte + N° factura
        pw.Row(children: [
          _pill('Estado', labelEstadoPago(abono.estadoPago), _azul),
          pw.SizedBox(width: 8),
          if (abono.idrepPago != null)
            _pill('Reporte', '#${abono.idrepPago}', _verde),
          pw.SizedBox(width: 8),
          if (abono.numFactura != null)
            _pill('Factura', abono.numFactura!, _gris),
        ]),
        pw.SizedBox(height: 8),

        if (abono.obsPago != null && abono.obsPago!.isNotEmpty) ...[
          pw.Text('Observaciones:', style: _bold()),
          pw.Text(abono.obsPago!, style: _body()),
          pw.SizedBox(height: 8),
        ],

        _divider(),
        pw.SizedBox(height: 6),
        if (abono.apodoUsuario != null)
          pw.Text(
            'Registrado por: ${abono.apodoUsuario}'
            '${abono.fcreado != null ? '  –  ${_dft.format(abono.fcreado!)}' : ''}',
            style: _small(),
          ),
      ],
    ));

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESTADO DE CUENTA por póliza
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> estadoCuentaPoliza({
    required List<AbonoPoliza> abonos,
    required num totalAbonado,
    required num totalComision,
    required num primaPoliza,
    required num saldo,
  }) async {
    final doc  = pw.Document();
    final logo = await _cargarLogo();
    final a    = abonos.isNotEmpty ? abonos.first : null;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => _headerEmpresa(logo),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _divider(),
        pw.SizedBox(height: 8),
        pw.Text('ESTADO DE CUENTA – PÓLIZA', style: _h1()),
        pw.SizedBox(height: 10),

        if (a != null)
          _bloqueInfo('INFORMACIÓN DE LA PÓLIZA', [
            ('N° Póliza',     a.nroPoliza ?? '${a.idPoliza}'),
            ('Cliente',       a.nombreCliente ?? '—'),
            ('Aseguradora',   a.nombreAseg ?? '—'),
            ('Ramo',          a.nombreRamo ?? '—'),
            ('Producto',      a.nombreProd ?? '—'),
            ('Bien asegurado',a.bienAsegurado ?? '—'),
            if (a.finiPoliza != null && a.ffinPoliza != null)
              ('Vigencia',
                  '${_df.format(a.finiPoliza!)} – ${_df.format(a.ffinPoliza!)}'),
          ]),
        pw.SizedBox(height: 12),

        // Resumen financiero
        pw.Text('RESUMEN DE CUENTA', style: _h2()),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _grisClaro, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            _tablaHeader(
                ['Prima Total', 'Total Abonado', 'Saldo Pendiente', 'Total Comisión']),
            _tablaFila([
              '\$ ${Fmt.money(primaPoliza)}',
              '\$ ${Fmt.money(totalAbonado)}',
              '\$ ${Fmt.money(saldo)}',
              '\$ ${Fmt.money(totalComision)}',
            ]),
          ],
        ),
        pw.SizedBox(height: 16),

        // Historial
        pw.Text('HISTORIAL DE PAGOS', style: _h2()),
        pw.SizedBox(height: 6),
        _tablaHistorialPoliza(abonos),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generado el ${_dft.format(DateTime.now())}',
          style: _small(),
        ),
      ],
    ));

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESTADO DE CUENTA por reporte
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> estadoCuentaReporte({
    required List<AbonoPoliza> abonos,
    required ReportePago? reporte,
    required num totalAbonado,
    required num totalComision,
  }) async {
    final doc  = pw.Document();
    final logo = await _cargarLogo();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => _headerEmpresa(logo),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _divider(),
        pw.SizedBox(height: 8),
        pw.Text(
          'ESTADO DE CUENTA – REPORTE #${reporte?.id ?? ''}',
          style: _h1(),
        ),
        pw.SizedBox(height: 10),

        if (reporte != null)
          _bloqueInfo('INFORMACIÓN DEL REPORTE', [
            ('Reporte #',    '${reporte.id}'),
            ('Fecha',         _df.format(reporte.fechaRep)),
            ('Aseguradora',   reporte.nombreAseg ?? '—'),
            ('Intermediario', reporte.nombreInterm ?? '—'),
            if (reporte.finiRep != null && reporte.ffinRep != null)
              ('Período',
                  '${_df.format(reporte.finiRep!)} – ${_df.format(reporte.ffinRep!)}'),
            ('Estado',        labelEstadoPago(reporte.estadoRep)),
          ]),
        pw.SizedBox(height: 12),

        pw.Text('RESUMEN', style: _h2()),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _grisClaro, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            _tablaHeader(['N° Pólizas', 'Total Abonado', 'Total Comisión']),
            _tablaFila([
              '${abonos.length}',
              '\$ ${Fmt.money(totalAbonado)}',
              '\$ ${Fmt.money(totalComision)}',
            ]),
          ],
        ),
        pw.SizedBox(height: 16),

        pw.Text('DETALLE POR PÓLIZA', style: _h2()),
        pw.SizedBox(height: 6),
        _tablaHistorialReporte(abonos),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generado el ${_dft.format(DateTime.now())}',
          style: _small(),
        ),
      ],
    ));

    return doc.save();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers internos
  // ─────────────────────────────────────────────────────────────────────────

  static Future<pw.ImageProvider?> _cargarLogo() async {
    try {
      final data = await rootBundle
          .load('assets/images/LogoRuedaSerranoFondoTransparente2.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _headerEmpresa(pw.ImageProvider? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[
          pw.Image(logo, height: 40, width: 40),
          pw.SizedBox(width: 12),
        ],
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Rueda Serrano Asesores de Seguros',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: _azul)),
          pw.Text('SegurApp – Sistema de Gestión de Pólizas',
              style: const pw.TextStyle(fontSize: 9, color: _gris)),
        ]),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 4),
      child: pw.Text(
        'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
        style: _small(),
      ),
    );
  }

  static pw.Widget _divider() => pw.Divider(color: _azulClaro, thickness: 1);

  static pw.Widget _bloqueInfo(
      String titulo, List<(String, String)> filas) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _grisClaro, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _azul,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(titulo,
                style: pw.TextStyle(
                    color: _blanco,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9)),
          ),
          pw.Padding(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: filas.map((f) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(children: [
                    pw.SizedBox(
                      width: 100,
                      child: pw.Text('${f.$1}:', style: _label()),
                    ),
                    pw.Expanded(child: pw.Text(f.$2, style: _body())),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _tablaHeader(List<String> cols) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _azul),
      children: cols
          .map((c) => pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(c,
                    style: pw.TextStyle(
                        color: _blanco,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9)),
              ))
          .toList(),
    );
  }

  static pw.TableRow _tablaFila(List<String> celdas,
      {bool shade = false}) {
    return pw.TableRow(
      decoration: shade
          ? const pw.BoxDecoration(color: _grisClaro)
          : null,
      children: celdas
          .map((c) => pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Text(c,
                    style: c.startsWith('\$') ? _mono() : _body()),
              ))
          .toList(),
    );
  }

  static pw.TableRow _tablaTotal(List<String> celdas) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _grisClaro),
      children: celdas
          .map((c) => pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(c,
                    style: c.startsWith('\$')
                        ? pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            font: pw.Font.courier())
                        : _bold()),
              ))
          .toList(),
    );
  }

  static pw.Widget _pill(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor(color.red, color.green, color.blue, 0.12),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
            color: PdfColor(color.red, color.green, color.blue, 0.4),
            width: 0.5),
      ),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text('$label: ',
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ]),
    );
  }

  static pw.Widget _tablaHistorialPoliza(List<AbonoPoliza> abonos) {
    final totAbono = abonos.fold<num>(0, (s, a) => s + a.vlrabonoprima);
    final totCom   = abonos.fold<num>(0, (s, a) => s + a.vlrcomision);
    final totComAd = abonos.fold<num>(0, (s, a) => s + a.vlrcomad);

    return pw.Table(
      border: pw.TableBorder.all(color: _grisClaro, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(0.8),
        5: pw.FlexColumnWidth(1.5),
      },
      children: [
        _tablaHeader(
            ['Fecha', 'Reporte #', 'Abono', 'Comisión', '% Com', 'Estado']),
        ...abonos.asMap().entries.map((e) {
          final a = e.value;
          return _tablaFila([
            a.fechaPago != null ? _df.format(a.fechaPago!) : '—',
            a.idrepPago != null ? '#${a.idrepPago}' : '—',
            '\$ ${Fmt.money(a.vlrabonoprima)}',
            '\$ ${Fmt.money(a.vlrcomision + a.vlrcomad)}',
            Fmt.percent(a.porccomision, dec: 1),
            labelEstadoPago(a.estadoPago),
          ], shade: e.key.isOdd);
        }),
        _tablaTotal([
          'TOTALES',
          '',
          '\$ ${Fmt.money(totAbono)}',
          '\$ ${Fmt.money(totCom + totComAd)}',
          '',
          '',
        ]),
      ],
    );
  }

  static pw.Widget _tablaHistorialReporte(List<AbonoPoliza> abonos) {
    final totAbono = abonos.fold<num>(0, (s, a) => s + a.vlrabonoprima);
    final totCom   = abonos.fold<num>(0, (s, a) => s + a.vlrcomision + a.vlrcomad);

    return pw.Table(
      border: pw.TableBorder.all(color: _grisClaro, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(2.5),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2),
        5: pw.FlexColumnWidth(1),
      },
      children: [
        _tablaHeader(
            ['N° Póliza', 'Cliente', 'Ramo / Producto', 'Abono', 'Comisión', 'Estado']),
        ...abonos.asMap().entries.map((e) {
          final a = e.value;
          return _tablaFila([
            a.nroPoliza ?? '${a.idPoliza}',
            a.nombreCliente ?? '—',
            "${a.nombreRamo ?? '—'}${a.nombreProd != null ? ' / ${a.nombreProd!}' : ''}",
            '\$ ${Fmt.money(a.vlrabonoprima)}',
            '\$ ${Fmt.money(a.vlrcomision + a.vlrcomad)}',
            labelEstadoPago(a.estadoPago),
          ], shade: e.key.isOdd);
        }),
        _tablaTotal([
          'TOTALES',
          '',
          '',
          '\$ ${Fmt.money(totAbono)}',
          '\$ ${Fmt.money(totCom)}',
          '',
        ]),
      ],
    );
  }
}
