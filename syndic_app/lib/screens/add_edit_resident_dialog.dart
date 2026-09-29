import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/resident.dart';

class AddEditResidentDialog extends StatefulWidget {
  final Resident? resident;
  final VoidCallback onSuccess;

  const AddEditResidentDialog({Key? key, this.resident, required this.onSuccess}) : super(key: key);

  @override
  State<AddEditResidentDialog> createState() => _AddEditResidentDialogState();
}

class _AddEditResidentDialogState extends State<AddEditResidentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aptController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _aptController = TextEditingController(text: widget.resident?.apartmentNumber ?? '');
    _nameController = TextEditingController(text: widget.resident?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.resident?.phone ?? '');
  }

  @override
  void dispose() {
    _aptController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.resident == null) {
      await DBHelper.instance.insertResident(
        Resident(
          apartmentNumber: _aptController.text.trim(),
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
    } else {
      await DBHelper.instance.updateResident(
        widget.resident!.copyWith(
          apartmentNumber: _aptController.text.trim(),
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
    }

    widget.onSuccess();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.resident != null;

    return AlertDialog(
      title: Text(isEditing ? 'تعديل بيانات الساكن' : 'إضافة شقة / ساكن جديد'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _aptController,
                decoration: const InputDecoration(labelText: 'رقم الشقة'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال رقم الشقة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم والنسب'),
                validator: (val) => val == null || val.trim().isEmpty ? 'يرجى إدخال الاسم والنسب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف (WhatsApp)', hintText: '06XXXXXXXX'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(onPressed: _save, child: Text(isEditing ? 'حفظ التعديل' : 'إضافة')),
      ],
    );
  }
}