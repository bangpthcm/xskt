// lib/presentation/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/number_utils.dart';
import '../../../data/models/api_account.dart';
import '../../../data/models/app_config.dart';
import 'settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _totalCapitalController;
  late TextEditingController _namBudgetController;
  late TextEditingController _trungBudgetController;
  late TextEditingController _bacBudgetController;
  late TextEditingController _xienBudgetController;
  late TextEditingController _bettingDomainController;

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
    _totalCapitalController = TextEditingController();
    _namBudgetController = TextEditingController();
    _trungBudgetController = TextEditingController();
    _bacBudgetController = TextEditingController();
    _xienBudgetController = TextEditingController();
    _bettingDomainController = TextEditingController();

    for (int i = 0; i < 3; i++) {
      _apiAccountControllers.add({
        'username': TextEditingController(),
        'password': TextEditingController(),
      });
    }
  }

  void _updateControllersFromConfig() {
    final config = context.read<SettingsViewModel>().config;

    _bettingDomainController.text = config.betting.domain;
    _totalCapitalController.text =
        _formatToThousands(config.budget.totalCapital);
    _namBudgetController.text = _formatToThousands(config.budget.namBudget);
    _trungBudgetController.text = _formatToThousands(config.budget.trungBudget);
    _bacBudgetController.text = _formatToThousands(config.budget.bacBudget);
    _xienBudgetController.text = _formatToThousands(config.budget.xienBudget);

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
    _totalCapitalController.dispose();
    _namBudgetController.dispose();
    _trungBudgetController.dispose();
    _bacBudgetController.dispose();
    _xienBudgetController.dispose();
    _bettingDomainController.dispose();

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
                _buildApiAccountsSection(),
                const SizedBox(height: 8),
                _buildBudgetSection(),
                const SizedBox(height: 8),
                if (viewModel.errorMessage != null)
                  _buildErrorCard(viewModel.errorMessage!),
                const SizedBox(height: 8),
                _buildActionButtons(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

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
                ..._buildApiAccountFields(0, 'Tài khoản 1'),
                const Divider(height: 32),
                ..._buildApiAccountFields(1, 'Tài khoản 2'),
                const Divider(height: 32),
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
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _apiAccountControllers[index]['username'],
        decoration: const InputDecoration(
          labelText: 'Username',
          prefixIcon: Icon(Icons.person),
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _apiAccountControllers[index]['password'],
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock),
        ),
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
        subtitle: const Text('700 => 700.000đ',
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
                    labelText: 'Tổng vốn (nghìn đ)',
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
                  controller: _namBudgetController,
                  decoration: const InputDecoration(
                    labelText: 'Miền Nam (nghìn đ)',
                    prefixIcon: Icon(Icons.filter),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trungBudgetController,
                  decoration: const InputDecoration(
                    labelText: 'Miền Trung (nghìn đ)',
                    prefixIcon: Icon(Icons.filter_1),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bacBudgetController,
                  decoration: const InputDecoration(
                    labelText: 'Miền Bắc (nghìn đ)',
                    prefixIcon: Icon(Icons.filter_2),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _xienBudgetController,
                  decoration: const InputDecoration(
                    labelText: 'Xiên (nghìn đ)',
                    prefixIcon: Icon(Icons.favorite_border),
                  ),
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
    final namBudget = _parseFromThousands(_namBudgetController.text);
    final trungBudget = _parseFromThousands(_trungBudgetController.text);
    final bacBudget = _parseFromThousands(_bacBudgetController.text);
    final xienBudget = _parseFromThousands(_xienBudgetController.text);

    final totalAllocated = namBudget + trungBudget + bacBudget + xienBudget;
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
        Text(
          '${NumberUtils.formatCurrency(value)} đ',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            onPressed: viewModel.isLoading ? null : _saveConfig,
            icon: viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(viewModel.isLoading ? 'Đang lưu...' : 'Lưu cấu hình'),
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
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final totalCapital = _parseFromThousands(_totalCapitalController.text);
    final namBudget = _parseFromThousands(_namBudgetController.text);
    final trungBudget = _parseFromThousands(_trungBudgetController.text);
    final bacBudget = _parseFromThousands(_bacBudgetController.text);
    final xienBudget = _parseFromThousands(_xienBudgetController.text);

    if (namBudget + trungBudget + bacBudget + xienBudget >
        (1.5 * totalCapital)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vốn phân bổ không hợp lệ'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Giữ nguyên các giá trị hardcoded từ config hiện tại
    final currentConfig = context.read<SettingsViewModel>().config;

    final config = AppConfig(
      googleSheets: currentConfig.googleSheets,
      telegram: currentConfig.telegram,
      budget: BudgetConfig(
        totalCapital: totalCapital,
        namBudget: namBudget,
        trungBudget: trungBudget,
        bacBudget: bacBudget,
        xienBudget: xienBudget,
      ),
      probability: currentConfig.probability,
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

    // Test API accounts sau khi lưu
    await viewModel.testAllApiAccounts(
        config.apiAccounts, config.betting.domain);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Đã lưu cấu hình'),
        backgroundColor: ThemeProvider.profit,
      ));
    }
  }

  String _formatToThousands(double value) => (value / 1000).toStringAsFixed(0);
  double _parseFromThousands(String text) =>
      (double.tryParse(text) ?? 0) * 1000;
}
