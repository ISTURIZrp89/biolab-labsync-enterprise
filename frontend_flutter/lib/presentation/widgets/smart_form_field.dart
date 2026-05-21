import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SmartFormFieldHistory {
  static const String _prefix = 'smart_field_history_';

  static Future<List<String>> getSuggestions(String fieldKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$fieldKey';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    return (raw.split('|').toSet().toList())..sort((a, b) => b.compareTo(a));
  }

  static Future<void> saveValue(String fieldKey, String value) async {
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final storeKey = '$_prefix$fieldKey';
    final existing = prefs.getString(storeKey) ?? '';
    final values = existing.split('|').where((v) => v.isNotEmpty).toSet();
    values.add(value);
    final limited = values.take(50).toList();
    await prefs.setString(storeKey, limited.join('|'));
  }

  static Future<void> clearHistory(String fieldKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$fieldKey');
  }
}

class SmartTextField extends StatefulWidget {
  final String fieldKey;
  final String label;
  final bool required;
  final bool multiline;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final VoidCallback? onFieldSubmitted;

  const SmartTextField({
    super.key,
    required this.fieldKey,
    required this.label,
    this.required = false,
    this.multiline = false,
    this.controller,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  State<SmartTextField> createState() => _SmartTextFieldState();
}

class _SmartTextFieldState extends State<SmartTextField> {
  late TextEditingController _controller;
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  bool _isValid = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _loadSuggestions();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final suggestions = await SmartFormFieldHistory.getSuggestions(widget.fieldKey);
    if (mounted) {
      setState(() => _suggestions = suggestions);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    final filtered = _suggestions.where((s) => s.toLowerCase().contains(text.toLowerCase())).toList();
    setState(() {
      _showSuggestions = filtered.isNotEmpty && text.length >= 1 && !widget.multiline;
    });
    widget.onChanged?.call(text);
    if (widget.required && text.isEmpty) {
      setState(() {
        _isValid = false;
        _errorText = '${widget.label} es requerido';
      });
    } else {
      setState(() {
        _isValid = true;
        _errorText = null;
      });
    }
  }

  void _selectSuggestion(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: suggestion.length));
    setState(() => _showSuggestions = false);
    SmartFormFieldHistory.saveValue(widget.fieldKey, suggestion);
    widget.onChanged?.call(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            TextFormField(
              controller: _controller,
              focusNode: widget.focusNode,
              maxLines: widget.multiline ? 3 : 1,
              minLines: widget.multiline ? 2 : 1,
              textInputAction: widget.textInputAction,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFFEF4444), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                suffixIcon: widget.multiline ? null : (_showSuggestions ? const Icon(Icons.arrow_drop_down, color: Colors.white38) : null),
              ),
              validator: widget.validator ?? (widget.required ? (v) => (v == null || v.isEmpty) ? '${widget.label} es requerido' : null : null),
              onChanged: (v) {
                widget.onChanged?.call(v);
                if (widget.required && v.isEmpty) {
                  setState(() { _isValid = false; _errorText = '${widget.label} es requerido'; });
                } else {
                  setState(() { _isValid = true; _errorText = null; });
                }
              },
              onFieldSubmitted: (_) {
                if (_showSuggestions && _suggestions.isNotEmpty) {
                  _selectSuggestion(_suggestions.first);
                }
                SmartFormFieldHistory.saveValue(widget.fieldKey, _controller.text);
                widget.onFieldSubmitted?.call();
              },
            ),
            if (_showSuggestions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.where((s) => s.toLowerCase().contains(_controller.text.toLowerCase())).take(5).length,
                      itemBuilder: (context, index) {
                        final filtered = _suggestions.where((s) => s.toLowerCase().contains(_controller.text.toLowerCase())).take(5).toList();
                        final suggestion = filtered[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(suggestion, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          leading: const Icon(Icons.history, size: 16, color: Colors.white38),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_errorText!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        if (_isValid && _controller.text.isNotEmpty && !widget.multiline)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text('Valido', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class SmartNumberField extends StatefulWidget {
  final String fieldKey;
  final String label;
  final bool required;
  final String? unit;
  final double? min;
  final double? max;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const SmartNumberField({
    super.key,
    required this.fieldKey,
    required this.label,
    this.required = false,
    this.unit,
    this.min,
    this.max,
    this.controller,
    this.onChanged,
    this.focusNode,
  });

  @override
  State<SmartNumberField> createState() => _SmartNumberFieldState();
}

class _SmartNumberFieldState extends State<SmartNumberField> {
  late TextEditingController _controller;
  bool _isValid = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged?.call(text);

    if (widget.required && text.isEmpty) {
      setState(() { _isValid = false; _errorText = '${widget.label} es requerido'; });
      return;
    }

    if (text.isNotEmpty) {
      final num = double.tryParse(text);
      if (num != null) {
        if (widget.min != null && num < widget.min!) {
          setState(() { _isValid = false; _errorText = 'Valor minimo: ${widget.min}'; });
        } else if (widget.max != null && num > widget.max!) {
          setState(() { _isValid = false; _errorText = 'Valor maximo: ${widget.max}'; });
        } else {
          setState(() { _isValid = true; _errorText = null; });
        }
      } else {
        setState(() { _isValid = false; _errorText = 'Ingrese un numero valido'; });
      }
    } else {
      setState(() { _isValid = true; _errorText = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
            suffixText: widget.unit,
            suffixStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
          ),
          onChanged: (v) {
            widget.onChanged?.call(v);
            if (widget.required && v.isEmpty) {
              setState(() { _isValid = false; _errorText = '${widget.label} es requerido'; });
            } else if (v.isNotEmpty) {
              final num = double.tryParse(v);
              if (num != null) {
                if (widget.min != null && num < widget.min!) {
                  setState(() { _isValid = false; _errorText = 'Valor minimo: ${widget.min}'; });
                } else if (widget.max != null && num > widget.max!) {
                  setState(() { _isValid = false; _errorText = 'Valor maximo: ${widget.max}'; });
                } else {
                  setState(() { _isValid = true; _errorText = null; });
                }
              } else {
                setState(() { _isValid = false; _errorText = 'Ingrese un numero valido'; });
              }
            } else {
              setState(() { _isValid = true; _errorText = null; });
            }
          },
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_errorText!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        if (_isValid && _controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text(_controller.text + (widget.unit != null ? ' ${widget.unit}' : ''), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class SmartDateField extends StatefulWidget {
  final String fieldKey;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;
  final DateTime? initialDate;

  const SmartDateField({
    super.key,
    required this.fieldKey,
    required this.label,
    this.required = false,
    this.onChanged,
    this.initialDate,
  });

  @override
  State<SmartDateField> createState() => _SmartDateFieldState();
}

class _SmartDateFieldState extends State<SmartDateField> {
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = DateFormat('yyyy-MM-dd').format(widget.initialDate!);
    }
  }

  Future<void> _pickDate() async {
    final initialDate = _selectedDate.isNotEmpty ? _tryParseDate(_selectedDate) : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      widget.onChanged?.call(_selectedDate);
    }
  }

  void _selectToday() {
    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    });
    widget.onChanged?.call(_selectedDate);
  }

  DateTime _tryParseDate(String text) {
    try {
      return DateTime.parse(text);
    } catch (_) {
      try {
        return DateFormat('dd/MM/yyyy').parse(text);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String _getDisplayDate() {
    if (_selectedDate.isEmpty) return '';
    try {
      final date = DateTime.parse(_selectedDate);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return _selectedDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.required && _selectedDate.isEmpty ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.white.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF0F172A),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getDisplayDate().isEmpty ? widget.label : _getDisplayDate(),
                            style: TextStyle(
                              color: _getDisplayDate().isEmpty ? Colors.white54 : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _selectToday,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Hoy', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (widget.required && _selectedDate.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('${widget.label} es requerido', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        if (_selectedDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text(_getDisplayDate(), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class SmartTimeField extends StatefulWidget {
  final String fieldKey;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;
  final TimeOfDay? initialTime;

  const SmartTimeField({
    super.key,
    required this.fieldKey,
    required this.label,
    this.required = false,
    this.onChanged,
    this.initialTime,
  });

  @override
  State<SmartTimeField> createState() => _SmartTimeFieldState();
}

class _SmartTimeFieldState extends State<SmartTimeField> {
  String _selectedTime = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialTime != null) {
      _selectedTime = '${widget.initialTime!.hour.toString().padLeft(2, '0')}:${widget.initialTime!.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final initialTime = _selectedTime.isNotEmpty ? _tryParseTime(_selectedTime) : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
      widget.onChanged?.call(_selectedTime);
    }
  }

  void _selectNow() {
    final now = TimeOfDay.now();
    setState(() {
      _selectedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    widget.onChanged?.call(_selectedTime);
  }

  TimeOfDay _tryParseTime(String text) {
    try {
      final parts = text.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.required && _selectedTime.isEmpty ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.white.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF0F172A),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white54, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedTime.isEmpty ? widget.label : _selectedTime,
                            style: TextStyle(
                              color: _selectedTime.isEmpty ? Colors.white54 : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _selectNow,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ahora', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (widget.required && _selectedTime.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('${widget.label} es requerido', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        if (_selectedTime.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text(_selectedTime, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}

class SmartSelectField extends StatefulWidget {
  final String fieldKey;
  final String label;
  final List<String> options;
  final bool required;
  final ValueChanged<String?>? onChanged;
  final String? initialValue;

  const SmartSelectField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.options,
    this.required = false,
    this.onChanged,
    this.initialValue,
  });

  @override
  State<SmartSelectField> createState() => _SmartSelectFieldState();
}

class _SmartSelectFieldState extends State<SmartSelectField> {
  String? _selectedValue;
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _filteredOptions = widget.options;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showSelectDialog(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.required && _selectedValue == null ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.white.withOpacity(0.1),
              ),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                const Icon(Icons.list, color: Colors.white54, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedValue ?? widget.label,
                    style: TextStyle(
                      color: _selectedValue == null ? Colors.white54 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
        ),
        if (widget.required && _selectedValue == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text('${widget.label} es requerido', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
          ),
        if (_selectedValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                const SizedBox(width: 4),
                Text(_selectedValue!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showSelectDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(widget.label, style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                    ),
                    onChanged: (v) {
                      setDialogState(() {
                        _filteredOptions = widget.options.where((o) => o.toLowerCase().contains(v.toLowerCase())).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        final isSelected = option == _selectedValue;
                        return ListTile(
                          dense: true,
                          title: Text(option, style: TextStyle(color: isSelected ? const Color(0xFF3B82F6) : Colors.white)),
                          trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF3B82F6)) : null,
                          onTap: () {
                            Navigator.pop(context, option);
                          },
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
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _selectedValue = result);
      widget.onChanged?.call(result);
    }
  }
}

class SmartFormFieldGroup extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Color? accentColor;

  const SmartFormFieldGroup({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
