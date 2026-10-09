import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../models/expense.dart';

/// Opens the add/edit form: a dialog on wide windows, a full page on phones.
Future<void> openExpenseForm(BuildContext context, {Expense? expense}) {
  final form = ExpenseFormPage(expense: expense);
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 480, height: 620, child: form),
      ),
    );
  }
  return Navigator.of(context)
      .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => form));
}

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key, this.expense});

  /// The expense being edited, or null when adding a new one.
  final Expense? expense;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late ExpenseCategory _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amount = TextEditingController(
      text: expense == null
          ? ''
          : (expense.amountMinor / 100).toStringAsFixed(2),
    );
    _note = TextEditingController(text: expense?.note ?? '');
    _category = expense?.category ?? ExpenseCategory.food;
    _date = expense?.date ?? dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final store = StoreScope.of(context);
    final existing = widget.expense;
    final expense = Expense(
      id: existing?.id ?? store.newId(),
      amountMinor: (double.parse(_amount.text) * 100).round(),
      category: _category,
      date: _date,
      note: _note.text.trim(),
    );
    existing == null ? store.add(expense) : store.update(expense);
    Navigator.of(context).pop();
  }

  void _delete() {
    StoreScope.of(context).remove(widget.expense!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final editing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(editing ? 'Edit expense' : 'Add expense'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        // Not a lazy ListView: every field must stay mounted so validation
        // still covers ones that have scrolled out of view.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amount,
                autofocus: !editing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: Theme.of(context).textTheme.headlineMedium,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${store.currency.symbol} ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) return 'Enter an amount';
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ExpenseCategory.values)
                    ChoiceChip(
                      avatar: Icon(category.icon, size: 18),
                      label: Text(category.label),
                      showCheckmark: false,
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(formatDay(_date)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'What was it for?',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      // Pinned so it stays reachable when the form scrolls.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: FilledButton(
            onPressed: _save,
            child: Text(editing ? 'Save changes' : 'Add expense'),
          ),
        ),
      ),
    );
  }
}
