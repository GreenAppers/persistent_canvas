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
  ui.Image uploaded;
  img.Image downloaded;
  bool autoUpload = true, autoDownload = false;
  int uploadedVersion = 0, uploadingVersion = 0;
  int downloadedVersion = 0, downloadingVersion = 0;
  int paintedUserVersion = 0, paintingUserVersion = 0;
  int transformedUserVersion = 0, transformingUserVersion = 0;

  PixelBuffer(this.size) {
    paintUploaded();
  }

  PixelBuffer.fromImage(this.uploaded, [this.paintedUserVersion=1]) :
    size = Size(uploaded.width.toDouble(), uploaded.height.toDouble()) {
    setUploadedState((ui.Image x) {});
  }

  PixelBuffer.fromImg(this.downloaded) :
    size = Size(downloaded.width.toDouble(), downloaded.height.toDouble()) {
    setDownloadedState((img.Image x) {});
  }

  void transformDownloaded(ImgFilter tf, {int userVersion=1, VoidCallback done}) {
    assert(transformingUserVersion == 0);
    transformingUserVersion = userVersion;
    if (downloadedVersion >= uploadedVersion) return transformDownloadedState(tf, done);
    downloadUploaded((img.Image x) {
      downloadUploadedComplete(x);
      transformDownloadedState(tf, done);
    });
  }

  void transformDownloadedState(ImgFilter tf, VoidCallback done) async {
    // If we could move Objects between Isolates we would use compute() here
    setDownloadedState((img.Image x){ downloaded = tf(x); });
    transformDownloadedComplete(done);
  }

  void transformDownloadedComplete(VoidCallback done) {
    transformedUserVersion = transformingUserVersion;
    transformingUserVersion = 0;
    done();
  }

  void cropUploaded(Rect src, {Rect dst, Size newSize, int userVersion=1}) {
    assert(paintingUserVersion == 0);
    paintingUserVersion = userVersion;
    if (dst == null) dst = Rect.fromLTWH(0, 0, src.width, src.height);
    size = newSize != null ? newSize : Size(dst.width, dst.height);
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    canvas.drawImageRect(uploaded, src, dst, Paint());
    recorder.endRecording().toImage(size.width.floor(), size.height.floor()).then(paintUploadedComplete);
  }

  void paintUploaded({CustomPainter painter, ui.Image startingImage, int userVersion=1}) {
    assert(paintingUserVersion == 0);
    paintingUserVersion = userVersion;
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    if (startingImage != null) canvas.drawImage(startingImage, Offset(0, 0), Paint());
    if (painter != null) painter.paint(canvas, size);
    recorder.endRecording().toImage(size.width.floor(), size.height.floor()).then(paintUploadedComplete);
  }

  void paintUploadedComplete(ui.Image nextFrame) {
    paintedUserVersion = paintingUserVersion;
    paintingUserVersion = 0;
    setUploadedState((ui.Image x) { uploaded = nextFrame; });
  }

  void setUploadedState(ImageCallback cb) {
    cb(uploaded);
    uploadedVersion++;
    broadcastUploaded();
    if (autoDownload && downloadingVersion == 0) {
      downloadUploaded(downloadUploadedComplete);
    }
  }

  void setDownloadedState(ImgCallback cb) {
    cb(downloaded);
    downloadedVersion++;
    if (autoUpload && uploadingVersion == 0) {
      uploadDownloaded(uploadDownloadedComplete);
    }
  }

  void downloadUploadedComplete(img.Image nextFrame) {
    downloaded = nextFrame;
    downloadedVersion = downloadingVersion;
    downloadingVersion = 0;
    if (autoDownload && uploadedVersion > downloadedVersion) {
      downloadUploaded(downloadUploadedComplete);
    }
  }

  void uploadDownloadedComplete(ui.Image nextFrame) {
    uploaded = nextFrame;
    uploadedVersion = uploadingVersion;
    uploadingVersion = 0;
    broadcastUploaded();
    if (downloadedVersion != uploadedVersion) {
      uploadDownloaded(uploadDownloadedComplete);
    }
  }

  void broadcastUploaded() {
    setImage(ImageInfo(image: uploaded));
  }

  void downloadUploaded(ImgCallback cb) {
    assert(downloadingVersion == 0);
    downloadingVersion = uploadedVersion;
    imgFromImage(uploaded).then(cb);
  }

  void uploadDownloaded(ImageCallback cb) {
    assert(uploadingVersion == 0);
    uploadingVersion = downloadedVersion;
    imageFromImg(downloaded).then(cb);
  }
}

class PixelBufferImageProvider extends ImageProvider<PixelBufferImageProvider> {
  PixelBuffer pixelBuffer;
  PixelBufferImageProvider(this.pixelBuffer);

  @override
  Future<PixelBufferImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<PixelBufferImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(PixelBufferImageProvider key) {
    if (key.pixelBuffer.uploaded != null) key.pixelBuffer.broadcastUploaded();
    return key.pixelBuffer;
  }
}

class PixelBufferPainter extends CustomPainter {
  ui.Image uploadedPixelBuffer;

  PixelBufferPainter(PixelBuffer pb) : uploadedPixelBuffer = pb.uploaded;

  @override
  bool shouldRepaint(PixelBufferPainter oldDelegate) {
    return uploadedPixelBuffer != oldDelegate.uploadedPixelBuffer;
  }

  void paint(Canvas canvas, Size size) {
    if (uploadedPixelBuffer == null) return;
    canvas.drawImage(uploadedPixelBuffer, Offset(0, 0), Paint());
  }
}

Future<ui.Image> imageFromImg(img.Image input) async {
  Completer<ui.Image> completer = Completer(); 
  ui.decodeImageFromPixels(input.getBytes(), input.width, input.height, ui.PixelFormat.rgba8888,
                           (ui.Image result) { completer.complete(result); });
  return completer.future;
}

Future<img.Image> imgFromImage(ui.Image input) async {
  var rgbaBytes = await input.toByteData(format: ui.ImageByteFormat.rawRgba);
  return img.Image.fromBytes(input.width, input.height, rgbaBytes.buffer.asUint8List());
}

img.Image imgFromFloat32List(Float32List image, int inputSize, double mean, double std) {
  img.Image ret = img.Image(inputSize, inputSize);
  var buffer = Float32List.view(image.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      ret.setPixel(j, i, img.getColor(
        (buffer[pixelIndex+0] * std - mean).round(),
        (buffer[pixelIndex+1] * std - mean).round(),
        (buffer[pixelIndex+2] * std - mean).round()));
      pixelIndex += 3;
    }
  }
  return ret;
}

Float32List imgToFloat32List(img.Image image, int inputSize, double mean, double std) {
  var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < inputSize; i++) {
    for (var j = 0; j < inputSize; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = (img.getRed  (pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getGreen(pixel) - mean) / std;
      buffer[pixelIndex++] = (img.getBlue (pixel) - mean) / std;
    }
  }
  return convertedBytes;
}
