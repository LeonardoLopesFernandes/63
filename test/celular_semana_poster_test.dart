import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papeleta63/utils/celular_semana.dart';
import 'package:papeleta63/widgets/celular_semana_poster.dart';

void main() {
  testWidgets('poster curto', (tester) async {
    tester.view.physicalSize = const Size(1240, 1754);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RepaintBoundary(
        child: const CelularSemanaPoster(
          data: CelularSemanaData(
            descricao: 'MOTOROLA MOTO G47 5G 256GB', imagemPath: '',
            precoOriginal: 1599, descontoPortabilidade: 300, percentualCartao: 10,
            seguro: 455.72, ofertaInicio: '16/11/26', ofertaFim: '22/11/26',
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/overlays/celular_semana.png'),
        tester.element(find.byType(CelularSemanaPoster)),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
