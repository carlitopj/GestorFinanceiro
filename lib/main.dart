import 'package:flutter/material.dart';
import 'database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor Financeiro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterialDesign: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _movimentacoes = [];

  @override
  void initState() {
    super.initState();
    _atualizarDados();
  }

  // Recarrega as informações vindas do banco de dados ativo
  Future<void> _atualizarDados() async {
    final dados = await _dbService.listarMovimentacoes();
    setState(() {
      _movimentacoes = dados;
    });
  }

  // Adiciona um dado fictício apenas para testar se a gravação funciona
  Future<void> _adicionarDadoTeste() async {
    await _dbService.inserirMovimentacao({
      'descricao': 'Teste Carteira ${DateTime.now().minute}:${DateTime.now().second}',
      'valor': 150.50,
      'tipo': 'receita',
      'data': DateTime.now().toIso8601String(),
    });
    _atualizarDados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor Financeiro'),
      ),
      // MENU LATERAL CORRIGIDO (Sem o botão Novo)
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu Finanças',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // Opção Abrir Banco de Dados de Qualquer Pasta
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Abrir Banco de Dados'),
              onTap: () async {
                Navigator.pop(context); // Fecha o Drawer
                bool importou = await _dbService.abrirArquivo();
                if (importou) {
                  _atualizarDados();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Banco de dados carregado com sucesso!')),
                  );
                }
              },
            ),
            // Opção Salvar Como para Exportar o Banco de Dados
            ListTile(
              leading: const Icon(Icons.save_as),
              title: const Text('Salvar Como...'),
              onTap: () async {
                Navigator.pop(context); // Fecha o Drawer
                String? caminhoSalvo = await _dbService.salvarComo();
                if (caminhoSalvo != null) {
                  _atualizarDados();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cópia do banco criada e ativa!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: _movimentacoes.isEmpty
          ? const Center(
              child: Text(
                'Nenhum dado encontrado no arquivo .db atual.\nUse o botão + para testar a persistência.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: _movimentacoes.length,
              itemBuilder: (context, index) {
                final item = _movimentacoes[index];
                return ListTile(
                  leading: const Icon(Icons.monetization_on, color: Colors.green),
                  title: Text(item['descricao'] ?? ''),
                  subtitle: Text('R\$ ${item['valor']}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarDadoTeste,
        tooltip: 'Adicionar Item de Teste',
        child: const Icon(Icons.add),
      ),
    );
  }
}
