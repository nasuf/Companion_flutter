import 'package:cached_network_image/cached_network_image.dart';
import 'package:companion_flutter/src/widgets/agent_avatar_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agent avatar provider trims and persistently caches the URL', () {
    final provider = AgentAvatarImage.providerFor(
      '  https://example.com/agents/avatar/companion-female-01.png  ',
    );
    final sameAvatar = AgentAvatarImage.providerFor(
      'https://example.com/agents/avatar/companion-female-01.png',
    );

    expect(provider, isA<CachedNetworkImageProvider>());
    expect(
      provider?.url,
      'https://example.com/agents/avatar/companion-female-01.png',
    );
    expect(sameAvatar, provider);
  });

  test('agent avatar provider ignores an empty URL', () {
    expect(AgentAvatarImage.providerFor(null), isNull);
    expect(AgentAvatarImage.providerFor('   '), isNull);
  });

  testWidgets('agent avatar renders its fallback without a URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AgentAvatarImage(imageUrl: null, fallback: Text('伴')),
      ),
    );

    expect(find.text('伴'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
