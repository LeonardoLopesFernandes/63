import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter, SystemNavigator, Clipboard;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:papeleta63/api/endpoints.dart';
import 'package:papeleta63/api/models.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/barcode_scanner_screen.dart';
import 'package:papeleta63/screens/browser_screen.dart';
import 'package:papeleta63/screens/login_screen.dart';
import 'package:papeleta63/screens/preview_screen.dart';
import 'package:papeleta63/screens/profile_screen.dart';
import 'package:papeleta63/utils/celulares.dart';
import 'package:papeleta63/utils/specs_parser.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<CelularSpec> _celulares = [];
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

  void _onScroll() => _evaluateBottom();

  void _evaluateBottom() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final atBottom = max <= 0 || _scroll.position.pixels >= max - 24;
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
    // Sessão expirada enquanto o app estava aberto/fechado: volta ao
    // login, que reloga sozinho com as credenciais salvas.
    if (!Session.hasValidToken()) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        });
      }
      return;
    }
    // Inclui assets + já buscados via MobileAPI (phones.json) para que
    // S23 etc., uma vez buscados, apareçam na lista.
    final celulares = await loadAllCelulares();
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
    if (mounted) {
      setState(() {
        _celulares = celulares;
        _loaded = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateBottom());
    }
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

  Future<void> _onPhoneRenamed(CelularSpec phone, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'phone_name_${phone.id}';
    await prefs.setString(key, newName);

    final idx = _celulares.indexWhere((p) => p.id == phone.id);
    if (idx != -1) {
      _celulares[idx] = CelularSpec(
        id: phone.id, marca: phone.marca, modelo: newName,
        armazenamento: phone.armazenamento, specs: phone.specs,
      );
    }

    for (var i = 0; i < _states.length; i++) {
      if (_states[i].selectedPhone?.id == phone.id) {
        _states[i] = _states[i].copyWith(
          selectedPhone: CelularSpec(
            id: phone.id, marca: phone.marca, modelo: newName,
            armazenamento: phone.armazenamento, specs: phone.specs,
          ),
        );
      }
    }

    _saveAll();
    if (mounted) setState(() {});
    _toast('Modelo renomeado para "$newName"');
  }

  Future<void> _onPhoneDeleted(CelularSpec phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('phone_deleted_${phone.id}', true);

    _celulares.removeWhere((p) => p.id == phone.id);

    for (var i = 0; i < _states.length; i++) {
      if (_states[i].selectedPhone?.id == phone.id) {
        _states[i] = _states[i].copyWith(selectedPhone: null);
      }
    }

    _saveAll();
    if (mounted) setState(() {});
    _toast('Modelo removido');
  }

  Future<void> _onPhonesDeleted(List<CelularSpec> phones) async {
    if (phones.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = phones.map((p) => p.id).toSet();
    for (final id in ids) {
      await prefs.setBool('phone_deleted_$id', true);
    }
    _celulares.removeWhere((p) => ids.contains(p.id));
    for (var i = 0; i < _states.length; i++) {
      final sel = _states[i].selectedPhone;
      if (sel != null && ids.contains(sel.id)) {
        _states[i] = _states[i].copyWith(selectedPhone: null);
      }
    }
    _saveAll();
    if (mounted) setState(() {});
    _toast('${ids.length} modelo(s) removido(s)');
  }

  Future<void> _onPhoneEdited(CelularSpec phone, List<String> newSpecs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('phone_specs_${phone.id}', newSpecs);

    final idx = _celulares.indexWhere((p) => p.id == phone.id);
    if (idx != -1) {
      _celulares[idx] = CelularSpec(
        id: phone.id, marca: phone.marca, modelo: phone.modelo,
        armazenamento: phone.armazenamento, specs: newSpecs,
      );
    }

    for (var i = 0; i < _states.length; i++) {
      if (_states[i].selectedPhone?.id == phone.id) {
        _states[i] = _states[i].copyWith(
          selectedPhone: CelularSpec(
            id: phone.id, marca: phone.marca, modelo: phone.modelo,
            armazenamento: phone.armazenamento, specs: newSpecs,
          ),
        );
      }
    }

    _saveAll();
    if (mounted) setState(() {});
    _toast('Specs do "${phone.modelo}" atualizadas!');
  }

  Future<void> _showAddModelDialog() async {
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final pasteController = TextEditingController();
    final specsControllers = List.generate(6, (_) => TextEditingController());
    final specLabels = ['Câmera traseira', 'Câmera frontal', 'RAM', 'Bateria', 'Processador', 'Tela'];
    final specHints = [
      'Ex: 50 Mp + 12 Mp + 10 Mp',
      'Ex: 12MP',
      'Ex: 8 GB de RAM',
      'Ex: 5000 mAh',
      'Ex: 8 Core 3.2 GHZ',
      'Ex: 6,7"',
    ];

    // Extrai specs do texto colado (ficha técnica) e preenche os campos.
    void extrair() {
      final texto = pasteController.text;
      if (texto.trim().isEmpty) return;
      final specs = parseSpecsDeFicha(texto);
      for (var i = 0; i < specs.length && i < 6; i++) {
        specsControllers[i].text = specs[i];
      }
      if (descController.text.trim().isEmpty) {
        descController.text = extrairDescricao(texto, '');
      }
      setState(() {});
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF4F8FE),
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F8FE),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            automaticallyImplyLeading: false,
            title: const Center(
              child: Text('Adicionar modelo manualmente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Descrição do modelo *',
                    hintText: 'Ex: SAMSUNG A17 5G 256GB',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Preço do aparelho *',
                    hintText: 'Ex: 150000 (para R\$ 1.500,00)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Colar ficha técnica (busquei no navegador)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    TextField(
                      controller: pasteController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Cole aqui o texto com as specs...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: 'Colar do clipboard',
                        icon: const Icon(Icons.content_paste, color: Color(0xFF0D47A1), size: 20),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          final texto = data?.text ?? '';
                          if (texto.isNotEmpty) {
                            pasteController.text = texto;
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: extrair,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Extrair specs automaticamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Especificações (6 campos)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(6, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: specsControllers[i],
                    decoration: InputDecoration(
                      labelText: specLabels[i],
                      hintText: specHints[i],
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.black38),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final desc = descController.text.trim();
                          final price = priceController.text.trim();
                          if (desc.isEmpty || price.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Preencha descrição e preço')),
                            );
                            return;
                          }
                          final specs = specsControllers
                              .map((c) => c.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (specs.length < 3) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Preencha pelo menos 3 especificações')),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          _saveManualModel(desc, price, specs);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Adicionar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveManualModel(String desc, String price, List<String> specs) async {
    final upper = desc.toUpperCase();
    String marca = 'Desconhecido';
    if (upper.contains('SAMSUNG') || upper.contains('GALAXY')) marca = 'Samsung';
    else if (upper.contains('MOTOROLA') || upper.contains('MOTO') || upper.contains('EDGE')) marca = 'Motorola';
    else if (upper.contains('XIAOMI') || upper.contains('REDMI') || upper.contains('POCO')) marca = 'Xiaomi';
    else if (upper.contains('APPLE') || upper.contains('IPHONE')) marca = 'Apple';

    String armazenamento = 'Não informado';
    final storageMatch = RegExp(r'(\d{2,4})\s?GB').firstMatch(upper);
    if (storageMatch != null) {
      armazenamento = '${storageMatch.group(1)}GB';
    }

    var modelo = desc;
    if (armazenamento != 'Não informado') {
      modelo = modelo.replaceAll(RegExp(r'\d{2,4}\s?GB', caseSensitive: false), '').trim();
    }

    final newPhone = CelularSpec(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      marca: marca,
      modelo: modelo.toUpperCase(),
      armazenamento: armazenamento,
      specs: specs,
    );

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('manual_phones') ?? [];
    existing.add(jsonEncode(newPhone.toJson()));
    await prefs.setStringList('manual_phones', existing);

    setState(() {
      _celulares.add(newPhone);
    });

    final priceDigits = price.replaceAll(RegExp(r'[^0-9]'), '');
    _onStateChange(0, _states[0].copyWith(
      selectedPhone: newPhone,
      priceText: priceDigits,
    ));

    _toast('Modelo "$modelo $armazenamento" adicionado e selecionado!');
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
    try {
      final resp = await getPriceSignStandalone(
        storeId: Session.getUserStore(),
        type: 'PAPELETA_PROMOCIONAL',
        ean: ean,
        startDate: _today(),
      );
      await _mostrarDialogoResultados(index, resp.items);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        Session.clearToken();
        Session.onLoginChange?.call();
        return;
      } else if (msg.contains('403')) {
        _toast('Acesso negado.');
      } else {
        _toast('Erro ao consultar EAN: $msg');
      }
    }
  }

  void _openBrowser(int index) {
    final selected = _states[index].selectedPhone;
    final query = selected == null
        ? 'celular'
        : '${selected.marca} ${selected.modelo} ${selected.armazenamento}';
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrowserScreen(initialQuery: query)),
    );
  }

  Future<void> _abrirBuscaDescricao(int index, String query) async {
    final q = query.trim();
    if (q.length < 2) {
      _toast('Digite ao menos 2 caracteres');
      return;
    }
    _toast('Buscando...');
    try {
      final resp = await getSingleLabelPrinting(
        storeId: Session.getUserStore(),
        description: q,
        startDate: _today(),
      );
      final dept63Items = resp.items.where((item) {
        final dept = item.department.toLowerCase();
        return dept.contains('63') || dept.contains('telefonia');
      }).toList();
      await _mostrarDialogoResultados(index, dept63Items.isNotEmpty ? dept63Items : resp.items);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        // Limpa só o token (mantém credenciais p/ o auto-login relogar sozinho).
        Session.clearToken();
        Session.onLoginChange?.call();
        return;
      } else if (msg.contains('403')) {
        _toast('Acesso negado.');
      } else {
        _toast('Erro na busca: $msg');
      }
    }
  }

  Future<void> _mostrarDialogoResultados(int index, List<PriceSign> items) async {
    if (!mounted) return;
    if (items.isEmpty) {
      _toast('Nenhum resultado encontrado');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecione o aparelho'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (c, i) {
              final item = items[i];
              return ListTile(
                title: Text(item.description),
                subtitle: Text('R\$ ${item.price}'),
                onTap: () {
                  // 1. Preenche IMEDIATAMENTE com o que veio da 1ª API.
                  Navigator.pop(ctx);
                  _states[index] = _states[index].copyWith(
                    selectedPhone: CelularSpec(
                      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
                      marca: '',
                      modelo: item.description,
                      armazenamento: 'Não informado',
                      specs: [],
                    ),
                    priceText: parsePriceToDigits(item.price),
                    ean: item.ean,
                    codSap: item.sap,
                  );
                  _saveAll();
                  if (mounted) setState(() {});
                  _toast('${item.description} selecionado — buscando specs...');

                  // 2. Em background busca specs corretas (MobileAPI/GSMArena).
                  Future.microtask(() async {
                    final matched = await getOrCreateSpecs(item.description, _celulares);
                    if (!mounted) return;
                    if (matched != null) {
                      final already = _celulares.any((c) =>
                          c.modelo.toLowerCase() == matched.modelo.toLowerCase() &&
                          c.armazenamento.toLowerCase() == matched.armazenamento.toLowerCase());
                      if (!already) {
                        setState(() => _celulares = [..._celulares, matched]);
                      }
                      _states[index] = _states[index].copyWith(
                        selectedPhone: matched,
                        priceText: parsePriceToDigits(item.price),
                        ean: item.ean,
                        codSap: item.sap,
                      );
                      _saveAll();
                      setState(() {});
                      _toast('${matched.modelo} ${matched.armazenamento} — specs carregadas');
                    } else {
                      _toast('Specs não encontradas na internet para: ${item.description}');
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    final outros = _celulares
        .where((c) => c.marca != 'Motorola' && c.marca != 'Samsung')
        .toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _onBackPressed(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FE),
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            // Toolbar que some ao rolar para baixo e volta ao rolar pra cima.
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              centerTitle: true,
              backgroundColor: const Color(0xFFF4F8FE),
              foregroundColor: const Color(0xFF1D1B20),
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child:
                    Image.asset('assets/ic_papeleta.png', width: 34, height: 34),
              ),
              title: Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                    children: [
                      TextSpan(
                        text: 'Plano de ',
                        style: TextStyle(color: Color(0xFFD32F2F)),
                      ),
                      TextSpan(
                        text: 'Telefonia',
                        style: TextStyle(color: Color(0xFF0040A0)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person, color: Color(0xFFD32F2F)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ],
            ),
            SliverPadding(
              // Menos padding lateral -> cards mais largos. O bottom grande
              // reserva espaço pro FAB, que fica abaixo do último card.
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FormRow(
                      index: i,
                      state: _states[i],
                      motorolaPhones: motorola,
                      samsungPhones: samsung,
                      outrosPhones: outros,
                      allPhones: _celulares,
                      onStateChange: (s) => _onStateChange(i, s),
                      onScan: () => _openScanner(i),
                      onSearchSubmit: _abrirBuscaDescricao,
                      onSearchWeb: (i) => _openBrowser(i),
                      onWeekToggle: (checked) {
                        if (checked) {
                          for (var j = 0; j < 4; j++) {
                            _states[j] = j == i
                                ? _states[j].copyWith(daSemana: true)
                                : _states[j].copyWith(daSemana: false);
                          }
                        } else {
                          _states[i] = _states[i].copyWith(daSemana: false);
                        }
                        _saveAll();
                        setState(() {});
                      },
                      onPhoneRenamed: (phone, newName) =>
                          _onPhoneRenamed(phone, newName),
                      onPhoneDeleted: (phone) => _onPhoneDeleted(phone),
                      onPhonesDeleted: (phones) => _onPhonesDeleted(phones),
                      onPhoneEdited: (phone, newSpecs) =>
                          _onPhoneEdited(phone, newSpecs),
                      onAddModel: _showAddModelDialog,
                    ),
                  ),
                  childCount: 4,
                ),
              ),
            ),
            if (_errors.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _errors
                        .map((e) => Text(e,
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)))
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: _atBottom
            ? SizedBox(
                width: MediaQuery.of(context).size.width - 24,
                child: FloatingActionButton.extended(
                  onPressed: _gerar,
                  backgroundColor: const Color(0xFFD32F2F),
                  label: const Text('GERAR PAPELETA',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
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
  final List<CelularSpec> outrosPhones;
  final List<CelularSpec> allPhones;
  final void Function(PapeletaFormState) onStateChange;
  final VoidCallback onScan;
  final void Function(int, String) onSearchSubmit;
  final void Function(bool) onWeekToggle;
  final void Function(int) onSearchWeb;
  final void Function(CelularSpec, String) onPhoneRenamed;
  final void Function(CelularSpec) onPhoneDeleted;
  final void Function(List<CelularSpec>) onPhonesDeleted;
  final void Function(CelularSpec, List<String>) onPhoneEdited;
  final VoidCallback onAddModel;

  const FormRow({
    super.key,
    required this.index,
    required this.state,
    required this.motorolaPhones,
    required this.samsungPhones,
    this.outrosPhones = const [],
    required this.allPhones,
    required this.onStateChange,
    required this.onScan,
    required this.onSearchSubmit,
    required this.onWeekToggle,
    required this.onSearchWeb,
    required this.onPhoneRenamed,
    required this.onPhoneDeleted,
    required this.onPhonesDeleted,
    required this.onPhoneEdited,
    required this.onAddModel,
  });

  @override
  State<FormRow> createState() => _FormRowState();
}

class _FormRowState extends State<FormRow> {
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _priceCtrl.dispose();
    _discountCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0x1AD32F2F))),
          color: Colors.white,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header compacto: PAPELETA X + busca + ícones na mesma faixa.
                Row(
                  children: [
                    Text('PAPELETA ${widget.index + 1}',
                        style: const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onSubmitted: (q) => widget.onSearchSubmit(widget.index, q),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Buscar aparelho...',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFD32F2F), size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward, color: Color(0xFFD32F2F), size: 18),
                            onPressed: () => widget.onSearchSubmit(widget.index, _searchCtrl.text),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFEBEE).withOpacity(0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _miniIcon(Icons.public, const Color(0xFF0D47A1),
                        'Buscar ficha técnica na internet',
                        () => widget.onSearchWeb(widget.index)),
                    const SizedBox(width: 6),
                    _miniIcon(Icons.qr_code_scanner, const Color(0xFFD32F2F),
                        'Escanear código de barras', widget.onScan),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Modelo', style: TextStyle(color: Color(0xFF49454F), fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                PhoneDropdown(
                  selectedPhone: widget.state.selectedPhone,
                  motorolaPhones: widget.motorolaPhones,
                  samsungPhones: widget.samsungPhones,
                  outrosPhones: widget.outrosPhones,
                  onPhoneSelected: (p) => widget.onStateChange(widget.state.copyWith(selectedPhone: p)),
                  onPhoneRenamed: (phone, newName) => widget.onPhoneRenamed(phone, newName),
                  onPhoneDeleted: (phone) => widget.onPhoneDeleted(phone),
                  onPhonesDeleted: (phones) => widget.onPhonesDeleted(phones),
                  onPhoneEdited: (phone, newSpecs) => widget.onPhoneEdited(phone, newSpecs),
                  onAddModel: widget.onAddModel,
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
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12)),
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
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFFD32F2F),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniIcon(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
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
  final List<CelularSpec> outrosPhones;
  final void Function(CelularSpec?) onPhoneSelected;
  final void Function(CelularSpec, String) onPhoneRenamed;
  final void Function(CelularSpec) onPhoneDeleted;
  final void Function(List<CelularSpec>) onPhonesDeleted;
  final void Function(CelularSpec, List<String>) onPhoneEdited;
  final VoidCallback onAddModel;

  const PhoneDropdown({
    super.key,
    required this.selectedPhone,
    required this.motorolaPhones,
    required this.samsungPhones,
    this.outrosPhones = const [],
    required this.onPhoneSelected,
    required this.onPhoneRenamed,
    required this.onPhoneDeleted,
    required this.onPhonesDeleted,
    required this.onPhoneEdited,
    required this.onAddModel,
  });

  @override
  State<PhoneDropdown> createState() => _PhoneDropdownState();
}

class _PhoneDropdownState extends State<PhoneDropdown> {
  bool _expanded = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CelularSpec> _filter(List<CelularSpec> phones) {
    if (_searchTerm.trim().isEmpty) return phones;
    final q = _searchTerm.toLowerCase();
    return phones
        .where((p) =>
            p.modelo.toLowerCase().contains(q) ||
            p.armazenamento.toLowerCase().contains(q) ||
            p.marca.toLowerCase().contains(q))
        .toList();
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(selectedText.isEmpty ? 'Selecione o modelo...' : selectedText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                const Icon(Icons.arrow_drop_down, color: Color(0xFFD32F2F)),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchTerm = v),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar modelo na lista...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                        suffixIcon: _searchTerm.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchTerm = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF0F4F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_circle, color: Color(0xFF0D47A1)),
                    title: const Text('Adicionar modelo manualmente', style: TextStyle(fontSize: 16, color: Color(0xFF0D47A1), fontWeight: FontWeight.w500)),
                    onTap: () {
                      setState(() => _expanded = false);
                      widget.onAddModel();
                    },
                  ),
                  const Divider(),
                  const Padding(padding: EdgeInsets.all(8), child: Text('Motorola', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  ..._filter(widget.motorolaPhones).map((p) => _item(p)),
                  const Divider(),
                  const Padding(padding: EdgeInsets.all(8), child: Text('Samsung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  ..._filter(widget.samsungPhones).map((p) => _item(p)),
                  if (_filter(widget.outrosPhones).isNotEmpty) ...[
                    const Divider(),
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Buscados na internet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    ..._filter(widget.outrosPhones).map((p) => _item(p)),
                  ],
                ],
              ),
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
      onLongPress: () => _showOptionsDialog(phone),
    );
  }

  static const _azul = Color(0xFF0D47A1);

  void _showOptionsDialog(CelularSpec phone) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(
          bottom: 24.0,
          left: 24.0,
          right: 24.0,
          top: 12.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador de arraste
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${phone.modelo} ${phone.armazenamento}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'O que deseja fazer?',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _optionButton(
              icon: Icons.edit,
              iconColor: _azul,
              label: 'Renomear',
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(phone);
              },
            ),
            const SizedBox(height: 8),
            _optionButton(
              icon: Icons.build_rounded,
              iconColor: _azul,
              label: 'Editar Especificações',
              onTap: () {
                Navigator.pop(ctx);
                _showEditSpecsDialog(phone);
              },
            ),
            const SizedBox(height: 8),
            _optionButton(
              icon: Icons.delete,
              iconColor: Colors.red.shade600,
              label: 'Remover',
              textColor: Colors.red.shade600,
              onTap: () {
                Navigator.pop(ctx);
                _showRemoveModelsDialog(phone);
              },
            ),
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _azul,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(CelularSpec phone) {
    final controller = TextEditingController(text: phone.modelo);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: const Text('Renomear modelo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Novo nome',
            hintText: 'Ex: Meu S23 Personalizado',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != phone.modelo) {
                widget.onPhoneRenamed(phone, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showEditSpecsDialog(CelularSpec phone) {
    final specsControllers = phone.specs.map((s) => TextEditingController(text: s)).toList();
    final pasteController = TextEditingController();
    final specLabels = ['Câmera traseira', 'Câmera frontal', 'RAM', 'Bateria', 'Processador', 'Tela'];
    final specHints = [
      'Ex: 50 Mp + 12 Mp + 10 Mp',
      'Ex: 12MP',
      'Ex: 8 GB de RAM',
      'Ex: 5000 mAh',
      'Ex: 8 Core 3.2 GHZ',
      'Ex: 6,7"',
    ];

    while (specsControllers.length < 6) {
      specsControllers.add(TextEditingController());
    }

    // Extrai as specs do texto colado (ficha técnica) e preenche os campos.
    void extrair() {
      final texto = pasteController.text;
      if (texto.trim().isEmpty) return;
      final specs = parseSpecsDeFicha(texto);
      for (var i = 0; i < specs.length && i < 6; i++) {
        specsControllers[i].text = specs[i];
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text('${phone.modelo} ${phone.armazenamento}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final q =
                          '${phone.marca} ${phone.modelo} ${phone.armazenamento}';
                      Navigator.of(ctx).push(MaterialPageRoute(
                          builder: (_) => BrowserScreen(initialQuery: q)));
                    },
                    icon: const Icon(Icons.public, size: 18),
                    label: const Text('Buscar ficha no navegador'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side:
                          const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Colar ficha técnica (extrai as specs automaticamente)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    TextField(
                      controller: pasteController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Cole aqui o texto com as specs...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        tooltip: 'Colar do clipboard',
                        icon: const Icon(Icons.content_paste, color: Color(0xFF0D47A1), size: 20),
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          final texto = data?.text ?? '';
                          if (texto.isNotEmpty) pasteController.text = texto;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: extrair,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Extrair specs automaticamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Edite as especificações:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(6, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: specsControllers[i],
                    decoration: InputDecoration(
                      labelText: i < specLabels.length ? specLabels[i] : 'Spec ${i + 1}',
                      hintText: i < specHints.length ? specHints[i] : '',
                    ),
                  ),
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final newSpecs = specsControllers
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (newSpecs.length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Preencha pelo menos 3 especificações')),
                );
                return;
              }
              Navigator.pop(ctx);
              widget.onPhoneEdited(phone, newSpecs);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showRemoveModelsDialog(CelularSpec phone) {
    final todos = <CelularSpec>[
      ...widget.motorolaPhones,
      ...widget.samsungPhones,
      ...widget.outrosPhones,
    ];
    final selecionados = <String>{phone.id};
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          title: const Text('Remover modelos'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Selecione os modelos que deseja remover:',
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: todos.map((p) {
                        final sel = selecionados.contains(p.id);
                        return CheckboxListTile(
                          dense: true,
                          value: sel,
                          activeColor: const Color(0xFFD32F2F),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${p.modelo} ${p.armazenamento}',
                              style: const TextStyle(fontSize: 14)),
                          onChanged: (v) => set(() {
                            if (v == true) {
                              selecionados.add(p.id);
                            } else {
                              selecionados.remove(p.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: selecionados.isEmpty
                  ? null
                  : () {
                      final remover = todos
                          .where((p) => selecionados.contains(p.id))
                          .toList();
                      Navigator.pop(ctx);
                      widget.onPhonesDeleted(remover);
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Remover (${selecionados.length})'),
            ),
          ],
        ),
      ),
    );
  }


}
