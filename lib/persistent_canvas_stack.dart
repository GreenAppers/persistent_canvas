// Copyright 2019 Green Appers, Inc. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:busy_model/busy_model.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:persistent_canvas/persistent_canvas.dart';
import 'package:persistent_canvas/pixel_buffer.dart';
import 'package:persistent_canvas/photograph_transducer.dart';

class PersistentCanvasStack extends Model {
  List<PersistentCanvas> layer;
  int selectedLayerIndex = 0;
  final BusyModel busy;

  PersistentCanvas get canvas => layer[selectedLayerIndex];

  PersistentCanvasStack(
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

  Future<ui.Image> saveImage({Size size, ui.Image originalResolutionInput}) {
    return canvas.saveImage(size: size, originalResolutionInput: originalResolutionInput);
  }

  void selectLayer([int index]) {
    index = index ?? layer.length;
    assert(index >= 0 && index <= layer.length);
    selectedLayerIndex = index;
    notifyListeners();
  }

  PersistentCanvas addLayer([int index]) {
    index = index ?? layer.length;
    assert(index >= 0 && index <= layer.length);
    PersistentCanvas prevLayer = layer[index == 0 ? index : index-1], ret = PersistentCanvas(
      coordinates: prevLayer.coordinates,
      size: prevLayer.size,
      busy: busy,
    );
    layer.insert(index, ret);
    notifyListeners();
    return ret;
  }

  void removeLayer([int index]) {
    index = index ?? layer.length;
    assert(index >= 0 && index <= layer.length);
    layer.removeAt(index);
    notifyListeners();
  }

  void swapLayer(int index1, int index2) {
    assert(index1 != index2);
    assert(index1 >=0 && index1 <= layer.length);
    assert(index2 >=0 && index2 <= layer.length);
    PersistentCanvas swap = layer[index1];
    layer[index1] = layer[index2];
    layer[index2] = swap;
    notifyListeners();
  }

  void mergeLayer(int index1, int index2) {
    assert(index1 != index2);
    assert(index1 >=0 && index1 <= layer.length);
    assert(index2 >=0 && index2 <= layer.length);
    layer[index1].model.addImage(layer[index2].image);
    layer.removeAt(index2);
    notifyListeners();
  }
}

class PersistentCanvasStackWidget extends StatelessWidget {
  final PersistentCanvasStack layers;

  PersistentCanvasStackWidget(this.layers);

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
                  CustomPaint(
                    painter: PixelBufferPainter.fromImage(layer.image)
                  ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: layers.canvas.size.width,
      height: layers.canvas.size.height,
      alignment: Alignment.topLeft,
      color: Colors.white,
      child: Stack(children: stack),
    );
  }
}
