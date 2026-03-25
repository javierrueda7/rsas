import 'package:flutter/material.dart';

class BuscadorDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final String? helperText;

  const BuscadorDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                itemLabel(e),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () async {
            final seleccionado = await showDialog<T>(
              context: context,
              builder: (_) => _BuscadorDialog<T>(
                label: label,
                items: items,
                itemLabel: itemLabel,
              ),
            );
            if (seleccionado != null || items.contains(seleccionado)) {
              onChanged(seleccionado);
            }
          },
        ),
      ),
    );
  }
}

class _BuscadorDialog<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;

  const _BuscadorDialog({
    required this.label,
    required this.items,
    required this.itemLabel,
  });

  @override
  State<_BuscadorDialog<T>> createState() => _BuscadorDialogState<T>();
}

class _BuscadorDialogState<T> extends State<_BuscadorDialog<T>> {
  final ctrl = TextEditingController();
  late List<T> filtrados;

  @override
  void initState() {
    super.initState();
    filtrados = widget.items;
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _filtrar(String q) {
    final b = q.trim().toLowerCase();
    setState(() {
      if (b.isEmpty) {
        filtrados = widget.items;
      } else {
        filtrados = widget.items
            .where((e) => widget.itemLabel(e).toLowerCase().contains(b))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Buscar ${widget.label}'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              onChanged: _filtrar,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtrados.length,
                itemBuilder: (_, i) {
                  final item = filtrados[i];
                  return ListTile(
                    title: Text(widget.itemLabel(item)),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}