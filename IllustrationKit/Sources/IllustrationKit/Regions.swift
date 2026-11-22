import Foundation

/// 色の面（同じ色の番号がつながった領域）を扱う
struct Regions {
    /// 各画素がどの面に属するか（面の番号）
    var ids: [Int32]
    var count: Int

    /// 上下左右でつながった同じ番号の画素を1つの面にまとめる
    init(labels: [UInt8], width w: Int, height h: Int) {
        var ids = [Int32](repeating: -1, count: w * h)
        var next: Int32 = 0
        var stack: [Int] = []
        for start in 0..<(w * h) where ids[start] < 0 {
            let label = labels[start]
            ids[start] = next
            stack.append(start)
            while let i = stack.popLast() {
                let x = i % w, y = i / w
                for (n, ok) in [(i - 1, x > 0), (i + 1, x + 1 < w), (i - w, y > 0), (i + w, y + 1 < h)]
                where ok && ids[n] < 0 && labels[n] == label {
                    ids[n] = next
                    stack.append(n)
                }
            }
            next += 1
        }
        self.ids = ids
        self.count = Int(next)
    }

    /// 面積が `minArea` 未満の面を、一番長く接している隣の面の色の番号に塗り替える。
    /// 小さな面が消えると、写真のざらつきや細かすぎる線が減る
    static func mergeSmall(labels: [UInt8], width w: Int, height h: Int, minArea: Int, passes: Int = 3) -> [UInt8] {
        var labels = labels
        for _ in 0..<passes {
            let regions = Regions(labels: labels, width: w, height: h)
            var area = [Int](repeating: 0, count: regions.count)
            for id in regions.ids { area[Int(id)] += 1 }
            guard area.contains(where: { $0 < minArea }) else { break }

            // 小さな面ごとに、接している隣の面の数を数える
            var neighbors = [Int: [Int: Int]]()
            for y in 0..<h {
                for x in 0..<w {
                    let a = Int(regions.ids[y * w + x])
                    for (nx, ny) in [(x + 1, y), (x, y + 1)] where nx < w && ny < h {
                        let b = Int(regions.ids[ny * w + nx])
                        guard a != b else { continue }
                        if area[a] < minArea { neighbors[a, default: [:]][b, default: 0] += 1 }
                        if area[b] < minArea { neighbors[b, default: [:]][a, default: 0] += 1 }
                    }
                }
            }
            // 塗り替え先の色の番号（隣のうち大きな面を優先するため、接している長さ×面積の平方根で選ぶ）
            var regionLabel = [UInt8](repeating: 0, count: regions.count)
            for i in 0..<(w * h) { regionLabel[Int(regions.ids[i])] = labels[i] }
            var target = regionLabel
            for (small, counts) in neighbors {
                if let best = counts.max(by: {
                    Double($0.value) * Double(area[$0.key]).squareRoot() < Double($1.value) * Double(area[$1.key]).squareRoot()
                }) {
                    target[small] = regionLabel[best.key]
                }
            }
            for i in 0..<(w * h) { labels[i] = target[Int(regions.ids[i])] }
        }
        return labels
    }

    /// 面ごとの平均色
    func meanColors(of image: RGBAImage) -> [SIMD3<Float>] {
        var sums = [SIMD3<Float>](repeating: .zero, count: count)
        var counts = [Float](repeating: 0, count: count)
        for i in 0..<ids.count {
            sums[Int(ids[i])] += image.rgb(at: i)
            counts[Int(ids[i])] += 1
        }
        return zip(sums, counts).map { $0 / max(1, $1) }
    }
}
