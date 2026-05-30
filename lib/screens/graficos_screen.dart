import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../services/database_service.dart';

class GraficosScreen extends StatefulWidget {
  final String usuario;
  final String mesRef;
  const GraficosScreen(
      {super.key, required this.usuario, required this.mesRef});
  @override
  State<GraficosScreen> createState() => _GraficosScreenState();
}

class _GraficosScreenState extends State<GraficosScreen>
    with SingleTickerProviderStateMixin {
  final _db  = DatabaseService();
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late TabController _tab;

  List<Transacao> _todas = [];
  List<Transacao> _doMes = [];
  bool _carregando = true;

  final _cores = const [
    Color(0xFF3498DB), Color(0xFFE74C3C), Color(0xFF2ECC71),
    Color(0xFFF39C12), Color(0xFF9B59B6), Color(0xFF1ABC9C),
    Color(0xFFE67E22), Color(0xFF34495E),
  ];

  final _mesesAbrev = const [
    'Jan','Fev','Mar','Abr','Mai','Jun',
    'Jul','Ago','Set','Out','Nov','Dez'
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    _todas = await _db.buscarTodas(widget.usuario);
    _doMes = _todas.where((t) => t.mesRef == widget.mesRef).toList();
    setState(() => _carregando = false);
  }

  Map<String, Map<String, double>> _resumoPorMes() {
    final Map<String, Map<String, double>> mapa = {};
    for (final t in _todas) {
      mapa.putIfAbsent(t.mesRef, () => {'Receita': 0, 'Despesa': 0});
      mapa[t.mesRef]![t.tipo] = (mapa[t.mesRef]![t.tipo] ?? 0) + t.valor;
    }
    return Map.fromEntries(mapa.entries.toList()
      ..sort((a, b) {
        DateTime _parse(String s) {
          final p = s.split('/');
          return DateTime(int.parse(p[1]), int.parse(p[0]));
        }
        return _parse(a.key).compareTo(_parse(b.key));
      }));
  }

  Map<String, double> _gastosPorCategoria() {
    final Map<String, double> mapa = {};
    for (final t in _doMes) {
      if (t.tipo == 'Despesa') {
        mapa[t.categoria] = (mapa[t.categoria] ?? 0) + t.valor;
      }
    }
    return mapa;
  }

  Map<int, Map<String, double>> _evolucaoAnual() {
    final ano = widget.mesRef.split('/').last;
    final mapa = {
      for (int i = 1; i <= 12; i++) i: {'Receita': 0.0, 'Despesa': 0.0}
    };
    for (final t in _todas) {
      final p = t.mesRef.split('/');
      if (p.length == 2 && p[1] == ano) {
        final mes = int.tryParse(p[0]);
        if (mes != null) {
          mapa[mes]![t.tipo] = (mapa[mes]![t.tipo] ?? 0) + t.valor;
        }
      }
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6F8),
    appBar: AppBar(
      title: Text('Gráficos — ${widget.usuario}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      bottom: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: 'Mensal',     icon: Icon(Icons.bar_chart,   size: 18)),
          Tab(text: 'Categorias', icon: Icon(Icons.pie_chart,   size: 18)),
          Tab(text: 'Anual',      icon: Icon(Icons.show_chart,  size: 18)),
        ],
      ),
    ),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: _tab, children: [
            _tabBarras(),
            _tabPizza(),
            _tabAnual(),
          ]),
  );

  // ── ABA 1: Barras mensais ───────────────────────────────────────
  Widget _tabBarras() {
    final resumo = _resumoPorMes();
    final labels = resumo.keys.toList();
    if (labels.isEmpty) return _vazio();

    final grupos = labels.asMap().entries.map((e) {
      final rec  = resumo[e.value]!['Receita']!;
      final desp = resumo[e.value]!['Despesa']!;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: rec,  color: const Color(0xFF27AE60),
            width: 10, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: desp, color: const Color(0xFFE74C3C),
            width: 10, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('Histórico de Receitas e Despesas',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        _legenda(),
        const SizedBox(height: 16),
        SizedBox(height: 280, child: BarChart(BarChartData(
          barGroups: grupos,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                'R\$${(v / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(fontSize: 9)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 32,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                final p = labels[i].split('/');
                return Text(
                  '${_mesesAbrev[int.parse(p[0]) - 1]}\n${p[1].substring(2)}',
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                );
              },
            )),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              _fmt.format(rod.toY),
              const TextStyle(color: Colors.white, fontSize: 12)),
          )),
        ))),
        const SizedBox(height: 16),
        ...resumo.entries.map((e) {
          final rec  = e.value['Receita']!;
          final desp = e.value['Despesa']!;
          final sal  = rec - desp;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              title: Text(e.key,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Rec: ${_fmt.format(rec)}  |  Desp: ${_fmt.format(desp)}',
                style: const TextStyle(fontSize: 12)),
              trailing: Text(_fmt.format(sal),
                  style: TextStyle(
                      color: sal >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ]),
    );
  }

  // ── ABA 2: Pizza por categoria ──────────────────────────────────
  Widget _tabPizza() {
    final gastos = _gastosPorCategoria();
    if (gastos.isEmpty) {
      return _vazio(msg: 'Sem despesas em ${widget.mesRef}');
    }
    final total    = gastos.values.fold(0.0, (a, b) => a + b);
    final cats     = gastos.keys.toList();
    final sections = cats.asMap().entries.map((e) {
      final val = gastos[e.value]!;
      return PieChartSectionData(
        color: _cores[e.key % _cores.length],
        value: val,
        title: '${(val / total * 100).toStringAsFixed(1)}%',
        radius: 90,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('Gastos por Categoria — ${widget.mesRef}',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 16),
        SizedBox(height: 250, child: PieChart(PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ))),
        const SizedBox(height: 16),
        ...cats.asMap().entries.map((e) {
          final cor = _cores[e.key % _cores.length];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 14, height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: cor, shape: BoxShape.circle)),
              Expanded(child: Text(e.value,
                  style: GoogleFonts.poppins(fontSize: 13))),
              Text(_fmt.format(gastos[e.value]!),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: cor)),
            ]),
          );
        }),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total despesas',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          Text(_fmt.format(total),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
      ]),
    );
  }

  // ── ABA 3: Evolução anual ───────────────────────────────────────
  Widget _tabAnual() {
    final ano    = widget.mesRef.split('/').last;
    final evoluc = _evolucaoAnual();
    final recs   = List.generate(12,
        (i) => FlSpot(i.toDouble(), evoluc[i + 1]!['Receita']!));
    final desps  = List.generate(12,
        (i) => FlSpot(i.toDouble(), evoluc[i + 1]!['Despesa']!));
    final maxY   = [...recs, ...desps]
        .map((s) => s.y)
        .fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('Evolução Anual $ano',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        _legenda(),
        const SizedBox(height: 16),
        SizedBox(height: 280, child: LineChart(LineChartData(
          minY: 0,
          maxY: maxY * 1.2 + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 24,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= 12) return const SizedBox();
                return Text(_mesesAbrev[i],
                    style: const TextStyle(fontSize: 9));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                'R\$${(v / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(fontSize: 9)),
            )),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            _linha(recs,  const Color(0xFF27AE60)),
            _linha(desps, const Color(0xFFE74C3C)),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                _fmt.format(s.y),
                const TextStyle(color: Colors.white, fontSize: 12))).toList(),
            ),
          ),
        ))),
        const SizedBox(height: 16),
        // Tabela anual
        Table(
          border: TableBorder.all(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8)),
          columnWidths: const {
            0: FlexColumnWidth(1.2), 1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF2C3E50)),
              children: ['Mês', 'Receitas', 'Despesas', 'Saldo']
                  .map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(h,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        textAlign: TextAlign.center),
                  ))
                  .toList(),
            ),
            ...List.generate(12, (i) {
              final rec  = evoluc[i + 1]!['Receita']!;
              final desp = evoluc[i + 1]!['Despesa']!;
              final sal  = rec - desp;
              return TableRow(
                decoration: BoxDecoration(
                    color: i % 2 == 0 ? Colors.white : Colors.grey.shade50),
                children: [
                  _cell(_mesesAbrev[i]),
                  _cell(_fmt.format(rec),  color: Colors.green),
                  _cell(_fmt.format(desp), color: Colors.red),
                  _cell(_fmt.format(sal),
                      color: sal >= 0 ? Colors.green : Colors.red,
                      bold: true),
                ],
              );
            }),
          ],
        ),
      ]),
    );
  }

  LineChartBarData _linha(List<FlSpot> spots, Color cor) =>
      LineChartBarData(
        spots: spots, color: cor, isCurved: true, barWidth: 3,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 4, color: cor,
              strokeWidth: 2, strokeColor: Colors.white),
        ),
        belowBarData: BarAreaData(
            show: true, color: cor.withOpacity(0.08)),
      );

  Widget _cell(String txt, {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(txt,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.normal)),
      );

  Widget _legenda() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _dot(const Color(0xFF27AE60)), const SizedBox(width: 4),
      Text('Receitas', style: GoogleFonts.poppins(fontSize: 12)),
      const SizedBox(width: 16),
      _dot(const Color(0xFFE74C3C)), const SizedBox(width: 4),
      Text('Despesas', style: GoogleFonts.poppins(fontSize: 12)),
    ],
  );

  Widget _dot(Color c) => Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _vazio({String msg = 'Nenhum dado disponível'}) =>
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ));
}
