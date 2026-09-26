/// Helpers para armar filtros `.or(...)` de PostgREST con texto que escribe
/// el usuario. Sin comillas, una coma o un paréntesis en la búsqueda
/// ("PEREZ, JUAN", "ACME (EN LIQUIDACION)") rompe la sintaxis del filtro o
/// cambia su significado.
library;

/// Valor entre comillas dobles, con `"` y `\` escapados.
String valorFiltro(String v) =>
    '"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// `columna ILIKE '%texto%'` listo para usar dentro de `.or(...)`.
String ilikeContiene(String columna, String texto) =>
    '$columna.ilike.${valorFiltro('%$texto%')}';

/// Solo letras y dígitos en mayúscula — igual que las columnas generadas
/// doc_cliente_norm / nro_poliza_norm de la base.
String normalizarAlfanumerico(String s) =>
    s.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

/// Número de póliza como se guarda: sin espacios en los extremos y cada
/// grupo de espacios o guiones entre números/letras cambiado por un solo
/// guion ("96-95-1000000164 0" → "96-95-1000000164-0"). Misma regla que
/// lib/fix_nro_poliza_guiones.sql aplicó a las pólizas existentes.
String formatearNroPoliza(String s) =>
    s.trim().replaceAll(RegExp(r'[\s-]+'), '-');
