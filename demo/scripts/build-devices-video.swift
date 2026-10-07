import AppKit
import AVFoundation
import CoreVideo

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
    fatalError("Usage: swift build-devices-video.swift <frames-directory> <output.mp4> [frame-count]")
}

let framesDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let frameCount = CommandLine.arguments.count == 4 ? Int(CommandLine.arguments[3])! : 181
for index in 0..<frameCount {
    let path = framesDirectory.appendingPathComponent(String(format: "%03d.png", index)).path
    guard FileManager.default.fileExists(atPath: path) else { fatalError("Missing input: \(path)") }
}
try? FileManager.default.removeItem(at: outputURL)
let firstImage = NSImage(contentsOf: framesDirectory.appendingPathComponent("000.png"))!
let firstCGImage = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let width = firstCGImage.width
let height = firstCGImage.height

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4
    ],
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: width > 288 ? 2_400_000 : 1_200_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
        AVVideoAllowFrameReorderingKey: false
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let attributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
writer.add(input)
guard writer.startWriting() else { fatalError("Writer: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

for index in 0..<frameCount {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    let filename = String(format: "%03d.png", index)
    let url = framesDirectory.appendingPathComponent(filename)
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let pool = adaptor.pixelBufferPool else { fatalError("Frame \(filename)") }
    var optionalBuffer: CVPixelBuffer?
    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
          let buffer = optionalBuffer else { fatalError("Pixel buffer \(index)") }
    CVPixelBufferLockBaseAddress(buffer, [])
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: colorSpace, bitmapInfo: bitmapInfo) else { fatalError("Context \(index)") }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(index), timescale: 60)) else {
        fatalError("Append \(index): \(String(describing: writer.error))")
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fatalError("Finish: \(String(describing: writer.error))") }
print(outputURL.path)
