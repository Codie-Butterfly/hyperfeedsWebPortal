import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyperfeeds_mobile/providers/auth_provider.dart';
import 'package:hyperfeeds_mobile/screens/employee/walk_in_chick_booking_screen.dart';

void main() {
  testWidgets('records a walk-in chick deposit with retry-safe request and shows remaining balance', (tester) async {
    tester.view.physicalSize=const Size(1000,2400); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({'access_token':'h.${base64Url.encode(utf8.encode(jsonEncode({'sub':'staff'})))}.s'});
    final dio=Dio(); final api=ApiClient(dio:dio);
    Map<String,dynamic>? submitted;
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h){
      dynamic data;
      if(r.path.endsWith('/branches')) {
        data=[{'id':'branch','name':'Shop'}];
      } else if(r.path=='/chicks/availability') {
        data=[{'id':'breed','chickType':'BROILER','breed':'Ross','pricePerChick':2,'currency':'USD','depositRequired':true,'depositPercentage':25,'deliveryDate':'2026-10-01','cutoffAt':'2026-10-01'}];
      } else if(r.path=='/commerce/walk-in-chick-bookings') {
        submitted=Map<String,dynamic>.from(r.data);
        data={'id':'booking','reference':'CHK-TEST','customer_name':'Walk-in customer','quantity':100,'breed':'Ross','delivery_date':'2026-10-01','branch_name':'Shop','total':200,'amount_paid':50,'amount_owed':150,'currency':'USD','status':'CONFIRMED'};
      } else {h.reject(DioException(requestOptions:r));return;}
      h.resolve(Response(requestOptions:r,data:data,statusCode:200));
    }));
    await tester.pumpWidget(ProviderScope(overrides:[apiClientProvider.overrideWithValue(api)],child:const MaterialApp(home:WalkInChickBookingScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField,'Customer name'),'Walk-in customer');
    final breed=find.widgetWithText(DropdownButtonFormField<String>,'Chick type and breed');
    await tester.ensureVisible(breed); await tester.tap(breed); await tester.pumpAndSettle();
    await tester.tap(find.text('BROILER • Ross').last); await tester.pumpAndSettle();
    expect(find.text('50.00'),findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile)); await tester.tap(find.byType(CheckboxListTile)); await tester.pumpAndSettle();
    final save=find.text('Record chick booking'); await tester.ensureVisible(save); await tester.tap(save); await tester.pumpAndSettle();
    expect(submitted?['customerName'],'Walk-in customer');
    expect(submitted?['amountPaid'],50);
    expect(submitted?['requestId'],isNotEmpty);
    expect(find.text('Remaining: USD 150'),findsOneWidget);
  });
}
