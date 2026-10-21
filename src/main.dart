import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MeuApp());

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Gastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}

class Gasto {
  final String descricao;
  final double valor;
  final DateTime data;

  Gasto(this.descricao, this.valor, this.data);

  Map<String, dynamic> toJson() =>
      {'d': descricao, 'v': valor, 't': data.toIso8601String()};

  factory Gasto.fromJson(Map<String, dynamic> j) => Gasto(
        j['d'] as String,
        (j['v'] as num).toDouble(),
        DateTime.parse(j['t'] as String),
      );
}

String moeda(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

String dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

double? lerValor(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  double salario = 0;
  List<Gasto> gastos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('gastos') ?? [];
    setState(() {
      salario = prefs.getDouble('salario') ?? 0;
      gastos = lista
          .map((s) => Gasto.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('salario', salario);
    await prefs.setStringList(
        'gastos', gastos.map((g) => jsonEncode(g.toJson())).toList());
  }

  double get gastoMes {
    final agora = DateTime.now();
    return gastos
        .where((g) => g.data.year == agora.year && g.data.month == agora.month)
        .fold(0.0, (soma, g) => soma + g.valor);
  }

  double get gastoSemana {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    // semana começa na segunda-feira
    final inicio = hoje.subtract(Duration(days: hoje.weekday - 1));
    return gastos
        .where((g) => !g.data.isBefore(inicio))
        .fold(0.0, (soma, g) => soma + g.valor);
  }

  Future<void> _editarSalario() async {
    final ctrl = TextEditingController(
        text: salario > 0 ? salario.toStringAsFixed(2) : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seu salário'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) {
      final v = lerValor(ctrl.text);
      if (v != null && v >= 0) {
        setState(() => salario = v);
        _salvar();
      }
    }
  }

  Future<void> _novoGasto() async {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    DateTime data = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Novo gasto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: valorCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Valor', prefixText: 'R\$ '),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(dataBr(data)),
                onPressed: () async {
                  final escolhida = await showDatePicker(
                    context: ctx,
                    initialDate: data,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (escolhida != null) setD(() => data = escolhida);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Adicionar')),
          ],
        ),
      ),
    );

    if (ok == true) {
      final v = lerValor(valorCtrl.text);
      if (v != null && v > 0) {
        final desc =
            descCtrl.text.trim().isEmpty ? 'Gasto' : descCtrl.text.trim();
        setState(() {
          gastos.add(Gasto(desc, v, data));
          gastos.sort((a, b) => b.data.compareTo(a.data));
        });
        _salvar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sobra = salario - gastoMes;
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Gastos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoGasto,
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Salário'),
                    subtitle: Text(moeda(salario),
                        style: Theme.of(context).textTheme.headlineSmall),
                    trailing: IconButton(
                        icon: const Icon(Icons.edit), onPressed: _editarSalario),
                  ),
                  const Divider(),
                  _linha('Gasto na semana', moeda(gastoSemana)),
                  _linha('Gasto no mês', moeda(gastoMes)),
                  _linha(
                    'Sobra do mês',
                    moeda(sobra),
                    cor: sobra < 0 ? cores.error : Colors.green.shade700,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: gastos.isEmpty
                ? const Center(child: Text('Nenhum gasto ainda.'))
                : ListView.builder(
                    itemCount: gastos.length,
                    itemBuilder: (ctx, i) {
                      final g = gastos[i];
                      return Dismissible(
                        key: ValueKey('${g.data.toIso8601String()}-$i-${g.descricao}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: cores.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() => gastos.removeAt(i));
                          _salvar();
                        },
                        child: ListTile(
                          title: Text(g.descricao),
                          subtitle: Text(dataBr(g.data)),
                          trailing: Text(moeda(g.valor),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String titulo, String valor, {Color? cor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo),
            Text(valor,
                style: TextStyle(fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      );
}
