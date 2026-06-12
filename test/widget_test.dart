import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_chat/main.dart';
import 'package:offline_mesh_chat/data/services/mock_communication_service.dart';
import 'package:offline_mesh_chat/data/services/routing_service.dart';

void main() {
  testWidgets('OfflineMeshApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: OfflineMeshApp(),
      ),
    );

    // Verify splash screen or loading spinner renders
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the splash timer complete and navigate
    await tester.pump(const Duration(seconds: 3));

    // Cancel pending simulation timers
    MockCommunicationService().dispose();
    RoutingService().dispose();
  });
}
