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

// Photograph Transducer is an image manipulation engine inspired by Finite
// State Automata.  We imagine a "transducer" (with empty output alphabet)
// whose state space is the set of all "photographs" (e.g. images) of some size.
//
// Formally, a finite transducer T is a 6-tuple (Q, Σ, Γ, I, F, δ) such that:
//
// Q is a finite set, the set of states;
// Σ is a finite set, called the input alphabet;
// Γ is a finite set, called the output alphabet;
// I is a subset of Q, the set of initial states;
// F is a subset of Q, the set of final states; and
// δ ⊆ Q ⨉ (Σ ∪ {ϵ}) ⨉ (Γ ∪ {ϵ}) ⨉ Q (where ϵ is the empty string) is the transition relation.

typedef UploadedStateTransform = void Function(Canvas, Size, Object);
typedef UploadedCropTransform = ui.Image Function(ui.Image, Rect);
typedef DownloadedStateTransform = img.Image Function(img.Image);
typedef BackendTextureStateTransform = void Function(int);
typedef PaintCallback = void Function(Paint);

class Input {
  Object transform;
  Object value;

  Input(this.transform, this.value);

  bool get processing =>
      value == null &&
      (transform is DownloadedStateTransform ||
          transform is BackendTextureStateTransform);
}

class OrthogonalState {
  Paint paint = Paint();
  Color backgroundColor = Colors.white;

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

/// [PhotographTransducer] transforms [PixelBuffer] 'state' by the [List<Input>] 'input'
class PhotographTransducer extends Model {
  int version;
  PixelBuffer state;
  OrthogonalState orthogonalState;
  VoidCallback updateUploadedStateMethod;
  Size initialSize;
  List<Input> input;
  final BusyModel busy;
  List<ImageCallback> renderDone = <ImageCallback>[];

  PhotographTransducer({ui.Image initialState, Size size, this.busy}) {
    updateUploadedStateMethod = updateUploadedStatePaintDelta;
    reset(initialState, size);
  }

  void reset([ui.Image image, Size size]) {
    version = 0;
    input = <Input>[];
    if (image != null) {
      addImage(image, reseting: true);
      state = PixelBuffer.fromImage(image, version);
      notifyListeners();
    } else {
      state = PixelBuffer(size ?? Size(256, 256));
    }
    initialSize = state.size;
    state.addListener(_updatedUploadedState);
    orthogonalState = OrthogonalState();
  }

  Future<img.Image> getDownloadedState() async => state.getDownloadedState();

  Future<ui.Image> getUploadedState() async {
    if (version == state.paintedUserVersion) return state.uploaded;
    Completer<ui.Image> completer = Completer();
    renderDone.add((ui.Image result) {
      completer.complete(result);
    });
    return completer.future;
  }

  void setInitialState() {
    orthogonalState = OrthogonalState();
    if (state.size != initialSize) {
      state.size = initialSize;
      if (busy != null) busy.reset();
    }
  }

  void changeColor([Color color]) {
    orthogonalState.setPaintState((Paint paint) => paint
      ..color = color ?? paint.color
      ..shader = null
    );
  }

  void changeShader([Shader shader]) {
    orthogonalState.setPaintState((Paint paint) => paint
      ..shader = shader ?? paint.shader
    );
  }

  void addInput(Input x) {
    if (version < input.length) input.removeRange(version, input.length);
    input.add(x);
    version++;
  }

  void addList(List<Input> list, {int startIndex}) {
    for (var i = startIndex == null ? 0 : startIndex; i < list.length; i++) {
      var x = list[i];
      addInput(Input(
          x.transform, x.transform is UploadedStateTransform ? x.value : null));
    }
  }

  void addImage(ui.Image image, {reseting = false}) {
    final Paint paint = orthogonalState.paint;
    addInput(Input(
        (Canvas canvas, Size size, Object x) =>
            canvas.drawImage(x, Offset(0, 0), paint),
        image));
    if (!reseting) _updateState();
  }

  void addCrop(Rect rect) {
    UploadedCropTransform tf = (ui.Image x, Rect r) {
      return x;
    };
    addInput(Input(tf, rect));
    _updateState();
  }

  void addUploadedTransform(UploadedStateTransform transform, Object v) {
    addInput(Input(transform, v));
    _updateState();
  }

  void addDownloadedTransform(DownloadedStateTransform filter) {
    addInput(Input(filter, null));
    _updateState();
  }

  /// Generalized "undo" that redraws from scratch to go backwards
  bool walkVersion(int n) {
    int oldVersion = version;
    version += n;
    version = version.clamp(0, input.length);
    _updateState();
    return oldVersion != version;
  }

  /// Can be used to implement tool previews
  void undo() {
    assert(state.lastUploaded != null);
    state.uploaded = state.lastUploaded;
    state.uploadedVersion = state.lastUploadedVersion;
    state.paintedUserVersion = state.lastPaintedUserVersion;
    input.removeLast();
    version--;
  }

  int _transduceUploaded(Canvas canvas, Size size,
      {int startVersion = 0, int endVersion}) {
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

  int _findTransduceUploadedVersion({int startVersion = 0, int endVersion}) {
    int i = startVersion;
    endVersion = endVersion == null ? version : min(endVersion, version);
    for (/**/; i < endVersion; i++) {
      var x = input[i];
      if (x.value == null) break;
    }
    return i;
  }

  void _updateState() {
    if (version == state.paintedUserVersion) return;
    if (state.paintingUserVersion != 0 ||
        state.transformingUserVersion != 0 ||
        state.uploadingVersion != 0) return;
    if (version < state.paintedUserVersion) return updateUploadedStateRepaint();
    var x = input[state.paintedUserVersion];
    if (x.processing) {
      _updateDownloadedState(state.paintedUserVersion + 1, x.transform);
    } else {
      if (x.transform is UploadedCropTransform) {
        state.cropUploaded(x.value, userVersion: state.paintedUserVersion + 1);
        // Reset the "busy state" to trigger e.g. PhotoView rebuilds after resizing
        if (busy != null)
          getUploadedState().then((ui.Image x) {
            busy.reset();
          });
      } else {
        updateUploadedStateMethod();
      }
    }
  }

  void _updateDownloadedState(int newVersion, DownloadedStateTransform tf) {
    if (busy != null) busy.setBusy('Processing');
    state.transformDownloaded(tf,
        userVersion: newVersion, done: _updatedDownloadedState);
  }

  void _updatedDownloadedState() {
    if (busy != null) busy.reset();
  }

  void _updatedUploadedState(ImageInfo image, bool synchronousCall) {
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
      _updateState();
    }
  }

  void updateUploadedStateRepaint() {
    int newVersion = _findTransduceUploadedVersion();
    state.paintUploaded(
      userVersion: newVersion,
      painter: _PhotographTransducerDeltaPainter(
        this,
        endVersion: newVersion,
      ),
    );
  }

  void updateUploadedStatePaintDelta() {
    int startVersion = state.paintedUserVersion;
    int newVersion = _findTransduceUploadedVersion(startVersion: startVersion);
    assert(newVersion > startVersion);
    state.paintUploaded(
      userVersion: newVersion,
      painter: _PhotographTransducerDeltaPainter(
        this,
        startingImage: state.uploaded,
        startVersion: startVersion,
        endVersion: newVersion,
      ),
    );
  }
}

class _PhotographTransducerDeltaPainter extends CustomPainter {
  PhotographTransducer transducer;
  int startVersion, endVersion;
  ui.Image startingImage;

  _PhotographTransducerDeltaPainter(this.transducer,
      {this.startVersion = 0, this.endVersion, this.startingImage});

  @override
  bool shouldRepaint(_PhotographTransducerDeltaPainter oldDelegate) => true;

  void paint(Canvas canvas, Size size) {
    if (startingImage != null)
      canvas.drawImage(startingImage, Offset(0, 0), Paint());

    int version = transducer._transduceUploaded(
      canvas,
      size,
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
