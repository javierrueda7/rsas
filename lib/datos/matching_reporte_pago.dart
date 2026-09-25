import 'poliza.dart';

/// Resultado de cruzar una línea de un reporte de comisiones contra las
/// pólizas de la base. Solo [exacta] y [unicaSinAnexo] se consideran
/// suficientemente seguras para incluirse solas; todo lo demás exige que
/// una persona confirme antes de crear el abono — es plata.
enum EstadoMatch {
  /// Mismo número base y mismo anexo, una sola póliza.
  exacta,

  /// El reporte no trae anexo (ej. Mundial) y hay una sola póliza con ese
  /// número base.
  unicaSinAnexo,

  /// Hay una póliza asignada pero algo no cuadra (documento distinto,
  /// póliza registrada sin anexo) — asignada pero destildada.
  revisar,

  /// Varias pólizas posibles — hay que elegir una.
  ambigua,

  /// El número base existe, pero ese anexo puntual no está registrado.
  anexoNoRegistrado,

  /// Ninguna póliza con ese número base.
  noEncontrada,
}

class ResultadoMatch {
  final EstadoMatch estado;
  final Poliza? poliza;

  /// Opciones para que el usuario elija rápido (otros anexos del mismo
  /// número, o las pólizas del cliente cuando el número no apareció).
  final List<Poliza> candidatos;
  final String motivo;

  const ResultadoMatch(this.estado, {this.poliza, this.candidatos = const [], this.motivo = ''});

  bool get seIncluyeSolo =>
      estado == EstadoMatch.exacta || estado == EstadoMatch.unicaSinAnexo;
}

/// Solo letras y dígitos, en mayúscula.
String normalizarDoc(String s) =>
    s.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

String _sinCerosIzq(String s) {
  final r = s.replaceFirst(RegExp(r'^0+'), '');
  return r.isEmpty && s.isNotEmpty ? '0' : r;
}

/// Segmentos de un número de póliza ("400-97-994000000046-6" →
/// [400, 97, 994000000046, 6]). Por convención de la app el anexo va
/// siempre como último segmento.
List<String> segmentosNroPoliza(String nro) => nro
    .toUpperCase()
    .split(RegExp(r'[^0-9A-Z]+'))
    .where((s) => s.isNotEmpty)
    .toList();

/// Si [nroPoliza] corresponde al número base [nucleo] del reporte, devuelve
/// el anexo con el que quedó registrada la póliza ('' si se registró sin
/// anexo). Null si no corresponde. Compara por segmento completo — nunca
/// por "contiene", para que '046' no matchee '1046' ni otros anexos.
String? anexoSiCorresponde(String nroPoliza, String nucleo, {String? anexoReporte}) {
  final n = _sinCerosIzq(normalizarDoc(nucleo));
  if (n.isEmpty) return null;
  final segs = segmentosNroPoliza(nroPoliza);
  if (segs.isEmpty) return null;

  for (var i = 0; i < segs.length; i++) {
    if (_sinCerosIzq(segs[i]) == n) {
      return i < segs.length - 1 ? _sinCerosIzq(segs.last) : '';
    }
  }

  // Pólizas viejas digitadas sin separadores: "9940000001936" = núcleo +
  // anexo pegados.
  if (segs.length == 1) {
    final todo = _sinCerosIzq(segs.first);
    if (todo == n) return '';
    final a = anexoReporte == null ? '' : normalizarDoc(anexoReporte);
    if (a.isNotEmpty && todo == '$n$a') return _sinCerosIzq(a);
  }
  return null;
}

/// Decide a qué póliza corresponde una línea del reporte.
///
/// [candidatos]: pólizas traídas de la base que podrían corresponder (por
/// número y/o por documento del cliente) — acá se filtran con precisión.
/// [polizasDelCliente]: las del cliente encontrado por documento, solo
/// para ofrecerlas como sugerencia si el número no aparece.
ResultadoMatch resolverMatch({
  required String nucleo,
  String? anexo,
  String? docCliente,
  int? aseguradoraId,
  num? primaLinea,
  required List<Poliza> candidatos,
  List<Poliza> polizasDelCliente = const [],
}) {
  final anexoRep =
      (anexo == null || normalizarDoc(anexo).isEmpty) ? null : _sinCerosIzq(normalizarDoc(anexo));
  final doc = docCliente == null ? '' : normalizarDoc(docCliente);

  // Número base + anexo con el que está registrada cada póliza.
  final vistos = <int>{};
  final conNucleo = <(Poliza, String)>[];
  for (final p in candidatos) {
    if (!vistos.add(p.id) || p.nroPoliza == null) continue;
    if (aseguradoraId != null && p.asegId != null && p.asegId != aseguradoraId) continue;
    final a = anexoSiCorresponde(p.nroPoliza!, nucleo, anexoReporte: anexoRep);
    if (a != null) conNucleo.add((p, a));
  }

  if (conNucleo.isEmpty) {
    return ResultadoMatch(
      EstadoMatch.noEncontrada,
      candidatos: polizasDelCliente,
      motivo: polizasDelCliente.isEmpty
          ? 'No hay ninguna póliza con el número $nucleo.'
          : 'No hay ninguna póliza con el número $nucleo. Abajo están las pólizas de '
              'ese cliente por si el número vino distinto en el reporte.',
    );
  }

  List<Poliza> ordenar(List<Poliza> ps) {
    if (primaLinea == null) return ps;
    final l = [...ps];
    l.sort((a, b) => (a.primaPoliza - primaLinea).abs().compareTo((b.primaPoliza - primaLinea).abs()));
    return l;
  }

  ResultadoMatch confirmarDocumento(Poliza p, EstadoMatch estado, String motivoOk) {
    final docPoliza = p.docCliente == null ? '' : normalizarDoc(p.docCliente!);
    if (doc.isNotEmpty && docPoliza.isNotEmpty && docPoliza != doc) {
      return ResultadoMatch(
        EstadoMatch.revisar,
        poliza: p,
        candidatos: [p],
        motivo: 'El número coincide, pero el documento del reporte ($doc) no es el del '
            'cliente de la póliza (${p.docCliente}). Confirmá antes de incluirla.',
      );
    }
    return ResultadoMatch(estado, poliza: p, motivo: motivoOk);
  }

  final todas = conNucleo.map((e) => e.$1).toList();

  if (anexoRep == null) {
    if (conNucleo.length == 1) {
      return confirmarDocumento(conNucleo.first.$1, EstadoMatch.unicaSinAnexo,
          'El reporte no trae anexo; es la única póliza con ese número.');
    }
    return ResultadoMatch(
      EstadoMatch.ambigua,
      candidatos: ordenar(todas),
      motivo: 'El reporte no trae anexo y hay ${conNucleo.length} pólizas con el número '
          '$nucleo. Elegí a cuál corresponde.',
    );
  }

  final exactas = conNucleo.where((e) => e.$2 == anexoRep).map((e) => e.$1).toList();
  if (exactas.length == 1) {
    return confirmarDocumento(exactas.first, EstadoMatch.exacta, 'Número y anexo coinciden.');
  }
  if (exactas.length > 1) {
    return ResultadoMatch(
      EstadoMatch.ambigua,
      candidatos: ordenar(exactas),
      motivo: 'Hay ${exactas.length} pólizas registradas con el número $nucleo anexo '
          '$anexoRep. Elegí la correcta.',
    );
  }

  final sinAnexo = conNucleo.where((e) => e.$2.isEmpty).map((e) => e.$1).toList();
  if (sinAnexo.length == 1 && conNucleo.length == 1) {
    return ResultadoMatch(
      EstadoMatch.revisar,
      poliza: sinAnexo.first,
      candidatos: sinAnexo,
      motivo: 'La póliza está registrada sin anexo y el reporte dice anexo $anexoRep. '
          'Confirmá que sea la misma antes de incluirla.',
    );
  }

  final registrados = conNucleo.map((e) => e.$2.isEmpty ? 'sin anexo' : e.$2).join(', ');
  return ResultadoMatch(
    EstadoMatch.anexoNoRegistrado,
    candidatos: ordenar(todas),
    motivo: 'El número $nucleo existe, pero el anexo $anexoRep no está registrado '
        '(registrados: $registrados). Elegí a cuál asignarlo o dejala afuera.',
  );
}
