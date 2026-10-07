import AppKit
import AVFoundation
for name in ["IntroPhone", "IntroMessage"] {
 let asset = AVURLAsset(url: URL(fileURLWithPath: "Resources/\(name).mp4"))
 let track = asset.tracks(withMediaType: .video)[0]
 print(name, track.naturalSize, track.nominalFrameRate, asset.duration.seconds)
 let reader = try AVAssetReader(asset: asset)
 let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
 reader.add(output); reader.startReading()
 var count = 0
 while let sample = output.copyNextSampleBuffer() {
  let buffer = CMSampleBufferGetImageBuffer(sample)!
  if count == 60 {
   CVPixelBufferLockBaseAddress(buffer, .readOnly)
   for plane in 0..<2 {
    let data = Data(bytes: CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!, count: CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)*CVPixelBufferGetHeightOfPlane(buffer, plane))
    try data.write(to: URL(fileURLWithPath:"asset-build/\(name)-plane\(plane).raw"))
    print("plane",plane,CVPixelBufferGetWidthOfPlane(buffer,plane),CVPixelBufferGetHeightOfPlane(buffer,plane),CVPixelBufferGetBytesPerRowOfPlane(buffer,plane))
   }
   CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  }
  count += 1
 }
 print("decoded",count, "status",reader.status.rawValue)
}
