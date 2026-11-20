import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:papeleta63/utils/celular_semana.dart';
import 'package:papeleta63/widgets/celular_semana_poster.dart';

Future<void> _render(WidgetTester tester, CelularSemanaData data) async {
  tester.view.physicalSize = const Size(1240, 1754);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: CelularSemanaPoster(data: data)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('poster curto', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _render(
      tester,
      const CelularSemanaData(
        descricao: 'MOTOROLA MOTO G17 128GB',
        imagemPath: '',
        precoOriginal: 999,
        descontoPortabilidade: 300,
        percentualCartao: 10,
        seguro: 284.72,
        ofertaInicio: '16/11/26',
        ofertaFim: '22/11/26',
      ),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('poster descricao longa', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _render(
      tester,
      const CelularSemanaData(
        descricao: 'SAMSUNG GALAXY S24 ULTRA 5G 512GB PRETO',
        imagemPath: '',
        precoOriginal: 8999.99,
        descontoPortabilidade: 3000,
        percentualCartao: 10,
        seguro: 284.72,
        ofertaInicio: '16/11/26',
        ofertaFim: '22/11/26',
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
