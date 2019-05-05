import 'dart:math';

import 'package:flutter/material.dart';

import 'package:persistent_canvas/persistent_canvas.dart';
import 'package:random_color/random_color.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  PersistentCanvas _canvas = PersistentCanvas(
    size: Size(250, 250),
    coordinates: PersistentCanvasCoordinates.preNormalized
  );
  RandomColor _randomColor = RandomColor();
  Random _random = Random();
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
      Paint paint = Paint()..color = _randomColor.randomColor();
      Offset center = Offset(_random.nextDouble(), _random.nextDouble());
      double radius = _random.nextDouble() / 20.0;
      _canvas.drawCircle(center, radius, paint);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),

      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(40.0),
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.all(5.0),
              child: PersistentCanvasWidget(_canvas),
              decoration: BoxDecoration(
                border: Border.all(width: 5.0),
                borderRadius: BorderRadius.circular(5.0),
              ),
            )
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'You have pushed the button this many times:',
                ),
                Text(
                  '$_counter',
                  style: Theme.of(context).textTheme.display1,
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
