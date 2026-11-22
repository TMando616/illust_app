import CoreImage

/// 画風の定義。名前・パレット・初期値を「データ」として持ち、コードを変えずに画風を足せるようにする
/// （モデルファイルはステップ6で足す）
public struct IllustrationStyle: Sendable, Identifiable {
    public let id: String
    public let name: String
    /// 色数を減らすときに寄せる色。空なら画像から色を選ぶ
    public let palette: [CIColor]
    public let defaultLineWidth: Double
    public let defaultStrength: Double

    public init(id: String, name: String, palette: [CIColor] = [], defaultLineWidth: Double = 1.0, defaultStrength: Double = 1.0) {
        self.id = id
        self.name = name
        self.palette = palette
        self.defaultLineWidth = defaultLineWidth
        self.defaultStrength = defaultStrength
    }
}

/// 写真をイラスト風に変換する。入出力は CIImage に統一する（無音カメラの撮影フレームをそのまま渡せるように）
public struct Illustrator: Sendable {
    public init() {}

    /// ステップ1で中身（縮小 → 平滑化 → 色数を減らす → 線画）を組む。今はそのまま返す
    public func render(_ image: CIImage, style: IllustrationStyle, maxLongSide: CGFloat = 1024) -> CIImage {
        image
    }
}
