import Foundation

/// 画風の定義。名前・パレット・各処理の強さを「データ」として持ち、コードを変えずに画風を足せるようにする
/// （スタイル転送のモデルファイルはステップ6で足す）
public struct IllustrationStyle: Sendable, Identifiable {
    public let id: String
    public let name: String
    /// 色数を減らしたあとに寄せる色（0〜255のRGB）。空なら写真の色のまま
    public var palette: [SIMD3<Float>]
    /// パレットへの寄せ具合（0 = 写真の色のまま、1 = パレットの色に置き換える）
    public var paletteBlend: Float
    /// 平滑化の半径と回数。大きいほど細部が消えて平らになる（長辺1024pxのときの値）
    public var smoothingRadius: Int
    public var smoothingPasses: Int
    /// 面を分けるときに使う色の数（多いほど細かく分かれる）
    public var colorCount: Int
    /// これより小さい面は隣の面にまとめる（画像全体の面積に対する割合）
    public var minRegionFraction: Double
    /// 色の差がこれより小さい境目には線を引かない（0〜441）
    public var edgeThreshold: Float
    /// 線の色（0〜255のRGB）
    public var lineColor: SIMD3<Float>
    public var defaultLineWidth: Double
    public var defaultStrength: Double

    public init(id: String, name: String,
                palette: [SIMD3<Float>] = [], paletteBlend: Float = 0,
                smoothingRadius: Int = 5, smoothingPasses: Int = 3,
                colorCount: Int = 10, minRegionFraction: Double = 0.0015, edgeThreshold: Float = 30,
                lineColor: SIMD3<Float> = SIMD3(45, 36, 33),
                defaultLineWidth: Double = 2, defaultStrength: Double = 1) {
        self.id = id
        self.name = name
        self.palette = palette
        self.paletteBlend = paletteBlend
        self.smoothingRadius = smoothingRadius
        self.smoothingPasses = smoothingPasses
        self.colorCount = colorCount
        self.minRegionFraction = minRegionFraction
        self.edgeThreshold = edgeThreshold
        self.lineColor = lineColor
        self.defaultLineWidth = defaultLineWidth
        self.defaultStrength = defaultStrength
    }

    /// お手本なしの基本の画風
    public static let basic = IllustrationStyle(id: "basic", name: "基本")
}
