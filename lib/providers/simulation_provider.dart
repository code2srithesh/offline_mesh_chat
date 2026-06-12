import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/mock_communication_service.dart';

class SimulationNodesNotifier extends StateNotifier<List<SimulatedNode>> {
  final MockCommunicationService _simService = MockCommunicationService();

  SimulationNodesNotifier() : super([]) {
    _refresh();
  }

  void _refresh() {
    state = [..._simService.nodes];
  }

  void addNode(String name, double x, double y) {
    final id = 'node_${DateTime.now().millisecondsSinceEpoch}';
    final newNode = SimulatedNode(
      deviceId: id,
      name: name,
      profilePicture: 'avatar_custom',
      x: x,
      y: y,
      isOnline: true,
    );
    _simService.addSimulatedNode(newNode);
    _refresh();
  }

  void moveNode(String id, double x, double y) {
    _simService.updateNodePosition(id, x, y);
    _refresh();
  }

  void toggleNode(String id, bool online) {
    _simService.toggleNodeStatus(id, online);
    _refresh();
  }

  // Get current host X/Y coordinates
  double get hostX => _simService.hostX;
  double get hostY => _simService.hostY;
  bool get hostOnline => _simService.hostOnline;

  void moveHost(double x, double y) {
    _simService.updateNodePosition('host-device', x, y);
    _refresh();
  }

  void toggleHost(bool online) {
    _simService.toggleNodeStatus('host-device', online);
    _refresh();
  }
}

final simulationNodesProvider = StateNotifierProvider<SimulationNodesNotifier, List<SimulatedNode>>((ref) {
  return SimulationNodesNotifier();
});
