// Copyright 2019 Green Appers, Inc. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:busy_model/busy_model.dart';
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
typedef UploadedCropTransform = ui.Image Function(ui.Image, Rect);
typedef DownloadedStateTransform = img.Image Function(img.Image);
typedef BackendTextureStateTransform = void Function(int);

class Input {
  Object transform;
  Object value;

  Input(this.transform, this.value);

  bool get processing => value == null && (transform is DownloadedStateTransform || transform is BackendTextureStateTransform);
}

/// The [PhotographTransducer] class transforms [PixelBuffer] `state` by the [List<Input>] `input`
class PhotographTransducer extends Model {
  int version;
  PixelBuffer state;
  VoidCallback updateUploadedStateMethod;
  OrthogonalState orthogonalState;
  Size initialSize;
  List<Input> input;
  final BusyModel busy;
  List<ImageCallback> renderDone = <ImageCallback>[];

  PhotographTransducer({this.busy}) {
    updateUploadedStateMethod = updateUploadedStatePaintDelta;
    reset();
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
    initialSize = state.size;
    state.addListener(updatedUploadedState);
    orthogonalState = OrthogonalState();
  }

  Future<ui.Image> getRenderedImage() async {
    if (version == state.paintedUserVersion) return state.uploaded;
    Completer<ui.Image> completer = Completer(); 
    renderDone.add((ui.Image result) { completer.complete(result); });
    return completer.future;
  }

  void changeColor(Color color) {
    orthogonalState.setPaintState((Paint paint) => paint.color = color);
  }

  void addInput(Input x) {
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

  void addCrop(Rect rect) {
    UploadedCropTransform tf = (ui.Image x, Rect r) { return x; };
    addInput(Input(tf, rect));
    updateState();
  }

  void addUploadedTransform(UploadedStateTransform transform, Object v) {
    addInput(Input(transform, v));
    updateState();
  }

  void addDownloadedTransform(DownloadedStateTransform filter) {
    addInput(Input(filter, null));
    updateState();
  }

  void addList(List<Input> list, {int startIndex}) {
    for(var i = startIndex == null ? 0 : startIndex; i < list.length; i++) {
      var x = list[i];
      addInput(Input(x.transform, x.transform is UploadedStateTransform ? x.value : null));
    }
  }

  void walkVersion(int n) {
    version += n;
    version = version.clamp(0, input.length);
    updateState();
  }

  void setInitialState() {
    orthogonalState = OrthogonalState();
    if (state.size != initialSize) {
      state.size = initialSize;
      if (busy != null) busy.reset();
    }
  }

  int transduceUploaded(Canvas canvas, Size size, {int startVersion=0, int endVersion}) {
    if (startVersion == 0) setInitialState();
    int i = startVersion;
    endVersion = endVersion == null ? version : min(endVersion, version);
    for (/**/; i < endVersion; i++) {
      var x = input[i];
      if (x.value == null) break;
      if (x.transform is UploadedStateTransform) {
        (x.transform as UploadedStateTransform)(canvas, size, x.value);
      } else {
        canvas.drawImage(x.value, Offset(0, 0), orthogonalState.paint);
      }
    }
    return i;
  }

  int findTransduceUploadedVersion({int startVersion=0, int endVersion}) {
    int i = startVersion;
    endVersion = endVersion == null ? version : min(endVersion, version);
    for (/**/; i < endVersion; i++) {
      var x = input[i];
      if (x.value == null) break;
    }
    return i;
  }

  void updateState() {
    if (version == state.paintedUserVersion) return;
    if (state.paintingUserVersion != 0 || state.transformingUserVersion != 0 || state.uploadingVersion != 0) return;
    if (version < state.paintedUserVersion) return updateUploadedStateRepaint();
    var x = input[state.paintedUserVersion];
    if (x.processing) {
      updateDownloadedState(state.paintedUserVersion + 1, x.transform);
    } else {
      if (x.transform is UploadedCropTransform) {
        state.cropUploaded(
          x.value,
          userVersion: state.paintedUserVersion + 1
        );
        // Reset the "busy state" to trigger e.g. PhotoView rebuilds after resizing
        if (busy != null) getRenderedImage().then((ui.Image x) { busy.reset(); });
      } else {
        updateUploadedStateMethod();
      }
    }
  }

  void updateDownloadedState(int newVersion, DownloadedStateTransform tf) {
    if (busy != null) busy.setBusy('Processing');
    state.transformDownloaded(tf,
      userVersion: newVersion,
      done: updatedDownloadedState
    );
  }

  void updatedDownloadedState() {
    if (busy != null) busy.reset();
  }
 
  void updatedUploadedState(ImageInfo image, bool synchronousCall) {
    if (state.paintedUserVersion < input.length) {
      var x = input[state.paintedUserVersion];
      if (x.processing) x.value = state.uploaded;
    }

    notifyListeners();

    if (version == state.paintedUserVersion) {
      for (int i = 0; i < renderDone.length; i++) {
        renderDone[i](state.uploaded);
      }
      renderDone.clear();
    } else {
      updateState();
    }
  }

  void updateUploadedStateRepaint() {
    int newVersion = findTransduceUploadedVersion();
    state.paintUploaded(
      userVersion: newVersion,
      painter: PhotographTransducerPainter(this,
        endVersion: newVersion,
      ),
    );
  }

  void updateUploadedStatePaintDelta() {
    int startVersion = state.paintedUserVersion;
    int newVersion = findTransduceUploadedVersion(startVersion: startVersion);
    assert(newVersion > startVersion);
    state.paintUploaded(
      userVersion: newVersion,
      painter: PhotographTransducerPainter(this,
        startVersion: startVersion,
        endVersion: newVersion,
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
    int version = transducer.transduceUploaded(canvas, size,
      startVersion: startVersion,
      endVersion: endVersion,
    );
    if (endVersion != null) {
      assert(version == endVersion);
    }
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
