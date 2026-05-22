import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final ScrollController _verticalScroll = ScrollController();
  final FocusNode _tableFocus = FocusNode();

  static const double _rowHeight = 44.0;
  static const double _headerHeight = 40.0;
  double _viewportHeight = 400;
  double _totalWidth = 0;

  @override
  void initState() {
    super.initState();
    _rows = widget.rows.map((r) => Map<String, dynamic>.from(r)).toList();
    _initControllers();
    _calcTotalWidth();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateViewport());
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
      _calcTotalWidth();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    _tableFocus.dispose();
    super.dispose();
  }

  void _updateViewport() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      setState(() => _viewportHeight = renderBox.size.height - 60);
    }
  }

  void _calcTotalWidth() {
    double w = 0;
    for (final col in widget.columns) {
      w += col['width'] as double? ?? 120;
    }
    _totalWidth = w + 70;
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
    widget.onChanged(List.from(_rows));
  }

  void _scrollToBottom() {
    if (_rows.length * _rowHeight > _viewportHeight) {
      final maxScroll = _rows.length * _rowHeight - _viewportHeight;
      _verticalScroll.animateTo(maxScroll, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
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

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data == null || data.text == null || data.text!.trim().isEmpty) return;

      final lines = data.text!
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isEmpty) return;

      setState(() {
        for (final line in lines) {
          final values = line.split('\t');
          final row = <String, dynamic>{};
          final rowIdx = _rows.length;
          for (int c = 0; c < widget.columns.length; c++) {
            final key = widget.columns[c]['key'] as String;
            final val = c < values.length ? values[c].trim() : '';
            row[key] = val;
            _controllers[_cellKey(rowIdx, key)] = TextEditingController(text: val);
          }
          _rows.add(row);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      });
      widget.onChanged(List.from(_rows));
    } catch (_) {}
  }

  bool _isRowVisible(int index) {
    final scrollOffset = _verticalScroll.offset;
    final start = scrollOffset / _rowHeight - 2;
    final end = (scrollOffset + _viewportHeight) / _rowHeight + 2;
    return index >= start.floor() && index <= end.ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _tableFocus,
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                  _buildActionChip(Icons.content_paste, 'Pegar', _pasteFromClipboard),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _viewportHeight = constraints.maxHeight;
                  return NotificationListener<ScrollNotification>(
                    onNotification: (_) { setState(() {}); return false; },
                    child: _buildVirtualizedTable(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualizedTable() {
    final visibleCount = (_viewportHeight / _rowHeight).ceil() + 4;
    final firstVisible = (_verticalScroll.offset / _rowHeight).floor().clamp(0, _rows.length - 1);
    final lastVisible = (firstVisible + visibleCount).clamp(0, _rows.length);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScroll,
      child: SizedBox(
        width: _totalWidth,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                controller: _verticalScroll,
                itemCount: _rows.length,
                itemExtent: _rowHeight,
                itemBuilder: (ctx, i) => _buildRow(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: _headerHeight,
      color: OmniTheme.bg800,
      child: Row(
        children: [
          ...widget.columns.map((col) {
            final label = col['label'] as String? ?? col['key'] as String;
            final width = col['width'] as double? ?? 120;
            return SizedBox(
              width: width,
              child: Center(
                child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OmniTheme.textMuted), overflow: TextOverflow.ellipsis),
              ),
            );
          }),
          SizedBox(
            width: 70,
            child: Center(child: Text('ACCIÓN', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
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

  Widget _buildRow(int rowIdx) {
    final cells = <Widget>[];

    for (final col in widget.columns) {
      final key = col['key'] as String;
      final type = col['type'] as String? ?? 'text';
      final options = col['options'] as List?;
      final width = col['width'] as double? ?? 120;
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

      cells.add(SizedBox(width: width, child: cell));
    }

    cells.add(SizedBox(
      width: 70,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(onTap: () => _duplicateRow(rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 14, color: OmniTheme.accentBlue))),
          InkWell(onTap: () => _removeRow(rowIdx), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 14, color: OmniTheme.red400))),
        ],
      ),
    ));

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: OmniTheme.bg800, width: 0.5)),
      ),
      child: Row(children: cells),
    );
  }
}
