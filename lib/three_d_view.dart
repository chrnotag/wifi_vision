import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'main.dart';

class ThreeDViewPage extends StatefulWidget {
  const ThreeDViewPage({super.key});

  @override
  State<ThreeDViewPage> createState() => _ThreeDViewPageState();
}

class _ThreeDViewPageState extends State<ThreeDViewPage> {
  String _currentModel = '';
  List<Map<String, dynamic>> _objects3D = [];

  @override
  void initState() {
    super.initState();
  }

  void _generate3DModel() {
    try {
      // Usar BlocBuilder para acessar o estado de forma segura
      final cubit = context.read<MapperCubit>();
      final state = cubit.state;
      final objects = extractPolygonsFromGrid(state.grid, state.threshold);

      _objects3D = objects.asMap().entries.map((entry) {
        final index = entry.key;
        final object = entry.value;
        final world = polygonToWorld(object, state.grid);
        final area = _calculatePolygonArea(object);

        return {
          'id': index,
          'vertices': object
              .map(
                (p) => {
                  'x': (p.dx - 0.5) * 10, // Escalar para 3D
                  'y': 0.0,
                  'z': (p.dy - 0.5) * 10,
                },
              )
              .toList(),
          'position': {
            'x': world.position.x,
            'y': world.position.y,
            'z': world.position.z,
          },
          'scale': {'x': world.scale.x, 'y': world.scale.y, 'z': world.scale.z},
          'area': area,
          'vertexCount': object.length,
        };
      }).toList();

      _updateModelViewer();
    } catch (e) {
      print('Erro ao gerar modelo 3D: $e');
      _objects3D = [];
      _updateModelViewer();
    }
  }

  void _updateModelViewer() {
    if (_objects3D.isEmpty) {
      _currentModel = _getEmptyScene();
    } else {
      _currentModel = _generateSceneWithObjects();
    }
    setState(() {});
  }

  String _getEmptyScene() {
    return '''
    {
      "scene": {
        "name": "WiFi Sonar Scene",
        "objects": []
      }
    }
    ''';
  }

  String _generateSceneWithObjects() {
    final objects = _objects3D
        .map(
          (obj) => {
            'type': 'mesh',
            'id': 'object_${obj['id']}',
            'position': obj['position'],
            'scale': obj['scale'],
            'vertices': obj['vertices'],
            'color': [1.0, 0.2, 0.2, 0.8], // Vermelho semi-transparente
            'metadata': {
              'area': obj['area'],
              'vertexCount': obj['vertexCount'],
            },
          },
        )
        .toList();

    return jsonEncode({
      'scene': {
        'name': 'WiFi Sonar - Objetos Detectados',
        'objects': objects,
        'camera': {
          'position': [0, 5, 10],
          'target': [0, 0, 0],
        },
        'lighting': {
          'ambient': [0.3, 0.3, 0.3],
          'directional': [0.7, 0.7, 0.7],
        },
      },
    });
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visualização 3D - Sonar WiFi'),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _generate3DModel();
            },
            tooltip: 'Atualizar visualização',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          try {
            final state = context.read<MapperCubit>().state;
            return Column(
              children: [
                // Informações do cabeçalho
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[900]!.withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(Icons.view_in_ar, color: Colors.cyan[300]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Objetos Detectados: ${_objects3D.length}',
                              style: TextStyle(
                                color: Colors.cyan[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Use gestos para rotacionar, zoom e navegar',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Visualização 3D
                Expanded(
                  child: _objects3D.isEmpty
                      ? _buildEmptyState()
                      : _build3DViewer(),
                ),

                // Lista de objetos
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  child: _buildObjectsList(),
                ),
              ],
            );
          } catch (e) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Erro ao carregar dados',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Volte para a tela principal e tente novamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_in_ar_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Nenhum objeto detectado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use o botão "Varrer" na tela principal\npara detectar objetos WiFi',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _build3DViewer() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ModelViewer(
          src: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
          alt: 'WiFi Sonar 3D Scene',
          ar: false,
          autoRotate: true,
          cameraControls: true,
          shadowIntensity: 0.5,
          exposure: 1.0,
          environmentImage: 'neutral',
          backgroundColor: Colors.black,
          onWebViewCreated: (controller) {
            // ModelViewer criado com sucesso
            print('WiFi Sonar 3D Scene loaded');
            print('Objects: ${jsonEncode(_objects3D)}');
          },
        ),
      ),
    );
  }

  Widget _buildObjectsList() {
    if (_objects3D.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum objeto para exibir',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _objects3D.length,
      itemBuilder: (context, index) {
        final obj = _objects3D[index];

        return Container(
          width: 160,
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
                  Icon(Icons.view_in_ar, color: Colors.cyan[300], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Objeto ${obj['id'] + 1}',
                    style: TextStyle(
                      color: Colors.cyan[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Área: ${obj['area'].toStringAsFixed(1)} m²',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'Vértices: ${obj['vertexCount']}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                'Pos: (${obj['position']['x'].toStringAsFixed(1)}, ${obj['position']['z'].toStringAsFixed(1)})',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
