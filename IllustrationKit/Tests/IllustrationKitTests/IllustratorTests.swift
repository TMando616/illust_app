import CoreImage
import Testing
@testable import IllustrationKit

@Test func 変換後も画像の大きさが変わらない() {
    let input = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 80))
    let style = IllustrationStyle.wholeScene
    let output = Illustrator().render(input, style: style)
    #expect(output.extent.size == input.extent.size)
}
