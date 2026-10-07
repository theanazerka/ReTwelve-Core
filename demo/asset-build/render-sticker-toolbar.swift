import Foundation
import CoreGraphics
import ImageIO
let root = "/Users/anazerka/Telegram-iOS/submodules/TelegramUI/Images.xcassets/Chat/Attach Menu"
let output = "/Users/anazerka/Documents/ChatGPT/twelve/demo/Resources/StickerKeyboard"
for (name, file) in [("Emoji", "Emoji.imageset/emojitab.pdf"), ("Sticker", "Sticker.imageset/stickertab.pdf")] {
 for scale in [1, 2] {
  for selected in [false, true] {
   let side = 24 * scale
   guard let doc = CGPDFDocument(URL(fileURLWithPath: "\(root)/\(file)") as CFURL), let page = doc.page(at:1), let ctx = CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("missing asset") }
   ctx.concatenate(page.getDrawingTransform(.mediaBox,rect:CGRect(x:0,y:0,width:side,height:side),rotate:0,preserveAspectRatio:true));ctx.drawPDFPage(page)
   guard let icon = ctx.makeImage(), let tint = CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("render") }
   tint.draw(icon,in:CGRect(x:0,y:0,width:side,height:side));tint.setBlendMode(.sourceIn);tint.setFillColor(red:selected ? 0.12 : 0.30,green:selected ? 0.43 : 0.35,blue:selected ? 0.72 : 0.41,alpha:1);tint.fill(CGRect(x:0,y:0,width:side,height:side))
   let url=URL(fileURLWithPath:"\(output)/\(name)\(selected ? "Selected" : "")\(scale == 2 ? "@2x" : "").png")
   guard let image=tint.makeImage(),let dest=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil) else { fatalError("write") };CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
  }
 }
}
