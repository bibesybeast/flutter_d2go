import UIKit

extension UIImage {
    func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image
    }
    
    func normalized(mean normMeanRGB: [Float32], std normStdRGB: [Float32] ) -> [Float32]? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        let w = cgImage.width
        let h = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bitsPerComponent = 8
        var rawBytes: [UInt8] = [UInt8](repeating: 0, count: w * h * 4)
        rawBytes.withUnsafeMutableBytes { ptr in
            if let cgImage = self.cgImage,
                let context = CGContext(data: ptr.baseAddress,
                                        width: w,
                                        height: h,
                                        bitsPerComponent: bitsPerComponent,
                                        bytesPerRow: bytesPerRow,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                context.draw(cgImage, in: rect)
            }
        }
        var normalizedBuffer: [Float32] = [Float32](repeating: 0, count: w * h * 3)
        for i in 0 ..< w * h {
            normalizedBuffer[i] = Float32(Float(rawBytes[i * 4 + 0]) - normMeanRGB[0]) / 255.0 / normStdRGB[0]
            normalizedBuffer[w * h + i] = Float32(Float(rawBytes[i * 4 + 1]) - normMeanRGB[1]) / 255.0 / normStdRGB[1]
            normalizedBuffer[w * h * 2 + i] = Float32(Float(rawBytes[i * 4 + 2]) - normMeanRGB[2]) / 255.0 / normStdRGB[2]
        }
        return normalizedBuffer
    }
}
