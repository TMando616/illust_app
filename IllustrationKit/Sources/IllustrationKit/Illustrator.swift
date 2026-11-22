import CoreImage
import CoreImage.CIFilterBuiltins

/// 写真をイラスト風に変換する。入出力は CIImage に統一する（無音カメラの撮影フレームをそのまま渡せるように）。
/// 流れ：縮小 → 平滑化（桑原フィルター）→ 色数を減らす → 線画を重ねる
public struct Illustrator: @unchecked Sendable {
    private let context: CIContext

    public init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    /// - Parameters:
    ///   - maxLongSide: 処理する長辺の画素数。小さいほど細部が消えてイラストらしくなり、速い
    ///   - lineWidth: 線の太さ（長辺1024pxのときの画素数）。0なら線を引かない
    ///   - strength: 元の写真との混ぜ具合（1 = イラストだけ）
    public func render(_ image: CIImage, style: IllustrationStyle, maxLongSide: CGFloat = 1024,
                       lineWidth: Double? = nil, strength: Double? = nil) -> CIImage {
        let scaled = downscale(image, maxLongSide: maxLongSide)
        let source = RGBAImage(scaled, context: context)
        let w = source.width, h = source.height
        // 半径や線の太さは長辺1024pxを基準に決めてあるので、解像度に合わせて伸び縮みさせる
        let unit = Double(max(w, h)) / 1024

        // 平滑化
        var smooth = source
        let radius = max(1, Int((Double(style.smoothingRadius) * unit).rounded()))
        for _ in 0..<style.smoothingPasses { smooth = Kuwahara.apply(smooth, radius: radius) }

        // 面に分ける：色数を減らして色の番号を振り、小さな粒と小さな面を隣にまとめる。
        // 色数を減らすのは「面の分け方」を決めるためで、塗る色は面ごとの平均色にする
        // （代表色で塗ると、背景の大きな面に色を取られて肌や髪の色がずれるため）
        let centers = ColorQuantizer.centroids(of: [smooth], count: style.colorCount)
        var labels = ColorQuantizer.labels(of: smooth, centers: centers)
        let modeRadius = max(1, Int((2 * unit).rounded()))
        for _ in 0..<2 {
            labels = ColorQuantizer.modeFilter(labels, width: w, height: h, colors: centers.count, radius: modeRadius)
        }
        labels = Regions.mergeSmall(labels: labels, width: w, height: h,
                                    minArea: max(4, Int(Double(w * h) * style.minRegionFraction)))
        let regions = Regions(labels: labels, width: w, height: h)

        // 面ごとの色（＋パレットへ寄せる）
        var colors = regions.meanColors(of: smooth)
        if !style.palette.isEmpty, style.paletteBlend > 0 {
            colors = colors.map { c in
                let p = style.palette[ColorQuantizer.nearestIndex(c, style.palette)]
                return c + (p - c) * style.paletteBlend
            }
        }

        // 線画：面の境目のうち、色の差がはっきりしているところだけに線を引く
        let width = (lineWidth ?? style.defaultLineWidth) * unit
        let lines = width > 0
            ? LineArt.edges(regions: regions.ids, colors: colors, width: w, height: h,
                            threshold: style.edgeThreshold, thickness: width)
            : [Bool](repeating: false, count: w * h)
        // 線のふちを1画素ぶんぼかして、ギザギザを目立たなくする（線の濃さ 0〜1）
        let lineAlpha = LineArt.soften(lines, width: w, height: h)

        let mix = Float(strength ?? style.defaultStrength)
        var out = source.pixels
        for i in 0..<(w * h) {
            let fill = colors[Int(regions.ids[i])]
            let flat = fill + (style.lineColor - fill) * lineAlpha[i]
            let c = source.rgb(at: i) + (flat - source.rgb(at: i)) * mix
            out[i * 4] = UInt8(min(255, max(0, c.x.rounded())))
            out[i * 4 + 1] = UInt8(min(255, max(0, c.y.rounded())))
            out[i * 4 + 2] = UInt8(min(255, max(0, c.z.rounded())))
            out[i * 4 + 3] = 255
        }
        return RGBAImage(width: w, height: h, pixels: out).ciImage
    }

    func downscale(_ image: CIImage, maxLongSide: CGFloat) -> CIImage {
        let longSide = max(image.extent.width, image.extent.height)
        guard longSide > maxLongSide else { return image }
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(maxLongSide / longSide)
        filter.aspectRatio = 1
        return filter.outputImage!
    }
}
