import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/omni_theme.dart';

class DynamicFormWidget extends StatefulWidget {
  final Map<String, dynamic> template;
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onSave;

  const DynamicFormWidget({
    super.key,
    required this.template,
    this.initialData = const {},
    required this.onSave,
  });

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  final Map<String, dynamic> _formData = {};
  final Map<String, TextEditingController> _controllers = {};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final fields = widget.template['fields'] as List? ?? [];
    for (var field in fields) {
      final key = field['key'] as String;
      final initial = widget.initialData[key];
      _formData[key] = initial ?? '';
      if (field['type'] != 'select' && field['type'] != 'signature') {
        _controllers[key] = TextEditingController(text: initial?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label'] as String;
    final required = field['required'] as bool? ?? false;
    final type = field['type'] as String? ?? 'text';

    switch (type) {
      case 'number':
        return TextFormField(
          controller: _controllers[key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            suffixText: field['unit'] as String?,
          ),
          style: const TextStyle(color: Colors.white),
          validator: required ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null : null,
          onChanged: (v) => _formData[key] = v,
        );
      case 'select':
        final options = (field['options'] as List?)?.cast<String>() ?? [];
        return DropdownButtonFormField<String>(
          value: _formData[key]?.toString().isNotEmpty == true ? _formData[key].toString() : null,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
          ),
          dropdownColor: OmniTheme.bg800,
          style: const TextStyle(color: Colors.white),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (v) => setState(() => _formData[key] = v ?? ''),
          validator: required ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null : null,
        );
      case 'signature':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _controllers[key],
                decoration: const InputDecoration(
                  hintText: 'Nombre y Firma',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => _formData[key] = v,
              ),
            ],
          ),
        );
      default:
        return TextFormField(
          controller: _controllers[key],
          maxLines: type == 'text' ? 3 : 1,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          validator: required ? (v) => (v == null || v.isEmpty) ? '$label es requerido' : null : null,
          onChanged: (v) => _formData[key] = v,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.template['fields'] as List? ?? [];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.template['name'] as String? ?? 'Formulario',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete los campos requeridos',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          ...fields.map((field) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildField(field as Map<String, dynamic>),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() == true) {
                  widget.onSave(Map.from(_formData));
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: OmniTheme.primary,
              ),
              child: const Text('Guardar Bitacora', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
