import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_storage.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final String? transactionId;

  const AddEditTransactionScreen({
    super.key,
    this.transactionId,
  });

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();

  final TransactionService _transactionService = TransactionService(ApiClient());
  final CategoryService _categoryService = CategoryService(ApiClient());

  String _transactionType = 'expense';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final list = await _categoryService.getCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoadingCategories = false;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textLight,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await AppStorage.getUserId();
      final txDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final payload = {
        'user_id': userId,
        'amount': amount,
        'merchant': _merchantController.text.trim(),
        'transaction_type': _transactionType,
        'transaction_date': txDateTime.toIso8601String(),
        'category_id': _selectedCategory?.id,
        'description': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        'source': 'manual',
      };

      final res = await _transactionService.createTransaction(payload);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res is Map<String, dynamic> && res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(_transactionType == 'expense' ? 'Expense added!' : 'Income logged!'),
                ],
              ),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(res['message'] ?? 'Failed to save transaction'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _transactionType == 'expense';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Transaction'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Expense / Income Selector
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _transactionType = 'expense'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isExpense ? AppColors.error : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                            boxShadow: isExpense
                                ? [
                                    BoxShadow(
                                      color: AppColors.error.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                                color: isExpense ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Expense',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isExpense ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _transactionType = 'income'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isExpense ? AppColors.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                            boxShadow: !isExpense
                                ? [
                                    BoxShadow(
                                      color: AppColors.success.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 18,
                                color: !isExpense ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Income',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: !isExpense ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 2. Amount Input Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'AMOUNT',
                      style: AppTextStyles.caption.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹ ',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: isExpense ? AppColors.error : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            autofocus: true,
                            style: AppTextStyles.displayLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: AppColors.textMuted),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter amount';
                              if (double.tryParse(v.trim()) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 3. Merchant / Payee Field
              Text('Title / Payee', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  hintText: isExpense ? 'e.g. Starbucks, Amazon, Grocery' : 'e.g. Monthly Salary, Freelance',
                  prefixIcon: const Icon(Icons.store_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title/merchant' : null,
              ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 4. Category Selector
              Text('Category', style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              if (_isLoadingCategories)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory?.id == cat.id;
                    return ChoiceChip(
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                      avatar: CircleAvatar(
                        backgroundColor: isSelected ? Colors.white : cat.color.withValues(alpha: 0.15),
                        child: Icon(
                          cat.iconData,
                          size: 16,
                          color: isSelected ? cat.color : cat.color,
                        ),
                      ),
                      label: Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 5. Date & Time Picker Row
              Text('Date & Time', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy').format(_selectedDate),
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _selectedTime.format(context),
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 6. Notes Field (Optional)
              Text('Notes (Optional)', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add extra details...',
                  prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXLarge),

              // 7. Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpense ? AppColors.error : AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              isExpense ? 'Save Expense' : 'Save Income',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
