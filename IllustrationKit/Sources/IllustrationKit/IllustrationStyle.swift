import Foundation

/// 画風の定義。名前・パレット・各処理の強さを「データ」として持ち、コードを変えずに画風を足せるようにする
/// （スタイル転送のモデルファイルはステップ6で足す）。
/// 長さの値（半径・太さなど）は、長辺1024pxのときの画素数で書く
public struct IllustrationStyle: Sendable, Identifiable {
    /// 背景の扱い
    public enum Background: Sendable {
        /// 背景もイラストにする（被写体より大胆に単純化し、線は引かない）
        case illustrated
        /// 背景を単色にして、被写体だけをイラストにする（ステッカーのような仕上がり）
        case plain(SIMD3<Float>)
    }

    public let id: String
    public let name: String
    public var background: Background

    /// 面の分け方を決めるときの長辺の画素数。小さいほど面が大きくまとまる。被写体と背景で別に持つ
    public var subjectDetail: Int
    public var backgroundDetail: Int
    /// 平滑化（桑原フィルター）の半径と回数
    public var smoothingRadius: Int
    public var smoothingPasses: Int
    /// 面を分けるときに使う色の数
    public var colorCount: Int
    /// これより小さい面は隣の面にまとめる（画像全体の面積に対する割合）
    public var minRegionFraction: Double
    /// 小さな面でも、隣との色の差がこれより大きければ特徴として残す（0〜441）
    public var keepContrast: Float
    /// 面の形の丸め具合（半径）
    public var shapeRounding: Int

    /// 色を寄せるパレット（0〜255のRGB）と寄せ具合（0〜1）
    public var palette: [SIMD3<Float>]
    public var paletteBlend: Float
    /// パステル調の強さ（0〜1）
    public var pastel: Float

    /// 被写体の中の線（XDoG）：ぼかしの大きさ・線にする差の大きさ・線のふちのやわらかさ
    public var lineSigma: Float
    public var lineThreshold: Float
    public var lineSoftness: Float
    /// 被写体の輪郭線の太さ（線の太さに対する倍率）
    public var outlineScale: Double
    /// 線の色（0〜255のRGB）
    public var lineColor: SIMD3<Float>
    public var defaultLineWidth: Double
    public var defaultStrength: Double

    public init(id: String, name: String, background: Background = .illustrated,
                subjectDetail: Int = 640, backgroundDetail: Int = 220,
                smoothingRadius: Int = 2, smoothingPasses: Int = 2,
                colorCount: Int = 10, minRegionFraction: Double = 0.0015,
                keepContrast: Float = 60, shapeRounding: Int = 3,
                palette: [SIMD3<Float>] = [], paletteBlend: Float = 0, pastel: Float = 0.8,
                lineSigma: Float = 1.2, lineThreshold: Float = 0.02, lineSoftness: Float = 0.025,
                outlineScale: Double = 1.5,
                lineColor: SIMD3<Float> = SIMD3(60, 48, 44),
                defaultLineWidth: Double = 2, defaultStrength: Double = 1) {
        self.id = id
        self.name = name
        self.background = background
        self.subjectDetail = subjectDetail
        self.backgroundDetail = backgroundDetail
        self.smoothingRadius = smoothingRadius
        self.smoothingPasses = smoothingPasses
        self.colorCount = colorCount
        self.minRegionFraction = minRegionFraction
        self.keepContrast = keepContrast
        self.shapeRounding = shapeRounding
        self.palette = palette
        self.paletteBlend = paletteBlend
        self.pastel = pastel
        self.lineSigma = lineSigma
        self.lineThreshold = lineThreshold
        self.lineSoftness = lineSoftness
        self.outlineScale = outlineScale
        self.lineColor = lineColor
        self.defaultLineWidth = defaultLineWidth
        self.defaultStrength = defaultStrength
    }

    /// A：写真全体をイラストにする
    public static let wholeScene = IllustrationStyle(id: "whole", name: "A：全体をイラストに")
    /// B：被写体だけをイラストにして、背景は白
    public static let subjectOnly = IllustrationStyle(id: "subject", name: "B：被写体だけ",
                                                      background: .plain(SIMD3(255, 255, 255)))
}
