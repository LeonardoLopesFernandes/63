import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papeleta63/api/session.dart';
import 'package:papeleta63/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _fotoPerfil;
  late final TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: Session.getPrinterIp());
    _carregarFoto();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _carregarFoto() {
    final path = Session.getProfilePhoto();
    if (path != null) {
      final f = File(path);
      if (f.existsSync()) setState(() => _fotoPerfil = f);
    }
  }

  Future<void> _escolherFoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      final arquivo = File(picked.path);
      Session.saveProfilePhoto(arquivo.path);
      setState(() => _fotoPerfil = arquivo);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto atualizada com sucesso')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao escolher foto: $e')),
      );
    }
  }

  void _salvarIp() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o IP da impressora')),
      );
      return;
    }
    Session.savePrinterIp(ip);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('IP da impressora salvo: $ip')),
    );
  }

  void _confirmarSaida() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        Session.clearAll();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFD32F2F);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FE),
      appBar: AppBar(
        title: const Text('Perfil do Usuário', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: brandRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _escolherFoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _fotoPerfil != null ? FileImage(_fotoPerfil!) : null,
                    child: _fotoPerfil == null
                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: brandRed, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Toque para alterar a foto', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informações da Conta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandRed)),
                    const SizedBox(height: 12),
                    Text('Nome: ${Session.getUserName() ?? 'Usuário'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('E-mail: ${Session.getUserEmail() ?? 'Não informado'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('Loja: ${Session.getUserStore()}', style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.print, color: brandRed),
                        SizedBox(width: 8),
                        Text('Configuração da Impressora Socket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: brandRed)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP da Impressora',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: brandRed)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _salvarIp,
                        style: ElevatedButton.styleFrom(backgroundColor: brandRed, foregroundColor: Colors.white),
                        child: const Text('Salvar IP'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmarSaida,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Sair da Conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
