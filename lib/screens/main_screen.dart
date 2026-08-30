import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, SystemNavigator;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papeleta63/api/endpoints.dart';
import 'package:papeleta63/api/models.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/barcode_scanner_screen.dart';
import 'package:papeleta63/screens/preview_screen.dart';
import 'package:papeleta63/utils/celulares.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final List<CelularSpec> _celulares;
  late List<PapeletaFormState> _states;
  bool _loaded = false;
  bool _atBottom = false;
  List<String> _errors = [];
  final ScrollController _scroll = ScrollController();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _states = List.generate(4, (_) => PapeletaFormState());
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    final atBottom = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 24;
    if (atBottom != _atBottom && mounted) setState(() => _atBottom = atBottom);
  }

  String _randomPriceDigits() {
    final cents = _random.nextInt(220000) + 80000; // R$ 800,00 a R$ 2.999,00
    return cents.toString();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final celulares = await loadCelulares();
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 4; i++) {
      final phoneId = prefs.getString('papeleta_${i}_phone');
      CelularSpec? phone;
      if (phoneId != null) {
        for (final c in celulares) {
          if (c.id == phoneId) {
            phone = c;
            break;
          }
        }
      }
      _states[i] = PapeletaFormState(
        selectedPhone: phone,
        priceText: prefs.getString('papeleta_${i}_price') ?? _randomPriceDigits(),
        discountText: prefs.getString('papeleta_${i}_discount') ?? '100',
        daSemana: prefs.getBool('papeleta_${i}_semana') ?? false,
      );
    }
    if (mounted) setState(() {
      _celulares = celulares;
      _loaded = true;
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 4; i++) {
      final s = _states[i];
      await prefs.setString('papeleta_${i}_phone', s.selectedPhone?.id ?? '');
      await prefs.setString('papeleta_${i}_price', s.priceText);
      await prefs.setString('papeleta_${i}_discount', s.discountText);
      await prefs.setBool('papeleta_${i}_semana', s.daSemana);
    }
  }

  void _onStateChange(int i, PapeletaFormState s) {
    _states[i] = s;
    _saveAll();
    if (mounted) setState(() {});
  }

  void _gerar() async {
    final newErrors = <String>[];
    final dados = <PapeletaData>[];
    for (var i = 0; i < 4; i++) {
      final s = _states[i];
      if (s.selectedPhone == null) {
        newErrors.add('Papeleta ${i + 1}: selecione um modelo');
      } else {
        final price = parsePrice(s.priceText);
        final discount = parsePrice(s.discountText);
        if (price <= 0) {
          newErrors.add('Papeleta ${i + 1}: digite o preço');
        } else if (discount <= 0) {
          newErrors.add('Papeleta ${i + 1}: digite o desconto');
        } else {
          final discountedPrice = (price - discount) < 0 ? 0.0 : price - discount;
          final parc = calcParcelas(discountedPrice, daSemana: s.daSemana);
          final phone = s.selectedPhone!;
          dados.add(PapeletaData(
            modelo: phone.modelo,
            armazenamento: phone.armazenamento,
            specs: phone.specs,
            precoOriginal: fmtPrice(price),
            desconto: fmtPrice(discount),
            precoComDesconto: fmtPrice(discountedPrice),
            qtdParcelas: parc.first,
            valorParcela: fmtPrice(parc.second),
            ean: s.ean,
            codSap: s.codSap,
            daSemana: s.daSemana,
          ));
        }
      }
    }
    setState(() => _errors = newErrors);
    if (newErrors.isEmpty && dados.length == 4) {
      await _saveAll();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PreviewScreen(dados: dados)),
        );
      }
    }
  }

  void _openScanner(int index) async {
    final ean = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (ean == null || ean.isEmpty) return;
    await _consultarEan(ean, index);
  }

  Future<void> _consultarEan(String ean, int index) async {
    final token = Session.getToken();
    if (token == null || token.isEmpty) {
      _toast('Sessão expirada. Faça login novamente.');
      return;
    }
    try {
      final resp = await getPriceSignStandalone(
        storeId: Session.getUserStore(),
        type: 'PAPELETA_PROMOCIONAL',
        ean: ean,
        startDate: _today(),
      );
      if (resp.items.isNotEmpty) {
        final item = resp.items.first;
        final matched = findPhoneByDescription(_celulares, item.description);
        if (matched != null) {
          _states[index] = _states[index].copyWith(
            selectedPhone: matched,
            priceText: parsePriceToDigits(item.price),
            ean: item.ean,
            codSap: item.sap,
          );
          _saveAll();
          if (mounted) setState(() {});
          _toast('${matched.modelo} selecionado na Papeleta ${index + 1}');
        } else {
          _toast('Modelo não encontrado: ${item.description}');
        }
      } else {
        _toast('Nenhum item encontrado para o EAN informado');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        _toast('Sessão expirada.');
      } else if (msg.contains('403')) {
        _toast('Acesso negado.');
      } else {
        _toast('Erro ao consultar EAN: $msg');
      }
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<List<PriceSign>> _searchApi(String query) async {
    final resp = await getPriceSignStandalone(
      storeId: Session.getUserStore(),
      type: 'PAPELETA_PROMOCIONAL',
      description: query,
      startDate: _today(),
    );
    return resp.items;
  }

  void _applySearchResult(int index, CelularSpec phone, String priceDigits, String ean, String codSap) {
    _states[index] = _states[index].copyWith(
      selectedPhone: phone,
      priceText: priceDigits,
      ean: ean,
      codSap: codSap,
    );
    _saveAll();
    if (mounted) setState(() {});
    _toast('${phone.modelo} selecionado');
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onBackPressed(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Deseja sair do aplicativo?',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NÃO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SIM, SAIR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (sair == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final motorola = _celulares.where((c) => c.marca == 'Motorola').toList();
    final samsung = _celulares.where((c) => c.marca == 'Samsung').toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _onBackPressed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FE),
        appBar: AppBar(
        title: const Text('Plano de Telefonia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1D1B20),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: 4,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FormRow(
                  index: i,
                  state: _states[i],
                  motorolaPhones: motorola,
                  samsungPhones: samsung,
                  allPhones: _celulares,
                  onStateChange: (s) => _onStateChange(i, s),
                  onScan: () => _openScanner(i),
                  onSearch: _searchApi,
                  onPhoneSelectedFromSearch: _applySearchResult,
                  onWeekToggle: (checked) {
                    if (checked) {
                      for (var j = 0; j < 4; j++) {
                        _states[j] = j == i ? _states[j].copyWith(daSemana: true) : _states[j].copyWith(daSemana: false);
                      }
                    } else {
                      _states[i] = _states[i].copyWith(daSemana: false);
                    }
                    _saveAll();
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          if (_errors.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _errors.map((e) => Text(e, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))).toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: _atBottom
          ? SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: FloatingActionButton.extended(
                onPressed: _gerar,
                backgroundColor: const Color(0xFF0D47A1),
                label: const Text('GERAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.check, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class FormRow extends StatefulWidget {
  final int index;
  final PapeletaFormState state;
  final List<CelularSpec> motorolaPhones;
  final List<CelularSpec> samsungPhones;
  final List<CelularSpec> allPhones;
  final void Function(PapeletaFormState) onStateChange;
  final VoidCallback onScan;
  final Future<List<PriceSign>> Function(String) onSearch;
  final void Function(int, CelularSpec, String, String, String) onPhoneSelectedFromSearch;
  final void Function(bool) onWeekToggle;

  const FormRow({
    super.key,
    required this.index,
    required this.state,
    required this.motorolaPhones,
    required this.samsungPhones,
    required this.allPhones,
    required this.onStateChange,
    required this.onScan,
    required this.onSearch,
    required this.onPhoneSelectedFromSearch,
    required this.onWeekToggle,
  });

  @override
  State<FormRow> createState() => _FormRowState();
}

class _FormRowState extends State<FormRow> {
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  List<PriceSign> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: _format(widget.state.priceText));
    _discountCtrl = TextEditingController(text: _format(widget.state.discountText));
  }

  String _format(String digits) => formatCurrencyInput(digits);

  @override
  void didUpdateWidget(covariant FormRow old) {
    super.didUpdateWidget(old);
    final pf = _format(widget.state.priceText);
    final df = _format(widget.state.discountText);
    if (pf != _priceCtrl.text) _priceCtrl.text = pf;
    if (df != _discountCtrl.text) _discountCtrl.text = df;
  }

  Future<void> _onSearchChanged(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    if (mounted) setState(() => _searching = true);
    try {
      final results = await widget.onSearch(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickResult(PriceSign item) {
    final matched = findPhoneByDescription(widget.allPhones, item.description);
    if (matched != null) {
      widget.onPhoneSelectedFromSearch(widget.index, matched, parsePriceToDigits(item.price), item.ean, item.sap);
      _searchCtrl.clear();
      if (mounted) setState(() => _searchResults = []);
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0x1A0D47A1))),
      color: Colors.white,
      elevation: 4,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text('PAPELETA ${widget.index + 1}', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar aparelho na loja',
                      hintStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: widget.onScan,
                  style: IconButton.styleFrom(backgroundColor: Color(0xFF0D47A1)),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          if (_searchResults.isNotEmpty || _searching)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFBBDEFB))),
              child: _searching
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (c, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          dense: true,
                          title: Text(item.description, style: const TextStyle(fontSize: 14)),
                          onTap: () => _pickResult(item),
                        );
                      },
                    ),
            ),
          const Divider(height: 1, color: Color(0xFFBBDEFB)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Modelo', style: TextStyle(color: Color(0xFF49454F), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                PhoneDropdown(
                  selectedPhone: widget.state.selectedPhone,
                  motorolaPhones: widget.motorolaPhones,
                  samsungPhones: widget.samsungPhones,
                  onPhoneSelected: (p) => widget.onStateChange(widget.state.copyWith(selectedPhone: p)),
                ),
                const SizedBox(height: 16),
                const Text('DIGITE O PREÇO DO APARELHO', style: TextStyle(color: Color(0xFF49454F), fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _currencyField(_priceCtrl, (digits) => widget.onStateChange(widget.state.copyWith(priceText: digits))),
                const SizedBox(height: 16),
                const Text('DIGITE O DESCONTO DO PLANO CONTROLE', style: TextStyle(color: Color(0xFF49454F), fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                _currencyField(_discountCtrl, (digits) => widget.onStateChange(widget.state.copyWith(discountText: digits))),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: const Color(0xFFE8EEF5), borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('CELULAR DA SEMANA (até 15x)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1D1B20), fontSize: 14)),
                        ),
                        Switch(
                          value: widget.state.daSemana,
                          onChanged: widget.onWeekToggle,
                          activeThumbColor: const Color(0xFF0D47A1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyField(TextEditingController ctrl, void Function(String) onDigits) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'digite o valor',
        filled: true,
        fillColor: const Color(0xFFF0F4F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1))),
      ),
      inputFormatters: [TextInputFormatter.withFunction((oldVal, newVal) {
        final digits = newVal.text.replaceAll(RegExp(r'[^0-9]'), '');
        final formatted = formatCurrencyInput(digits);
        onDigits(digits);
        return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
      })],
    );
  }
}

class PhoneDropdown extends StatefulWidget {
  final CelularSpec? selectedPhone;
  final List<CelularSpec> motorolaPhones;
  final List<CelularSpec> samsungPhones;
  final void Function(CelularSpec?) onPhoneSelected;

  const PhoneDropdown({
    super.key,
    required this.selectedPhone,
    required this.motorolaPhones,
    required this.samsungPhones,
    required this.onPhoneSelected,
  });

  @override
  State<PhoneDropdown> createState() => _PhoneDropdownState();
}

class _PhoneDropdownState extends State<PhoneDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.selectedPhone == null ? '' : '${widget.selectedPhone!.modelo} ${widget.selectedPhone!.armazenamento}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(selectedText.isEmpty ? 'Selecione o modelo...' : selectedText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF0D47A1)),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.all(8), child: Text('Motorola', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                ...widget.motorolaPhones.map((p) => _item(p)),
                const Divider(),
                const Padding(padding: EdgeInsets.all(8), child: Text('Samsung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                ...widget.samsungPhones.map((p) => _item(p)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _item(CelularSpec phone) {
    return ListTile(
      dense: true,
      title: Text('${phone.modelo} ${phone.armazenamento}', style: const TextStyle(fontSize: 16)),
      onTap: () {
        widget.onPhoneSelected(phone);
        setState(() => _expanded = false);
      },
    );
  }
}
