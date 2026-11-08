import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedidos_app/features/cliente/data/models/catalog_models.dart';
import 'package:pedidos_app/features/cliente/presentation/widgets/cliente_widgets.dart';
import 'package:pedidos_app/features/cliente/presentation/widgets/promo_ads_banner.dart';

void main() {
  testWidgets('promo Ver más opens its configured commerce', (tester) async {
    int? openedCommerceId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PromoAdsBanner(
            slides: const [
              PromoAdSlide(
                id: 1,
                imageUrl: 'https://example.test/banner.png',
                linkUrl: '/cliente/comercio/42',
              ),
            ],
            onOpenComercio: (id) => openedCommerceId = id,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ver más'));
    expect(openedCommerceId, 42);
  });

  testWidgets('promo without a commerce destination has no dead action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PromoAdsBanner(
            slides: [
              PromoAdSlide(
                id: 1,
                imageUrl: 'https://example.test/banner.png',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ver más'), findsNothing);
  });

  testWidgets('commerce cards do not invent rating scores', (tester) async {
    const comercio = ComercioModel(
      id: 1,
      name: 'Comercio sin opiniones',
      estaAbierto: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ComercioMarketplaceTile(
                comercio: comercio,
                onTap: () {},
              ),
              StoreCard(comercio: comercio),
            ],
          ),
        ),
      ),
    );

    expect(find.text('4.6'), findsNothing);
    expect(find.text('(173)'), findsNothing);
  });
}
