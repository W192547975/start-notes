import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:start/widgets/ui.dart';

void main() {
  testWidgets('日期选择器：渲染正常、年滚轮仅今年+明年、确认有返回', (tester) async {
    DateTime? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await showStartDatePicker(ctx),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('确认'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    final wheels = find.byType(ListWheelScrollView);
    expect(wheels, findsNWidgets(3));
    // 未来最多选一年：年滚轮只有 今年/明年 两项。
    final yearWheel = tester.widget<ListWheelScrollView>(wheels.first);
    expect((yearWheel.childDelegate as ListWheelChildBuilderDelegate).childCount, 2);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
  });

  testWidgets('时间选择器：渲染正常、确认有返回', (tester) async {
    TimeOfDay? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await showStartTimePicker(ctx),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ListWheelScrollView), findsNWidgets(2));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
  });
}
