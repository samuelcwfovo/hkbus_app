import 'package:flutter/material.dart';
import 'package:hkbus_app/components/map/map.dart';
import 'package:hkbus_app/components/dragableSheet/dragable_sheet.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
          body: Stack(
            children: const <Widget>[Map(), DragableSheet()],
          ),
        ));
  }
}
