import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MeuApp());

const corPrincipal = Color(0xFF00796B);
const diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const nomesMeses = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
];

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meus Gastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: corPrincipal, useMaterial3: true),
      home: const Capa(),
    );
  }
}

// ---------------------------------------------------------------------------
// CAPA (tela de abertura)
// ---------------------------------------------------------------------------
class Capa extends StatefulWidget {
  const Capa({super.key});

  @override
  State<Capa> createState() => _CapaState();
}

class _CapaState extends State<Capa> {
  bool _saiu = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), _entrar);
  }

  void _entrar() {
    if (!mounted || _saiu) return;
    _saiu = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TelaInicial(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _entrar,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004D40), Color(0xFF26A69A)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircleAvatar(
                radius: 70,
                backgroundColor: Color.fromRGBO(255, 255, 255, 0.15),
                child: Icon(Icons.bar_chart_rounded,
                    size: 84, color: Colors.white),
              ),
              SizedBox(height: 28),
              Text(
                'Meus Gastos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Controle seu dinheiro, semana a semana',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODELO E FUNÇÕES AUXILIARES
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// GRÁFICO DE BARRAS (sem bibliotecas externas)
// ---------------------------------------------------------------------------
class GraficoBarras extends StatelessWidget {
  final List<String> rotulos;
  final List<double> valores;
  final int destaque;
  final Color cor;

  const GraficoBarras({
    super.key,
    required this.rotulos,
    required this.valores,
    required this.destaque,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final maior = valores.fold<double>(0, (a, b) => a > b ? a : b);
    const alturaMax = 110.0;
    final estilo = Theme.of(context).textTheme.labelSmall;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(valores.length, (i) {
          final v = valores[i];
          final h = maior == 0 ? 3.0 : math.max(3.0, alturaMax * v / maior);
          final atual = i == destaque;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(v == 0 ? '' : v.toStringAsFixed(0), style: estilo),
                const SizedBox(height: 4),
                Container(
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: atual ? cor : cor.withAlpha(90),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  rotulos[i],
                  style: estilo?.copyWith(
                    fontWeight: atual ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TELA PRINCIPAL
// ---------------------------------------------------------------------------
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

  // --- cálculos ---------------------------------------------------------

  DateTime get _inicioSemana {
    final agora = DateTime.now();
    // semana começa na segunda-feira
    return DateTime(agora.year, agora.month, agora.day - (agora.weekday - 1));
  }

  /// Gasto de cada dia da semana atual (índice 0 = segunda).
  List<double> get gastosPorDia {
    final inicio = _inicioSemana;
    final fim = DateTime(inicio.year, inicio.month, inicio.day + 7);
    final lista = List<double>.filled(7, 0);
    for (final g in gastos) {
      if (!g.data.isBefore(inicio) && g.data.isBefore(fim)) {
        lista[g.data.weekday - 1] += g.valor;
      }
    }
    return lista;
  }

  double get gastoSemana => gastosPorDia.fold<double>(0, (a, b) => a + b);

  /// Gasto de cada um dos últimos 6 meses (o último é o mês atual).
  List<double> get gastosUltimosMeses {
    final agora = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(agora.year, agora.month - (5 - i));
      return gastos
          .where((g) => g.data.year == m.year && g.data.month == m.month)
          .fold<double>(0, (soma, g) => soma + g.valor);
    });
  }

  List<String> get rotulosMeses {
    final agora = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(agora.year, agora.month - (5 - i));
      return nomesMeses[m.month - 1];
    });
  }

  double get gastoMes => gastosUltimosMeses.last;

  // --- diálogos -----------------------------------------------------------

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

  // --- interface ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sobra = salario - gastoMes;
    final cores = Theme.of(context).colorScheme;
    final porcentagem =
        salario > 0 ? (gastoMes / salario).clamp(0.0, 1.0).toDouble() : 0.0;
    final porDia = gastosPorDia;
    final porMes = gastosUltimosMeses;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus Gastos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novoGasto,
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Resumo
          Card(
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
                        icon: const Icon(Icons.edit),
                        onPressed: _editarSalario),
                  ),
                  const Divider(),
                  _linha('Gasto na semana', moeda(gastoSemana)),
                  _linha('Gasto no mês', moeda(gastoMes)),
                  _linha(
                    'Sobra do mês',
                    moeda(sobra),
                    cor: sobra < 0 ? cores.error : Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: porcentagem,
                      minHeight: 10,
                      color: porcentagem >= 0.9 ? cores.error : corPrincipal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    salario > 0
                        ? '${(gastoMes / salario * 100).toStringAsFixed(0)}% do salário gasto neste mês'
                        : 'Informe seu salário para ver a porcentagem gasta',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          // Gráfico semanal
          _cartaoGrafico(
            titulo: 'Gastos da semana',
            subtitulo: 'Total: ${moeda(gastoSemana)} (segunda a domingo)',
            grafico: GraficoBarras(
              rotulos: diasSemana,
              valores: porDia,
              destaque: DateTime.now().weekday - 1,
              cor: corPrincipal,
            ),
          ),

          // Gráfico mensal
          _cartaoGrafico(
            titulo: 'Gastos por mês',
            subtitulo: 'Últimos 6 meses',
            grafico: GraficoBarras(
              rotulos: rotulosMeses,
              valores: porMes,
              destaque: 5,
              cor: Colors.orange.shade700,
            ),
          ),

          // Lista
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text('Gastos recentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (gastos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Nenhum gasto ainda.')),
            )
          else
            ...gastos.map(
              (g) => Dismissible(
                key: ObjectKey(g),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: cores.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  setState(() => gastos.remove(g));
                  _salvar();
                },
                child: ListTile(
                  title: Text(g.descricao),
                  subtitle: Text(dataBr(g.data)),
                  trailing: Text(moeda(g.valor),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cartaoGrafico({
    required String titulo,
    required String subtitulo,
    required Widget grafico,
  }) =>
      Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              grafico,
            ],
          ),
        ),
      );

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
