// RF Mapper Prototype — Flutter (LinkedIn-level demo) v4
// Organização por camadas + upgrades pedidos
// - Heading real (magnetômetro) com EventChannel
// - Slider de threshold
// - Contornos via Marching Squares + simplificação (RDP)
// - Preenchimento (triangulação ear-clipping) opcional
// - Rótulos por blob (área/perímetro)
// - Bússola só girando (não a cena)
// - Chunks menores (10cm, 120x80)
// - Malhas 2D com wireframe
// - Visualização de Sonar WiFi - Mapeamento de Ambiente

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'wifi_service.dart';
import 'three_d_view.dart';

void main() => runApp(const RFMapperApp());

// =============================================================
//  APP
// =============================================================
class RFMapperApp extends StatelessWidget {
  const RFMapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => MapperCubit()..init())],
      child: MaterialApp(
        title: 'WiFi Sonar - Mapeamento de Ambiente',
        theme: ThemeData.dark(useMaterial3: true),
        home: const HomePage(),
      ),
    );
  }
}

// =============================================================
//  DOMAIN: modelos básicos
// =============================================================
class AP {
  final String bssid;
  final vm.Vector3 pos;

  const AP({required this.bssid, required this.pos});
}

class VoxelCell {
  double sum = 0, sum2 = 0;
  int n = 0;
}

class VoxelGrid {
  final double cellSize;
  final int width;
  final int height;
  final List<VoxelCell> cells;

  VoxelGrid({required this.cellSize, required this.width, required this.height})
    : cells = List.generate(width * height, (_) => VoxelCell());

  VoxelGrid clear() {
    for (final c in cells) {
      c.sum = 0;
      c.sum2 = 0;
      c.n = 0;
    }
    return this;
  }

  int _idx(int ix, int iy) => iy * width + ix;

  VoxelGrid accumulate(double x, double y, double v) {
    final ix = ((x / cellSize) + width / 2).floor().clamp(0, width - 1);
    final iy = ((y / cellSize) + height / 2).floor().clamp(0, height - 1);
    final c = cells[_idx(ix, iy)];
    c.sum += v;
    c.sum2 += v * v;
    c.n++;
    return this;
  }

  double valueAt(int ix, int iy) {
    final c = cells[_idx(ix, iy)];
    return c.n == 0 ? 0 : c.sum / c.n;
  }

  double get vmax {
    double m = 1e-9;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        m = max(m, valueAt(x, y));
      }
    }
    return m;
  }
}

// =============================================================
//  SERVICES: platform channels (RTT + Heading)
// =============================================================
class HeadingService {
  static const _ev = EventChannel('sensor.heading');

  static Stream<double> stream() =>
      _ev.receiveBroadcastStream().map((e) => (e as num).toDouble());
}

class RttService {
  static const _ch = MethodChannel('rf.sensing');

  static Future<List<Map<String, dynamic>>> wifiScan() async {
    final res = await _ch.invokeMethod('wifiScan');
    return (res as List)
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> rangeOnce(
    List<String> bssids,
  ) async {
    final res = await _ch.invokeMethod('rangeOnce', {'bssids': bssids});
    return (res as List)
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

// =============================================================
//  PROCESSING: smoothing + marching squares (interp), simplificação (RDP) e triangulação
// =============================================================
class FieldSmoothing {
  static List<List<double>> smooth(
    VoxelGrid g, {
    int radius = 3,
    double sigma = 1.5,
  }) {
    final w = g.width, h = g.height;
    List<double> k = List.generate(2 * radius + 1, (i) {
      final x = i - radius;
      return exp(-(x * x) / (2 * sigma * sigma));
    });
    final sumK = k.reduce((a, b) => a + b);
    k = k.map((e) => e / sumK).toList();
    final horiz = List.generate(h, (_) => List.filled(w, 0.0));
    final out = List.generate(h, (_) => List.filled(w, 0.0));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double acc = 0;
        for (int dx = -radius; dx <= radius; dx++) {
          final xx = (x + dx).clamp(0, w - 1);
          acc += g.valueAt(xx, y) * k[dx + radius];
        }
        horiz[y][x] = acc;
      }
    }
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double acc = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          final yy = (y + dy).clamp(0, h - 1);
          acc += horiz[yy][x] * k[dy + radius];
        }
        out[y][x] = acc;
      }
    }
    return out;
  }
}

class MarchingSquares {
  static List<List<Offset>> contours(VoxelGrid g, double t) {
    final sm = FieldSmoothing.smooth(g);
    final h = g.height, w = g.width;
    final vmax = _max(sm);
    double v(int x, int y) => sm[y][x] / (vmax <= 0 ? 1 : vmax);
    double lerp(double a, double b, double t) => a + (b - a) * t;
    double interp(int x0, int y0, int x1, int y1) {
      final a = v(x0, y0), b = v(x1, y1);
      final d = b - a;
      if (d.abs() < 1e-6) return 0.5;
      return (t - a) / d;
    }

    const tbl = <int, List<List<Offset>>>{
      0: [],
      1: [
        [Offset(0, 0.5), Offset(0.5, 0)],
      ],
      2: [
        [Offset(0.5, 0), Offset(1, 0.5)],
      ],
      3: [
        [Offset(0, 0.5), Offset(1, 0.5)],
      ],
      4: [
        [Offset(0.5, 1), Offset(1, 0.5)],
      ],
      5: [
        [Offset(0.5, 0), Offset(0.5, 1)],
        [Offset(0, 0.5), Offset(1, 0.5)],
      ],
      6: [
        [Offset(0.5, 0), Offset(0.5, 1)],
      ],
      7: [
        [Offset(0, 0.5), Offset(0.5, 1)],
      ],
      8: [
        [Offset(0, 0.5), Offset(0.5, 1)],
      ],
      9: [
        [Offset(0.5, 0), Offset(0.5, 1)],
      ],
      10: [
        [Offset(0, 0.5), Offset(1, 0.5)],
      ],
      11: [
        [Offset(0.5, 1), Offset(1, 0.5)],
      ],
      12: [
        [Offset(0, 0.5), Offset(1, 0.5)],
      ],
      13: [
        [Offset(0.5, 0), Offset(1, 0.5)],
      ],
      14: [
        [Offset(0, 0.5), Offset(0.5, 0)],
      ],
      15: [],
    };
    final segs = <List<Offset>>[];
    for (int y = 0; y < h - 1; y++) {
      for (int x = 0; x < w - 1; x++) {
        final v00 = v(x, y),
            v10 = v(x + 1, y),
            v11 = v(x + 1, y + 1),
            v01 = v(x, y + 1);
        int code = 0;
        if (v00 > t) code |= 1;
        if (v10 > t) code |= 2;
        if (v11 > t) code |= 4;
        if (v01 > t) code |= 8;
        final edges = tbl[code] ?? const [];
        for (final e in edges) {
          Offset mapCorner(Offset c) {
            if (c == const Offset(0.5, 0)) {
              final u = interp(x, y, x + 1, y);
              return Offset(lerp(x.toDouble(), x + 1.0, u), y.toDouble());
            } else if (c == const Offset(1, 0.5)) {
              final u = interp(x + 1, y, x + 1, y + 1);
              return Offset(x + 1.0, lerp(y.toDouble(), y + 1.0, u));
            } else if (c == const Offset(0.5, 1)) {
              final u = interp(x, y + 1, x + 1, y + 1);
              return Offset(lerp(x.toDouble(), x + 1.0, u), y + 1.0);
            } else if (c == const Offset(0, 0.5)) {
              final u = interp(x, y, x, y + 1);
              return Offset(x.toDouble(), lerp(y.toDouble(), y + 1.0, u));
            }
            return Offset(x + c.dx, y + c.dy);
          }

          segs.add([mapCorner(e[0]), mapCorner(e[1])]);
        }
      }
    }
    return segs
        .map(
          (s) => [
            Offset(s[0].dx / (w - 1), s[0].dy / (h - 1)),
            Offset(s[1].dx / (w - 1), s[1].dy / (h - 1)),
          ],
        )
        .toList();
  }

  static double _max(List<List<double>> m) {
    double v = 0;
    for (final r in m) {
      for (final x in r) {
        if (x > v) v = x;
      }
    }
    return v;
  }
}

class RDPSimplifier {
  static List<Offset> simplify(List<Offset> pts, double eps) {
    if (pts.length < 3) return List.of(pts);
    int idx = 0;
    double dmax = 0;
    for (int i = 1; i < pts.length - 1; i++) {
      final d = _distToSegment(pts[i], pts.first, pts.last);
      if (d > dmax) {
        idx = i;
        dmax = d;
      }
    }
    if (dmax > eps) {
      final l1 = simplify(pts.sublist(0, idx + 1), eps);
      final l2 = simplify(pts.sublist(idx, pts.length), eps);
      return [...l1.take(l1.length - 1), ...l2];
    } else {
      return [pts.first, pts.last];
    }
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final t =
        ((ap.dx * ab.dx + ap.dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy))
            .clamp(0, 1)
            .toDouble();
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    final d = p - proj;
    return d.distance;
  }
}

class Triangulator {
  static List<List<Offset>> triangulate(List<Offset> poly) {
    final tris = <List<Offset>>[];
    if (poly.length < 3) return tris;
    final v = List<Offset>.from(poly);
    bool isCCW(List<Offset> p) {
      double a = 0;
      for (int i = 0; i < p.length; i++) {
        final p0 = p[i], p1 = p[(i + 1) % p.length];
        a += p0.dx * p1.dy - p1.dx * p0.dy;
      }
      return a > 0;
    }

    if (!isCCW(v)) v.setAll(0, v.reversed);
    bool isEar(int i) {
      final a = v[(i - 1 + v.length) % v.length],
          b = v[i],
          c = v[(i + 1) % v.length];
      if (_cross(a, b, c) <= 0) return false;
      for (int j = 0; j < v.length; j++) {
        if (j == i ||
            j == (i - 1 + v.length) % v.length ||
            j == (i + 1) % v.length)
          continue;
        if (_pointInTri(v[j], a, b, c)) return false;
      }
      return true;
    }

    while (v.length >= 3) {
      bool clipped = false;
      for (int i = 0; i < v.length; i++) {
        if (isEar(i)) {
          final a = v[(i - 1 + v.length) % v.length],
              b = v[i],
              c = v[(i + 1) % v.length];
          tris.add([a, b, c]);
          v.removeAt(i);
          clipped = true;
          break;
        }
      }
      if (!clipped) break;
    }
    return tris;
  }

  static double _cross(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

  static bool _pointInTri(Offset p, Offset a, Offset b, Offset c) {
    final c1 = _cross(a, b, p) >= 0,
        c2 = _cross(b, c, p) >= 0,
        c3 = _cross(c, a, p) >= 0;
    return c1 && c2 && c3;
  }
}

// =============================================================
//  STATE (Cubit)
// =============================================================
class MapperState {
  final bool demoMode;
  final bool scanning;
  final bool fillPolygons;
  final double threshold;
  final double headingDeg;
  final List<AP> aps;
  final VoxelGrid grid;
  final String status;

  const MapperState({
    required this.demoMode,
    required this.scanning,
    required this.fillPolygons,
    required this.threshold,
    required this.headingDeg,
    required this.aps,
    required this.grid,
    required this.status,
  });

  MapperState copyWith({
    bool? demoMode,
    bool? scanning,
    bool? fillPolygons,
    double? threshold,
    double? headingDeg,
    List<AP>? aps,
    VoxelGrid? grid,
    String? status,
  }) => MapperState(
    demoMode: demoMode ?? this.demoMode,
    scanning: scanning ?? this.scanning,
    fillPolygons: fillPolygons ?? this.fillPolygons,
    threshold: threshold ?? this.threshold,
    headingDeg: headingDeg ?? this.headingDeg,
    aps: aps ?? this.aps,
    grid: grid ?? this.grid,
    status: status ?? this.status,
  );
}

class MapperCubit extends Cubit<MapperState> {
  MapperCubit()
    : super(
        MapperState(
          demoMode: true,
          scanning: false,
          fillPolygons: true,
          threshold: 0.6,
          headingDeg: 0,
          aps: const [],
          grid: VoxelGrid(cellSize: 0.1, width: 120, height: 80),
          status: 'init',
        ),
      );

  StreamSubscription<double>? _headingSub;
  Timer? _timer;
  final _rnd = Random(42);
  vm.Vector3 _pos = vm.Vector3.zero();

  Future<void> init() async {
    _headingSub = HeadingService.stream().listen((deg) {
      emit(state.copyWith(headingDeg: deg));
    });
    emit(state.copyWith(status: 'ready'));
  }

  @override
  Future<void> close() {
    _headingSub?.cancel();
    _timer?.cancel();
    return super.close();
  }

  void setThreshold(double v) => emit(state.copyWith(threshold: v));

  void toggleFill(bool v) => emit(state.copyWith(fillPolygons: v));

  void toggleDemo(bool v) => emit(state.copyWith(demoMode: v));

  Future<void> discoverAPs() async {
    try {
      emit(state.copyWith(status: 'Escaneando redes WiFi...'));

      final wifiAPs = await RealWiFiService.scanWiFiNetworks(state.headingDeg);

      // Converter WiFiAP para AP
      final aps = wifiAPs
          .map(
            (wifiAP) => AP(bssid: wifiAP.ssid, pos: wifiAP.estimatedPosition),
          )
          .toList();

      emit(
        state.copyWith(
          aps: aps,
          status: 'APs WiFi detectados: ${aps.length}',
          demoMode: false, // Usar dados reais
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: 'Erro ao escanear WiFi: $e'));
    }
  }

  void startSweep() {
    if (state.scanning) return;
    emit(state.copyWith(scanning: true, status: 'varrendo...'));
    state.grid.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!state.scanning) return;
      final p = _randomWalk();
      final v = state.demoMode ? _fakeReading(p) : _rssiReadingFromPlatform();
      emit(state.copyWith(grid: state.grid.accumulate(p.x, p.y, v)));
    });
  }

  void stopSweep() {
    _timer?.cancel();
    emit(state.copyWith(scanning: false, status: 'parado'));
  }

  vm.Vector3 _randomWalk() {
    _pos += vm.Vector3(
      (_rnd.nextDouble() - 0.5) * 0.5,
      (_rnd.nextDouble() - 0.5) * 0.5,
      0,
    );
    final w = state.grid.width * state.grid.cellSize / 2,
        h = state.grid.height * state.grid.cellSize / 2;
    _pos.x = _pos.x.clamp(-w, w);
    _pos.y = _pos.y.clamp(-h, h);
    return _pos.clone();
  }

  double _fakeReading(vm.Vector3 p) {
    // Se temos APs WiFi reais, usar eles
    if (state.aps.isNotEmpty && !state.demoMode) {
      return RealWiFiService.calculateSignalAtPosition(
        p,
        state.aps
            .map(
              (ap) => WiFiAP(
                ssid: ap.bssid,
                bssid: ap.bssid,
                rssi: -50, // Valor padrão
                frequency: 2412,
                estimatedPosition: ap.pos,
                signalStrength: 0.7, // Valor padrão
              ),
            )
            .toList(),
      );
    }

    // Fallback para dados simulados
    double gauss(vm.Vector3 c, double s) {
      final d = (p - c).length2;
      return exp(-d / (2 * s * s));
    }

    // Simular múltiplas fontes WiFi com diferentes intensidades
    double totalSignal = 0.0;

    // APs WiFi simulados
    totalSignal +=
        0.8 * gauss(vm.Vector3(-2.0, 0, -1.5), 1.2); // WiFi_Router_01
    totalSignal += 0.6 * gauss(vm.Vector3(3.0, 0, 2.0), 1.5); // Neighbor_WiFi
    totalSignal += 0.7 * gauss(vm.Vector3(0.5, 0, -3.0), 1.3); // Office_Network
    totalSignal += 0.5 * gauss(vm.Vector3(-1.0, 0, 2.5), 1.8); // Public_Hotspot

    // Simular objetos físicos (paredes, móveis) que refletem/absorvem sinais
    totalSignal += 0.4 * gauss(vm.Vector3(1.5, 0, 0.5), 0.8); // Parede
    totalSignal += 0.3 * gauss(vm.Vector3(-0.5, 0, 1.0), 0.6); // Móvel

    // Adicionar ruído realista
    final noise = (_rnd.nextDouble() - 0.5) * 0.15;
    final signal = (0.1 + 0.9 * totalSignal).clamp(0.0, 1.0) + noise;

    return signal.clamp(0.0, 1.0);
  }

  double _rssiReadingFromPlatform() {
    return 0.5 + (_rnd.nextDouble() - 0.5) * 0.2;
  }
}

// =============================================================
//  UI
// =============================================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _buildLegendItem(String label, Color color, String description) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $description',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MapperCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('WiFi Sonar - Mapeamento de Ambiente')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            BlocBuilder<MapperCubit, MapperState>(
              builder: (_, s) => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(value: s.demoMode, onChanged: cubit.toggleDemo),
                      const Text('Demo'),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: cubit.discoverAPs,
                    child: const Text('Descobrir APs'),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: s.scanning
                            ? cubit.stopSweep
                            : cubit.startSweep,
                        child: Text(s.scanning ? 'Parar' : 'Varrer'),
                      ),
                      Text(s.status),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ARDemoPage(),
                            ),
                          ),
                          child: const Text('Sonar WiFi'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ThreeDViewPage(),
                            ),
                          ),
                          child: const Text('Visualização 3D'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            BlocBuilder<MapperCubit, MapperState>(
              builder: (_, s) => Row(
                children: [
                  const Text('Threshold'),
                  Expanded(
                    child: Slider(
                      value: s.threshold,
                      min: 0.2,
                      max: 0.9,
                      onChanged: cubit.setThreshold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Preencher'),
                  Switch(value: s.fillPolygons, onChanged: cubit.toggleFill),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: const MapCanvas(),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.cyan[300],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mapa do Sonar WiFi:',
                        style: TextStyle(
                          color: Colors.cyan[300],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• Você está no centro (ponto branco)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '• Cada quadrado = 10cm x 10cm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '• Área total: 12m x 8m',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '• "Varrer" simula ondas WiFi detectando objetos',
                              style: TextStyle(
                                color: Colors.cyan[300],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(
                            'Azul escuro',
                            Colors.blue[900]!,
                            'Sem detecção',
                          ),
                          _buildLegendItem(
                            'Azul claro',
                            Colors.blue[400]!,
                            'Detecção fraca',
                          ),
                          _buildLegendItem(
                            'Verde',
                            Colors.green[400]!,
                            'Detecção média',
                          ),
                          _buildLegendItem(
                            'Vermelho',
                            Colors.red[400]!,
                            'Detecção forte',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapCanvas extends StatelessWidget {
  const MapCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapperCubit, MapperState>(
      builder: (_, s) {
        return CustomPaint(
          painter: CompositePainter(
            s.grid,
            s.threshold,
            s.fillPolygons,
            s.headingDeg,
          ),
          child: Container(),
        );
      },
    );
  }
}

// =============================================================
//  RENDERING: múltiplas camadas em um painter composto
// =============================================================
class CompositePainter extends CustomPainter {
  final VoxelGrid g;
  final double thr;
  final bool fill;
  final double headingDeg;

  CompositePainter(this.g, this.thr, this.fill, this.headingDeg);

  @override
  void paint(Canvas canvas, Size size) {
    _drawHeatmap(canvas, size);
    _drawContours(canvas, size);
    _drawNorthAndScale(canvas, size);
  }

  void _drawHeatmap(Canvas canvas, Size size) {
    final cw = size.width / g.width, ch = size.height / g.height;
    final paint = Paint();
    final vmax = g.vmax;
    for (int y = 0; y < g.height; y++) {
      for (int x = 0; x < g.width; x++) {
        final v = g.valueAt(x, y) / vmax;
        paint.color = _colormap(v);
        canvas.drawRect(
          Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5),
          paint,
        );
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, border);
  }

  void _drawContours(Canvas canvas, Size size) {
    final segs = MarchingSquares.contours(g, thr);
    final loops = _connectSegmentsIntoLoops(segs);
    final cw = size.width, ch = size.height;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.9);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.15);
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white30
      ..strokeWidth = 1;

    int id = 1;
    for (final loop in loops) {
      final pts = loop.map((p) => Offset(p.dx * cw, p.dy * ch)).toList();
      final simp = RDPSimplifier.simplify(pts, 4.0);

      if (fill) {
        final tri = Triangulator.triangulate(_normalize(simp, cw, ch));
        for (final t in tri) {
          final path = Path()
            ..moveTo(t[0].dx * cw, t[0].dy * ch)
            ..lineTo(t[1].dx * cw, t[1].dy * ch)
            ..lineTo(t[2].dx * cw, t[2].dy * ch)
            ..close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, wirePaint);
        }
      }

      final path = Path()..moveTo(simp.first.dx, simp.first.dy);
      for (int i = 1; i < simp.length; i++) {
        path.lineTo(simp[i].dx, simp[i].dy);
      }
      path.close();
      canvas.drawPath(path, stroke);

      final areaPx = _polygonArea(simp);
      final areaM2 =
          areaPx / (cw * ch) * (g.width * g.cellSize) * (g.height * g.cellSize);
      final centroid = _centroid(simp);
      final tp = TextPainter(
        text: TextSpan(
          text: 'obj $id ~${areaM2.toStringAsFixed(1)} m²',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, centroid - Offset(tp.width / 2, tp.height / 2));
      id++;
    }
  }

  void _drawNorthAndScale(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white54
      ..strokeWidth = 2;

    // Bússola (Norte)
    canvas.save();
    final double cx = size.width - 36, cy = 36;
    canvas.translate(cx, cy);
    canvas.rotate(headingDeg * pi / 180);
    canvas.translate(-cx, -cy);
    final arrow = Path()
      ..moveTo(cx, cy - 16)
      ..lineTo(cx - 8, cy + 8)
      ..lineTo(cx + 8, cy + 8)
      ..close();
    final arrowPaint = Paint()..color = Colors.white70;
    canvas.drawPath(arrow, arrowPaint);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - 6, cy + 10));
    canvas.restore();

    // Escala de distância
    final meters5px = 5.0 / g.cellSize * (size.width / g.width);
    final yBar = size.height - 20;
    canvas.drawLine(Offset(16, yBar), Offset(16 + meters5px, yBar), border);
    final tp2 = TextPainter(
      text: const TextSpan(
        text: '5m',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(16, yBar - 16));

    // Ponto central (usuário)
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    canvas.drawCircle(Offset(centerX, centerY), 3, centerPaint);

    // Círculos de referência de distância
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 2m, 4m, 6m de raio
    final radius2m = 2.0 / g.cellSize * (size.width / g.width);
    final radius4m = 4.0 / g.cellSize * (size.width / g.width);
    final radius6m = 6.0 / g.cellSize * (size.width / g.width);

    canvas.drawCircle(Offset(centerX, centerY), radius2m, circlePaint);
    canvas.drawCircle(Offset(centerX, centerY), radius4m, circlePaint);
    canvas.drawCircle(Offset(centerX, centerY), radius6m, circlePaint);

    // Rótulos de distância
    final textPaint = TextPainter(
      text: TextSpan(
        text: '2m',
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPaint.paint(canvas, Offset(centerX + radius2m + 5, centerY - 5));

    textPaint.text = TextSpan(
      text: '4m',
      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
    );
    textPaint.layout();
    textPaint.paint(canvas, Offset(centerX + radius4m + 5, centerY - 5));

    textPaint.text = TextSpan(
      text: '6m',
      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
    );
    textPaint.layout();
    textPaint.paint(canvas, Offset(centerX + radius6m + 5, centerY - 5));

    // Informações do grid
    final gridInfoPaint = TextPainter(
      text: TextSpan(
        text: 'Grid: ${g.width}x${g.height} células (${g.cellSize}m cada)',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gridInfoPaint.paint(canvas, Offset(16, 16));
  }

  List<List<Offset>> _connectSegmentsIntoLoops(List<List<Offset>> segs) {
    const tol = 1e-3;
    final loops = <List<Offset>>[];
    final used = List<bool>.filled(segs.length, false);
    for (int i = 0; i < segs.length; i++) {
      if (used[i]) continue;
      used[i] = true;
      final loop = <Offset>[segs[i][0], segs[i][1]];
      bool extended = true;
      while (extended) {
        extended = false;
        for (int j = 0; j < segs.length; j++) {
          if (used[j]) continue;
          if ((loop.last - segs[j][0]).distance < tol) {
            loop.add(segs[j][1]);
            used[j] = true;
            extended = true;
          } else if ((loop.last - segs[j][1]).distance < tol) {
            loop.add(segs[j][0]);
            used[j] = true;
            extended = true;
          }
        }
      }
      if (loop.length > 3) loops.add(loop);
    }
    return loops;
  }

  List<Offset> _normalize(List<Offset> pts, double cw, double ch) =>
      pts.map((p) => Offset(p.dx / cw, p.dy / ch)).toList();

  double _polygonArea(List<Offset> poly) {
    double a = 0;
    for (int i = 0; i < poly.length; i++) {
      final p0 = poly[i], p1 = poly[(i + 1) % poly.length];
      a += p0.dx * p1.dy - p1.dx * p0.dy;
    }
    return a.abs() / 2;
  }

  Offset _centroid(List<Offset> poly) {
    double cx = 0, cy = 0;
    double a = 0;
    for (int i = 0; i < poly.length; i++) {
      final p0 = poly[i], p1 = poly[(i + 1) % poly.length];
      final cross = p0.dx * p1.dy - p1.dx * p0.dy;
      a += cross;
      cx += (p0.dx + p1.dx) * cross;
      cy += (p0.dy + p1.dy) * cross;
    }
    a *= 0.5;
    if (a == 0) return poly.first;
    return Offset(cx / (6 * a), cy / (6 * a));
  }

  Color _colormap(double t) {
    t = t.clamp(0, 1);
    // Mapa de cores mais intuitivo para sonar
    if (t < 0.3) {
      // Azul escuro para áreas sem detecção
      return Color.fromARGB(180, 0, 0, 100);
    } else if (t < 0.6) {
      // Azul claro para detecção fraca
      final intensity = ((t - 0.3) / 0.3 * 255).round();
      return Color.fromARGB(200, 0, intensity, 255);
    } else if (t < 0.8) {
      // Verde para detecção média
      final intensity = ((t - 0.6) / 0.2 * 255).round();
      return Color.fromARGB(220, 0, 255, intensity);
    } else {
      // Vermelho para detecção forte
      final intensity = ((t - 0.8) / 0.2 * 255).round();
      return Color.fromARGB(240, 255, 255 - intensity, 0);
    }
  }

  @override
  bool shouldRepaint(covariant CompositePainter old) => true;
}

// =============================================================
//  UTIL: extrai polígonos (loops) do grid atual
// =============================================================
List<List<Offset>> extractPolygonsFromGrid(VoxelGrid g, double thr) {
  final segs = MarchingSquares.contours(g, thr);
  final loops = _connectSegmentsIntoLoops(segs);
  final polys = <List<Offset>>[];
  for (final loop in loops) {
    final simp = RDPSimplifier.simplify(
      loop.map((p) => Offset(p.dx, p.dy)).toList(),
      0.02,
    );
    if (simp.length >= 3) polys.add(simp);
  }
  return polys;
}

List<List<Offset>> _connectSegmentsIntoLoops(List<List<Offset>> segs) {
  const tol = 1e-3;
  final loops = <List<Offset>>[];
  final used = List<bool>.filled(segs.length, false);
  for (int i = 0; i < segs.length; i++) {
    if (used[i]) continue;
    used[i] = true;
    final loop = <Offset>[segs[i][0], segs[i][1]];
    bool extended = true;
    while (extended) {
      extended = false;
      for (int j = 0; j < segs.length; j++) {
        if (used[j]) continue;
        if ((loop.last - segs[j][0]).distance < tol) {
          loop.add(segs[j][1]);
          used[j] = true;
          extended = true;
        } else if ((loop.last - segs[j][1]).distance < tol) {
          loop.add(segs[j][0]);
          used[j] = true;
          extended = true;
        }
      }
    }
    if (loop.length > 3) loops.add(loop);
  }
  for (final l in loops) {
    if ((l.first - l.last).distance > 1e-3) l.add(l.first);
  }
  return loops;
}

// =============================================================
//  UTIL: conversão normalizado (0..1) -> metros (grid)
// =============================================================
class PolyWorld {
  final vm.Vector3 position;
  final vm.Vector3 scale;
  final double yawRad;

  PolyWorld(this.position, this.scale, this.yawRad);
}

PolyWorld polygonToWorld(List<Offset> poly, VoxelGrid g) {
  double minx = 1e9, miny = 1e9, maxx = -1e9, maxy = -1e9;
  for (final p in poly) {
    minx = min(minx, p.dx);
    maxx = max(maxx, p.dx);
    miny = min(miny, p.dy);
    maxy = max(maxy, p.dy);
  }
  final worldW = g.width * g.cellSize;
  final worldH = g.height * g.cellSize;
  final cx = (minx + maxx) * 0.5;
  final cy = (miny + maxy) * 0.5;
  final wx = (cx - 0.5) * worldW;
  final wz = (cy - 0.5) * worldH;
  final w = (maxx - minx) * worldW;
  final h = (maxy - miny) * worldH;
  final yaw = w >= h ? 0.0 : pi / 2;
  return PolyWorld(
    vm.Vector3(wx, 0.0, wz),
    vm.Vector3(max(w, 0.5), 0.02, max(h, 0.5)),
    yaw,
  );
}

// =============================================================
//  Sonar WiFi Visualization: visualização intuitiva do sonar
// =============================================================
class ARDemoPage extends StatefulWidget {
  const ARDemoPage({super.key});

  @override
  State<ARDemoPage> createState() => _ARDemoPageState();
}

class _ARDemoPageState extends State<ARDemoPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Animação de pulso do sonar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animação de ondas
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    _pulseController.repeat();
    _waveController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonar WiFi - Visualização'),
        backgroundColor: Colors.blue[900],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[900]!, Colors.black],
          ),
        ),
        child: BlocBuilder<MapperCubit, MapperState>(
          builder: (context, state) {
            return Column(
              children: [
                // Header explicativo
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.radar, size: 48, color: Colors.cyan[300]),
                      const SizedBox(height: 8),
                      Text(
                        'Sonar WiFi Ativo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan[300],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detectando objetos através das ondas WiFi',
                        style: TextStyle(fontSize: 14, color: Colors.grey[300]),
                      ),
                    ],
                  ),
                ),

                // Visualização do sonar
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _pulseController,
                        _waveController,
                      ]),
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(300, 300),
                          painter: SonarPainter(
                            pulseProgress: _pulseAnimation.value,
                            waveProgress: _waveAnimation.value,
                            objects: extractPolygonsFromGrid(
                              state.grid,
                              state.threshold,
                            ),
                            heading: state.headingDeg,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Informações dos objetos detectados
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Objetos Detectados:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan[300],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildObjectsList(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildObjectsList(MapperState state) {
    final objects = extractPolygonsFromGrid(state.grid, state.threshold);

    if (objects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[300]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nenhum objeto detectado ainda. Use o botão "Varrer" na tela principal.',
                style: TextStyle(color: Colors.orange[300]),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: objects.length,
        itemBuilder: (context, index) {
          final object = objects[index];
          final area = _calculatePolygonArea(object);

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyan[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.architecture, color: Colors.cyan[300], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Objeto ${index + 1}',
                      style: TextStyle(
                        color: Colors.cyan[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Área: ${area.toStringAsFixed(1)} m²',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  'Vértices: ${object.length}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _calculatePolygonArea(List<Offset> poly) {
    double area = 0;
    for (int i = 0; i < poly.length; i++) {
      final p0 = poly[i];
      final p1 = poly[(i + 1) % poly.length];
      area += p0.dx * p1.dy - p1.dx * p0.dy;
    }
    return area.abs() / 2;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
}

// =============================================================
//  Sonar Painter: desenha a visualização do sonar
// =============================================================
class SonarPainter extends CustomPainter {
  final double pulseProgress;
  final double waveProgress;
  final List<List<Offset>> objects;
  final double heading;

  SonarPainter({
    required this.pulseProgress,
    required this.waveProgress,
    required this.objects,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Desenhar círculos de fundo (grades do sonar)
    _drawSonarGrid(canvas, center, radius);

    // Desenhar ondas de pulso
    _drawPulseWaves(canvas, center, radius);

    // Desenhar objetos detectados
    _drawDetectedObjects(canvas, center, radius);

    // Desenhar indicador de direção
    _drawDirectionIndicator(canvas, center, radius);
  }

  void _drawSonarGrid(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.blue[700]!.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Círculos concêntricos
    for (int i = 1; i <= 5; i++) {
      final r = radius * i / 5;
      canvas.drawCircle(center, r, paint);
    }

    // Linhas radiais
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final endPoint = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawLine(center, endPoint, paint);
    }
  }

  void _drawPulseWaves(Canvas canvas, Offset center, double radius) {
    // Onda principal
    final pulsePaint = Paint()
      ..color = Colors.cyan[300]!.withOpacity(0.8 - pulseProgress * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final pulseRadius = radius * pulseProgress;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Ondas secundárias
    for (int i = 1; i <= 3; i++) {
      final wavePaint = Paint()
        ..color = Colors.blue[400]!.withOpacity(0.3 - waveProgress * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      final waveRadius = radius * (waveProgress + i * 0.2) % 1.0;
      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  void _drawDetectedObjects(Canvas canvas, Offset center, double radius) {
    for (final object in objects) {
      final paint = Paint()
        ..color = Colors.red[400]!.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = Colors.red[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Converter coordenadas normalizadas para coordenadas do canvas
      final points = object
          .map(
            (p) => Offset(
              center.dx + (p.dx - 0.5) * radius * 2,
              center.dy + (p.dy - 0.5) * radius * 2,
            ),
          )
          .toList();

      if (points.length >= 3) {
        final path = Path();
        path.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        path.close();

        canvas.drawPath(path, paint);
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  void _drawDirectionIndicator(Canvas canvas, Offset center, double radius) {
    // Bússola
    final compassPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final compassRadius = 30.0;
    canvas.drawCircle(center, compassRadius, compassPaint);

    // Seta do norte
    final northAngle = heading * pi / 180;
    final northPoint = Offset(
      center.dx + compassRadius * cos(northAngle - pi / 2),
      center.dy + compassRadius * sin(northAngle - pi / 2),
    );

    final arrowPaint = Paint()
      ..color = Colors.red[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(center, northPoint, arrowPaint);

    // Texto "N"
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx +
            (compassRadius + 10) * cos(northAngle - pi / 2) -
            textPainter.width / 2,
        center.dy +
            (compassRadius + 10) * sin(northAngle - pi / 2) -
            textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant SonarPainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.waveProgress != waveProgress ||
        oldDelegate.objects != objects ||
        oldDelegate.heading != heading;
  }
}
