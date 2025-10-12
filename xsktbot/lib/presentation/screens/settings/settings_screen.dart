// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'settings_viewmodel.dart';
import '../../../data/models/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Google Sheets Controllers (chỉ còn 2 field)
  late TextEditingController _sheetNameController;
  late TextEditingController _worksheetNameController;
  
  // Telegram Controllers
  late TextEditingController _telegramTokenController;
  late TextEditingController _chatIdsController;
  
  // Budget Controllers
  late TextEditingController _budgetMinController;
  late TextEditingController _budgetMaxController;

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
    _worksheetNameController = TextEditingController();
    _telegramTokenController = TextEditingController();
    _chatIdsController = TextEditingController();
    _budgetMinController = TextEditingController();
    _budgetMaxController = TextEditingController();
  }

  void _updateControllersFromConfig() {
    final config = context.read<SettingsViewModel>().config;
    
    _sheetNameController.text = config.googleSheets.sheetName;
    _worksheetNameController.text = config.googleSheets.worksheetName;
    _telegramTokenController.text = config.telegram.botToken;
    _chatIdsController.text = config.telegram.chatIds.join(', ');
    _budgetMinController.text = config.budget.budgetMin.toString();
    _budgetMaxController.text = config.budget.budgetMax.toString();
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    _worksheetNameController.dispose();
    _telegramTokenController.dispose();
    _chatIdsController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
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
                labelText: 'Sheet Name / ID',
                hintText: 'XSKT hoặc 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                helperText: 'Tên hoặc ID của Google Sheet',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập Sheet Name/ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _worksheetNameController,
              decoration: const InputDecoration(
                labelText: 'Worksheet Name',
                hintText: 'KQXS',
                helperText: 'Tên worksheet chứa dữ liệu kết quả',
                prefixIcon: Icon(Icons.table_chart),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập Worksheet Name';
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
              controller: _telegramTokenController,
              decoration: const InputDecoration(
                labelText: 'Bot Token',
                hintText: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
                prefixIcon: Icon(Icons.key),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập Bot Token';
                }
                if (!value.contains(':')) {
                  return 'Bot Token không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
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
            TextFormField(
              controller: _budgetMinController,
              decoration: const InputDecoration(
                labelText: 'Ngân sách tối thiểu',
                hintText: '330000',
                suffixText: 'VNĐ',
                prefixIcon: Icon(Icons.money_off),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập ngân sách tối thiểu';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Số tiền không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetMaxController,
              decoration: const InputDecoration(
                labelText: 'Ngân sách tối đa',
                hintText: '350000',
                suffixText: 'VNĐ',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập ngân sách tối đa';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Số tiền không hợp lệ';
                }
                final minBudget = double.tryParse(_budgetMinController.text);
                if (minBudget != null && number < minBudget) {
                  return 'Phải lớn hơn ngân sách tối thiểu';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
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
        
        // Hiển thị trạng thái kết nối
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

    final config = AppConfig(
      googleSheets: GoogleSheetsConfig.withHardcodedCredentials(
        sheetName: _sheetNameController.text.trim(),
        worksheetName: _worksheetNameController.text.trim(),
      ),
      telegram: TelegramConfig(
        botToken: _telegramTokenController.text.trim(),
        chatIds: _chatIdsController.text
            .split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList(),
      ),
      budget: BudgetConfig(
        budgetMin: double.parse(_budgetMinController.text),
        budgetMax: double.parse(_budgetMaxController.text),
      ),
    );

    final viewModel = context.read<SettingsViewModel>();
    
    // Lưu config
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

    // Test kết nối Google Sheets
    await viewModel.testGoogleSheetsConnection();
    
    // Test kết nối Telegram
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
}