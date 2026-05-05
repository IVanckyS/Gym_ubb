import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../core/widgets/section_banner.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/services/history_service.dart';
import '../../../shared/services/workout_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _service = HistoryService();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _exportToPdf() async {
    setState(() => _exporting = true);
    try {
      final unit = context.read<WeightUnitNotifier>().unit;
      final unitLabel = unit == WeightUnit.lbs ? 'lbs' : 'kg';

      final records = await _service.getPersonalRecords();
      final measurements = await _service.getMeasurements();

      final pdf = pw.Document();

      // ── Estilos ────────────────────────────────────────────────────────────
      final headerStyle = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
      final sectionStyle = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
      final cellStyle = pw.TextStyle(fontSize: 10);
      final mutedStyle = pw.TextStyle(fontSize: 9);

      final accentColor = PdfColor.fromHex('#6C63FF');

      // ── Encabezado ─────────────────────────────────────────────────────────
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/'
          '${now.month.toString().padLeft(2, '0')}/${now.year}';

      // ── Mejor PR por ejercicio (mayor peso) ─────────────────────────────────
      final bestPr = <String, Map<String, dynamic>>{};
      for (final r in records) {
        final name = r['exerciseName'] as String? ?? '';
        final w = (r['weightKg'] as num?)?.toDouble() ?? 0;
        final cur = (bestPr[name]?['weightKg'] as num?)?.toDouble() ?? -1;
        if (w > cur) bestPr[name] = r;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Historial de Entrenamiento', style: headerStyle),
                  pw.Text('Generado: $dateStr', style: mutedStyle),
                ],
              ),
              pw.Divider(color: accentColor, thickness: 1.5),
              pw.SizedBox(height: 4),
            ],
          ),
          build: (context) => [
            // ── SECCIÓN: Récords Personales ──────────────────────────────────
            pw.Text('Récords Personales', style: sectionStyle),
            pw.SizedBox(height: 8),

            if (bestPr.isEmpty)
              pw.Text('Sin récords registrados.', style: mutedStyle)
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: ['Ejercicio', 'Peso ($unitLabel)', 'Reps', 'Fecha', 'Estado']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(h, style: mutedStyle),
                            ))
                        .toList(),
                  ),
                  ...bestPr.entries.map((entry) {
                    final r = entry.value;
                    final rawKg = (r['weightKg'] as num?)?.toDouble();
                    final weight = rawKg != null
                        ? toDisplayUnit(rawKg, unit).toStringAsFixed(1)
                        : '--';
                    final repCount = r['reps']?.toString() ?? '--';
                    final date = (r['achievedAt'] as String? ?? '').split('T').first;
                    final validated = r['isValidated'] as bool? ?? false;

                    return pw.TableRow(children: [
                      entry.key,
                      weight,
                      repCount,
                      date,
                      validated ? 'Validado' : 'Pendiente',
                    ]
                        .map((v) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(v,
                                  style: v == 'Validado'
                                      ? pw.TextStyle(fontSize: 9, color: PdfColors.teal)
                                      : cellStyle),
                            ))
                        .toList());
                  }),
                ],
              ),

            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),

            // ── SECCIÓN: Medidas Corporales ──────────────────────────────────
            pw.Text('Medidas Corporales', style: sectionStyle),
            pw.SizedBox(height: 8),

            if (measurements.isEmpty)
              pw.Text('Sin medidas registradas.', style: mutedStyle)
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.8),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                  5: const pw.FlexColumnWidth(1),
                  6: const pw.FlexColumnWidth(1),
                  7: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      'Fecha', 'Peso ($unitLabel)', '% Grasa',
                      'Pecho', 'Cintura', 'Cadera', 'Brazo', 'Pierna',
                    ].map((h) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(h, style: mutedStyle),
                    )).toList(),
                  ),
                  ...measurements.map((m) {
                    final rawKg = (m['weightKg'] as num?)?.toDouble();
                    final weight = rawKg != null
                        ? toDisplayUnit(rawKg, unit).toStringAsFixed(1)
                        : '--';
                    String fmtCm(String key) {
                      final v = m[key];
                      return v != null ? (v as num).toStringAsFixed(1) : '--';
                    }
                    final date = (m['measuredAt'] as String? ?? '').split('T').first;
                    final fat = m['bodyFatPct'] != null
                        ? '${(m['bodyFatPct'] as num).toStringAsFixed(1)}%'
                        : '--';

                    return pw.TableRow(children: [
                      date, weight, fat,
                      fmtCm('chestCm'), fmtCm('waistCm'), fmtCm('hipCm'),
                      fmtCm('armCm'), fmtCm('legCm'),
                    ].map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(v, style: cellStyle),
                    )).toList());
                  }),
                ],
              ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'historial_gym_ubb_$dateStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: AppColors.accentSecondary,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: Column(
        children: [
          SectionBanner(
            title: 'Historial',
            subtitle: 'Progreso · Medidas · Récords',
            label: 'Seguimiento',
            accentColor: const Color(0xFF00C9A7),
            iconName: 'history',
            gradientColors: const [Color(0xFF011210), Color(0xFF012820)],
            trailing: _exporting
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : GestureDetector(
                    onTap: _exportToPdf,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(80)),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                    ),
                  ),
          ),
          Container(
            color: context.colorBgSecondary,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: context.colorTextSecondary,
              indicatorColor: AppColors.accentPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Progreso'),
                Tab(text: 'Medidas'),
                Tab(text: 'Récords'),
                Tab(text: 'Calendario'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _ProgressTab(),
                _MeasurementsTab(),
                _RecordsTab(),
                _CalendarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — PROGRESO POR EJERCICIO
// ═══════════════════════════════════════════════════════════════════════════════

class _ProgressTab extends StatefulWidget {
  const _ProgressTab();

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  final _service = HistoryService();

  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic>? _selectedExercise;
  Map<String, dynamic>? _progressData;
  bool _loadingExercises = true;
  bool _loadingProgress = false;
  String? _error;

  // Vista del gráfico: 'weight' | 'volume'
  String _chartMode = 'weight';

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() { _loadingExercises = true; _error = null; });
    try {
      final list = await _service.getTrainedExercises();
      setState(() {
        _exercises = list;
        _loadingExercises = false;
        if (list.isNotEmpty) {
          _selectedExercise = list.first;
          _loadProgress(list.first['id'] as String);
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingExercises = false; });
    }
  }

  Future<void> _loadProgress(String exerciseId) async {
    setState(() { _loadingProgress = true; _progressData = null; });
    try {
      final data = await _service.getExerciseProgress(exerciseId);
      setState(() { _progressData = data; _loadingProgress = false; });
    } catch (e) {
      setState(() { _loadingProgress = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExercises) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadExercises);
    }
    if (_exercises.isEmpty) {
      return const _EmptyView(
        icon: Icons.show_chart_rounded,
        title: 'Sin datos de progreso',
        subtitle: 'Completa sesiones de entrenamiento\npara ver tu progreso aquí',
      );
    }

    final points = (_progressData?['points'] as List? ?? []).cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Selector de ejercicio ──
          Text('Ejercicio', style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          _ExerciseDropdown(
            exercises: _exercises,
            selected: _selectedExercise,
            onChanged: (ex) {
              setState(() => _selectedExercise = ex);
              if (ex != null) _loadProgress(ex['id'] as String);
            },
          ),
          const SizedBox(height: 20),

          // ── Toggle peso / volumen ──
          Row(
            children: [
              _ChipToggle(
                label: 'Peso máximo',
                selected: _chartMode == 'weight',
                onTap: () => setState(() => _chartMode = 'weight'),
              ),
              const SizedBox(width: 8),
              _ChipToggle(
                label: 'Volumen',
                selected: _chartMode == 'volume',
                onTap: () => setState(() => _chartMode = 'volume'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Gráfico ──
          if (_loadingProgress)
            const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(color: AppColors.accentPrimary)),
            )
          else if (points.isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'Sin sesiones completadas para este ejercicio',
                  style: TextStyle(color: context.colorTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            _ProgressChart(points: points, mode: _chartMode),
            const SizedBox(height: 20),
            // ── Estadísticas rápidas ──
            _ProgressStats(points: points, mode: _chartMode),
            const SizedBox(height: 20),
            // ── Tabla de sesiones ──
            _SessionsTable(points: points),
          ],
        ],
      ),
    );
  }
}

// ── Gráfico de línea ──────────────────────────────────────────────────────────

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.points, required this.mode});
  final List<Map<String, dynamic>> points;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<WeightUnitNotifier>().unit;
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < points.length; i++) {
      final rawVal = mode == 'weight'
          ? (points[i]['maxWeight'] as num?)?.toDouble()
          : (points[i]['volume'] as num?)?.toDouble();
      final val = rawVal != null ? toDisplayUnit(rawVal, unit) : null;
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val));
        if (val < minY) minY = val;
        if (val > maxY) maxY = val;
      }
    }

    if (spots.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text('Sin datos', style: TextStyle(color: context.colorTextSecondary)),
        ),
      );
    }

    final yPad = (maxY - minY) * 0.2;
    final yMin = (minY - yPad).clamp(0, double.infinity).toDouble();
    final yMax = maxY + yPad;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: LineChart(
        LineChartData(
          minY: yMin,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (val, meta) => Text(
                  mode == 'weight'
                      ? '${val.toStringAsFixed(0)}${unit == WeightUnit.lbs ? 'lb' : 'kg'}'
                      : '${(val / (unit == WeightUnit.lbs ? 453.592 : 1000)).toStringAsFixed(1)}${unit == WeightUnit.lbs ? 'klb' : 't'}',
                  style: TextStyle(color: context.colorTextMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (spots.length / 5).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (val, meta) {
                  final i = val.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final date = points[i]['date'] as String? ?? '';
                  if (date.length < 10) return const SizedBox.shrink();
                  final parts = date.split('-');
                  final label = parts.length == 3
                      ? '${parts[2]}/${parts[1]}'
                      : date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: TextStyle(color: context.colorTextMuted, fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.accentPrimary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.accentPrimary,
                  strokeWidth: 2,
                  strokeColor: AppColors.bgSecondary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentPrimary.withValues(alpha: 0.2),
                    AppColors.accentPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.bgTertiary,
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final date = i < points.length ? (points[i]['date'] as String? ?? '') : '';
                final unitLabel = unit == WeightUnit.lbs ? 'lbs' : 'kg';
                final val = mode == 'weight'
                    ? '${s.y.toStringAsFixed(1)} $unitLabel'
                    : '${s.y.toStringAsFixed(0)} $unitLabel vol.';
                return LineTooltipItem(
                  '$val\n$date',
                  TextStyle(color: context.colorTextPrimary, fontSize: 12),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats rápidas ─────────────────────────────────────────────────────────────

class _ProgressStats extends StatelessWidget {
  const _ProgressStats({required this.points, required this.mode});
  final List<Map<String, dynamic>> points;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitNotifier>().unit;
    final unitLabel = weightUnit == WeightUnit.lbs ? 'lbs' : 'kg';
    final vals = points
        .map((p) => mode == 'weight'
            ? (p['maxWeight'] as num?)?.toDouble()
            : (p['volume'] as num?)?.toDouble())
        .whereType<double>()
        .map((v) => toDisplayUnit(v, weightUnit))
        .toList();

    if (vals.isEmpty) return const SizedBox.shrink();

    final max = vals.reduce((a, b) => a > b ? a : b);
    final last = vals.last;
    final first = vals.first;
    final improvement = first > 0 ? ((last - first) / first * 100) : 0.0;
    final isUp = last >= first;

    final unit = mode == 'weight' ? unitLabel : '$unitLabel vol.';

    return Row(
      children: [
        _MiniStat(
          label: 'Máximo',
          value: '${max.toStringAsFixed(1)} $unit',
          color: AppColors.accentPrimary,
        ),
        const SizedBox(width: 10),
        _MiniStat(
          label: 'Último',
          value: '${last.toStringAsFixed(1)} $unit',
          color: AppColors.accentGreen,
        ),
        const SizedBox(width: 10),
        _MiniStat(
          label: 'Progreso',
          value: '${isUp ? '+' : ''}${improvement.toStringAsFixed(1)}%',
          color: isUp ? AppColors.accentGreen : AppColors.accentSecondary,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tabla de sesiones ─────────────────────────────────────────────────────────

class _SessionsTable extends StatelessWidget {
  const _SessionsTable({required this.points});
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle por sesión',
          style: TextStyle(color: context.colorTextPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Builder(builder: (context) {
            final unit = context.watch<WeightUnitNotifier>().unit;
            final unitLabel = unit == WeightUnit.lbs ? 'lbs' : 'kg';
            return Column(
            children: points.reversed.take(10).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final date = du.formatDate(p['date'] as String?);
              final rawMaxW = (p['maxWeight'] as num?)?.toDouble();
              final maxW = rawMaxW != null
                  ? '${toDisplayUnit(rawMaxW, unit).toStringAsFixed(1)} $unitLabel'
                  : '--';
              final rawVol = (p['volume'] as num?)?.toDouble();
              final vol = rawVol != null
                  ? '${toDisplayUnit(rawVol, unit).toStringAsFixed(0)} $unitLabel'
                  : '--';
              final sets = p['completedSets']?.toString() ?? '0';

              return Container(
                decoration: BoxDecoration(
                  border: i > 0
                      ? const Border(top: BorderSide(color: AppColors.border))
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(date, style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(maxW,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colorTextPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: Text(vol,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('$sets series',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
                    ),
                  ],
                ),
              );
            }).toList(),
            );
          }),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MEDIDAS CORPORALES
// ═══════════════════════════════════════════════════════════════════════════════

class _MeasurementsTab extends StatefulWidget {
  const _MeasurementsTab();

  @override
  State<_MeasurementsTab> createState() => _MeasurementsTabState();
}

class _MeasurementsTabState extends State<_MeasurementsTab> {
  final _service = HistoryService();
  List<Map<String, dynamic>> _measurements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getMeasurements();
      setState(() { _measurements = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showAddForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MeasurementForm(
        onSaved: (m) async {
          await _service.createMeasurement(
            measuredAt: m['measuredAt'],
            weightKg: m['weightKg'],
            bodyFatPct: m['bodyFatPct'],
            chestCm: m['chestCm'],
            waistCm: m['waistCm'],
            hipCm: m['hipCm'],
            armCm: m['armCm'],
            legCm: m['legCm'],
            notes: m['notes'],
          );
          await _load();
        },
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteMeasurement(id);
      setState(() => _measurements.removeWhere((m) => m['id'] == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentSecondary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }

    return Column(
      children: [
        // Botón agregar
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                side: const BorderSide(color: AppColors.accentPrimary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar medidas'),
              onPressed: _showAddForm,
            ),
          ),
        ),

        if (_measurements.isEmpty)
          const Expanded(
            child: _EmptyView(
              icon: Icons.monitor_weight_outlined,
              title: 'Sin medidas registradas',
              subtitle: 'Registra tu peso y medidas\npara ver tu evolución',
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentPrimary,
              backgroundColor: AppColors.bgSecondary,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _measurements.length,
                itemBuilder: (_, i) => _MeasurementCard(
                  measurement: _measurements[i],
                  onDelete: () => _delete(_measurements[i]['id'] as String),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.measurement, required this.onDelete});
  final Map<String, dynamic> measurement;
  final VoidCallback onDelete;

  String _fmt(dynamic v, String unit) =>
      v != null ? '${(v as num).toStringAsFixed(1)} $unit' : '--';

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitNotifier>().unit;
    final weightLabel = weightUnit == WeightUnit.lbs ? 'lbs' : 'kg';
    final date = measurement['measuredAt'] as String? ?? '';
    final rawWeightKg = (measurement['weightKg'] as num?)?.toDouble();
    final weight = rawWeightKg != null
        ? '${toDisplayUnit(rawWeightKg, weightUnit).toStringAsFixed(1)} $weightLabel'
        : '--';
    final fat = measurement['bodyFatPct'] != null
        ? '${(measurement['bodyFatPct'] as num).toStringAsFixed(1)}%'
        : null;
    final notes = measurement['notes'] as String?;

    final details = <String, String?>{
      'Pecho': measurement['chestCm'] != null ? _fmt(measurement['chestCm'], 'cm') : null,
      'Cintura': measurement['waistCm'] != null ? _fmt(measurement['waistCm'], 'cm') : null,
      'Cadera': measurement['hipCm'] != null ? _fmt(measurement['hipCm'], 'cm') : null,
      'Brazo': measurement['armCm'] != null ? _fmt(measurement['armCm'], 'cm') : null,
      'Pierna': measurement['legCm'] != null ? _fmt(measurement['legCm'], 'cm') : null,
    }..removeWhere((_, v) => v == null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(date, style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BigVal(label: 'Peso', value: weight, color: AppColors.accentPrimary),
              if (fat != null) ...[
                const SizedBox(width: 16),
                _BigVal(label: '% Grasa', value: fat, color: AppColors.accentSecondary),
              ],
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: details.entries.map((e) => _SmallChip(
                label: e.key,
                value: e.value!,
              )).toList(),
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(notes, style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _BigVal extends StatelessWidget {
  const _BigVal({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorBgTertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
      ),
    );
  }
}

// ── Formulario de medidas ─────────────────────────────────────────────────────

class _MeasurementForm extends StatefulWidget {
  const _MeasurementForm({required this.onSaved});
  final Future<void> Function(Map<String, dynamic>) onSaved;

  @override
  State<_MeasurementForm> createState() => _MeasurementFormState();
}

class _MeasurementFormState extends State<_MeasurementForm> {
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hip = TextEditingController();
  final _arm = TextEditingController();
  final _leg = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_weight, _fat, _chest, _waist, _hip, _arm, _leg, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSaved({
        'weightKg': double.tryParse(_weight.text),
        'bodyFatPct': double.tryParse(_fat.text),
        'chestCm': double.tryParse(_chest.text),
        'waistCm': double.tryParse(_waist.text),
        'hipCm': double.tryParse(_hip.text),
        'armCm': double.tryParse(_arm.text),
        'legCm': double.tryParse(_leg.text),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.accentSecondary),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Registrar medidas',
                  style: TextStyle(color: context.colorTextPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _FormField(controller: _weight, label: 'Peso (kg)', hint: '70.5')),
                const SizedBox(width: 12),
                Expanded(child: _FormField(controller: _fat, label: '% Grasa', hint: '15.0')),
              ],
            ),
            SizedBox(height: 12),
            Text('Medidas corporales (cm)',
                style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _FormField(controller: _chest, label: 'Pecho', hint: '95')),
                const SizedBox(width: 10),
                Expanded(child: _FormField(controller: _waist, label: 'Cintura', hint: '80')),
                const SizedBox(width: 10),
                Expanded(child: _FormField(controller: _hip, label: 'Cadera', hint: '95')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _FormField(controller: _arm, label: 'Brazo', hint: '35')),
                const SizedBox(width: 10),
                Expanded(child: _FormField(controller: _leg, label: 'Pierna', hint: '55')),
                const Expanded(child: SizedBox()),
              ],
            ),
            SizedBox(height: 12),
            TextField(
              controller: _notes,
              style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
              decoration: _inputDecoration('Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colorTextSecondary),
        filled: true,
        fillColor: AppColors.bgTertiary,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _FormField extends StatelessWidget {
  const _FormField({required this.controller, required this.label, required this.hint});
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.colorTextSecondary, fontSize: 12),
        hintStyle: TextStyle(color: context.colorTextMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.bgTertiary,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — RÉCORDS PERSONALES
// ═══════════════════════════════════════════════════════════════════════════════

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  final _service = HistoryService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getPersonalRecords();
      setState(() { _records = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static const _muscleColors = {
    'pecho': Color(0xFF3b82f6),
    'espalda': Color(0xFF8b5cf6),
    'piernas': Color(0xFF22c55e),
    'hombros': Color(0xFFf97316),
    'brazos': Color(0xFFec4899),
    'core': Color(0xFFeab308),
    'gluteos': Color(0xFFef4444),
  };

  // Un PR por ejercicio: el levantamiento con mayor peso
  Map<String, Map<String, dynamic>> _getBestPerExercise() {
    final best = <String, Map<String, dynamic>>{};
    for (final r in _records) {
      final name = r['exerciseName'] as String? ?? '';
      final w = (r['weightKg'] as num?)?.toDouble() ?? 0;
      final current = (best[name]?['weightKg'] as num?)?.toDouble() ?? -1;
      if (w > current) best[name] = r;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_records.isEmpty) {
      return const _EmptyView(
        icon: Icons.emoji_events_outlined,
        title: 'Sin récords aún',
        subtitle: 'Completa series en tus entrenamientos\npara establecer tus primeros récords',
      );
    }

    final best = _getBestPerExercise();
    final unit = context.watch<WeightUnitNotifier>().unit;

    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: best.entries.map((entry) {
          final name = entry.key;
          final r = entry.value;
          final muscleGroup = r['muscleGroup'] as String? ?? '';
          final color = _muscleColors[muscleGroup] ?? AppColors.accentPrimary;
          final rawKg = (r['weightKg'] as num?)?.toDouble();
          final weight = rawKg != null
              ? '${toDisplayUnit(rawKg, unit).toStringAsFixed(1)} ${unit.name}'
              : '--';
          final repCount = r['reps']?.toString() ?? '--';
          final date = du.formatDate(r['achievedAt'] as String?);
          final validated = r['isValidated'] as bool? ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text('$repCount rep',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Text(date,
                              style: TextStyle(
                                  color: context.colorTextMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(weight,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    const SizedBox(height: 4),
                    if (validated)
                      Row(children: [
                        const Icon(Icons.verified_rounded,
                            size: 12, color: AppColors.accentGreen),
                        const SizedBox(width: 4),
                        Text('Validado',
                            style: TextStyle(
                                color: AppColors.accentGreen, fontSize: 10)),
                      ])
                    else
                      Text('Pendiente',
                          style: TextStyle(
                              color: context.colorTextMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets de utilidad compartidos
// ═══════════════════════════════════════════════════════════════════════════════

class _ExerciseDropdown extends StatelessWidget {
  const _ExerciseDropdown({
    required this.exercises,
    required this.selected,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> exercises;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<Map<String, dynamic>>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.bgSecondary,
        style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
        icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
        items: exercises.map((ex) => DropdownMenuItem(
          value: ex,
          child: Text(
            ex['name'] as String? ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accentPrimary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 52),
          SizedBox(height: 16),
          Text(title, style: TextStyle(color: context.colorTextSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: context.colorTextMuted, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 40),
          SizedBox(height: 12),
          Text(error, style: TextStyle(color: context.colorTextSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — CALENDARIO DE ACTIVIDAD
// ═══════════════════════════════════════════════════════════════════════════════

class _CalendarTab extends StatefulWidget {
  const _CalendarTab();

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  final _workoutService = WorkoutService();
  late DateTime _currentMonth;
  Map<String, String> _statusByDay = {};
  bool _loading = true;
  String? _error;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final from = _currentMonth;
      final to = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final days = await _workoutService.getCalendar(from: from, to: to);
      if (!mounted) return;
      setState(() { _statusByDay = days; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
    _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPicker(initial: _currentMonth),
    );
    if (picked != null) {
      setState(() => _currentMonth = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  String _isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const SizedBox(height: 14),
          _buildLegend(context),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : _buildGrid(context),
          ),
          const SizedBox(height: 8),
          _buildSummary(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final label =
        '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';
    return Row(
      children: [
        _NavButton(icon: Icons.chevron_left, onTap: () => _shiftMonth(-1)),
        Expanded(
          child: GestureDetector(
            onTap: _pickMonth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_drop_down, color: context.colorTextSecondary),
                ],
              ),
            ),
          ),
        ),
        _NavButton(icon: Icons.chevron_right, onTap: () => _shiftMonth(1)),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    Widget chip(Color color, String label) => Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(color: context.colorTextSecondary, fontSize: 11)),
            ],
          ),
        );

    return Wrap(
      children: [
        chip(AppColors.accentGreen, 'Cumplido'),
        chip(const Color(0xFFFFB347), 'Parcial'),
        chip(AppColors.accentSecondary, 'Perdido'),
        chip(AppColors.accentPrimary, 'Libre'),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final firstDay = _currentMonth;
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    // En Dart weekday: 1=Lunes..7=Domingo. Mapeamos directo a columnas (0-6).
    final leadingBlanks = firstDay.weekday - 1;

    final today = DateTime.now();
    final todayIso = _isoDay(DateTime(today.year, today.month, today.day));

    const headerRow = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        Row(
          children: headerRow
              .map((d) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colorTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...List.generate(leadingBlanks, (_) => const SizedBox.shrink()),
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final date =
                    DateTime(_currentMonth.year, _currentMonth.month, day);
                final iso = _isoDay(date);
                final status = _statusByDay[iso];
                final isToday = iso == todayIso;
                return _DayCell(
                  day: day,
                  status: status,
                  isToday: isToday,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    var completed = 0, partial = 0, missed = 0, free = 0;
    for (final v in _statusByDay.values) {
      switch (v) {
        case 'completed': completed++; break;
        case 'partial':   partial++;   break;
        case 'missed':    missed++;    break;
        case 'free':      free++;      break;
      }
    }
    Widget cell(String label, int count, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('$count',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                Text(label,
                    style: TextStyle(
                        color: context.colorTextMuted, fontSize: 10)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        cell('Cumplidos', completed, AppColors.accentGreen),
        const SizedBox(width: 6),
        cell('Parciales', partial, const Color(0xFFFFB347)),
        const SizedBox(width: 6),
        cell('Perdidos', missed, AppColors.accentSecondary),
        const SizedBox(width: 6),
        cell('Libres', free, AppColors.accentPrimary),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.status, required this.isToday});
  final int day;
  final String? status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _stylesFor(status, context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? AppColors.accentPrimary : border,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _stylesFor(String? s, BuildContext ctx) {
    switch (s) {
      case 'completed':
        return (
          AppColors.accentGreen.withValues(alpha: 0.85),
          Colors.white,
          AppColors.accentGreen,
        );
      case 'partial':
        return (
          const Color(0xFFFFB347).withValues(alpha: 0.85),
          Colors.white,
          const Color(0xFFFFB347),
        );
      case 'missed':
        return (
          AppColors.accentSecondary.withValues(alpha: 0.85),
          Colors.white,
          AppColors.accentSecondary,
        );
      case 'free':
        return (
          AppColors.accentPrimary.withValues(alpha: 0.7),
          Colors.white,
          AppColors.accentPrimary,
        );
      case 'scheduled':
        return (
          Colors.transparent,
          ctx.colorTextSecondary,
          AppColors.accentPrimary.withValues(alpha: 0.4),
        );
      default:
        return (
          ctx.colorBgTertiary,
          ctx.colorTextMuted,
          AppColors.border,
        );
    }
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: context.colorTextPrimary),
      ),
    );
  }
}

class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({required this.initial});
  final DateTime initial;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year;
  late int _month;

  static const _months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Ir a mes',
          style: TextStyle(color: context.colorTextPrimary, fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year picker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: context.colorTextSecondary,
                  onPressed: () => setState(() => _year--),
                ),
                Text('$_year',
                    style: TextStyle(
                        color: context.colorTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: context.colorTextSecondary,
                  onPressed: () => setState(() => _year++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Month grid 4×3
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.6,
              children: List.generate(12, (i) {
                final m = i + 1;
                final selected = m == _month;
                return GestureDetector(
                  onTap: () => setState(() => _month = m),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentPrimary
                          : context.colorBgTertiary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppColors.accentPrimary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _months[i],
                        style: TextStyle(
                          color:
                              selected ? Colors.white : context.colorTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar',
              style: TextStyle(color: context.colorTextSecondary)),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, DateTime(_year, _month, 1)),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
          child: const Text('Ir'),
        ),
      ],
    );
  }
}

