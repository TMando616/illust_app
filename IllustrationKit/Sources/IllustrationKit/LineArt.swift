import Foundation

/// 線画。写真から輪郭を拾うのではなく、色を減らしたあとの「色の面の境目」に線を引く。
/// 写真の細かい模様には線が出ず、面の形に沿ったすっきりした線になる
enum LineArt {
    static func edges(regions ids: [Int32], colors: [SIMD3<Float>], width w: Int, height h: Int,
                      threshold: Float, thickness: Double) -> [Bool] {
        let t2 = threshold * threshold
        var edge = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let a = Int(ids[y * w + x])
                if x + 1 < w, case let b = Int(ids[y * w + x + 1]), a != b,
                   ColorQuantizer.distanceSquared(colors[a], colors[b]) > t2 {
                    edge[y * w + x] = true
                }
                if y + 1 < h, case let b = Int(ids[(y + 1) * w + x]), a != b,
                   ColorQuantizer.distanceSquared(colors[a], colors[b]) > t2 {
                    edge[y * w + x] = true
                }
            }
        }
        // 太さ：境目の画素を中心に、半径ぶん広げる（横→縦の順に広げると四角に広がる）
        let r = max(0, Int((thickness - 1) / 2 + 0.5))
        guard r > 0 else { return edge }
        var horizontal = edge
        for y in 0..<h {
            for x in 0..<w where edge[y * w + x] {
                for xx in max(0, x - r)...min(w - 1, x + r) { horizontal[y * w + xx] = true }
            }
        }
        var out = horizontal
        for y in 0..<h {
            for x in 0..<w where horizontal[y * w + x] {
                for yy in max(0, y - r)...min(h - 1, y + r) { out[yy * w + x] = true }
            }
        }
        return out
    }

    /// 線の有無（true/false）を、3×3の平均で0〜1の濃さに変える。線の中心は1のまま、ふちだけが中間の濃さになる
    static func soften(_ mask: [Bool], width w: Int, height h: Int) -> [Float] {
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var sum = 0, n = 0
                for yy in max(0, y - 1)...min(h - 1, y + 1) {
                    for xx in max(0, x - 1)...min(w - 1, x + 1) {
                        n += 1
                        if mask[yy * w + xx] { sum += 1 }
                    }
                }
                out[y * w + x] = min(1, Float(sum) / Float(n) * 1.5)
            }
        }
        return out
    }

    /// 明るさの変化から線を拾う（XDoG：ぼかし具合の違う2枚の差を取る方法）。
    /// 色の差が小さい目鼻や毛並みの流れも線として残る。戻り値は線の濃さ（0〜1）
    /// `mask` を渡すと、被写体の中の明るさの幅を0〜1に広げてから線を拾う（黒い犬のような暗い被写体でも線が出るように）
    static func xdog(_ image: RGBAImage, sigma: Float, threshold: Float, softness: Float, mask: [Float]? = nil) -> [Float] {
        let w = image.width, h = image.height
        var lum = [Float](repeating: 0, count: w * h)
        for i in 0..<(w * h) { lum[i] = (image.rgb(at: i) * SIMD3(0.299, 0.587, 0.114)).sum() / 255 }
        if let mask {
            let inside = zip(lum, mask).filter { $0.1 > 0.5 }.map(\.0).sorted()
            if inside.count > 100 {
                // 明るさの下から2%・上から2%を0と1にそろえる（極端な画素に引っぱられないように）
                let lo = inside[inside.count * 2 / 100], hi = inside[inside.count * 98 / 100]
                if hi - lo > 0.02 { lum = lum.map { min(1, max(0, ($0 - lo) / (hi - lo))) } }
            }
        }
        let narrow = gaussian(lum, width: w, height: h, sigma: sigma)
        let wide = gaussian(lum, width: w, height: h, sigma: sigma * 1.6)
        // 輪郭の暗い側では「細かいぼかし」が「粗いぼかし」より暗くなる。その差が大きいところを線にする
        return (0..<(w * h)).map { i in min(1, max(0, (wide[i] - narrow[i] - threshold) / softness)) }
    }

    /// ガウスぼかし（横→縦の順にかける）
    static func gaussian(_ src: [Float], width w: Int, height h: Int, sigma: Float) -> [Float] {
        let r = max(1, Int((sigma * 3).rounded(.up)))
        var kernel = (-r...r).map { exp(-Float($0 * $0) / (2 * sigma * sigma)) }
        let total = kernel.reduce(0, +)
        kernel = kernel.map { $0 / total }
        var tmp = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var v: Float = 0
                for k in -r...r { v += src[y * w + min(w - 1, max(0, x + k))] * kernel[k + r] }
                tmp[y * w + x] = v
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                var v: Float = 0
                for k in -r...r { v += tmp[min(h - 1, max(0, y + k)) * w + x] * kernel[k + r] }
                out[y * w + x] = v
            }
        }
        return out
    }
}
