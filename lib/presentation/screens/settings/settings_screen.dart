// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_viewmodel.dart';
import '../../../data/models/app_config.dart';
import '../../../core/utils/number_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // ✅ CONTROLLERS
  late TextEditingController _sheetNameController;
  late TextEditingController _chatIdsController;
  late TextEditingController _totalCapitalController;
  late TextEditingController _trungBudgetController;
  late TextEditingController _bacBudgetController;
  late TextEditingController _xienBudgetController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsViewModel>().loadConfig().then((_) {
        _updateControllersFromConfig();
      });
    });
  }

  void _initializeControllers() {
    _sheetNameController = TextEditingController();
    _chatIdsController = TextEditingController();
    _totalCapitalController = TextEditingController();
    _trungBudgetController = TextEditingController();
    _bacBudgetController = TextEditingController();
    _xienBudgetController = TextEditingController();
  }

  void _updateControllersFromConfig() {
    final config = context.read<SettingsViewModel>().config;
    
    _sheetNameController.text = config.googleSheets.sheetName;
    _chatIdsController.text = config.telegram.chatIds.join(', ');
    _totalCapitalController.text = config.budget.totalCapital.toString();
    _trungBudgetController.text = config.budget.trungBudget.toString();
    _bacBudgetController.text = config.budget.bacBudget.toString();
    _xienBudgetController.text = config.budget.xienBudget.toString();
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    _chatIdsController.dispose();
    _totalCapitalController.dispose();
    _trungBudgetController.dispose();
    _bacBudgetController.dispose();
    _xienBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGoogleSheetsSection(),
                const SizedBox(height: 24),
                _buildTelegramSection(),
                const SizedBox(height: 24),
                _buildBudgetSection(),
                const SizedBox(height: 24),
                if (viewModel.errorMessage != null)
                  _buildErrorCard(viewModel.errorMessage!),
                const SizedBox(height: 16),
                _buildActionButtons(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoogleSheetsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Google Sheets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            const Text(
              'Credentials đã được cấu hình sẵn trong code',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sheetNameController,
              decoration: const InputDecoration(
                labelText: 'Sheet ID',
                hintText: 'XSKT hoặc 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                helperText: 'ID của Google Sheet',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập Sheet ID';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelegramSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.telegram, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Telegram',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            TextFormField(
              controller: _chatIdsController,
              decoration: const InputDecoration(
                labelText: 'Chat IDs',
                hintText: '-1001234567890, -1009876543210',
                helperText: 'Nhiều Chat ID cách nhau bằng dấu phẩy',
                prefixIcon: Icon(Icons.chat),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập Chat ID';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ BUDGET SECTION MỚI
  Widget _buildBudgetSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Ngân sách',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            
            // TỔNG VỐN
            const Text(
              'Tổng vốn:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            
            TextFormField(
              controller: _totalCapitalController,
              decoration: const InputDecoration(
                labelText: 'Tổng vốn khả dụng',
                hintText: '600000',
                suffixText: 'VNĐ',
                helperText: 'Tổng vốn bạn muốn sử dụng',
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tổng vốn';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Số tiền không hợp lệ';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // PHÂN BỔ HEADER
            const Text(
              '── Phân bổ theo bảng ──',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 14),

            // ✅ INFO - Đặt TRƯỚC các input (giống screenshot)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade300, size: 24),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget "Tất cả" sẽ tự động tính:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tổng vốn - (Tổng tiền dòng thứ 5 của 3 bảng)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Miền Trung
            TextFormField(
              controller: _trungBudgetController,
              decoration: const InputDecoration(
                labelText: 'Miền Trung',
                hintText: '200000',
                suffixText: 'VNĐ',
                prefixIcon: Icon(Icons.filter_1),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              validator: (value) => _validateBudgetField(value, 'Miền Trung'),
            ),

            const SizedBox(height: 16),

            // Miền Bắc
            TextFormField(
              controller: _bacBudgetController,
              decoration: const InputDecoration(
                labelText: 'Miền Bắc',
                hintText: '200000',
                suffixText: 'VNĐ',
                prefixIcon: Icon(Icons.filter_2),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              validator: (value) => _validateBudgetField(value, 'Miền Bắc'),
            ),

            const SizedBox(height: 16),

            // Xiên
            TextFormField(
              controller: _xienBudgetController,
              decoration: const InputDecoration(
                labelText: 'Xiên',
                hintText: '150000',
                suffixText: 'VNĐ',
                prefixIcon: Icon(Icons.favorite_border),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() {}),
              validator: (value) => _validateBudgetField(value, 'Xiên'),
            ),

            const SizedBox(height: 16),

            // SUMMARY
            _buildBudgetSummary(),
            
          ],
        ),
      ),
    );
  }

  // ✅ BUDGET SUMMARY
  Widget _buildBudgetSummary() {
    final totalCapital = double.tryParse(_totalCapitalController.text) ?? 0;
    final trungBudget = double.tryParse(_trungBudgetController.text) ?? 0;
    final bacBudget = double.tryParse(_bacBudgetController.text) ?? 0;
    final xienBudget = double.tryParse(_xienBudgetController.text) ?? 0;
    
    final totalAllocated = trungBudget + bacBudget + xienBudget;
    final remaining = totalCapital - totalAllocated;
    final isValid = totalAllocated <= totalCapital;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFF2C2C2C) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? const Color(0xFF2C2C2C) : Colors.red.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng phân bổ:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isValid ? Colors.orange.shade300 : Colors.red.shade700,
                ),
              ),
              Text(
                NumberUtils.formatCurrency(totalAllocated),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isValid ? Colors.orange.shade300 : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vốn còn lại:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isValid ? Colors.orange.shade300 : Colors.red.shade700,
                ),
              ),
              Text(
                NumberUtils.formatCurrency(remaining),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isValid ? Colors.orange.shade300 : Colors.red.shade700,
                ),
              ),
            ],
          ),
          if (!isValid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '⚠️ Tổng phân bổ vượt quá tổng vốn!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _validateBudgetField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập budget $fieldName';
    }
    final number = double.tryParse(value);
    if (number == null || number < 0) {
      return 'Số tiền không hợp lệ';
    }
    return null;
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                context.read<SettingsViewModel>().clearError();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(SettingsViewModel viewModel) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: viewModel.isLoading ? null : _saveConfigAndTest,
            icon: viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Lưu và kiểm tra kết nối'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: viewModel.isLoading ? null : () => _syncRSSData(viewModel),
            icon: viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Đồng bộ dữ liệu RSS'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildConnectionStatus(
                'Google Sheets',
                viewModel.isGoogleSheetsConnected,
                Icons.cloud,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildConnectionStatus(
                'Telegram',
                viewModel.isTelegramConnected,
                Icons.telegram,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(String label, bool isConnected, IconData icon) {
    return Card(
      color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isConnected ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? Colors.green.shade700 : Colors.grey,
                ),
              ),
            ),
            Icon(
              isConnected ? Icons.check_circle : Icons.cancel,
              color: isConnected ? Colors.green : Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfigAndTest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final totalCapital = double.parse(_totalCapitalController.text);
    final trungBudget = double.parse(_trungBudgetController.text);
    final bacBudget = double.parse(_bacBudgetController.text);
    final xienBudget = double.parse(_xienBudgetController.text);
    
    if (trungBudget + bacBudget + xienBudget > totalCapital) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Tổng phân bổ vượt quá tổng vốn!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final config = AppConfig(
      googleSheets: GoogleSheetsConfig.withHardcodedCredentials(
        sheetName: _sheetNameController.text.trim(),
      ),
      telegram: TelegramConfig(
        botToken: TelegramConfig.defaultBotToken,
        chatIds: _chatIdsController.text
            .split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList(),
      ),
      budget: BudgetConfig(
        totalCapital: totalCapital,
        trungBudget: trungBudget,
        bacBudget: bacBudget,
        xienBudget: xienBudget,
      ),
    );

    final viewModel = context.read<SettingsViewModel>();
    
    final saved = await viewModel.saveConfig(config);
    
    if (!saved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu cấu hình thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await viewModel.testGoogleSheetsConnection();
    await viewModel.testTelegramConnection();

    if (mounted) {
      String message = 'Đã lưu cấu hình.\n';
      
      if (viewModel.isGoogleSheetsConnected && viewModel.isTelegramConnected) {
        message += 'Cả 2 kết nối đều thành công!';
      } else if (viewModel.isGoogleSheetsConnected) {
        message += 'Google Sheets: ✓\nTelegram: ✗';
      } else if (viewModel.isTelegramConnected) {
        message += 'Google Sheets: ✗\nTelegram: ✓';
      } else {
        message += 'Cả 2 kết nối đều thất bại!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: (viewModel.isGoogleSheetsConnected && 
                          viewModel.isTelegramConnected)
              ? Colors.green
              : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  Future<void> _syncRSSData(SettingsViewModel viewModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text(
          'Đồng bộ dữ liệu mới từ RSS vào Google Sheet?\n\n'
          'Quá trình này có thể mất vài phút.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đồng bộ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final message = await viewModel.syncRSSData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: viewModel.errorMessage != null
              ? Colors.red
              : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}