import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_storage.dart';
import '../../../transactions/models/category_model.dart';
import '../../../transactions/services/category_service.dart';
import '../../services/budget_service.dart';

class CreateBudgetScreen extends StatefulWidget {
  final Map<String, dynamic>? initialBudget;

  const CreateBudgetScreen({
    super.key,
    this.initialBudget,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  final BudgetService _budgetService = BudgetService(ApiClient());
  final CategoryService _categoryService = CategoryService(ApiClient());

  String _selectedPeriod = 'monthly'; // 'daily', 'weekly', 'monthly'
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBudget != null) {
      _nameController.text = widget.initialBudget!['name'] ?? '';
      _amountController.text = (widget.initialBudget!['amount'] ?? '').toString();
      _selectedPeriod = widget.initialBudget!['period'] ?? 'monthly';
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await _categoryService.getCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _isLoadingCategories = false;
        if (widget.initialBudget != null && widget.initialBudget!['category_id'] != null) {
          _selectedCategory = _categories.firstWhere(
            (c) => c.id == widget.initialBudget!['category_id'],
            orElse: () => _categories.first,
          );
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = await AppStorage.getUserId();
      final payload = {
        if (widget.initialBudget != null && widget.initialBudget!['id'] != null)
          'id': widget.initialBudget!['id'],
        'user_id': userId,
        'name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : (_selectedCategory != null ? '${_selectedCategory!.name} Budget' : '${_selectedPeriod.toUpperCase()} Budget'),
        'amount': amount,
        'period': _selectedPeriod,
        'category_id': _selectedCategory?.id,
      };

      final res = await _budgetService.saveBudget(payload);

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res is Map<String, dynamic> && res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(widget.initialBudget != null ? 'Budget updated!' : 'Budget created!'),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(res['message'] ?? 'Failed to save budget'),
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
    final isEditing = widget.initialBudget != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Budget' : 'Set Budget Limit'),
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
              // 1. Amount Card
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
                      'BUDGET LIMIT AMOUNT',
                      style: AppTextStyles.caption.copyWith(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '₹ ',
                          style: AppTextStyles.displayLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            autofocus: !isEditing,
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

              // 2. Budget Name (Optional / Custom)
              Text('Budget Name', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Monthly Living, Dining Out, Shopping',
                  prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.primary),
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
              const SizedBox(height: AppDimensions.paddingLarge),

              // 3. Period Selection
              Text('Budget Period', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPeriodOption('Daily', 'daily'),
                  const SizedBox(width: 10),
                  _buildPeriodOption('Weekly', 'weekly'),
                  const SizedBox(width: 10),
                  _buildPeriodOption('Monthly', 'monthly'),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingLarge),

              // 4. Category Attachment (Optional)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Category (Optional)', style: AppTextStyles.titleSmall),
                  if (_selectedCategory != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedCategory = null),
                      child: const Text('Clear / Overall Budget', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingCategories)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      selected: _selectedCategory == null,
                      label: const Text('Overall (All Categories)'),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _selectedCategory == null ? Colors.white : AppColors.textPrimary,
                        fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = null),
                    ),
                    ..._categories.map((cat) {
                      final isSel = _selectedCategory?.id == cat.id;
                      return ChoiceChip(
                        selected: isSel,
                        avatar: Icon(cat.iconData, size: 16, color: isSel ? Colors.white : cat.color),
                        label: Text(cat.name),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = cat);
                        },
                      );
                    }),
                  ],
                ),
              const SizedBox(height: AppDimensions.paddingXLarge),

              // 5. Submit Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                      : Text(
                          isEditing ? 'Update Budget' : 'Save Budget Limit',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
