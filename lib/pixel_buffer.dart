// Copyright 2019 Green Appers, Inc. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

import 'package:image/image.dart' as img;

typedef ImageCallback = void Function(ui.Image);
typedef ImgCallback = void Function(img.Image);
typedef ImgFilter = img.Image Function(img.Image);

/// The [PixelBuffer] class manages mutation versioning for images represented:
///
/// * In the 'uploaded' state by [ui.Image], which are suitable for rendering.
/// * In the 'downloaded' state by [img.Image], which are accessible to Dart code.
///
class PixelBuffer extends ImageStreamCompleter {
  Size size;
  img.Image downloaded;
  ui.Image uploaded, lastUploaded;
  bool autoUpload = true, autoDownload = false;
  int uploadedVersion = 0, uploadingVersion = 0;
  int downloadedVersion = 0, downloadingVersion = 0;
  int paintedUserVersion = 0, paintingUserVersion = 0;
  int transformedUserVersion = 0, transformingUserVersion = 0;
  int lastUploadedVersion, lastPaintedUserVersion;
  List<ImgCallback> downloadDone = <ImgCallback>[];

  /// Blank [PixelBuffer] in 'uploaded' state
  PixelBuffer(this.size) {
    paintUploaded();
  }

  /// Create [PixelBuffer] in 'uploaded' state
  PixelBuffer.fromImage(this.uploaded, [this.paintedUserVersion = 1])
      : size = Size(uploaded.width.toDouble(), uploaded.height.toDouble()) {
    setUploadedState((ui.Image x) {});
  }

  /// Create [PixelBuffer] in 'downloaded' state
  PixelBuffer.fromImg(this.downloaded)
      : size = Size(downloaded.width.toDouble(), downloaded.height.toDouble()) {
    setDownloadedState((img.Image x) {});
  }

  /// Get the latest [img.Image], "downloading" it if necessary
  Future<img.Image> getDownloadedState() async {
    if (downloadedVersion >= uploadedVersion) return downloaded;
    Completer<img.Image> completer = Completer();
    downloadDone.add((img.Image result) {
      completer.complete(result);
    });
    if (downloadingVersion == 0) _downloadUploaded(_downloadUploadedComplete);
    return completer.future;
  }

  /// Analogous to [State] setState().  Calls _broadcastUploaded() directly
  void setUploadedState(ImageCallback cb) {
    assert(uploadingVersion == 0);
    assert(paintingUserVersion == 0);
    assert(transformingUserVersion == 0);
    assert(uploadedVersion >= downloadedVersion);
    cb(uploaded);
    uploadedVersion++;
    _broadcastUploaded();
    if (autoDownload && downloadingVersion == 0) {
      _downloadUploaded(_downloadUploadedComplete);
    }
  }

  /// Analogous to [State] setState().  Culminates in _broadcastUploaded() when 'autoUpload' == true
  void setDownloadedState(ImgCallback cb) {
    assert(downloadingVersion == 0);
    assert(paintingUserVersion == 0);
    assert(downloadedVersion >= uploadedVersion);
    cb(downloaded);
    downloadedVersion++;
    if (autoUpload && uploadingVersion == 0) {
      _uploadDownloaded(_uploadDownloadedComplete);
    }
  }

  /// Primary method for 'uploaded' state transformations
  void paintUploaded({CustomPainter painter, int userVersion=1, Color backgroundColor}) {
    assert(paintingUserVersion == 0);
    paintingUserVersion = userVersion;
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    if (backgroundColor != null) canvas.drawColor(backgroundColor, BlendMode.src);
    if (painter != null) painter.paint(canvas, size);
    recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor())
        .then(_paintUploadedComplete);
  }

  /// Note: "crop" with arbitrary 'src' and 'dst' [Rect] generalizes scaling
  void cropUploaded(Rect src,
      {Rect dst,
      Size newSize,
      int userVersion = 1,
      Path clipPath,
      ImageCallback done}) {
    assert(paintingUserVersion == 0);
    paintingUserVersion = userVersion;

    dst = dst ?? Rect.fromLTWH(0, 0, src.width, src.height);
    newSize = newSize ?? Size(dst.width, dst.height);
    if (done == null) size = newSize;

    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    if (clipPath != null)
      canvas.clipPath(clipPath.shift(Offset(-src.left, -src.top)));
    canvas.drawImageRect(uploaded, src, dst, Paint());
    recorder
        .endRecording()
        .toImage(newSize.width.floor(), newSize.height.floor())
        .then(done ?? _paintUploadedComplete);
  }

  /// Primary method for 'downloaded' state transformations
  void transformDownloaded(ImgFilter tf,
      {int userVersion = 1, VoidCallback done}) {
    assert(transformingUserVersion == 0);
    transformingUserVersion = userVersion;
    if (downloadedVersion >= uploadedVersion)
      return _transformDownloaded(tf, done);
    _downloadUploaded((img.Image x) {
      _downloadUploadedComplete(x);
      _transformDownloaded(tf, done);
    });
  }

  void _downloadUploaded(ImgCallback cb) {
    assert(downloadingVersion == 0);
    downloadingVersion = uploadedVersion;
    imgFromImage(uploaded).then(cb);
  }

  void _uploadDownloaded(ImageCallback cb) {
    assert(uploadingVersion == 0);
    uploadingVersion = downloadedVersion;
    imageFromImg(downloaded).then(cb);
  }

  void _downloadUploadedComplete(img.Image nextFrame) {
    downloaded = nextFrame;
    downloadedVersion = downloadingVersion;
    downloadingVersion = 0;
    for (int i = 0; i < downloadDone.length; i++) {
      downloadDone[i](downloaded);
    }
    downloadDone.clear();
    if (autoDownload && uploadedVersion > downloadedVersion) {
      _downloadUploaded(_downloadUploadedComplete);
    }
  }

  void _uploadDownloadedComplete(ui.Image nextFrame) {
    _saveLastUploaded();
    uploaded = nextFrame;
    uploadedVersion = uploadingVersion;
    uploadingVersion = 0;
    _broadcastUploaded();
    if (downloadedVersion != uploadedVersion) {
      _uploadDownloaded(_uploadDownloadedComplete);
    }
  }

  void _paintUploadedComplete(ui.Image nextFrame) {
    _saveLastUploaded();
    paintedUserVersion = paintingUserVersion;
    paintingUserVersion = 0;
    setUploadedState((ui.Image x) {
      uploaded = nextFrame;
    });
  }

  /// Remember last 'uploaded' state for e.g. [PhotographTransducer]'s [undo].
  void _saveLastUploaded() {
    lastUploaded = uploaded;
    lastUploadedVersion = uploadedVersion;
    lastPaintedUserVersion = paintedUserVersion;
  }

  void _transformDownloaded(ImgFilter tf, VoidCallback done) async {
    // If we could move Objects between Isolates we would use compute() here
    setDownloadedState((img.Image x) {
      downloaded = tf(x);
    });
    _transformDownloadedComplete(done);
  }

  void _transformDownloadedComplete(VoidCallback done) {
    transformedUserVersion = transformingUserVersion;
    transformingUserVersion = 0;
    done();
  }

  /// Broadcast a new 'uploaded' image via the [ImageStreamCompleter] interface
  void _broadcastUploaded() {
    setImage(ImageInfo(image: uploaded));
  }
}

/// [ImageProvider] for [PixelBuffer]
class PixelBufferImageProvider extends ImageProvider<PixelBufferImageProvider> {
  PixelBuffer pixelBuffer;
  PixelBufferImageProvider(this.pixelBuffer);

  @override
  Future<PixelBufferImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<PixelBufferImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(PixelBufferImageProvider key) {
    if (key.pixelBuffer.uploaded != null) key.pixelBuffer._broadcastUploaded();
    return key.pixelBuffer;
  }
}

/// [CustomPainter] for [PixelBuffer]
class PixelBufferPainter extends CustomPainter {
  ui.Image uploadedPixelBuffer;

  PixelBufferPainter(PixelBuffer pb) : uploadedPixelBuffer = pb.uploaded;
  PixelBufferPainter.fromImage(this.uploadedPixelBuffer);

  @override
  bool shouldRepaint(PixelBufferPainter oldDelegate) {
    return uploadedPixelBuffer != oldDelegate.uploadedPixelBuffer;
  }

  void paint(Canvas canvas, Size size) {
    if (uploadedPixelBuffer == null) return;
    canvas.drawImage(uploadedPixelBuffer, Offset(0, 0), Paint());
  }
}

/// [CustomPainter] that scales [PixelBuffer] to fit [Canvas]
class ScaledPixelBufferPainter extends CustomPainter {
  ui.Image uploadedPixelBuffer;

  ScaledPixelBufferPainter(PixelBuffer pb) : uploadedPixelBuffer = pb.uploaded;
  ScaledPixelBufferPainter.fromImage(this.uploadedPixelBuffer);

  @override
  bool shouldRepaint(ScaledPixelBufferPainter oldDelegate) {
    return uploadedPixelBuffer != oldDelegate.uploadedPixelBuffer;
  }

  void paint(Canvas canvas, Size size) {
    if (uploadedPixelBuffer == null) return;
    Rect src = Rect.fromLTWH(0, 0, uploadedPixelBuffer.width.toDouble(),
        uploadedPixelBuffer.height.toDouble());
    Rect dst =
        Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble());
    canvas.drawImageRect(uploadedPixelBuffer, src, dst, Paint());
  }
}

Future<ui.Image> imageFromImg(img.Image input) async {
  Completer<ui.Image> completer = Completer();
  ui.decodeImageFromPixels(
      input.getBytes(), input.width, input.height, ui.PixelFormat.rgba8888,
      (ui.Image result) {
    completer.complete(result);
  });
  return completer.future;
}

Future<img.Image> imgFromImage(ui.Image input) async {
  var rgbaBytes = await input.toByteData(format: ui.ImageByteFormat.rawRgba);
  return img.Image.fromBytes(
      input.width, input.height, rgbaBytes.buffer.asUint8List());
}

Color colorFromImgColor(int color) {
  return Color.fromARGB(img.getAlpha(color), img.getRed(color),
      img.getGreen(color), img.getBlue(color));
}

int imgColorFromColor(Color color) {
  return img.Color.fromRgba(color.red, color.green, color.blue, color.alpha);
}

img.Image imgFromFloat32List(
    Float32List image, int inputSize, double mean, double std) {
  img.Image ret = img.Image(inputSize, inputSize);
  var buffer = Float32List.view(image.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      ret.setPixel(
          j,
          i,
          img.getColor(
              (buffer[pixelIndex + 0] * std - mean).round(),
              (buffer[pixelIndex + 1] * std - mean).round(),
              (buffer[pixelIndex + 2] * std - mean).round()));
      pixelIndex += 3;
    }
  }
  return ret;
}

Float32List imgToFloat32List(
    img.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (img.getRed(pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getBlue(pixel) - mean) / std;
    }
  }
  return convertedBytes;
}
