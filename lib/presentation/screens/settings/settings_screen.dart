// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/api_account.dart';
import '../../../data/models/app_config.dart';
import '../../../data/models/probability_config.dart';
import 'settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _sheetNameController;
  late TextEditingController _chatIdsController;
  late TextEditingController _totalCapitalController;
  late TextEditingController _trungBudgetController;
  late TextEditingController _bacBudgetController;
  late TextEditingController _xienBudgetController;
  late TextEditingController _bettingDomainController;
  late TextEditingController _cycleDurationController;
  late TextEditingController _trungDurationController;
  late TextEditingController _bacDurationController;
  late TextEditingController _xienDurationController;
  late TextEditingController _probabilityThresholdController;
  late TextEditingController _probabilityThresholdTatCaController;
  late TextEditingController _probabilityThresholdTrungController;
  late TextEditingController _probabilityThresholdBacController;
  late TextEditingController _probabilityThresholdXienController;

  final List<Map<String, TextEditingController>> _apiAccountControllers = [];

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
    _bettingDomainController = TextEditingController();
    _cycleDurationController = TextEditingController();
    _trungDurationController = TextEditingController();
    _bacDurationController = TextEditingController();
    _xienDurationController = TextEditingController();
    _probabilityThresholdController = TextEditingController();
    _probabilityThresholdTatCaController = TextEditingController();
    _probabilityThresholdTrungController = TextEditingController();
    _probabilityThresholdBacController = TextEditingController();
    _probabilityThresholdXienController = TextEditingController();

    for (int i = 0; i < 3; i++) {
      _apiAccountControllers.add({
        'username': TextEditingController(),
        'password': TextEditingController(),
      });
    }
  }

  void _updateControllersFromConfig() {
    final config = context.read<SettingsViewModel>().config;

    _sheetNameController.text = config.googleSheets.sheetName;
    _chatIdsController.text = config.telegram.chatIds.join(', ');
    _bettingDomainController.text = config.betting.domain;

    _totalCapitalController.text =
        _formatToThousands(config.budget.totalCapital);
    _trungBudgetController.text = _formatToThousands(config.budget.trungBudget);
    _bacBudgetController.text = _formatToThousands(config.budget.bacBudget);
    _xienBudgetController.text = _formatToThousands(config.budget.xienBudget);

    _cycleDurationController.text = config.duration.cycleDuration.toString();
    _trungDurationController.text = config.duration.trungDuration.toString();
    _bacDurationController.text = config.duration.bacDuration.toString();
    _xienDurationController.text = config.duration.xienDuration.toString();

    // ✅ CẬP NHẬT: Hiển thị giá trị Log (ln)
    // Lưu ý tên biến controller là _probabilityThreshold...
    _probabilityThresholdTatCaController.text =
        config.probability.thresholdLnTatCa.toString();
    _probabilityThresholdTrungController.text =
        config.probability.thresholdLnTrung.toString();
    _probabilityThresholdBacController.text =
        config.probability.thresholdLnBac.toString();
    _probabilityThresholdXienController.text =
        config.probability.thresholdLnXien.toString();

    for (int i = 0;
        i < _apiAccountControllers.length && i < config.apiAccounts.length;
        i++) {
      _apiAccountControllers[i]['username']!.text =
          config.apiAccounts[i].username;
      _apiAccountControllers[i]['password']!.text =
          config.apiAccounts[i].password;
    }
  }

  @override
  void dispose() {
    _sheetNameController.dispose();
    _chatIdsController.dispose();
    _totalCapitalController.dispose();
    _trungBudgetController.dispose();
    _bacBudgetController.dispose();
    _xienBudgetController.dispose();
    _bettingDomainController.dispose();
    _cycleDurationController.dispose();
    _trungDurationController.dispose();
    _bacDurationController.dispose();
    _xienDurationController.dispose();
    _probabilityThresholdController.dispose();
    _probabilityThresholdTatCaController.dispose();
    _probabilityThresholdTrungController.dispose();
    _probabilityThresholdBacController.dispose();
    _probabilityThresholdXienController.dispose();

    for (var controllers in _apiAccountControllers) {
      controllers['username']?.dispose();
      controllers['password']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 45, 16, 16),
              children: [
                _buildGoogleSheetsSection(),
                const SizedBox(height: 10),
                _buildTelegramSection(),
                const SizedBox(height: 10),
                _buildApiAccountsSection(),
                const SizedBox(height: 10),
                _buildBudgetSection(),
                const SizedBox(height: 10),
                _buildDurationSection(),
                const SizedBox(height: 10),
                if (viewModel.errorMessage != null)
                  _buildErrorCard(viewModel.errorMessage!),
                const SizedBox(height: 10),
                _buildProbabilitySection(),
                const SizedBox(height: 10),
                _buildActionButtons(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProbabilitySection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.insights, color: Theme.of(context).primaryColor),
        title: const Text(
          'Ngưỡng P_total (Độ hiếm)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Cấu hình P_total cho từng loại cược',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ THÊM: 4 input fields
                _buildProbabilityThresholdField(
                  controller: _probabilityThresholdTatCaController,
                  label: 'Tất cả (3 miền)',
                  hint: '1.18604E-75',
                  helperText: 'P_total nhỏ hơn ngưỡng này thì có thể vào cược',
                ),
                const SizedBox(height: 16),

                _buildProbabilityThresholdField(
                  controller: _probabilityThresholdTrungController,
                  label: 'Miền Trung',
                  hint: '5.56464e-49',
                  helperText: 'P_total nhỏ hơn ngưỡng này thì có thể vào cược',
                ),
                const SizedBox(height: 16),

                _buildProbabilityThresholdField(
                  controller: _probabilityThresholdBacController,
                  label: 'Miền Bắc',
                  hint: '7.74656e-53',
                  helperText: 'P_total nhỏ hơn ngưỡng này thì có thể vào cược',
                ),
                const SizedBox(height: 16),

                _buildProbabilityThresholdField(
                  controller: _probabilityThresholdXienController,
                  label: 'Xiên Bắc',
                  hint: ' 1.97e-6',
                  helperText: 'P1_pair nhỏ hơn ngưỡng này thì có thể vào cược',
                ),

                const SizedBox(height: 24),

                // ✅ THÊM: Giải thích
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📌 Giải thích:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• P_total: Xác suất xuất hiện số/cặp mục tiêu\n'
                        '• Chu kỳ: P_total = P2 × P3\n'
                        '• Xiên: P_total = P1 (cặp gan)\n'
                        '• Giá trị càng nhỏ → Ngày vào cược càng gần\n'
                        '• Giá trị càng lớn → Có thể chờ lâu hơn\n\n'
                        '• Mặc định:\n'
                        '  - Tất cả/Trung/Bắc: 7.74656e-53 (0.000000000005%)\n'
                        '  - Xiên: 1.00e-10 (cao hơn vì ít cặp)\n\n'
                        '• Range cho phép: 8e-8 đến 6e-6',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ THÊM: Helper - Build field input
  Widget _buildProbabilityThresholdField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.functions),
        helperText: helperText,
        helperMaxLines: 3,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập giá trị';
        }

        // ✅ CẬP NHẬT: Validate số Log (thường là số âm từ -500 đến -2)
        final val = double.tryParse(value);
        if (val == null) {
          return 'Phải là số thực (ví dụ: -172.63)';
        }

        // Range an toàn cho Log xác suất
        if (val < -500 || val > -2) {
          return 'Giá trị Log nên từ -500 đến -2';
        }
        return null;
      },
    );
  }

  Widget _buildDurationSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.schedule, color: Theme.of(context).primaryColor),
        title: const Text('Thời lượng chu kỳ',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Cấu hình số ngày cho mỗi loại cược',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chu kỳ
                _buildDurationField(
                  controller: _cycleDurationController,
                  label: 'Chu kỳ 00-99 (ngày)',
                  icon: Icons.calendar_month,
                  hint: '10',
                  minValue: 5,
                  maxValue: 11,
                  helperText: 'Phải > 9 (farming: 9). Mặc định: 10',
                ),
                const SizedBox(height: 16),

                // Miền Trung
                _buildDurationField(
                  controller: _trungDurationController,
                  label: 'Miền Trung (ngày)',
                  icon: Icons.calendar_month,
                  hint: '26',
                  minValue: 25,
                  maxValue: 31,
                  helperText: 'Phải > 25 (farming: 25). Mặc định: 30',
                ),
                const SizedBox(height: 16),

                // Miền Bắc
                _buildDurationField(
                  controller: _bacDurationController,
                  label: 'Miền Bắc (ngày)',
                  icon: Icons.calendar_month,
                  hint: '43',
                  minValue: 41,
                  maxValue: 46,
                  helperText: 'Phải > 41 (threshold: 41). Mặc định: 43',
                ),
                const SizedBox(height: 16),

                // Xiên
                _buildDurationField(
                  controller: _xienDurationController,
                  label: 'Xiên Bắc (ngày)',
                  icon: Icons.calendar_month,
                  hint: '234',
                  minValue: 222,
                  maxValue: 245,
                  helperText: 'Phải > 222 (threshold: 222). Mặc định: 234',
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📌 Giải thích:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Chu kỳ: Số ngày để đợi một vòng quay hoàn chỉnh (3 miền)\n'
                        '• Miền Trung/Bắc: Số ngày cụ thể cho mỗi miền\n'
                        '• Xiên: Số ngày chờ cặp số xuất hiện\n\n'
                        '• Mỗi loại phải lớn hơn threshold để đảm bảo có đủ dữ liệu phân tích',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required int minValue,
    required int maxValue,
    required String helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 2,
        suffixText: 'ngày',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Vui lòng nhập giá trị';
        }
        final intValue = int.tryParse(value);
        if (intValue == null) {
          return 'Phải là số nguyên';
        }
        if (intValue < minValue) {
          return 'Phải >= $minValue';
        }
        if (intValue > maxValue) {
          return 'Phải <= $maxValue';
        }
        return null;
      },
    );
  }

  Widget _buildGoogleSheetsSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.cloud, color: Theme.of(context).primaryColor),
        title: const Text('Google Sheets',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Cấu hình kết nối',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _sheetNameController,
              decoration: const InputDecoration(
                labelText: 'Sheet ID',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập Sheet ID'
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.telegram, color: Theme.of(context).primaryColor),
        title: const Text('Telegram',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Cấu hình thông báo',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _chatIdsController,
              decoration: const InputDecoration(
                labelText: 'Chat IDs',
                helperText: 'Nhiều ID cách nhau bằng dấu phẩy',
                prefixIcon: Icon(Icons.chat),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập Chat ID'
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: Đổi tên thành "Cấu hình sin88" và thêm Domain input
  Widget _buildApiAccountsSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.language, color: Theme.of(context).primaryColor),
        title: const Text('Cấu hình sin88',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Domain và tài khoản',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ✅ THÊM: Domain input ở đầu
                TextFormField(
                  controller: _bettingDomainController,
                  decoration: const InputDecoration(
                    labelText: 'Domain/Host',
                    hintText: 'sin88.pro',
                    prefixIcon: Icon(Icons.language),
                    helperText: 'Domain chung cho tất cả tài khoản',
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Vui lòng nhập domain'
                      : null,
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),

                // ✅ Tài khoản 1
                ..._buildApiAccountFields(0, 'Tài khoản 1'),
                const Divider(height: 32),

                // ✅ Tài khoản 2
                ..._buildApiAccountFields(1, 'Tài khoản 2'),
                const Divider(height: 32),

                // ✅ Tài khoản 3
                ..._buildApiAccountFields(2, 'Tài khoản 3'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildApiAccountFields(int index, String label) {
    return [
      Align(
          alignment: Alignment.centerLeft,
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      const SizedBox(height: 12),
      TextFormField(
        controller: _apiAccountControllers[index]['username'],
        decoration: const InputDecoration(
            labelText: 'Username', prefixIcon: Icon(Icons.person)),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiAccountControllers[index]['password'],
        obscureText: true,
        decoration: const InputDecoration(
            labelText: 'Password', prefixIcon: Icon(Icons.lock)),
      ),
    ];
  }

  Widget _buildBudgetSection() {
    return Card(
      child: ExpansionTile(
        leading:
            Icon(Icons.attach_money, color: Theme.of(context).primaryColor),
        title: const Text('Ngân sách',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('700 => 700.000K',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        initiallyExpanded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _totalCapitalController,
                  decoration: const InputDecoration(
                    labelText: 'Tổng vốn (triệu)',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Phân bổ:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _trungBudgetController,
                  decoration: const InputDecoration(
                      labelText: 'Miền Trung (triệu)',
                      prefixIcon: Icon(Icons.filter_1)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bacBudgetController,
                  decoration: const InputDecoration(
                      labelText: 'Miền Bắc (triệu)',
                      prefixIcon: Icon(Icons.filter_2)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _xienBudgetController,
                  decoration: const InputDecoration(
                      labelText: 'Xiên (triệu)',
                      prefixIcon: Icon(Icons.favorite_border)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                _buildBudgetSummary(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    final totalCapital = _parseFromThousands(_totalCapitalController.text);
    final trungBudget = _parseFromThousands(_trungBudgetController.text);
    final bacBudget = _parseFromThousands(_bacBudgetController.text);
    final xienBudget = _parseFromThousands(_xienBudgetController.text);

    final totalAllocated = trungBudget + bacBudget + xienBudget;
    final remaining = totalCapital - totalAllocated;
    final isValid = totalAllocated <= totalCapital;
    final color = isValid
        ? Theme.of(context).primaryColor
        : Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Tổng phân bổ:', totalAllocated, color),
          _buildSummaryRow('Vốn còn lại:', remaining, color),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color)),
        Text('${NumberUtils.formatCurrency(value)} đ',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(viewModel.isLoading
                ? 'Đang xử lý...'
                : 'Lưu và kiểm tra kết nối'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildApiAccountStatus(viewModel, 0, 'API 1')),
            const SizedBox(width: 8),
            Expanded(child: _buildApiAccountStatus(viewModel, 1, 'API 2')),
            const SizedBox(width: 8),
            Expanded(child: _buildApiAccountStatus(viewModel, 2, 'API 3')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _buildConnectionStatus('Google Sheets',
                    viewModel.isGoogleSheetsConnected, Icons.cloud)),
            const SizedBox(width: 8),
            Expanded(
                child: _buildConnectionStatus(
                    'Telegram', viewModel.isTelegramConnected, Icons.telegram)),
          ],
        ),
      ],
    );
  }

  Widget _buildApiAccountStatus(
      SettingsViewModel viewModel, int index, String label) {
    final status = viewModel.apiAccountStatus[index];
    final color = status == true
        ? ThemeProvider.profit
        : (status == false ? ThemeProvider.loss : Colors.grey);
    final icon = status == true
        ? Icons.check_circle
        : (status == false ? Icons.cancel : Icons.api);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(String label, bool isConnected, IconData icon) {
    final color = isConnected ? ThemeProvider.profit : Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child:
                    Text(label, style: TextStyle(color: color, fontSize: 12))),
            Icon(isConnected ? Icons.check_circle : Icons.cancel,
                color: color, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfigAndTest() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ CẬP NHẬT: Parse giá trị Logarithm từ Controller
    // Dùng tên biến đúng: _probabilityThreshold...
    double thresholdTatCa =
        double.tryParse(_probabilityThresholdTatCaController.text) ?? -172.63;
    double thresholdTrung =
        double.tryParse(_probabilityThresholdTrungController.text) ?? -111.11;
    double thresholdBac =
        double.tryParse(_probabilityThresholdBacController.text) ?? -120.08;
    double thresholdXien =
        double.tryParse(_probabilityThresholdXienController.text) ?? -13.14;

    // Validate Duration (giữ nguyên logic cũ)
    int cycleDuration = int.tryParse(_cycleDurationController.text) ?? 10;
    int trungDuration = int.tryParse(_trungDurationController.text) ?? 26;
    int bacDuration = int.tryParse(_bacDurationController.text) ?? 43;
    int xienDuration = int.tryParse(_xienDurationController.text) ?? 234;

    if (cycleDuration <= 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chu kỳ phải > 4 ngày'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (trungDuration <= 13) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trung phải > 13 ngày'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (bacDuration <= 19) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bắc phải > 19 ngày'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (xienDuration <= 155) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Xiên phải > 155 ngày'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Build Duration Config
    final durationConfig = DurationConfig(
      cycleDuration: cycleDuration,
      trungDuration: trungDuration,
      bacDuration: bacDuration,
      xienDuration: xienDuration,
    );

    // ✅ CẬP NHẬT: Tạo ProbabilityConfig với các trường Ln mới
    final probabilityConfig = ProbabilityConfig(
      thresholdLnTatCa: thresholdTatCa,
      thresholdLnTrung: thresholdTrung,
      thresholdLnBac: thresholdBac,
      thresholdLnXien: thresholdXien,
    );

    // Build full config
    final totalCapital = _parseFromThousands(_totalCapitalController.text);
    final trungBudget = _parseFromThousands(_trungBudgetController.text);
    final bacBudget = _parseFromThousands(_bacBudgetController.text);
    final xienBudget = _parseFromThousands(_xienBudgetController.text);

    if (trungBudget + bacBudget + xienBudget > totalCapital) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vốn phân bổ không hợp lệ'),
        backgroundColor: Colors.red,
      ));
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
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      ),
      budget: BudgetConfig(
        totalCapital: totalCapital,
        trungBudget: trungBudget,
        bacBudget: bacBudget,
        xienBudget: xienBudget,
      ),
      duration: durationConfig,
      probability: probabilityConfig, // ✅ MỚI
      apiAccounts: <ApiAccount>[
        for (int i = 0; i < _apiAccountControllers.length; i++)
          if (_apiAccountControllers[i]['username']!.text.isNotEmpty &&
              _apiAccountControllers[i]['password']!.text.isNotEmpty)
            ApiAccount(
              username: _apiAccountControllers[i]['username']!.text.trim(),
              password: _apiAccountControllers[i]['password']!.text.trim(),
            ),
      ],
      betting: BettingConfig(
        domain: _bettingDomainController.text.trim().isEmpty
            ? 'sin88.pro'
            : _bettingDomainController.text.trim(),
      ),
    );

    final viewModel = context.read<SettingsViewModel>();
    final saved = await viewModel.saveConfig(config);
    if (!saved) return;

    // Test connections
    await viewModel.testGoogleSheetsConnection();
    await viewModel.testTelegramConnection();
    await viewModel.testAllApiAccounts(
        config.apiAccounts, config.betting.domain);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Đã lưu và kiểm tra'),
        backgroundColor: ThemeProvider.profit,
      ));
    }
  }

  // ✅ THÊM: Helper validate
  bool _isValidProbabilityThreshold(double value) {
    return value >= 8e-8 && value <= 6e-6;
  }

  String _formatToThousands(double value) => (value / 1000).toStringAsFixed(0);
  double _parseFromThousands(String text) =>
      (double.tryParse(text) ?? 0) * 1000;
}
