import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:scoped_model/scoped_model.dart';

import 'package:persistent_canvas/pixel_buffer.dart';
import 'package:persistent_canvas/photograph_transducer.dart';

class PersistentCanvas implements Canvas {
  final PhotographTransducer model = PhotographTransducer();
  int saveCount = 1;

  @override
  void clipPath(Path path, { bool doAntiAlias = true }) {
    path = scalePath(path, model.state.size, down: true);
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.clipPath(scalePath(x, size), doAntiAlias: doAntiAlias), path);
  }

  @override
  void clipRRect(RRect rrect, { bool doAntiAlias = true }) {
    rrect = scaleRRect(rrect, model.state.size, down: true);
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.clipRRect(scaleRRect(x, size), doAntiAlias: doAntiAlias), rrect);
  }

  @override
  void clipRect(Rect rect, { ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true }) {
    rect = scaleRect(rect, model.state.size, down: true);
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.clipRect(scaleRect(x, size), clipOp: clipOp, doAntiAlias: doAntiAlias), rect);
  }

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) {
    rect = scaleRect(rect, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawArc(scaleRect(x, size), startAngle, sweepAngle, useCenter, paint), rect);
  }

  @override
  void drawAtlas(ui.Image atlas, List<RSTransform> transforms, List<Rect> rects, List<Color> colors, BlendMode blendMode, Rect cullRect, Paint paint) {
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    c = scaleOffset(c, model.state.size, down: true);
    radius = scaleDouble(radius, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawCircle(scaleOffset(c, size), scaleDouble(radius, size), x), paint);
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawColor(x, blendMode), color);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    outer = scaleRRect(outer, model.state.size, down: true);
    inner = scaleRRect(inner, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawDRRect(scaleRRect(x, size), scaleRRect(inner, size), paint), outer);
  }

  @override
  void drawImage(ui.Image image, Offset p, Paint paint) {
    p = scaleOffset(p, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawImage(x, scaleOffset(p, size), paint), image);
  }

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) {
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    dst = scaleRect(dst, model.state.size, down: true);
    // Assume the source image is derived if it has the same dimensions as the canvas
    bool scaleSrc = image.width == model.state.size.width && image.height == model.state.size.height;
    if (scaleSrc) src = scaleRect(src, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform(
      (Canvas canvas, Size size, Object x) => canvas.drawImageRect(x, scaleSrc ? scaleRect(src, size) : src, scaleRect(dst, size), paint), image);
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    p1 = scaleOffset(p1, model.state.size, down: true);
    p2 = scaleOffset(p2, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawLine(scaleOffset(p1, size), scaleOffset(x, size), paint), p2);
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    rect = scaleRect(rect, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawOval(scaleRect(x, size), paint), rect);
  }

  @override
  void drawPaint(Paint paint) {
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawPaint(x), paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    offset = scaleOffset(offset, model.state.size, down: true);
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawParagraph(x, scaleOffset(offset, size)), paragraph);
  }

  @override
  void drawPath(Path path, Paint paint) {
    path = scalePath(path, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawPath(scalePath(x, size), paint), path);
  }

  @override
  void drawPicture(ui.Picture picture) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawPicture(x), picture);
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    points = scaleOffsetList(points, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawPoints(pointMode, scaleOffsetList(x, size), paint), points);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    rrect = scaleRRect(rrect, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawRRect(scaleRRect(x, size), paint), rrect);
  }

  @override
  void drawRawAtlas(ui.Image atlas, Float32List rstTransforms, Float32List rects, Int32List colors, BlendMode blendMode, Rect cullRect, Paint paint) {
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    rect = scaleRect(rect, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawRect(scaleRect(x, size), paint), rect);
  }

  @override
  void drawShadow(Path path, Color color, double elevation, bool transparentOccluder) {
    path = scalePath(path, model.state.size, down: true);
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.drawShadow(scalePath(x, size), color, elevation, transparentOccluder), path);
  }

  @override
  void drawVertices(ui.Vertices vertices, BlendMode blendMode, Paint paint) {
  }

  @override
  int getSaveCount() => saveCount;

  @override
  void restore() {
    saveCount--;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.restore(), true);
  }

  @override
  void rotate(double radians) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.rotate(x), radians);
  }

  @override
  void save() {
    saveCount++;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.save(), true);
  }

  @override
  void saveLayer(Rect bounds, Paint paint) {
    saveCount++;
    bounds = scaleRect(bounds, model.state.size, down: true);
    if (paint == null) paint = model.orthogonalState.paint;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.saveLayer(scaleRect(x, size), paint), bounds);
  }

  @override
  void scale(double sx, [ double sy ]) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.scale(x, sy), sx);
  }

  @override
  void skew(double sx, double sy) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.skew(x, sy), sx);
  }

  @override
  void transform(Float64List matrix4) {
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.transform(x), matrix4);
  }

  @override
  void translate(double dx, double dy) {
    dx = dx / model.state.size.width;
    dy = dy / model.state.size.height;
    model.addUploadedTransform((Canvas canvas, Size size, Object x) => canvas.skew((x as double) * size.width, dy * size.height), dx);
  }
}

class PersistentCanvasWidget extends StatelessWidget {
  final PersistentCanvas canvas;

  PersistentCanvasWidget(this.canvas);

  PhotographTransducer model() { return canvas.model; }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: canvas.model.state.size.width,
      height: canvas.model.state.size.height,
      alignment: Alignment.topLeft,
      color: Colors.white,
      child: RepaintBoundary(
        child: ScopedModel<PhotographTransducer>(
          model: canvas.model,
          child: ScopedModelDescendant<PhotographTransducer>(
            builder: (context, child, cart) => CustomPaint(
              painter: PixelBufferPainter(canvas.model.state)
            ),
          ),
        ),
      ),
    );
  }
}

double scaleDouble(double x, Size size, {bool down=false}) {
  return down ? x / size.width / size.height : x * size.width * size.height;
}

Radius scaleRadius(Radius x, Size size, {bool down=false}) {
  return down ? Radius.elliptical(x.x / size.width, x.y / size.height) : Radius.elliptical(x.x * size.width, x.y * size.height);
}

Offset scaleOffset(Offset x, Size size, {bool down=false}) {
  return down ? x.scale(1.0 / size.width, 1.0 / size.height) : x.scale(size.width, size.height);
}

List<Offset> scaleOffsetList(List<Offset> x, Size size, {bool down=false}) {
  return x.map((offset) => scaleOffset(offset, size, down: down)).toList();
}

Rect scaleRect(Rect x, Size size, {bool down=false}) {
  return down ?
    Rect.fromLTWH(x.left / size.width, x.top / size.height, x.width / size.width, x.height / size.height) :
    Rect.fromLTWH(x.left * size.width, x.top * size.height, x.width * size.width, x.height * size.height);
}

RRect scaleRRect(RRect x, Size size, {bool down=false}) {
  return RRect.fromRectAndCorners(scaleRect(x.outerRect, size, down:down),
                                  topLeft:    scaleRadius(x.tlRadius, size, down:down), topRight:    scaleRadius(x.trRadius, size, down:down),
                                  bottomLeft: scaleRadius(x.blRadius, size, down:down), bottomRight: scaleRadius(x.brRadius, size, down:down));
}

Path scalePath(Path x, Size size, {bool down=false}) {
  Matrix4 scalingMatrix = Matrix4.diagonal3Values(down ? 1.0 / size.width : size.width, down ? 1.0 / size.height : size.height, 1.0);
  return x.transform(scalingMatrix.storage);
}
