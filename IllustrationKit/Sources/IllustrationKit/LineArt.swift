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
}
