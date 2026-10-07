import Foundation
import CoreGraphics
import ImageIO
let root = "/Users/anazerka/Telegram-iOS/submodules/TelegramUI/Images.xcassets/Chat/Context Menu"
let output = "/Users/anazerka/Documents/ChatGPT/twelve/demo/Resources/ContextMenu"
for (name, filename) in [("Pin", "ic_lt_pin.pdf"), ("Select", "ic_select.pdf")] {
    for scale in [1,2] {
    let pixels = 24 * scale
    guard let document = CGPDFDocument(URL(fileURLWithPath: "\(root)/\(name).imageset/\(filename)") as CFURL), let page = document.page(at: 1), let context = CGContext(data:nil, width:pixels, height:pixels, bitsPerComponent:8, bytesPerRow:0, space:CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("missing asset") }
    context.concatenate(page.getDrawingTransform(.mediaBox, rect:CGRect(x:0,y:0,width:CGFloat(pixels),height:CGFloat(pixels)), rotate:0, preserveAspectRatio:true))
    context.drawPDFPage(page)
    guard let original = context.makeImage(), let tint = CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("render") }
    tint.draw(original,in:CGRect(x:0,y:0,width:CGFloat(pixels),height:CGFloat(pixels))); tint.setBlendMode(.sourceIn); tint.setFillColor(red:0.32,green:0.39,blue:0.43,alpha:1); tint.fill(CGRect(x:0,y:0,width:CGFloat(pixels),height:CGFloat(pixels)))
    let url = URL(fileURLWithPath:"\(output)/\(name)\(scale == 2 ? "@2x" : "").png")
    guard let image = tint.makeImage(), let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString,1,nil) else { fatalError("export") }
    CGImageDestinationAddImage(destination,image,nil); precondition(CGImageDestinationFinalize(destination))
    }
}
