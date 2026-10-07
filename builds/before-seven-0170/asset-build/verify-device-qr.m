#import <Foundation/Foundation.h>
#import "TGLoginQRToken.h"
#import "TGQRStillDecoder.h"
#import "qr-codec/quirc.h"
static void checkPayload(NSString *uri) {
 NSData *token=TGLoginQRToken(uri); assert(token.length==32);
 const uint8_t *bytes=token.bytes;
 for (int i=0;i<32;i++) assert(bytes[i]==224+i);
}
int main() { @autoreleasepool {
 NSArray *metadata=[[NSString stringWithContentsOfFile:@"asset-build/qr-fixture.txt" encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
 int side=[metadata[0] intValue];NSString *uri=metadata[1];
 checkPayload(uri);checkPayload([uri stringByAppendingString:@"="]);
 assert(!TGLoginQRToken([uri stringByReplacingOccurrencesOfString:@"tg://" withString:@"https://"]));
 assert(!TGLoginQRToken([uri stringByReplacingOccurrencesOfString:@"login?" withString:@"login/path?"]));
 assert(!TGLoginQRToken([uri stringByAppendingString:@"&token=AAAA"]));
 assert(!TGLoginQRToken(@"tg://login?token=bad"));
 checkPayload([uri stringByAppendingString:@"%3D"]);
 assert(!TGLoginQRToken([uri stringByAppendingString:@"%ZZ"]));
 assert(!TGLoginQRToken([uri stringByAppendingString:@"==="]));
 assert(!TGLoginQRToken([uri stringByReplacingOccurrencesOfString:@"tg://" withString:@"tg://user@"]));
 NSData *raw=[NSData dataWithContentsOfFile:@"asset-build/qr-fixture.raw"];
 assert(raw.length==side*side);
 for(int rotation=0;rotation<2;rotation++) {
 struct quirc *q=quirc_new();assert(q && !quirc_resize(q,side,side));
 uint8_t *image=quirc_begin(q,NULL,NULL); const uint8_t *source=raw.bytes;
 for(int y=0;y<side;y++)for(int x=0;x<side;x++) image[y*side+x]=rotation?source[(side-1-x)*side+y]:source[y*side+x];
 quirc_end(q);assert(quirc_count(q)>0);BOOL found=NO;
 for(int i=0;i<quirc_count(q);i++) { struct quirc_code code;struct quirc_data data;quirc_extract(q,i,&code);
 if(!quirc_decode(&code,&data)) { NSString *decoded=[[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSUTF8StringEncoding];
 if([decoded isEqual:uri]) {checkPayload(decoded);found=YES;} }
 }assert(found);quirc_destroy(q);
 }
 NSData *camera=[NSData dataWithContentsOfFile:@"asset-build/qr-camera-fixture.raw"];
 assert(camera.length==640*480);
 struct quirc *q=quirc_new(); assert(!quirc_resize(q,480,480));
 uint8_t *image=quirc_begin(q,NULL,NULL);const uint8_t *cameraBytes=camera.bytes;
 for(int row=0;row<480;row++) memcpy(image+row*480,cameraBytes+row*640+80,480);
 quirc_end(q);BOOL recognized=NO;
 for(int i=0;i<quirc_count(q);i++) { struct quirc_code code;struct quirc_data data;quirc_extract(q,i,&code);
 if(!quirc_decode(&code,&data)) { NSString *decoded=[[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSUTF8StringEncoding];
 if([decoded isEqual:uri])recognized=YES; }
 }assert(recognized);quirc_destroy(q);
 NSData *stillToken=TGDecodeLoginQRStill(raw,side,side,^BOOL{return YES;});
 assert(stillToken.length==32);
 NSMutableData *saved=[NSMutableData dataWithData:raw];
 NSData *frozen=[saved copy]; memset(saved.mutableBytes,0,saved.length);
 assert(TGDecodeLoginQRStill(frozen,side,side,^BOOL{return YES;}).length==32);
 assert(!TGDecodeLoginQRStill(frozen,side,side,^BOOL{return NO;}));
 assert(!TGDecodeLoginQRStill([NSMutableData dataWithLength:side*side],side,side,^BOOL{return YES;}));
 puts("Saved frame: decoded after live buffer changed; cancellation and unreadable photo passed.");
 puts("Camera fixture: smaller blurred QR recognized at native resolution.");
 puts("QR decoder: generated Telegram login QR upright/rotated passed; token decoding and invalid URI tests passed.");
} }
