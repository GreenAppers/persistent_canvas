# Persistent Canvas Example

![](demo.gif)

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

