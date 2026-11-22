import Foundation

/// 輪郭を残したまま色をならす（桑原フィルター）。
/// 各画素のまわりを4つの四角に分け、色のばらつきが一番小さい四角の平均色にする。
/// 輪郭をまたぐ四角はばらつきが大きいので選ばれず、輪郭がぼけない。
/// 四角ごとの合計は「累積和の表」から4回の足し引きで出せるので、半径を大きくしても遅くならない
enum Kuwahara {
    static func apply(_ image: RGBAImage, radius: Int) -> RGBAImage {
        guard radius > 0 else { return image }
        let w = image.width, h = image.height
        let sw = w + 1
        // 累積和の表（R・G・B と、R²+G²+B²）。表の (x, y) は左上から (x-1, y-1) までの合計
        var sr = [Double](repeating: 0, count: sw * (h + 1))
        var sg = sr, sb = sr, sq = sr
        image.pixels.withUnsafeBufferPointer { px in
            for y in 0..<h {
                var rr = 0.0, rg = 0.0, rb = 0.0, rq = 0.0
                for x in 0..<w {
                    let i = (y * w + x) * 4
                    let r = Double(px[i]), g = Double(px[i + 1]), b = Double(px[i + 2])
                    rr += r; rg += g; rb += b; rq += r * r + g * g + b * b
                    let t = (y + 1) * sw + (x + 1), u = y * sw + (x + 1)
                    sr[t] = sr[u] + rr; sg[t] = sg[u] + rg; sb[t] = sb[u] + rb; sq[t] = sq[u] + rq
                }
            }
        }
        var out = image.pixels
        @inline(__always) func box(_ t: [Double], _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Double {
            t[(y1 + 1) * sw + (x1 + 1)] - t[y0 * sw + (x1 + 1)] - t[(y1 + 1) * sw + x0] + t[y0 * sw + x0]
        }
        for y in 0..<h {
            for x in 0..<w {
                var best = Double.infinity
                var br = 0.0, bg = 0.0, bb = 0.0
                for (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] {
                    let x0 = dx < 0 ? max(0, x - radius) : x, x1 = dx < 0 ? x : min(w - 1, x + radius)
                    let y0 = dy < 0 ? max(0, y - radius) : y, y1 = dy < 0 ? y : min(h - 1, y + radius)
                    let n = Double((x1 - x0 + 1) * (y1 - y0 + 1))
                    let mr = box(sr, x0, y0, x1, y1) / n
                    let mg = box(sg, x0, y0, x1, y1) / n
                    let mb = box(sb, x0, y0, x1, y1) / n
                    let variance = box(sq, x0, y0, x1, y1) / n - (mr * mr + mg * mg + mb * mb)
                    if variance < best { best = variance; br = mr; bg = mg; bb = mb }
                }
                let i = (y * w + x) * 4
                out[i] = UInt8(min(255, max(0, br.rounded())))
                out[i + 1] = UInt8(min(255, max(0, bg.rounded())))
                out[i + 2] = UInt8(min(255, max(0, bb.rounded())))
            }
        }
        return RGBAImage(width: w, height: h, pixels: out)
    }
}
