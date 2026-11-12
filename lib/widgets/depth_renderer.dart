import 'dart:math' as math;
import 'dart:typed_data';

class DepthVertex {
  const DepthVertex(this.x, this.y, this.inverseDepth, this.u, this.v);
  final double x, y, inverseDepth, u, v;
}

class DepthTexture {
  const DepthTexture(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;
}

class DepthTriangle {
  const DepthTriangle(this.a, this.b, this.c, this.argb, [this.texture]);
  final DepthVertex a, b, c;
  final int argb;
  final DepthTexture? texture;
}

/// Opaque fragments own their pixel regardless of triangle submission order.
/// UV interpolation uses reciprocal camera distance, preventing texture swim.
Uint8List renderDepth(int width, int height, List<DepthTriangle> triangles) {
  final pixels = Uint8List(width * height * 4),
      depth = Float64List(width * height);
  final translucent = <DepthTriangle>[];
  void draw(DepthTriangle tri, bool alphaPass) {
    final a = tri.a, b = tri.b, c = tri.c;
    final den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
    if (den.abs() < 1e-9) return;
    final minX = math.max(0, math.min(a.x, math.min(b.x, c.x)).floor()),
        maxX = math.min(width - 1, math.max(a.x, math.max(b.x, c.x)).ceil());
    final minY = math.max(0, math.min(a.y, math.min(b.y, c.y)).floor()),
        maxY = math.min(height - 1, math.max(a.y, math.max(b.y, c.y)).ceil());
    final texture = tri.texture;
    final invDen = 1 / den;
    final waDx = (b.y - c.y) * invDen, wbDx = (c.y - a.y) * invDen;
    final depthDx = waDx * (a.inverseDepth - c.inverseDepth) +
        wbDx * (b.inverseDepth - c.inverseDepth);
    final au = a.u * a.inverseDepth,
        bu = b.u * b.inverseDepth,
        cu = c.u * c.inverseDepth;
    final av = a.v * a.inverseDepth,
        bv0 = b.v * b.inverseDepth,
        cv = c.v * c.inverseDepth;
    final uDx = waDx * (au - cu) + wbDx * (bu - cu),
        vDx = waDx * (av - cv) + wbDx * (bv0 - cv);
    var hasAlpha = false;
    for (var y = minY; y <= maxY; y++) {
      final px = minX + .5, py = y + .5;
      var wa = ((b.y - c.y) * (px - c.x) + (c.x - b.x) * (py - c.y)) * invDen;
      var wb = ((c.y - a.y) * (px - c.x) + (a.x - c.x) * (py - c.y)) * invDen;
      var z = wa * (a.inverseDepth - c.inverseDepth) +
          wb * (b.inverseDepth - c.inverseDepth) +
          c.inverseDepth;
      var un = wa * (au - cu) + wb * (bu - cu) + cu,
          vn = wa * (av - cv) + wb * (bv0 - cv) + cv;
      for (var x = minX; x <= maxX; x++) {
        final cw = wa, cb = wb, cz = z, currentU = un, currentV = vn;
        wa += waDx;
        wb += wbDx;
        z += depthDx;
        un += uDx;
        vn += vDx;
        final wc = 1 - cw - cb;
        if (cw < -1e-8 || cb < -1e-8 || wc < -1e-8) continue;
        final at = y * width + x;
        if (cz < depth[at] - 1e-10) continue;
        int r, g, bv, alpha;
        if (texture != null) {
          final invZ = 1 / cz, u = currentU * invZ, v = currentV * invZ;
          final tx = (u * texture.width).floor().clamp(0, texture.width - 1),
              ty = (v * texture.height).floor().clamp(0, texture.height - 1);
          final t = (ty * texture.width + tx) * 4;
          r = texture.rgba[t];
          g = texture.rgba[t + 1];
          bv = texture.rgba[t + 2];
          alpha = texture.rgba[t + 3];
          // Transparent texture pixels reveal the object's material, rather
          // than punching holes through an otherwise solid shell.
          final baseAlpha = (tri.argb >> 24) & 255;
          if (alpha < 255 && baseAlpha > 0) {
            final ta = alpha / 255,
                ba = baseAlpha / 255 * (1 - ta),
                out = ta + ba;
            r = ((r * ta + ((tri.argb >> 16) & 255) * ba) / out).round();
            g = ((g * ta + ((tri.argb >> 8) & 255) * ba) / out).round();
            bv = ((bv * ta + (tri.argb & 255) * ba) / out).round();
            alpha = (out * 255).round();
          }
        } else {
          r = (tri.argb >> 16) & 255;
          g = (tri.argb >> 8) & 255;
          bv = tri.argb & 255;
          alpha = (tri.argb >> 24) & 255;
        }
        if (alpha == 0) continue;
        if (alpha < 255 && !alphaPass) {
          hasAlpha = true;
          continue;
        }
        if (alpha == 255 && alphaPass) continue;
        final p = at * 4;
        if (!alphaPass) {
          depth[at] = cz;
          pixels[p] = r;
          pixels[p + 1] = g;
          pixels[p + 2] = bv;
          pixels[p + 3] = 255;
        } else {
          final src = alpha / 255,
              dst = pixels[p + 3] / 255,
              out = src + dst * (1 - src);
          pixels[p] = ((r * src + pixels[p] * dst * (1 - src)) / out).round();
          pixels[p + 1] =
              ((g * src + pixels[p + 1] * dst * (1 - src)) / out).round();
          pixels[p + 2] =
              ((bv * src + pixels[p + 2] * dst * (1 - src)) / out).round();
          pixels[p + 3] = (out * 255).round();
        }
      }
    }
    if (hasAlpha) translucent.add(tri);
  }

  final nearFirst = List<DepthTriangle>.of(triangles)
    ..sort((a, b) => (b.a.inverseDepth + b.b.inverseDepth + b.c.inverseDepth)
        .compareTo(a.a.inverseDepth + a.b.inverseDepth + a.c.inverseDepth));
  for (final tri in nearFirst) {
    draw(tri, false);
  }
  translucent.sort((a, b) =>
      (a.a.inverseDepth + a.b.inverseDepth + a.c.inverseDepth)
          .compareTo(b.a.inverseDepth + b.b.inverseDepth + b.c.inverseDepth));
  for (final tri in translucent) {
    draw(tri, true);
  }
  return pixels;
}
