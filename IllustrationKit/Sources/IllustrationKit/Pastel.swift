import Foundation

/// 色をパステル調にする。色相はそのままに、明るさを高い範囲に寄せ、鮮やかさを少し抑える。
/// 暗い色も明るくなるので、黒っぽい被写体でも線と塗りの区別がつくようになる
enum Pastel {
    /// - Parameter amount: 0 = そのまま、1 = しっかりパステル
    static func apply(_ rgb: SIMD3<Float>, amount: Float) -> SIMD3<Float> {
        var (h, s, l) = hsl(rgb / 255)
        // 明るさ：0〜1 を 0.45〜0.95 に縮める（暗い部分ほど大きく持ち上がる）
        l += ((0.45 + 0.5 * l) - l) * amount
        // 鮮やかさ：強すぎる色を抑える（灰色に色味を足すと、黒い被写体が紫などに転ぶので足さない）
        s *= 1 - 0.35 * amount
        return rgbFrom(h: h, s: s, l: l) * 255
    }

    static func hsl(_ c: SIMD3<Float>) -> (Float, Float, Float) {
        let maxV = c.max(), minV = c.min()
        let l = (maxV + minV) / 2
        guard maxV > minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Float
        switch maxV {
        case c.x: h = (c.y - c.z) / d + (c.y < c.z ? 6 : 0)
        case c.y: h = (c.z - c.x) / d + 2
        default: h = (c.x - c.y) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    static func rgbFrom(h: Float, s: Float, l: Float) -> SIMD3<Float> {
        guard s > 0 else { return SIMD3(repeating: l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Float) -> Float {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        return SIMD3(channel(h + 1 / 3), channel(h), channel(h - 1 / 3))
    }
}
