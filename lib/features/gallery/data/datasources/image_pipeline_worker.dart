import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/entities/photo_filter.dart';
import '../../domain/entities/upscale_failure.dart';

/// Pixel work for the enhance and collage tools, off the main isolate.
///
/// Same boundary as `photo_signature_worker.dart`: no Flutter, no
/// `photo_manager`. Both entry points take **file paths** rather than bytes —
/// `compute` copies its argument into the worker, and copying a 12MP JPEG in
/// only to decode it there wastes the one thing this pipeline is short of.
/// Paths are resolved on the root isolate; `dart:io` reads them here.

// ─────────────────────────── enhance ───────────────────────────

class UpscaleRequest {
  const UpscaleRequest({
    required this.sourcePath,
    required this.targetLongEdge,
    this.quality = 95,
  });

  final String sourcePath;

  /// Long edge of the output in pixels. 3840 is the "4K" preset.
  final int targetLongEdge;

  final int quality;
}

class UpscaleOutcome {
  const UpscaleOutcome({
    this.bytes,
    this.failure,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.outputWidth,
    required this.outputHeight,
  });

  final Uint8List? bytes;
  final UpscaleFailure? failure;
  final int sourceWidth;
  final int sourceHeight;
  final int outputWidth;
  final int outputHeight;

  bool get succeeded => bytes != null;
}

/// Largest source this will attempt, in megapixels.
///
/// A 24MP decode is roughly 96MB as RGBA, and the 4K output is another ~33MB,
/// both live in this isolate at once. Past that, low-end devices do not fail
/// gracefully — they are killed. Refusing with a clear message beats an
/// unexplained crash.
const int kMaxSourceMegapixels = 24;

/// Enlarges and sharpens a photo.
///
/// This is high-quality resampling, not generative super-resolution: it does
/// not invent detail the source never had. The UI says "Enhance" for that
/// reason. If a real super-resolution model is ever added, this function is
/// the only thing that has to change.
UpscaleOutcome upscalePhoto(UpscaleRequest request) {
  final Uint8List raw;
  try {
    raw = File(request.sourcePath).readAsBytesSync();
  } catch (_) {
    return const UpscaleOutcome(
      failure: UpscaleFailure.unreadable,
      sourceWidth: 0,
      sourceHeight: 0,
      outputWidth: 0,
      outputHeight: 0,
    );
  }

  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    return const UpscaleOutcome(
      failure: UpscaleFailure.undecodable,
      sourceWidth: 0,
      sourceHeight: 0,
      outputWidth: 0,
      outputHeight: 0,
    );
  }

  final sourceWidth = decoded.width;
  final sourceHeight = decoded.height;
  final megapixels = (sourceWidth * sourceHeight) / 1000000;
  if (megapixels > kMaxSourceMegapixels) {
    return UpscaleOutcome(
      failure: UpscaleFailure.tooLarge,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      outputWidth: 0,
      outputHeight: 0,
    );
  }

  final longEdge = math.max(sourceWidth, sourceHeight);
  final scale = request.targetLongEdge / longEdge;
  if (scale <= 1.02) {
    return UpscaleOutcome(
      failure: UpscaleFailure.alreadyLarge,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      outputWidth: sourceWidth,
      outputHeight: sourceHeight,
    );
  }

  var working = decoded;

  // Two equal steps rather than one jump whenever the enlargement is more than
  // 2x. A single 4x cubic resample leaves visible halos along high-contrast
  // edges; two √scale steps cost one extra pass and largely avoid them.
  if (scale > 2) {
    final step = math.sqrt(scale);
    working = img.copyResize(
      working,
      width: (sourceWidth * step).round(),
      height: (sourceHeight * step).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  working = img.copyResize(
    working,
    width: (sourceWidth * scale).round(),
    height: (sourceHeight * scale).round(),
    interpolation: img.Interpolation.cubic,
  );

  // Resampling always softens. A mild unsharp pass puts back the edge acuity
  // it cost, blended at less than full strength so noise is not amplified with
  // it.
  working = img.convolution(
    working,
    filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
    div: 1,
    amount: 0.55,
  );

  working = img.adjustColor(working, contrast: 1.04, saturation: 1.03);

  return UpscaleOutcome(
    bytes: img.encodeJpg(working, quality: request.quality),
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    outputWidth: working.width,
    outputHeight: working.height,
  );
}

// ─────────────────────────── collage ───────────────────────────

class CollageRequest {
  const CollageRequest({
    required this.sourcePaths,
    required this.cells,
    required this.canvasWidth,
    required this.canvasHeight,
    this.focusX = const [],
    this.focusY = const [],
    this.zoom = const [],
    this.gapPx = 10,
    this.backgroundRgb = 0xFFFFFF,
    this.quality = 92,
  });

  final List<String> sourcePaths;

  /// Where the user dragged each photo inside its cell, as the centre of the
  /// crop window in source coordinates (0..1), plus how far they zoomed in
  /// (1.0 = the crop that just fills the cell).
  ///
  /// Empty, or a `null`/negative entry, means "not adjusted" — that cell falls
  /// back to [_smartCrop]. Kept as parallel flat lists rather than a list of
  /// objects so the request stays a trivially copyable isolate payload, the
  /// same reason [cells] is flat.
  final List<double> focusX;
  final List<double> focusY;
  final List<double> zoom;

  /// Flattened cell rectangles — left, top, width, height per cell, each 0..1.
  /// Flat doubles rather than objects so the request stays a trivially
  /// copyable payload.
  final List<double> cells;

  final int canvasWidth;
  final int canvasHeight;
  final int gapPx;
  final int backgroundRgb;
  final int quality;
}

/// Renders the collage at full resolution.
///
/// Deliberately not a `RepaintBoundary` capture of the preview widget: that
/// caps output at the device's screen resolution, so six 12MP photos would
/// export at roughly 1080p. The preview is a widget; the file is this.
Uint8List? renderCollage(CollageRequest request) {
  final canvas = img.Image(
    width: request.canvasWidth,
    height: request.canvasHeight,
    numChannels: 3,
  );
  img.fill(
    canvas,
    color: img.ColorRgb8(
      (request.backgroundRgb >> 16) & 0xFF,
      (request.backgroundRgb >> 8) & 0xFF,
      request.backgroundRgb & 0xFF,
    ),
  );

  final half = request.gapPx / 2;
  var drew = false;

  for (var index = 0; index < request.sourcePaths.length; index++) {
    final base = index * 4;
    if (base + 3 >= request.cells.length) break;

    // Cell rectangle in pixels, inset by half the gap on each side so
    // neighbouring cells end up a full gap apart.
    final left = (request.cells[base] * request.canvasWidth + half).round();
    final top = (request.cells[base + 1] * request.canvasHeight + half).round();
    final width =
        (request.cells[base + 2] * request.canvasWidth - request.gapPx).round();
    final height =
        (request.cells[base + 3] * request.canvasHeight - request.gapPx)
            .round();
    if (width <= 0 || height <= 0) continue;

    final source = _decodeFile(request.sourcePaths[index]);
    if (source == null) continue;

    // A cell the user has adjusted uses exactly what they set up; the rest
    // keep the automatic crop. Both produce a `width / height` rectangle, so
    // the compositing below does not care which ran.
    final cropped = _hasAdjustment(request, index)
        ? _focusCrop(
            source,
            width / height,
            request.focusX[index],
            request.focusY[index],
            request.zoom[index],
          )
        : _smartCrop(source, width / height);
    final fitted = img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );

    img.compositeImage(canvas, fitted, dstX: left, dstY: top);
    drew = true;
  }

  if (!drew) return null;
  return img.encodeJpg(canvas, quality: request.quality);
}

bool _hasAdjustment(CollageRequest request, int index) =>
    index < request.focusX.length &&
    index < request.focusY.length &&
    index < request.zoom.length &&
    request.zoom[index] > 0;

/// Crops [source] to [targetAspect] around a point the user chose.
///
/// [focusX]/[focusY] are the centre of the crop window in source coordinates
/// (0..1); [zoom] is 1.0 for the largest window that fits, larger to move in.
/// The window is clamped to the image, so dragging to an edge stops there
/// instead of exposing background — which is what "the photo is cut off"
/// looked like from the other side.
img.Image _focusCrop(
  img.Image source,
  double targetAspect,
  double focusX,
  double focusY,
  double zoom,
) {
  final sourceAspect = source.width / source.height;
  final scale = zoom < 1 ? 1.0 : zoom;

  int cropWidth;
  int cropHeight;
  if (sourceAspect > targetAspect) {
    cropHeight = (source.height / scale).round();
    cropWidth = (cropHeight * targetAspect).round();
  } else {
    cropWidth = (source.width / scale).round();
    cropHeight = (cropWidth / targetAspect).round();
  }
  cropWidth = cropWidth.clamp(1, source.width);
  cropHeight = cropHeight.clamp(1, source.height);

  final left = (focusX * source.width - cropWidth / 2)
      .round()
      .clamp(0, source.width - cropWidth);
  final top = (focusY * source.height - cropHeight / 2)
      .round()
      .clamp(0, source.height - cropHeight);

  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: cropWidth,
    height: cropHeight,
  );
}

img.Image? _decodeFile(String path) {
  try {
    return img.decodeImage(File(path).readAsBytesSync());
  } catch (_) {
    return null;
  }
}

/// Crops [source] to [targetAspect], keeping the busiest part of the frame.
///
/// A centre crop beheads people in group photos and cuts the subject out of
/// anything composed off-centre. This runs a Sobel pass over a small copy and
/// slides the crop window to wherever edge energy is highest — cheap, no
/// model, and right far more often than centring.
img.Image _smartCrop(img.Image source, double targetAspect) {
  final sourceAspect = source.width / source.height;

  int cropWidth;
  int cropHeight;
  if (sourceAspect > targetAspect) {
    cropHeight = source.height;
    cropWidth = (cropHeight * targetAspect).round();
  } else {
    cropWidth = source.width;
    cropHeight = (cropWidth / targetAspect).round();
  }
  cropWidth = cropWidth.clamp(1, source.width);
  cropHeight = cropHeight.clamp(1, source.height);

  if (cropWidth >= source.width && cropHeight >= source.height) return source;

  const probeSize = 96;
  final probe = img.copyResize(
    source,
    width: probeSize,
    height: probeSize,
    interpolation: img.Interpolation.average,
  );
  final edges = img.sobel(img.grayscale(probe));

  if (cropWidth < source.width) {
    final energy = List<double>.filled(probeSize, 0);
    for (var x = 0; x < probeSize; x++) {
      for (var y = 0; y < probeSize; y++) {
        energy[x] += edges.getPixel(x, y).luminanceNormalized.toDouble();
      }
    }
    final window =
        (probeSize * cropWidth / source.width).round().clamp(1, probeSize);
    final start = _bestWindow(energy, window);
    final x = (start / probeSize * source.width)
        .round()
        .clamp(0, source.width - cropWidth);
    return img.copyCrop(
      source,
      x: x,
      y: 0,
      width: cropWidth,
      height: cropHeight,
    );
  }

  final energy = List<double>.filled(probeSize, 0);
  for (var y = 0; y < probeSize; y++) {
    for (var x = 0; x < probeSize; x++) {
      energy[y] += edges.getPixel(x, y).luminanceNormalized.toDouble();
    }
  }
  final window =
      (probeSize * cropHeight / source.height).round().clamp(1, probeSize);
  final start = _bestWindow(energy, window);
  final y = (start / probeSize * source.height)
      .round()
      .clamp(0, source.height - cropHeight);
  return img.copyCrop(
    source,
    x: 0,
    y: y,
    width: cropWidth,
    height: cropHeight,
  );
}

/// Start index of the [window]-wide slice of [energy] with the highest sum,
/// found with a running total rather than by re-summing each position.
int _bestWindow(List<double> energy, int window) {
  if (window >= energy.length) return 0;

  var running = 0.0;
  for (var i = 0; i < window; i++) {
    running += energy[i];
  }

  var best = running;
  var bestStart = 0;
  for (var i = window; i < energy.length; i++) {
    running += energy[i] - energy[i - window];
    if (running > best) {
      best = running;
      bestStart = i - window + 1;
    }
  }
  return bestStart;
}

// ─────────────────────────── filters ───────────────────────────

class FilterRequest {
  const FilterRequest({
    required this.sourcePath,
    required this.filter,
    required this.adjustments,
    required this.maxEdge,
    this.quality = 92,
  });

  final String sourcePath;
  final PhotoFilter filter;
  final FilterAdjustments adjustments;

  /// Long edge to work at. The preview uses a small value so a slider feels
  /// immediate; the export uses the source's own size.
  final int maxEdge;

  final int quality;
}

/// Applies one look plus the manual adjustments, and encodes the result.
Uint8List? applyPhotoFilter(FilterRequest request) {
  final decoded = _decodeFile(request.sourcePath);
  if (decoded == null) return null;
  if ((decoded.width * decoded.height) / 1000000 > kMaxSourceMegapixels) {
    return null;
  }

  final working = _fitTo(decoded, request.maxEdge);
  final result = _applyLook(working, request.filter, request.adjustments);
  return img.encodeJpg(result, quality: request.quality);
}

/// Every look rendered onto one small thumbnail, for the filter strip.
class FilterStripRequest {
  const FilterStripRequest({
    required this.sourcePath,
    required this.filters,
    this.edge = 160,
  });

  final String sourcePath;
  final List<PhotoFilter> filters;
  final int edge;
}

/// Renders the whole strip in a single isolate hop.
///
/// One `compute` call rather than one per look: the decode happens once and is
/// reused for all twelve, and spawning twelve isolates to do a thumbnail each
/// would cost far more than the work itself.
List<Uint8List?> renderFilterStrip(FilterStripRequest request) {
  final decoded = _decodeFile(request.sourcePath);
  if (decoded == null) {
    return List<Uint8List?>.filled(request.filters.length, null);
  }

  // Square-ish crop keeps every chip the same shape, so the strip reads as a
  // row of swatches rather than a ragged line of thumbnails.
  final base = img.copyResizeCropSquare(decoded, size: request.edge);

  return [
    for (final filter in request.filters)
      img.encodeJpg(
        _applyLook(img.Image.from(base), filter, FilterAdjustments.none),
        quality: 78,
      ),
  ];
}

/// Downscales so the long edge is at most [maxEdge]. Never enlarges.
img.Image _fitTo(img.Image source, int maxEdge) {
  if (maxEdge <= 0) return source;
  final longest = math.max(source.width, source.height);
  if (longest <= maxEdge) return source;
  final scale = maxEdge / longest;
  return img.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: img.Interpolation.average,
  );
}

/// The preset recipes, then the user's own adjustments on top.
img.Image _applyLook(
  img.Image source,
  PhotoFilter filter,
  FilterAdjustments adjustments,
) {
  var image = source;

  switch (filter) {
    case PhotoFilter.original:
      break;
    case PhotoFilter.blackWhite:
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.12);
    case PhotoFilter.mono:
      // Grey with a cool cast — the classic "silver" monochrome rather than a
      // flat desaturation.
      image = img.grayscale(image);
      image = img.colorOffset(image, red: -6, green: 0, blue: 12);
      image = img.adjustColor(image, contrast: 1.08);
    case PhotoFilter.sepia:
      image = img.sepia(image);
    case PhotoFilter.hdr:
      // A "HDR look", not real HDR: a JPEG has already lost the dynamic range
      // this would otherwise recover. Lift the shadows, add local contrast so
      // texture reads, then push saturation.
      image = img.adjustColor(image, gamma: 0.82);
      image = img.convolution(
        image,
        filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
        div: 1,
        amount: 0.45,
      );
      image = img.adjustColor(image, contrast: 1.14, saturation: 1.28);
    case PhotoFilter.vivid:
      image = img.adjustColor(image, saturation: 1.45, contrast: 1.14);
    case PhotoFilter.warm:
      image = img.colorOffset(image, red: 20, green: 6, blue: -14);
      image = img.adjustColor(image, saturation: 1.08);
    case PhotoFilter.cool:
      image = img.colorOffset(image, red: -14, green: 0, blue: 20);
      image = img.adjustColor(image, saturation: 1.05);
    case PhotoFilter.dark:
      image = img.adjustColor(image, gamma: 1.38, contrast: 1.2, saturation: 0.9);
      image = img.vignette(image, start: 0.25, end: 0.9, amount: 0.55);
    case PhotoFilter.bright:
      image = img.adjustColor(image, gamma: 0.84, brightness: 1.12);
    case PhotoFilter.fade:
      // Lowered contrast with lifted blacks — the washed, filmic look.
      image = img.adjustColor(image, contrast: 0.8, saturation: 0.85);
      image = img.colorOffset(image, red: 12, green: 10, blue: 14);
    case PhotoFilter.vintage:
      image = img.sepia(image, amount: 0.65);
      image = img.adjustColor(image, contrast: 1.12, saturation: 1.05);
      image = img.vignette(image, start: 0.3, end: 0.92, amount: 0.6);
  }

  if (adjustments.isNeutral) return image;

  if (adjustments.warmth != 0) {
    final shift = adjustments.warmth * 0.25;
    image = img.colorOffset(image, red: shift, blue: -shift);
  }

  // −100…100 maps onto the library's multipliers: 1.0 is unchanged, and the
  // ranges are kept narrow enough that a slider at either end still looks
  // like a photograph.
  image = img.adjustColor(
    image,
    brightness: (1 + adjustments.brightness / 100 * 0.55).clamp(0.2, 2.0),
    contrast: (1 + adjustments.contrast / 100 * 0.6).clamp(0.0, 2.0),
    saturation: (1 + adjustments.saturation / 100).clamp(0.0, 2.0),
  );

  return image;
}
