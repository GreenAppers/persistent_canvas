// Copyright 2019 Green Appers, Inc. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:busy_model/busy_model.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:persistent_canvas/pixel_buffer.dart';
import 'package:persistent_canvas/photograph_transducer.dart';

enum PersistentCanvasCoordinates { regular, normalize, preNormalized }

/// The [PersistentCanvas] class provides [Canvas] backed by [PhotographTransducer]
class PersistentCanvas implements Canvas {
  final PhotographTransducer model;
  final PersistentCanvasCoordinates coordinates;
  int saveCount = 1;

  PersistentCanvas(
      {ui.Image startingImage,
      Size size,
      this.coordinates = PersistentCanvasCoordinates.regular,
      BusyModel busy})
      : model = PhotographTransducer(
            initialState: startingImage, size: size, busy: busy);

  Size get size => model.state.size;

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.clipPath(x, doAntiAlias: doAntiAlias),
          path);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        path = scalePath(path, model.state.size, down: true);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.clipPath(scalePath(x, size), doAntiAlias: doAntiAlias),
          path);
    }
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.clipRRect(x, doAntiAlias: doAntiAlias),
          rrect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rrect = scaleRRect(rrect, model.state.size, down: true);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.clipRRect(scaleRRect(x, size), doAntiAlias: doAntiAlias),
          rrect);
    }
  }

  @override
  void clipRect(Rect rect,
      {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.clipRect(x, clipOp: clipOp, doAntiAlias: doAntiAlias),
          rect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rect = scaleRect(rect, model.state.size, down: true);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.clipRect(
              scaleRect(x, size),
              clipOp: clipOp,
              doAntiAlias: doAntiAlias),
          rect);
    }
  }

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter,
      Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawArc(x, startAngle, sweepAngle, useCenter, paint),
          rect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rect = scaleRect(rect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawArc(
              scaleRect(x, size),
              startAngle,
              sweepAngle,
              useCenter,
              scalePaint(paint, size)),
          rect);
    }
  }

  @override
  void drawAtlas(ui.Image atlas, List<RSTransform> transforms, List<Rect> rects,
      List<Color> colors, BlendMode blendMode, Rect cullRect, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawAtlas(
              x, transforms, rects, colors, blendMode, cullRect, paint),
          atlas);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        transforms =
            scaleRSTransformList(transforms, model.state.size, down: true);
        cullRect = scaleRect(cullRect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawAtlas(
              x,
              scaleRSTransformList(transforms, size),
              rects,
              colors,
              blendMode,
              scaleRect(cullRect, size),
              scalePaint(paint, size)),
          atlas);
    }
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawCircle(x, radius, paint),
          c);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        c = scaleOffset(c, model.state.size, down: true);
        radius = scaleDouble(radius, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawCircle(
              scaleOffset(x, size),
              scaleDouble(radius, size),
              scalePaint(paint, size)),
          c);
    }
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.drawColor(x, blendMode),
        color);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawDRRect(x, inner, paint),
          outer);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        outer = scaleRRect(outer, model.state.size, down: true);
        inner = scaleRRect(inner, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawDRRect(
              scaleRRect(x, size),
              scaleRRect(inner, size),
              scalePaint(paint, size)),
          outer);
    }
  }

  @override
  void drawImage(ui.Image image, Offset p, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawImage(x, p, paint),
          image);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        p = scaleOffset(p, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawImage(
              x, scaleOffset(p, size), scalePaint(paint, size)),
          image);
    }
  }

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawImageNine(x, center, dst, paint),
          image);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        dst = scaleRect(dst, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawImageNine(
              x, center, scaleRect(dst, size), scalePaint(paint, size)),
          image);
    }
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawImageRect(x, src, dst, paint),
          image);
    } else {
      bool scaleSrc = false;
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        dst = scaleRect(dst, model.state.size, down: true);
        // Assume the source image is derived if it has the same dimensions as the canvas
        scaleSrc = image.width == model.state.size.width &&
            image.height == model.state.size.height;
        if (scaleSrc) src = scaleRect(src, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawImageRect(
              x,
              scaleSrc ? scaleRect(src, size) : src,
              scaleRect(dst, size),
              scalePaint(paint, size)),
          image);
    }
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawLine(p1, x, paint),
          p2);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        p1 = scaleOffset(p1, model.state.size, down: true);
        p2 = scaleOffset(p2, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawLine(
              scaleOffset(p1, size),
              scaleOffset(x, size),
              scalePaint(paint, size)),
          p2);
    }
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawOval(x, paint),
          rect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rect = scaleRect(rect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawOval(scaleRect(x, size), scalePaint(paint, size)),
          rect);
    }
  }

  @override
  void drawPaint(Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawPaint(x), paint);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawPaint(scalePaint(x, size)),
          paint);
    }
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawParagraph(x, offset),
          paragraph);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        offset = scaleOffset(offset, model.state.size, down: true);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawParagraph(x, scaleOffset(offset, size)),
          paragraph);
    }
  }

  @override
  void drawPath(Path path, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawPath(x, paint),
          path);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        path = scalePath(path, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawPath(scalePath(x, size), scalePaint(paint, size)),
          path);
    }
  }

  @override
  void drawPicture(ui.Picture picture) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.drawPicture(x), picture);
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawPoints(pointMode, x, paint),
          points);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        points = scaleOffsetList(points, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawPoints(
              pointMode, scaleOffsetList(x, size), scalePaint(paint, size)),
          points);
    }
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawRRect(x, paint),
          rrect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rrect = scaleRRect(rrect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawRRect(scaleRRect(x, size), scalePaint(paint, size)),
          rrect);
    }
  }

  @override
  void drawRawAtlas(ui.Image atlas, Float32List transforms, Float32List rects,
      Int32List colors, BlendMode blendMode, Rect cullRect, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawRawAtlas(
              x, transforms, rects, colors, blendMode, cullRect, paint),
          atlas);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        transforms =
            scaleRawRSTransformList(transforms, model.state.size, down: true);
        cullRect = scaleRect(cullRect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawRawAtlas(
              x,
              scaleRawRSTransformList(transforms, size),
              rects,
              colors,
              blendMode,
              scaleRect(cullRect, size),
              scalePaint(paint, size)),
          atlas);
    }
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawRawPoints(pointMode, x, paint),
          points);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        points = scaleRawOffsetList(points, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawRawPoints(
              pointMode, scaleRawOffsetList(x, size), scalePaint(paint, size)),
          points);
    }
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawRect(x, paint),
          rect);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        rect = scaleRect(rect, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawRect(scaleRect(x, size), scalePaint(paint, size)),
          rect);
    }
  }

  @override
  void drawShadow(
      Path path, Color color, double elevation, bool transparentOccluder) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawShadow(x, color, elevation, transparentOccluder),
          path);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        path = scalePath(path, model.state.size, down: true);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.drawShadow(
              scalePath(x, size), color, elevation, transparentOccluder),
          path);
    }
  }

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.drawVertices(vertices, blendMode, paint),
          vertices);
    } else {
      Size originalSize;
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        paint = _getScaledPaint(paint);
        originalSize = model.state.size;
      } else {
        originalSize = Size(1, 1);
      }
      model.addUploadedTransform((Canvas canvas, Size size, Object x) {
        canvas.save();
        canvas.scale(size.width.toDouble() / originalSize.width.toDouble(),
            size.height.toDouble() / originalSize.height.toDouble());
        canvas.drawVertices(vertices, blendMode, scalePaint(paint, size));
        canvas.restore();
      }, vertices);
    }
  }

  @override
  int getSaveCount() => saveCount;

  @override
  void restore() {
    saveCount--;
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.restore(), true);
  }

  @override
  void rotate(double radians) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.rotate(x), radians);
  }

  @override
  void save() {
    saveCount++;
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.save(), true);
  }

  @override
  void saveLayer(Rect bounds, Paint paint) {
    saveCount++;
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.saveLayer(x, paint),
          bounds);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        bounds = scaleRect(bounds, model.state.size, down: true);
        paint = _getScaledPaint(paint);
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.saveLayer(scaleRect(x, size), scalePaint(paint, size)),
          bounds);
    }
  }

  @override
  void scale(double sx, [double sy]) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.scale(x, sy), sx);
  }

  @override
  void skew(double sx, double sy) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.skew(x, sy), sx);
  }

  @override
  void transform(Float64List matrix4) {
    model.addUploadedTransform(
        (Canvas canvas, Size size, Object x) => canvas.transform(x), matrix4);
  }

  @override
  void translate(double dx, double dy) {
    if (coordinates == PersistentCanvasCoordinates.regular) {
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) => canvas.skew(x, dy), dx);
    } else {
      if (coordinates == PersistentCanvasCoordinates.normalize) {
        dx = dx / model.state.size.width;
        dy = dy / model.state.size.height;
      }
      model.addUploadedTransform(
          (Canvas canvas, Size size, Object x) =>
              canvas.skew((x as double) * size.width, dy * size.height),
          dx);
    }
  }

  Paint _getScaledPaint(Paint x) {
    if (x == null) x = model.orthogonalState.paint;
    return scalePaint(x, model.state.size, down: true);
  }
}

class PersistentCanvasLayers {
  final BusyModel busy;
  List<PersistentCanvas> layer;

  PersistentCanvas get canvas => layer[0];

  PersistentCanvasLayers(
      {ui.Image startingImage,
      Size size,
      PersistentCanvasCoordinates coordinates =
          PersistentCanvasCoordinates.regular,
      this.busy})
      : layer = <PersistentCanvas>[
          PersistentCanvas(
              startingImage: startingImage,
              coordinates: coordinates,
              size: size,
              busy: busy)
        ];
}

class PersistentCanvasWidget extends StatelessWidget {
  final PersistentCanvas canvas;

  PersistentCanvasWidget(this.canvas);

  PhotographTransducer get model => canvas.model;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: model.state.size.width,
      height: model.state.size.height,
      alignment: Alignment.topLeft,
      color: Colors.white,
      child: RepaintBoundary(
        child: ScopedModel<PhotographTransducer>(
          model: model,
          child: ScopedModelDescendant<PhotographTransducer>(
            builder: (context, child, cart) =>
                CustomPaint(painter: PixelBufferPainter(model.state)),
          ),
        ),
      ),
    );
  }
}

class PersistentCanvasLayersWidget extends StatelessWidget {
  final PersistentCanvasLayers layers;

  PersistentCanvasLayersWidget(this.layers);

  @override
  Widget build(BuildContext context) {
    List<Widget> stack = <Widget>[];
    for (var layer in layers.layer) {
      stack.add(
        RepaintBoundary(
          child: ScopedModel<PhotographTransducer>(
            model: layer.model,
            child: ScopedModelDescendant<PhotographTransducer>(
              builder: (context, child, cart) =>
                  CustomPaint(painter: PixelBufferPainter(layer.model.state)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: layers.canvas.model.state.size.width,
      height: layers.canvas.model.state.size.height,
      alignment: Alignment.topLeft,
      color: Colors.white,
      child: Stack(children: stack),
    );
  }
}

double scaleDouble(double x, Size size, {bool down = false}) {
  return down
      ? x / max(size.width, size.height)
      : x * max(size.width, size.height);
}

Radius scaleRadius(Radius x, Size size, {bool down = false}) {
  return down
      ? Radius.elliptical(x.x / size.width, x.y / size.height)
      : Radius.elliptical(x.x * size.width, x.y * size.height);
}

Offset scaleOffset(Offset x, Size size, {bool down = false}) {
  return down
      ? x.scale(1.0 / size.width, 1.0 / size.height)
      : x.scale(size.width, size.height);
}

List<Offset> scaleOffsetList(List<Offset> x, Size size, {bool down = false}) {
  return x.map((offset) => scaleOffset(offset, size, down: down)).toList();
}

Rect scaleRect(Rect x, Size size, {bool down = false}) {
  return down
      ? Rect.fromLTWH(x.left / size.width, x.top / size.height,
          x.width / size.width, x.height / size.height)
      : Rect.fromLTWH(x.left * size.width, x.top * size.height,
          x.width * size.width, x.height * size.height);
}

RRect scaleRRect(RRect x, Size size, {bool down = false}) {
  return RRect.fromRectAndCorners(scaleRect(x.outerRect, size, down: down),
      topLeft: scaleRadius(x.tlRadius, size, down: down),
      topRight: scaleRadius(x.trRadius, size, down: down),
      bottomLeft: scaleRadius(x.blRadius, size, down: down),
      bottomRight: scaleRadius(x.brRadius, size, down: down));
}

Path scalePath(Path x, Size size, {bool down = false}) {
  Matrix4 scalingMatrix = Matrix4.diagonal3Values(
      down ? 1.0 / size.width : size.width,
      down ? 1.0 / size.height : size.height,
      1.0);
  return x.transform(scalingMatrix.storage);
}

Paint scalePaint(Paint x, Size size, {bool down = false}) {
  if (x.style != PaintingStyle.stroke) return x;
  return clonePaint(x)
    ..strokeWidth = scaleDouble(x.strokeWidth, size, down: down)
    ..strokeMiterLimit = scaleDouble(x.strokeMiterLimit, size, down: down);
}

RSTransform scaleRSTransform(RSTransform x, Size size, {bool down = false}) {
  throw Exception("not yet implemented");
}

List<RSTransform> scaleRSTransformList(List<RSTransform> x, Size size,
    {bool down = false}) {
  return x.map((tf) => scaleRSTransform(tf, size, down: down)).toList();
}

Float32List scaleRawOffsetList(Float32List x, Size size, {bool down = false}) {
  Float32List ret = Float32List(x.length);
  for (int i = 0; i < x.length; i++) {
    if (i % 2 == 0)
      ret[i] = down ? x[i] / size.width : x[i] * size.width;
    else
      ret[i] = down ? x[i] / size.height : x[i] * size.height;
  }
  return ret;
}

Float32List scaleRawRSTransformList(Float32List x, Size size,
    {bool down = false}) {
  throw Exception("not yet implemented");
}
