import AppKit
import CoreImage
let token = Data((224...255).map { UInt8($0) }).base64EncodedString().replacingOccurrences(of:"+", with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
let uri = "tg://login?token=" + token
let filter = CIFilter(name:"CIQRCodeGenerator")!
filter.setValue(uri.data(using:.utf8)!,forKey:"inputMessage")
filter.setValue("M",forKey:"inputCorrectionLevel")
let image = filter.outputImage!
let cg = CIContext(options:nil).createCGImage(image,from:image.extent)!
let side = (cg.width + 8) * 5
var bytes = [UInt8](repeating:255,count:side*side)
let context = CGContext(data:&bytes,width:side,height:side,bitsPerComponent:8,bytesPerRow:side,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0)!
context.interpolationQuality = .none
context.draw(cg,in:CGRect(x:20,y:20,width:cg.width*5,height:cg.height*5))
try Data(bytes).write(to:URL(fileURLWithPath:"asset-build/qr-fixture.raw"))
try "\(side)\n\(uri)".write(toFile:"asset-build/qr-fixture.txt",atomically:true,encoding:.utf8)
print("QR test fixture", side, "pixels")
