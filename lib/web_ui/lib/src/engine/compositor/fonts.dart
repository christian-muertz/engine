// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of engine;

// This URL was found by using the Google Fonts Developer API to find the URL
// for Roboto. The API warns that this URL is not stable. In order to update
// this, list out all of the fonts and find the URL for the regular
// Roboto font. The API reference is here:
// https://developers.google.com/fonts/docs/developer_api
const String _robotoUrl =
    'https://fonts.gstatic.com/s/roboto/v20/KFOmCnqEu92Fr1Me5WZLCzYlKw.ttf';

/// Manages the fonts used in the Skia-based backend.
class SkiaFontCollection {
  final List<Future<ByteBuffer>> _loadingFontBuffers = <Future<ByteBuffer>>[];
  final List<Uint8List> _dynamicallyLoadedFonts = <Uint8List>[];

  final Set<String> registeredFamilies = <String>{};

  Future<void> ensureFontsLoaded() async {
    final List<Uint8List> fontBuffers =
        (await Future.wait<ByteBuffer>(_loadingFontBuffers))
            .map((ByteBuffer buffer) => buffer.asUint8List())
            .toList();
    fontBuffers.addAll(_dynamicallyLoadedFonts);
    skFontMgr = canvasKit['SkFontMgr'].callMethod('FromData', fontBuffers);
  }

  Future<void> loadFontFromList(Uint8List list, {String fontFamily}) async {
    _dynamicallyLoadedFonts.add(list);
    if (fontFamily != null) {
      registeredFamilies.add(fontFamily);
    }
    await ensureFontsLoaded();
  }

  Future<void> registerFonts(AssetManager assetManager) async {
    ByteData byteData;

    try {
      byteData = await assetManager.load('FontManifest.json');
    } on AssetManagerException catch (e) {
      if (e.httpStatus == 404) {
        html.window.console
            .warn('Font manifest does not exist at `${e.url}` – ignoring.');
        return;
      } else {
        rethrow;
      }
    }

    if (byteData == null) {
      throw AssertionError(
          'There was a problem trying to load FontManifest.json');
    }

    final List<dynamic> fontManifest =
        json.decode(utf8.decode(byteData.buffer.asUint8List()));
    if (fontManifest == null) {
      throw AssertionError(
          'There was a problem trying to load FontManifest.json');
    }

    for (Map<String, dynamic> fontFamily in fontManifest) {
      final String family = fontFamily['family'];
      final List<dynamic> fontAssets = fontFamily['fonts'];

      registeredFamilies.add(family);

      for (dynamic fontAssetItem in fontAssets) {
        final Map<String, dynamic> fontAsset = fontAssetItem;
        final String asset = fontAsset['asset'];
        _loadingFontBuffers.add(html.window
            .fetch(assetManager.getAssetUrl(asset))
            .then(_getArrayBuffer));
      }
    }

    /// We need a default fallback font for CanvasKit, in order to
    /// avoid crashing while laying out text with an unregistered font. We chose
    /// Roboto to match Android.
    if (!registeredFamilies.contains('Roboto')) {
      // Download Roboto and add it to the font buffers.
      _loadingFontBuffers.add(html.window
          .fetch(_robotoUrl)
          .then(_getArrayBuffer));
    }
  }

  Future<ByteBuffer> _getArrayBuffer(dynamic fetchResult) {
    return fetchResult.arrayBuffer().then<ByteBuffer>((x) => x as ByteBuffer);
  }

  js.JsObject skFontMgr;
}
