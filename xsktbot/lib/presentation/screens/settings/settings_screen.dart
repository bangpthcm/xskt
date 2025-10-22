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
  
  late TextEditingController _sheetNameController;
  late TextEditingController _chatIdsController;
  late TextEditingController _cycleTargetController;  // ✅ NEW
  late TextEditingController _xienBudgetController;
  late TextEditingController _tuesdayExtraBudgetController;

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
    _cycleTargetController = TextEditingController();  // ✅ NEW
    _xienBudgetController = TextEditingController();
    _tuesdayExtraBudgetController = TextEditingController();  // ✅ NEW
  }

  void _updateControllersFromConfig() {
    final config = context.read<SettingsViewModel>().config;
    
    _sheetNameController.text = config.googleSheets.sheetName;
    _chatIdsController.text = config.telegram.chatIds.join(', ');
    _cycleTargetController.text = config.budget.cycleTarget.toString();  // ✅ NEW
    _xienBudgetController.text = config.budget.xienBudget.toString();
    _tuesdayExtraBudgetController.text = config.budget.tuesdayExtraBudget.toString();  // ✅ NEW
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    _chatIdsController.dispose();
    _cycleTargetController.dispose();  // ✅ NEW
    _xienBudgetController.dispose();
    _tuesdayExtraBudgetController.dispose();  // ✅ NEW
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
            
            // ✅ CHU KỲ: Chỉ cần 1 field
            const Text(
              'Chu kỳ 00-99:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            
            TextFormField(
              controller: _cycleTargetController,  // ✅ NEW controller
              decoration: const InputDecoration(
                labelText: 'Ngân sách mục tiêu',
                hintText: '340000',
                suffixText: 'VNĐ',
                helperText: 'Target budget cho chu kỳ (±5% flexibility)',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập ngân sách chu kỳ';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Số tiền không hợp lệ';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // ✅ XIÊN
            const Text(
              'Cặp số (Xiên):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            
            TextFormField(
              controller: _xienBudgetController,
              decoration: const InputDecoration(
                labelText: 'Ngân sách mục tiêu',
                hintText: '19000',
                suffixText: 'VNĐ',
                helperText: 'Ngân sách cho mỗi cặp số xiên',
                prefixIcon: Icon(Icons.favorite_border),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập ngân sách xiên';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Số tiền không hợp lệ';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // ✅ TUESDAY EXTRA BUDGET
            const Text(
              'Ngân sách bổ sung:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            
            TextFormField(
              controller: _tuesdayExtraBudgetController,  // ✅ NEW controller
              decoration: const InputDecoration(
                labelText: 'Tiền thêm khi có Thứ 3',
                hintText: '200000',
                suffixText: 'VNĐ',
                helperText: 'Tăng budget khi ngày cuối/áp cuối là Thứ 3',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tiền thêm cho Thứ 3';
                }
                final number = double.tryParse(value);
                if (number == null || number < 0) {
                  return 'Số tiền không hợp lệ';
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
        
        // ✅ THÊM NÚT ĐỒNG BỘ RSS
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
        cycleTarget: double.parse(_cycleTargetController.text),  // ✅ NEW
        xienBudget: double.parse(_xienBudgetController.text),
        tuesdayExtraBudget: double.parse(_tuesdayExtraBudgetController.text),  // ✅ NEW
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
        message += 'Cả 2 kết nối đều thành công!\n';  // ✅ Thông báo rõ ràng
      } else if (viewModel.isGoogleSheetsConnected) {
        message += 'Google Sheets: ✓\nTelegram: ✗ (Bot token không hợp lệ)';  // ✅ Chi tiết lỗi
      } else if (viewModel.isTelegramConnected) {
        message += 'Google Sheets: ✗\nTelegram: ✓ (Bot token hợp lệ)';  // ✅ Chi tiết
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
  
  // ✅ THÊM METHOD NÀY
  Future<void> _syncRSSData(SettingsViewModel viewModel) async {
    // Show confirmation dialog
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

    // Perform sync
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