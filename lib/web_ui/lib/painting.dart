// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// For documentation see https://github.com/flutter/engine/blob/main/lib/ui/painting.dart
part of ui;

void _validateColorStops(List<Color> colors, List<double>? colorStops) {
  if (colorStops == null) {
    if (colors.length != 2) {
      throw ArgumentError('"colors" must have length 2 if "colorStops" is omitted.');
    }
  } else {
    if (colors.length != colorStops.length) {
      throw ArgumentError('"colors" and "colorStops" arguments must have equal length.');
    }
  }
}

Color _scaleAlpha(Color a, double factor) {
  return a.withAlpha(engine.clampInt((a.alpha * factor).round(), 0, 255));
}

class Color {
  const Color(int value)
      : _value = value & 0xFFFFFFFF,
        colorSpace = ColorSpace.sRGB,
        _a = null,
        _r = null,
        _g = null,
        _b = null;

  const Color.from(
      {required double alpha,
      required double red,
      required double green,
      required double blue,
      this.colorSpace = ColorSpace.sRGB})
      : _value = 0,
        _a = alpha,
        _r = red,
        _g = green,
        _b = blue;

  const Color.fromARGB(int a, int r, int g, int b)
      : _value = (((a & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF,
        colorSpace = ColorSpace.sRGB,
        _a = null,
        _r = null,
        _g = null,
        _b = null;

  const Color._fromARGBC(
      int alpha, int red, int green, int blue, this.colorSpace)
      : _value = (((alpha & 0xff) << 24) |
                ((red & 0xff) << 16) |
                ((green & 0xff) << 8) |
                ((blue & 0xff) << 0)) &
            0xFFFFFFFF,
        _a = null,
        _r = null,
        _g = null,
        _b = null;

  const Color.fromRGBO(int r, int g, int b, double opacity)
      : _value = ((((opacity * 0xff ~/ 1) & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF,
        colorSpace = ColorSpace.sRGB,
        _a = null,
        _r = null,
        _g = null,
        _b = null;

  double get a => _a ?? (alpha / 255);
  final double? _a;

  double get r => _r ?? (red / 255);
  final double? _r;

  double get g => _g ?? (green / 255);
  final double? _g;

  double get b => _b ?? (blue / 255);
  final double? _b;

  final ColorSpace colorSpace;

  static int _floatToInt8(double x) {
    return ((x * 255.0).round()) & 0xff;
  }

  int get value {
    if (_a != null && _r != null && _g != null && _b != null) {
      return _floatToInt8(_a) << 24 |
          _floatToInt8(_r) << 16 |
          _floatToInt8(_g) << 8 |
          _floatToInt8(_b) << 0;
    } else {
      return _value;
    }
  }
  final int _value;

  int get alpha => (0xff000000 & value) >> 24;

  double get opacity => alpha / 0xFF;

  int get red => (0x00ff0000 & value) >> 16;

  int get green => (0x0000ff00 & value) >> 8;

  int get blue => (0x000000ff & value) >> 0;

  Color withValues(
      {double? alpha,
      double? red,
      double? green,
      double? blue,
      ColorSpace? colorSpace}) {
    Color? updatedComponents;
    if (alpha != null || red != null || green != null || blue != null) {
      updatedComponents = Color.from(
          alpha: alpha ?? a,
          red: red ?? r,
          green: green ?? g,
          blue: blue ?? b,
          colorSpace: this.colorSpace);
    }
    if (colorSpace != null && colorSpace != this.colorSpace) {
      final _ColorTransform transform =
          _getColorTransform(this.colorSpace, colorSpace);
      return transform.transform(updatedComponents ?? this, colorSpace);
    } else {
      return updatedComponents ?? this;
    }
  }

  Color withAlpha(int a) {
    return Color.fromARGB(a, red, green, blue);
  }

  Color withOpacity(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withAlpha((255.0 * opacity).round());
  }

  Color withRed(int r) {
    return Color.fromARGB(alpha, r, green, blue);
  }

  Color withGreen(int g) {
    return Color.fromARGB(alpha, red, g, blue);
  }

  Color withBlue(int b) {
    return Color.fromARGB(alpha, red, green, b);
  }

  // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return math.pow((component + 0.055) / 1.055, 2.4) as double;
  }

  double computeLuminance() {
    // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
    final double R = _linearizeColorComponent(red / 0xFF);
    final double G = _linearizeColorComponent(green / 0xFF);
    final double B = _linearizeColorComponent(blue / 0xFF);
    return 0.2126 * R + 0.7152 * G + 0.0722 * B;
  }

  static Color? lerp(Color? a, Color? b, double t) {
    assert(a?.colorSpace != ColorSpace.extendedSRGB);
    assert(b?.colorSpace != ColorSpace.extendedSRGB);
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return _scaleAlpha(a, 1.0 - t);
      }
    } else {
      if (a == null) {
        return _scaleAlpha(b, t);
      } else {
        assert(a.colorSpace == b.colorSpace);
        return Color._fromARGBC(
          engine.clampInt(_lerpInt(a.alpha, b.alpha, t).toInt(), 0, 255),
          engine.clampInt(_lerpInt(a.red, b.red, t).toInt(), 0, 255),
          engine.clampInt(_lerpInt(a.green, b.green, t).toInt(), 0, 255),
          engine.clampInt(_lerpInt(a.blue, b.blue, t).toInt(), 0, 255),
          a.colorSpace,
        );
      }
    }
  }

  static Color alphaBlend(Color foreground, Color background) {
    assert(foreground.colorSpace == background.colorSpace);
    assert(foreground.colorSpace != ColorSpace.extendedSRGB);
    final int alpha = foreground.alpha;
    if (alpha == 0x00) {
      return background;
    }
    final int invAlpha = 0xff - alpha;
    int backAlpha = background.alpha;
    if (backAlpha == 0xff) {
      return Color._fromARGBC(
        0xff,
        (alpha * foreground.red + invAlpha * background.red) ~/ 0xff,
        (alpha * foreground.green + invAlpha * background.green) ~/ 0xff,
        (alpha * foreground.blue + invAlpha * background.blue) ~/ 0xff,
        foreground.colorSpace,
      );
    } else {
      backAlpha = (backAlpha * invAlpha) ~/ 0xff;
      final int outAlpha = alpha + backAlpha;
      assert(outAlpha != 0x00);
      return Color._fromARGBC(
        outAlpha,
        (foreground.red * alpha + background.red * backAlpha) ~/ outAlpha,
        (foreground.green * alpha + background.green * backAlpha) ~/ outAlpha,
        (foreground.blue * alpha + background.blue * backAlpha) ~/ outAlpha,
        foreground.colorSpace,
      );
    }
  }

  static int getAlphaFromOpacity(double opacity) {
    return (clampDouble(opacity, 0.0, 1.0) * 255).round();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is Color &&
        other.value == value &&
        other.colorSpace == colorSpace;
  }

  @override
  int get hashCode => Object.hash(value, colorSpace);

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}

enum StrokeCap {
  butt,
  round,
  square,
}

// These enum values must be kept in sync with SkPaint::Join.
enum StrokeJoin {
  miter,
  round,
  bevel,
}

enum PaintingStyle {
  fill,
  stroke,
}

enum BlendMode {
  // This list comes from Skia's SkXfermode.h and the values (order) should be
  // kept in sync.
  // See: https://skia.org/user/api/skpaint#SkXfermode
  clear,
  src,
  dst,
  srcOver,
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcATop,
  dstATop,
  xor,
  plus,
  modulate,

  // Following blend modes are defined in the CSS Compositing standard.
  screen, // The last coeff mode.
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  multiply, // The last separable mode.
  hue,
  saturation,
  color,
  luminosity,
}

enum Clip {
  none,
  hardEdge,
  antiAlias,
  antiAliasWithSaveLayer,
}

abstract class Paint {
  factory Paint() => engine.renderer.createPaint();

  factory Paint.from(Paint other) {
    // This is less efficient than copying the underlying buffer or object but
    // it's a reasonable default, as if a user wanted to implement a copy of a
    // paint object themselves they are unable to do much better than this.
    //
    // TODO(matanlurey): Web team, if important to optimize, could:
    // 1. Add a `engine.renderer.copyPaint` method.
    // 2. Use the below code as the default implementation.
    // 3. Have renderer-specific implementations override with optimized code.
    final Paint paint = Paint();
    paint
      ..blendMode = other.blendMode
      ..color = other.color
      ..colorFilter = other.colorFilter
      ..filterQuality = other.filterQuality
      ..imageFilter = other.imageFilter
      ..invertColors = other.invertColors
      ..isAntiAlias = other.isAntiAlias
      ..maskFilter = other.maskFilter
      ..shader = other.shader
      ..strokeCap = other.strokeCap
      ..strokeJoin = other.strokeJoin
      ..strokeMiterLimit = other.strokeMiterLimit
      ..strokeWidth = other.strokeWidth
      ..style = other.style;
    return paint;
  }

  BlendMode get blendMode;
  set blendMode(BlendMode value);
  PaintingStyle get style;
  set style(PaintingStyle value);
  double get strokeWidth;
  set strokeWidth(double value);
  StrokeCap get strokeCap;
  set strokeCap(StrokeCap value);
  StrokeJoin get strokeJoin;
  set strokeJoin(StrokeJoin value);
  bool get isAntiAlias;
  set isAntiAlias(bool value);

  Color get color;
  set color(Color value);
  bool get invertColors;

  set invertColors(bool value);
  Shader? get shader;
  set shader(Shader? value);
  MaskFilter? get maskFilter;
  set maskFilter(MaskFilter? value);
  // TODO(ianh): verify that the image drawing methods actually respect this
  FilterQuality get filterQuality;
  set filterQuality(FilterQuality value);
  ColorFilter? get colorFilter;
  set colorFilter(ColorFilter? value);

  double get strokeMiterLimit;
  set strokeMiterLimit(double value);
  ImageFilter? get imageFilter;
  set imageFilter(ImageFilter? value);
}

abstract class Shader {
  Shader._();

  void dispose();

  bool get debugDisposed;
}

abstract class Gradient implements Shader {
  factory Gradient.linear(
    Offset from,
    Offset to,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    Float64List? matrix4,
  ]) {
    final Float32List? matrix = matrix4 == null ? null : engine.toMatrix32(matrix4);
    return engine.renderer.createLinearGradient(
      from,
      to,
      colors,
      colorStops,
      tileMode,
      matrix);
  }

  factory Gradient.radial(
    Offset center,
    double radius,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    Float64List? matrix4,
    Offset? focal,
    double focalRadius = 0.0,
  ]) {
    _validateColorStops(colors, colorStops);
    // If focal is null or focal radius is null, this should be treated as a regular radial gradient
    // If focal == center and the focal radius is 0.0, it's still a regular radial gradient
    final Float32List? matrix32 = matrix4 != null ? engine.toMatrix32(matrix4) : null;
    if (focal == null || (focal == center && focalRadius == 0.0)) {
      return engine.renderer.createRadialGradient(
        center, radius, colors, colorStops, tileMode, matrix32);
    } else {
      assert(center != Offset.zero ||
          focal != Offset.zero); // will result in exception(s) in Skia side
      return engine.renderer.createConicalGradient(
        focal, focalRadius, center, radius, colors, colorStops, tileMode, matrix32);
    }
  }
  factory Gradient.sweep(
    Offset center,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    double startAngle = 0.0,
    double endAngle = math.pi * 2,
    Float64List? matrix4,
  ]) => engine.renderer.createSweepGradient(
    center,
    colors,
    colorStops,
    tileMode,
    startAngle,
    endAngle,
    matrix4 != null ? engine.toMatrix32(matrix4) : null);
}

typedef ImageEventCallback = void Function(Image image);

abstract class Image {
  static ImageEventCallback? onCreate;
  static ImageEventCallback? onDispose;

  int get width;
  int get height;
  Future<ByteData?> toByteData({ImageByteFormat format = ImageByteFormat.rawRgba});
  void dispose();
  bool get debugDisposed;

  Image clone() => this;

  bool isCloneOf(Image other) => other == this;

  List<StackTrace>? debugGetOpenHandleStackTraces() => null;

  ColorSpace get colorSpace => ColorSpace.sRGB;

  @override
  String toString() => '[$width\u00D7$height]';
}

class ColorFilter implements ImageFilter {
  const factory ColorFilter.mode(Color color, BlendMode blendMode) = engine.EngineColorFilter.mode;
  const factory ColorFilter.matrix(List<double> matrix) = engine.EngineColorFilter.matrix;
  const factory ColorFilter.linearToSrgbGamma() = engine.EngineColorFilter.linearToSrgbGamma;
  const factory ColorFilter.srgbToLinearGamma() = engine.EngineColorFilter.srgbToLinearGamma;
}

// These enum values must be kept in sync with SkBlurStyle.
enum BlurStyle {
  // These mirror SkBlurStyle and must be kept in sync.
  normal,
  solid,
  outer,
  inner,
}

class MaskFilter {
  const MaskFilter.blur(
    this._style,
    this._sigma,
  );

  final BlurStyle _style;
  final double _sigma;
  double get webOnlySigma => _sigma;
  BlurStyle get webOnlyBlurStyle => _style;

  @override
  bool operator ==(Object other) {
    return other is MaskFilter
        && other._style == _style
        && other._sigma == _sigma;
  }

  @override
  int get hashCode => Object.hash(_style, _sigma);

  @override
  String toString() => 'MaskFilter.blur($_style, ${_sigma.toStringAsFixed(1)})';
}

abstract class _ColorTransform {
  Color transform(Color color, ColorSpace resultColorSpace);
}

class _IdentityColorTransform implements _ColorTransform {
  const _IdentityColorTransform();
  @override
  Color transform(Color color, ColorSpace resultColorSpace) => color;
}

class _ClampTransform implements _ColorTransform {
  const _ClampTransform(this.child);
  final _ColorTransform child;
  @override
  Color transform(Color color, ColorSpace resultColorSpace) {
    return Color.from(
      alpha: clampDouble(color.a, 0, 1),
      red: clampDouble(color.r, 0, 1),
      green: clampDouble(color.g, 0, 1),
      blue: clampDouble(color.b, 0, 1),
      colorSpace: resultColorSpace);
  }
}

class _MatrixColorTransform implements _ColorTransform {
  const _MatrixColorTransform(this.values);

  final List<double> values;

  @override
  Color transform(Color color, ColorSpace resultColorSpace) {
    return Color.from(
        alpha: color.a,
        red: values[0] * color.r +
            values[1] * color.g +
            values[2] * color.b +
            values[3],
        green: values[4] * color.r +
            values[5] * color.g +
            values[6] * color.b +
            values[7],
        blue: values[8] * color.r +
            values[9] * color.g +
            values[10] * color.b +
            values[11],
        colorSpace: resultColorSpace);
  }
}

_ColorTransform _getColorTransform(ColorSpace source, ColorSpace destination) {
  const _MatrixColorTransform srgbToP3 = _MatrixColorTransform(<double>[
    0.808052267214446, 0.220292047628890, -0.139648846160100,
    0.145738111193222, //
    0.096480880462996, 0.916386732581291, -0.086093928394828,
    0.089490172325882, //
    -0.127099563510240, -0.068983484963878, 0.735426667591299, 0.233655661600230
  ]);
  const _ColorTransform p3ToSrgb = _MatrixColorTransform(<double>[
    1.306671048092539, -0.298061942172353, 0.213228303487995,
    -0.213580156254466, //
    -0.117390025596251, 1.127722006101976, 0.109727644608938,
    -0.109450321455370, //
    0.214813187718391, 0.054268702864647, 1.406898424029350, -0.364892765879631
  ]);
  switch (source) {
    case ColorSpace.sRGB:
      switch (destination) {
        case ColorSpace.sRGB:
          return const _IdentityColorTransform();
        case ColorSpace.extendedSRGB:
          return const _IdentityColorTransform();
        case ColorSpace.displayP3:
          return srgbToP3;
      }
    case ColorSpace.extendedSRGB:
      switch (destination) {
        case ColorSpace.sRGB:
          return const _ClampTransform(_IdentityColorTransform());
        case ColorSpace.extendedSRGB:
          return const _IdentityColorTransform();
        case ColorSpace.displayP3:
          return const _ClampTransform(srgbToP3);
      }
    case ColorSpace.displayP3:
      switch (destination) {
        case ColorSpace.sRGB:
          return const _ClampTransform(p3ToSrgb);
        case ColorSpace.extendedSRGB:
          return p3ToSrgb;
        case ColorSpace.displayP3:
          return const _IdentityColorTransform();
      }
  }
}

// This needs to be kept in sync with the "_FilterQuality" enum in skwasm's canvas.cpp
enum FilterQuality {
  none,
  low,
  medium,
  high,
}

class ImageFilter {
  factory ImageFilter.blur({
    double sigmaX = 0.0,
    double sigmaY = 0.0,
    TileMode tileMode = TileMode.clamp
  }) => engine.renderer.createBlurImageFilter(
    sigmaX: sigmaX,
    sigmaY: sigmaY,
    tileMode: tileMode
  );

  factory ImageFilter.dilate({ double radiusX = 0.0, double radiusY = 0.0 }) =>
    engine.renderer.createDilateImageFilter(radiusX: radiusX, radiusY: radiusY);

  factory ImageFilter.erode({ double radiusX = 0.0, double radiusY = 0.0 }) =>
    engine.renderer.createErodeImageFilter(radiusX: radiusX, radiusY: radiusY);

  factory ImageFilter.matrix(Float64List matrix4, {FilterQuality filterQuality = FilterQuality.medium}) {
    if (matrix4.length != 16) {
      throw ArgumentError('"matrix4" must have 16 entries.');
    }
    return engine.renderer.createMatrixImageFilter(matrix4, filterQuality: filterQuality);
  }

  factory ImageFilter.compose({required ImageFilter outer, required ImageFilter inner}) =>
    engine.renderer.composeImageFilters(outer: outer, inner: inner);
}

enum ColorSpace {
  sRGB,
  extendedSRGB,
  displayP3,
}

// This must be kept in sync with the `ImageByteFormat` enum in Skwasm's surface.cpp.
enum ImageByteFormat {
  rawRgba,
  rawStraightRgba,
  rawUnmodified,
  png,
}

// This must be kept in sync with the `PixelFormat` enum in Skwasm's image.cpp.
enum PixelFormat {
  rgba8888,
  bgra8888,
  rgbaFloat32,
}

typedef ImageDecoderCallback = void Function(Image result);

abstract class FrameInfo {
  FrameInfo._();
  Duration get duration => Duration(milliseconds: _durationMillis);
  int get _durationMillis => 0;
  Image get image;
}

class Codec {
  Codec._();
  int get frameCount => 0;
  int get repetitionCount => 0;
  Future<FrameInfo> getNextFrame() {
    return engine.futurize<FrameInfo>(_getNextFrame);
  }

  String? _getNextFrame(engine.Callback<FrameInfo> callback) => null;
  void dispose() {}
}

Future<Codec> instantiateImageCodec(
  Uint8List list, {
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) => engine.renderer.instantiateImageCodec(
  list,
  targetWidth: targetWidth,
  targetHeight: targetHeight,
  allowUpscaling: allowUpscaling);

Future<Codec> instantiateImageCodecFromBuffer(
  ImmutableBuffer buffer, {
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) => engine.renderer.instantiateImageCodec(
  buffer._list!,
  targetWidth: targetWidth,
  targetHeight: targetHeight,
  allowUpscaling: allowUpscaling);

Future<Codec> instantiateImageCodecWithSize(
  ImmutableBuffer buffer, {
  TargetImageSizeCallback? getTargetSize,
}) async {
  if (getTargetSize == null) {
    return engine.renderer.instantiateImageCodec(buffer._list!);
  } else {
    final Codec codec = await engine.renderer.instantiateImageCodec(buffer._list!);
    try {
      final FrameInfo info = await codec.getNextFrame();
      try {
        final int width = info.image.width;
        final int height = info.image.height;
        final TargetImageSize targetSize = getTargetSize(width, height);
        return engine.renderer.instantiateImageCodec(buffer._list!,
            targetWidth: targetSize.width, targetHeight: targetSize.height, allowUpscaling: false);
      } finally {
        info.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

typedef TargetImageSizeCallback = TargetImageSize Function(int intrinsicWidth, int intrinsicHeight);

class TargetImageSize {
  const TargetImageSize({this.width, this.height})
      : assert(width == null || width > 0),
        assert(height == null || height > 0);

  final int? width;
  final int? height;
}

// TODO(mdebbar): Deprecate this and remove it.
// https://github.com/flutter/flutter/issues/127395
Future<Codec> webOnlyInstantiateImageCodecFromUrl(
  Uri uri, {
  ui_web.ImageCodecChunkCallback? chunkCallback,
}) {
  assert(() {
    engine.printWarning(
      'The webOnlyInstantiateImageCodecFromUrl API is deprecated and will be '
      'removed in a future release. Please use `createImageCodecFromUrl` from '
      '`dart:ui_web` instead.',
    );
    return true;
  }());
  return ui_web.createImageCodecFromUrl(uri, chunkCallback: chunkCallback);
}

void decodeImageFromList(Uint8List list, ImageDecoderCallback callback) {
  _decodeImageFromListAsync(list, callback);
}

Future<void> _decodeImageFromListAsync(Uint8List list, ImageDecoderCallback callback) async {
  final Codec codec = await instantiateImageCodec(list);
  final FrameInfo frameInfo = await codec.getNextFrame();
  callback(frameInfo.image);
}

// Encodes the input pixels into a BMP file that supports transparency.
//
// The `pixels` should be the scanlined raw pixels, 4 bytes per pixel, from left
// to right, then from top to down. The order of the 4 bytes of pixels is
// decided by `format`.
Future<Codec> createBmp(
  Uint8List pixels,
  int width,
  int height,
  int rowBytes,
  PixelFormat format,
) {
  late bool swapRedBlue;
  switch (format) {
    case PixelFormat.bgra8888:
      swapRedBlue = true;
    case PixelFormat.rgba8888:
      swapRedBlue = false;
    case PixelFormat.rgbaFloat32:
      throw UnimplementedError('RGB conversion from rgbaFloat32 data is not implemented');
  }

  // See https://en.wikipedia.org/wiki/BMP_file_format for format examples.
  // The header is in the 108-byte BITMAPV4HEADER format, or as called by
  // Chromium, WindowsV4. Do not use the 56-byte or 52-byte Adobe formats, since
  // they're not supported.
  const int dibSize = 0x6C /* 108: BITMAPV4HEADER */;
  const int headerSize = dibSize + 0x0E;
  final int bufferSize = headerSize + (width * height * 4);
  final ByteData bmpData = ByteData(bufferSize);
  // 'BM' header
  bmpData.setUint16(0x00, 0x424D);
  // Size of data
  bmpData.setUint32(0x02, bufferSize, Endian.little);
  // Offset where pixel array begins
  bmpData.setUint32(0x0A, headerSize, Endian.little);
  // Bytes in DIB header
  bmpData.setUint32(0x0E, dibSize, Endian.little);
  // Width
  bmpData.setUint32(0x12, width, Endian.little);
  // Height
  bmpData.setUint32(0x16, height, Endian.little);
  // Color panes (always 1)
  bmpData.setUint16(0x1A, 0x01, Endian.little);
  // bpp: 32
  bmpData.setUint16(0x1C, 32, Endian.little);
  // Compression method is BITFIELDS to enable bit fields
  bmpData.setUint32(0x1E, 3, Endian.little);
  // Raw bitmap data size
  bmpData.setUint32(0x22, width * height, Endian.little);
  // Print DPI width
  bmpData.setUint32(0x26, width, Endian.little);
  // Print DPI height
  bmpData.setUint32(0x2A, height, Endian.little);
  // Colors in the palette
  bmpData.setUint32(0x2E, 0x00, Endian.little);
  // Important colors
  bmpData.setUint32(0x32, 0x00, Endian.little);
  // Bitmask R
  bmpData.setUint32(0x36, swapRedBlue ? 0x00FF0000 : 0x000000FF, Endian.little);
  // Bitmask G
  bmpData.setUint32(0x3A, 0x0000FF00, Endian.little);
  // Bitmask B
  bmpData.setUint32(0x3E, swapRedBlue ? 0x000000FF : 0x00FF0000, Endian.little);
  // Bitmask A
  bmpData.setUint32(0x42, 0xFF000000, Endian.little);

  int destinationByte = headerSize;
  final Uint32List combinedPixels = Uint32List.sublistView(pixels);
  // BMP is scanlined from bottom to top. Rearrange here.
  for (int rowCount = height - 1; rowCount >= 0; rowCount -= 1) {
    int sourcePixel = rowCount * rowBytes;
    for (int colCount = 0; colCount < width; colCount += 1) {
      bmpData.setUint32(destinationByte, combinedPixels[sourcePixel], Endian.little);
      destinationByte += 4;
      sourcePixel += 1;
    }
  }

  return instantiateImageCodec(
    bmpData.buffer.asUint8List(),
  );
}

void decodeImageFromPixels(
  Uint8List pixels,
  int width,
  int height,
  PixelFormat format,
  ImageDecoderCallback callback, {
  int? rowBytes,
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) => engine.renderer.decodeImageFromPixels(
  pixels,
  width,
  height,
  format,
  callback,
  rowBytes: rowBytes,
  targetWidth: targetWidth,
  targetHeight: targetHeight,
  allowUpscaling: allowUpscaling);

class Shadow {
  const Shadow({
    this.color = const Color(_kColorDefault),
    this.offset = Offset.zero,
    this.blurRadius = 0.0,
  })  : assert(blurRadius >= 0.0, 'Text shadow blur radius should be non-negative.');

  static const int _kColorDefault = 0xFF000000;
  final Color color;
  final Offset offset;
  final double blurRadius;
  // See SkBlurMask::ConvertRadiusToSigma().
  // <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
  static double convertRadiusToSigma(double radius) {
    return radius > 0 ? radius * 0.57735 + 0.5 : 0;
  }

  double get blurSigma => convertRadiusToSigma(blurRadius);
  Paint toPaint() {
    return Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
  }

  Shadow scale(double factor) {
    return Shadow(
      color: color,
      offset: offset * factor,
      blurRadius: blurRadius * factor,
    );
  }

  static Shadow? lerp(Shadow? a, Shadow? b, double t) {
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a.scale(1.0 - t);
      }
    } else {
      if (a == null) {
        return b.scale(t);
      } else {
        return Shadow(
          color: Color.lerp(a.color, b.color, t)!,
          offset: Offset.lerp(a.offset, b.offset, t)!,
          blurRadius: _lerpDouble(a.blurRadius, b.blurRadius, t),
        );
      }
    }
  }

  static List<Shadow>? lerpList(List<Shadow>? a, List<Shadow>? b, double t) {
    if (a == null && b == null) {
      return null;
    }
    a ??= <Shadow>[];
    b ??= <Shadow>[];
    final List<Shadow> result = <Shadow>[];
    final int commonLength = math.min(a.length, b.length);
    for (int i = 0; i < commonLength; i += 1) {
      result.add(Shadow.lerp(a[i], b[i], t)!);
    }
    for (int i = commonLength; i < a.length; i += 1) {
      result.add(a[i].scale(1.0 - t));
    }
    for (int i = commonLength; i < b.length; i += 1) {
      result.add(b[i].scale(t));
    }
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Shadow &&
        other.color == color &&
        other.offset == offset &&
        other.blurRadius == blurRadius;
  }

  @override
  int get hashCode => Object.hash(color, offset, blurRadius);

  @override
  String toString() => 'TextShadow($color, $offset, $blurRadius)';
}

abstract class ImageShader implements Shader {
  factory ImageShader(
    Image image,
    TileMode tmx,
    TileMode tmy,
    Float64List matrix4, {
    FilterQuality? filterQuality,
  }) => engine.renderer.createImageShader(
    image,
    tmx,
    tmy,
    matrix4,
    filterQuality
  );

  @override
  void dispose();

  @override
  bool get debugDisposed;
}

class ImmutableBuffer {
  ImmutableBuffer._(this._length);
  static Future<ImmutableBuffer> fromUint8List(Uint8List list) async {
    final ImmutableBuffer instance = ImmutableBuffer._(list.length);
    instance._list = list;
    return instance;
  }

  static Future<ImmutableBuffer> fromAsset(String assetKey) async {
    throw UnsupportedError('ImmutableBuffer.fromAsset is not supported on the web.');
  }

  static Future<ImmutableBuffer> fromFilePath(String path) async {
    throw UnsupportedError('ImmutableBuffer.fromFilePath is not supported on the web.');
  }

  Uint8List? _list;

  int get length => _length;
  final int _length;

  bool get debugDisposed {
    late bool disposed;
    assert(() {
      disposed = _list == null;
      return true;
    }());
    return disposed;
  }
  void dispose() => _list = null;
}

class ImageDescriptor {
  // Not async because there's no expensive work to do here.
  ImageDescriptor.raw(
    ImmutableBuffer buffer, {
    required int width,
    required int height,
    int? rowBytes,
    required PixelFormat pixelFormat,
  })   : _width = width,
        _height = height,
        _rowBytes = rowBytes,
        _format = pixelFormat {
    _data = buffer._list;
  }

  ImageDescriptor._()
      : _width = null,
        _height = null,
        _rowBytes = null,
        _format = null;

  static Future<ImageDescriptor> encoded(ImmutableBuffer buffer) async {
    final ImageDescriptor descriptor = ImageDescriptor._();
    descriptor._data = buffer._list;
    return descriptor;
  }

  Uint8List? _data;
  final int? _width;
  final int? _height;
  final int? _rowBytes;
  final PixelFormat? _format;

  Never _throw(String parameter) {
    throw UnsupportedError('ImageDescriptor.$parameter is not supported on web.');
  }

  int get width => _width ?? _throw('width');
  int get height => _height ?? _throw('height');
  int get bytesPerPixel =>
      throw UnsupportedError('ImageDescriptor.bytesPerPixel is not supported on web.');
  void dispose() => _data = null;
  Future<Codec> instantiateCodec({int? targetWidth, int? targetHeight}) async {
    if (_data == null) {
      throw StateError('Object is disposed');
    }
    if (_width == null) {
      return instantiateImageCodec(
        _data!,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        allowUpscaling: false,
      );
    }

    return createBmp(_data!, width, height, _rowBytes ?? width, _format!);
  }
}

abstract class FragmentProgram {
  static Future<FragmentProgram> fromAsset(String assetKey) {
    return engine.renderer.createFragmentProgram(assetKey);
  }

  FragmentShader fragmentShader();
}

abstract class FragmentShader implements Shader {
  void setFloat(int index, double value);

  void setImageSampler(int index, Image image);

  @override
  void dispose();

  @override
  bool get debugDisposed;
}
