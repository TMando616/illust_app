import Foundation

/// 色数を減らす。画像の色を k-means で `count` 色のグループに分け、各画素をグループの代表色に置き換える。
/// 同じ画像からは毎回同じ結果になるよう、乱数の種を固定している
public enum ColorQuantizer {
    /// 画像の色から代表色を選ぶ。`include` で集計に使う画素を絞れる（お手本の背景の白や線を除くため）
    public static func centroids(of images: [RGBAImage], count: Int, maxSamples: Int = 40_000,
                                 include: (SIMD3<Float>, UInt8) -> Bool = { _, _ in true }) -> [SIMD3<Float>] {
        var samples: [SIMD3<Float>] = []
        let total = images.reduce(0) { $0 + $1.width * $1.height }
        let step = max(1, total / maxSamples)
        for image in images {
            var i = 0
            while i < image.width * image.height {
                let c = image.rgb(at: i)
                if include(c, image.pixels[i * 4 + 3]) { samples.append(c) }
                i += step
            }
        }
        guard samples.count >= count else { return samples }
        var rng = SeededRandom(seed: 42)

        // k-means++：最初の代表色同士がなるべく離れるように選ぶ（似た色ばかり選ばれるのを防ぐ）
        var centers = [samples[Int(rng.next() % UInt64(samples.count))]]
        var nearest = samples.map { distanceSquared($0, centers[0]) }
        while centers.count < count {
            let sum = nearest.reduce(0, +)
            var target = Float(Double(rng.next() % 1_000_000) / 1_000_000) * sum
            var pick = samples.count - 1
            for (j, d) in nearest.enumerated() {
                target -= d
                if target <= 0 { pick = j; break }
            }
            centers.append(samples[pick])
            for j in samples.indices { nearest[j] = min(nearest[j], distanceSquared(samples[j], centers.last!)) }
        }

        for _ in 0..<12 {
            var sums = [SIMD3<Float>](repeating: .zero, count: count)
            var counts = [Int](repeating: 0, count: count)
            for s in samples {
                let k = nearestIndex(s, centers)
                sums[k] += s
                counts[k] += 1
            }
            for k in 0..<count where counts[k] > 0 { centers[k] = sums[k] / Float(counts[k]) }
        }
        return centers
    }

    /// 各画素がどの代表色に属するか（代表色の番号）を返す
    static func labels(of image: RGBAImage, centers: [SIMD3<Float>]) -> [UInt8] {
        (0..<(image.width * image.height)).map { UInt8(nearestIndex(image.rgb(at: $0), centers)) }
    }

    /// 代表色の番号を、まわりで一番多い番号に置き換える。色の小さな粒（ノイズ）が消えて面がきれいになる
    static func modeFilter(_ labels: [UInt8], width w: Int, height h: Int, colors: Int, radius: Int) -> [UInt8] {
        var out = labels
        var hist = [Int](repeating: 0, count: colors)
        for y in 0..<h {
            for x in 0..<w {
                for k in 0..<colors { hist[k] = 0 }
                for yy in max(0, y - radius)...min(h - 1, y + radius) {
                    for xx in max(0, x - radius)...min(w - 1, x + radius) { hist[Int(labels[yy * w + xx])] += 1 }
                }
                out[y * w + x] = UInt8(hist.indices.max { hist[$0] < hist[$1] }!)
            }
        }
        return out
    }

    @inline(__always) static func distanceSquared(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let d = a - b
        return (d * d).sum()
    }

    @inline(__always) static func nearestIndex(_ c: SIMD3<Float>, _ centers: [SIMD3<Float>]) -> Int {
        var best = 0
        var bestD = Float.infinity
        for (k, center) in centers.enumerated() {
            let d = distanceSquared(c, center)
            if d < bestD { bestD = d; best = k }
        }
        return best
    }
}

/// 種を固定できる乱数（同じ入力なら毎回同じ結果にするため）
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 1
    }
}
