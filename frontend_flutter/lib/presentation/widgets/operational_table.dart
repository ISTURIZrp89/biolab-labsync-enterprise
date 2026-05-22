import 'package:flutter/material.dart';
import '../../theme/omni_theme.dart';

typedef TableColumnDef = Map<String, dynamic>;

class OperationalTable extends StatefulWidget {
  final String label;
  final List<TableColumnDef> columns;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const OperationalTable({
    super.key,
    required this.label,
    required this.columns,
    required this.rows,
    required this.onChanged,
  });

  @override
  State<OperationalTable> createState() => _OperationalTableState();
}

class _OperationalTableState extends State<OperationalTable> {
  late List<Map<String, dynamic>> _rows;
  final Map<String, TextEditingController> _controllers = {};
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _rows = widget.rows.map((r) => Map<String, dynamic>.from(r)).toList();
    _initControllers();
  }

  @override
  void didUpdateWidget(OperationalTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newData = widget.rows.map((r) => r.toString()).join(',');
    final oldData = oldWidget.rows.map((r) => r.toString()).join(',');
    if (newData != oldData) {
      _rows = widget.rows.map((r) => Map<String, dynamic>.from(r)).toList();
      _disposeControllers();
      _initControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  void _initControllers() {
    for (int r = 0; r < _rows.length; r++) {
      for (final col in widget.columns) {
        final key = _cellKey(r, col['key'] as String);
        _controllers[key] = TextEditingController(text: _rows[r][col['key']]?.toString() ?? '');
      }
    }
  }

  String _cellKey(int row, String colKey) => 'r${row}_$colKey';

  void _addRow() {
    setState(() {
      final row = <String, dynamic>{};
      final rowIdx = _rows.length;
      for (final col in widget.columns) {
        final key = col['key'] as String;
        final initial = col['initial'] as String? ?? '';
        row[key] = initial;
        _controllers[_cellKey(rowIdx, key)] = TextEditingController(text: initial);
      }
      _rows.add(row);
    });
    widget.onChanged(List.from(_rows));
  }

  void _duplicateRow(int index) {
    if (index >= _rows.length) return;
    setState(() {
      final source = Map<String, dynamic>.from(_rows[index]);
      final rowIdx = _rows.length;
      for (final col in widget.columns) {
        final key = col['key'] as String;
        _controllers[_cellKey(rowIdx, key)] = TextEditingController(text: source[key]?.toString() ?? '');
      }
      _rows.insert(index + 1, source);
    });
    widget.onChanged(List.from(_rows));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      for (final col in widget.columns) {
        _controllers.remove(_cellKey(index, col['key'] as String));
      }
      _rows.removeAt(index);
      _reindexControllers();
    });
    widget.onChanged(List.from(_rows));
  }

  void _reindexControllers() {
    final newControllers = <String, TextEditingController>{};
    for (int r = 0; r < _rows.length; r++) {
      for (final col in widget.columns) {
        final key = col['key'] as String;
        final oldKey = _cellKey(r, key);
        final oldCtrl = _controllers[oldKey];
        if (oldCtrl != null) {
          newControllers[_cellKey(r, key)] = oldCtrl;
        }
      }
    }
    _controllers.clear();
    _controllers.addAll(newControllers);
  }

  void _onCellChanged(int row, String colKey, String value) {
    if (row < _rows.length) {
      _rows[row][colKey] = value;
      widget.onChanged(List.from(_rows));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(widget.label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted, letterSpacing: 1.5)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: OmniTheme.accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('${_rows.length}', style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                _buildActionChip(Icons.add, 'Agregar', _addRow),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalScroll,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(OmniTheme.bg800),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              dataRowMinHeight: 36,
              dataRowMaxHeight: 48,
              horizontalMargin: 8,
              columnSpacing: 4,
              columns: [
                ...widget.columns.map((col) {
                  final label = col['label'] as String? ?? col['key'] as String;
                  final width = col['width'] as double? ?? 120;
                  return DataColumn(
                    label: SizedBox(
                      width: width,
                      child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OmniTheme.textMuted), overflow: TextOverflow.ellipsis),
                    ),
                  );
                }),
                DataColumn(label: SizedBox(width: 60, child: Text('ACCIÓN', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OmniTheme.textMuted)))),
              ],
              rows: List.generate(_rows.length, (i) => _buildRow(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: OmniTheme.bg700),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: OmniTheme.accentBlue),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(int rowIdx) {
    final cells = <DataCell>[];

    for (final col in widget.columns) {
      final key = col['key'] as String;
      final type = col['type'] as String? ?? 'text';
      final options = col['options'] as List?;
      final ctrlKey = _cellKey(rowIdx, key);
      final controller = _controllers[ctrlKey] ?? TextEditingController();

      Widget cell;
      if (type == 'select' && options != null) {
        cell = DropdownButtonFormField<String>(
          value: options.contains(controller.text) ? controller.text : null,
          items: options.map((opt) => DropdownMenuItem(
            value: opt.toString(),
            child: Text(opt.toString(), style: const TextStyle(fontSize: 12, color: Colors.white)),
          )).toList(),
          onChanged: (v) {
            controller.text = v ?? '';
            _onCellChanged(rowIdx, key, v ?? '');
          },
          dropdownColor: OmniTheme.bg800,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4)),
        );
      } else {
        cell = TextFormField(
          controller: controller,
          keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4)),
          onChanged: (v) => _onCellChanged(rowIdx, key, v),
        );
      }

      cells.add(DataCell(cell));
    }

    cells.add(DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(onTap: () => _duplicateRow(rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 14, color: OmniTheme.accentBlue))),
          InkWell(onTap: () => _removeRow(rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: OmniTheme.red400))),
        ],
      ),
    ));

    return DataRow(cells: cells);
  }
}
