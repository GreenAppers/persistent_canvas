// Copyright 2019 Green Appers, Inc. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:busy_model/busy_model.dart';
import 'package:scoped_model/scoped_model.dart';

import 'package:persistent_canvas/persistent_canvas.dart';
import 'package:persistent_canvas/pixel_buffer.dart';
import 'package:persistent_canvas/photograph_transducer.dart';

class PersistentCanvasStack {
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

  PersistentCanvas addLayer([int index]) {
    PersistentCanvas topLayer = layer.last, ret = PersistentCanvas(
      coordinates: topLayer.coordinates,
      size: topLayer.size,
      busy: busy,
    );
    layer.add(ret);
    busy.reset();
    return ret;
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
      width: layers.canvas.model.state.size.width,
      height: layers.canvas.model.state.size.height,
      alignment: Alignment.topLeft,
      color: Colors.white,
      child: Stack(children: stack),
    );
  }
}
