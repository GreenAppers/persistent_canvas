import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:image/image.dart' as img;
import 'package:scoped_model/scoped_model.dart';

import 'package:persistent_canvas/pixel_buffer.dart';

class OrthogonalState {
  Paint paint = Paint();

  OrthogonalState() {
    paint.color = Colors.black;
    paint.strokeCap = StrokeCap.round;
    paint.strokeWidth = 1.0;
  }

  void setPaintState(PaintCallback cb) {
    paint = clonePaint(paint);
    cb(paint);
  }
}

typedef PaintCallback = void Function(Paint);
typedef UploadedStateTransform = void Function(Canvas, Size, Object);
typedef DownloadedStateTransform = img.Image Function(img.Image);
typedef BackendTextureStateTransform = void Function(int);

class Input {
  Object transform;
  Object value;

  Input(this.transform, this.value);
}

class PhotographTransducer extends Model {
  int version;
  PixelBuffer state;
  VoidCallback updateStateMethod;
  OrthogonalState orthogonalState;
  List<Input> input;

  PhotographTransducer() {
    updateStateMethod = updateStatePaintDelta;
    reset();
  }

  bool isProcessing() {
    return input.length > 0 && input.last.value == null &&
      (input.last.transform is DownloadedStateTransform || input.last.transform is BackendTextureStateTransform);
  }

  void reset([ui.Image image]) {
    version = 0;
    input = <Input>[];
    if (image != null) {
      addRedraw(image, reseting: true);
      state = PixelBuffer.fromImage(image, version);
      notifyListeners();
    } else {
      state = PixelBuffer(Size(256, 256));
    }
    state.addListener(updatedState);
    orthogonalState = OrthogonalState();
  }

  void changeColor(Color color) {
    orthogonalState.setPaintState((Paint paint) => paint.color = color);
  }

  void addInput(Input x) {
    assert(!isProcessing());
    if (version < input.length) input.removeRange(version, input.length);
    input.add(x);
    version++;
  }

  void addRedraw(ui.Image image, {reseting=false}) {
    final Paint paint = orthogonalState.paint;
    addInput(Input((Canvas canvas, Size size, Object x) => canvas.drawImage(x, Offset(0, 0), paint), image));
    if (!reseting)
      updateState();
  }

  void addUploadedTransform(UploadedStateTransform transform, Object v) {
    addInput(Input(transform, v));
    updateState();
  }

  void addDownloadedTransform(ImgFilter filter) {
    addInput(Input(filter, null));
    if (state.paintingUserVersion == 0)
      startProcessing();
  }

  void startProcessing() {
    assert(state.paintedUserVersion == version-1);
    state.transformDownloaded(input.last.transform, userVersion: version);
  }

  void walkVersion(int n) {
    version += n;
    version = version.clamp(0, input.length);
    updateState();
  }

  int transduce(Canvas canvas, Size size, {int startVersion=0, int endVersion}) {
    if (startVersion == 0) orthogonalState = OrthogonalState();
    int i = startVersion;
    endVersion = endVersion == null ? version : min(endVersion, version);
    for (/**/; i < endVersion; i++) {
      var x = input[i];
      if (x.value == null) return i;
      if (x.transform is UploadedStateTransform) {
        (x.transform as UploadedStateTransform)(canvas, size, x.value);
      } else {
        canvas.drawImage(x.value, Offset(0, 0), orthogonalState.paint);
      }
    }
    return endVersion;
  }

  void updateState() {
    if (version == state.paintedUserVersion || isProcessing()) return;
    if (version < state.paintedUserVersion) return updateStateRepaint();
    else updateStateMethod();
  }
 
  void updatedState(ImageInfo image, bool synchronousCall) {
    if (isProcessing()) {
      if (state.transformedUserVersion == version)
        input.last.value = state.uploaded;
      else
        startProcessing();
    }
    notifyListeners();
    updateState();
  }

  void updateStateRepaint() {
    if (state.paintingUserVersion != 0) return;
    state.paintUploaded(
      userVersion: version,
      painter: PhotographTransducerPainter(this,
        endVersion: version,
      ),
    );
  }

  void updateStatePaintDelta() {
    if (state.paintingUserVersion != 0) return;
    state.paintUploaded(
      userVersion: version,
      painter: PhotographTransducerPainter(this,
        startVersion: max(0, state.paintedUserVersion-1),
        endVersion: version,
      ),
      startingImage: state.uploaded,
    );
  }
}

class PhotographTransducerPainter extends CustomPainter {
  PhotographTransducer transducer;
  int startVersion, endVersion;

  PhotographTransducerPainter(
    this.transducer, {this.startVersion=0, this.endVersion}
  );

  @override
  bool shouldRepaint(PhotographTransducerPainter oldDelegate) {
    return true;
  }

  void paint(Canvas canvas, Size size) {
    transducer.transduce(canvas, size,
      startVersion: startVersion,
      endVersion: endVersion,
    );
  }
}

Paint clonePaint(Paint x) {
  return Paint()
    ..blendMode = x.blendMode
    ..color = x.color
    ..colorFilter = x.colorFilter
    ..filterQuality = x.filterQuality
    ..invertColors = x.invertColors
    ..isAntiAlias = x.isAntiAlias
    ..maskFilter = x.maskFilter
    ..shader = x.shader
    ..strokeCap = x.strokeCap
    ..strokeJoin = x.strokeJoin
    ..strokeMiterLimit = x.strokeMiterLimit
    ..strokeWidth = x.strokeWidth
    ..style = x.style;
}
