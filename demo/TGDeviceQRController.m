#import "Seven/RT7UIKit.h"
#import "TGDeviceQRController.h"
#import "TGClient.h"
#import "TGLoginQRToken.h"
#import "TGQRStillDecoder.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "qr-codec/quirc.h"

@interface TGDeviceQRController () <AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) TGClient *client;
@property (nonatomic, copy) void (^linked)(NSDictionary *);
@property (nonatomic, strong) AVCaptureSession *capture;
@property (nonatomic, strong) AVCaptureVideoDataOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preview;
@property (nonatomic, strong) UILabel *hint;
@property (nonatomic, strong) UIView *frameView;
@property (nonatomic, strong) UIImageView *capturedView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (atomic) BOOL visible, accepting, foreground;
@property (atomic) BOOL receivedFrame;
@end

@implementation TGDeviceQRController {
    dispatch_queue_t _cameraQueue;
    struct quirc *_decoder;
    CFTimeInterval _lastFrame;
    CFTimeInterval _lastHint;
    int _width, _height;
}
- (instancetype)initWithClient:(TGClient *)client linked:(void (^)(NSDictionary *))linked {
    if ((self = [super init])) {
        _client = client; _linked = [linked copy]; self.title = @"Добавить устройство";
        self.hidesBottomBarWhenPushed = YES;
        _cameraQueue = dispatch_queue_create("telegram.qr.camera", DISPATCH_QUEUE_SERIAL);
        _decoder = quirc_new();
        _foreground = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationInactive:)
            name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationActive:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = RT7Text();
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAtTap:)]];
    self.capture = [[AVCaptureSession alloc] init];
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession:self.capture];
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.preview];
    self.frameView = [[UIView alloc] initWithFrame:CGRectZero];
    self.frameView.userInteractionEnabled = NO;
    self.frameView.layer.borderWidth = 2;
    self.frameView.layer.borderColor = RT7Surface().CGColor;
    self.frameView.layer.cornerRadius = 12;
    self.capturedView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.capturedView.contentMode = UIViewContentModeScaleAspectFit;
    self.capturedView.hidden = YES;
    [self.view addSubview:self.capturedView];
    [self.view addSubview:self.frameView];
    self.hint = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.65];
    self.hint.textColor = RT7Surface(); self.hint.font = RT7Font(15,NO);
    self.hint.textAlignment = NSTextAlignmentCenter; self.hint.numberOfLines = 3;
    self.hint.text = @"Откройте Telegram на компьютере или в браузере и наведите камеру на QR-код входа.";
    [self.view addSubview:self.hint];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.hidesWhenStopped = YES; [self.view addSubview:self.spinner];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize size = self.view.bounds.size;
    CGFloat top = 0, bottom = 0;
#if __LP64__
    if (@available(iOS 11.0, *)) { top = self.view.safeAreaInsets.top; bottom = self.view.safeAreaInsets.bottom; }
#endif
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.preview.frame = self.view.bounds; [CATransaction commit];
    CGFloat side = MIN(240, MIN(size.width - 48, size.height - top - bottom - 120));
    self.frameView.frame = CGRectMake((size.width - side) / 2, top + (size.height - top - bottom - 88 - side) / 2, side, side);
    self.capturedView.frame = self.frameView.frame;
    self.hint.frame = CGRectMake(0, size.height - bottom - 88, size.width, 88);
    self.spinner.center = self.frameView.center;
    if (self.preview.connection.isVideoOrientationSupported) self.preview.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; self.visible = YES;
    self.receivedFrame = NO;
    __weak TGDeviceQRController *watchdog = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        TGDeviceQRController *controller = watchdog;
        if (controller.visible && controller.foreground && !controller.receivedFrame && !controller.accepting)
            controller.hint.text = @"Камера не передаёт изображение сканеру. Вернитесь и откройте сканер ещё раз.";
    });
#if __LP64__
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusNotDetermined) {
        __weak TGDeviceQRController *weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf.visible) return;
                if (granted) [weakSelf startCamera]; else [weakSelf cameraError:@"Разрешите доступ к камере в настройках iPhone."];
            });
        }]; return;
    }
    if (status != AVAuthorizationStatusAuthorized) { [self cameraError:@"Разрешите доступ к камере в настройках iPhone."]; return; }
#endif
    [self startCamera];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; self.visible = NO;
    AVCaptureSession *capture = self.capture;
    dispatch_async(_cameraQueue, ^{ [self.output setSampleBufferDelegate:nil queue:NULL]; [capture stopRunning]; });
}
- (void)startCamera {
    __weak TGDeviceQRController *weakSelf = self;
    dispatch_async(_cameraQueue, ^{
        TGDeviceQRController *controller = weakSelf;
        if (!controller.visible || !controller.foreground) return;
        if (!controller->_decoder) { dispatch_async(dispatch_get_main_queue(), ^{ [controller cameraError:@"Не удалось запустить распознавание QR-кода."]; }); return; }
        if (!controller.capture.inputs.count) {
            AVCaptureDevice *camera = nil;
            for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
                if (device.position == AVCaptureDevicePositionBack) { camera = device; break; }
            NSError *error = nil;
            AVCaptureDeviceInput *input = camera ? [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error] : nil;
            if (!input || ![controller.capture canAddInput:input]) {
                dispatch_async(dispatch_get_main_queue(), ^{ [controller cameraError:@"Не удалось открыть камеру. Проверьте, что её не использует другое приложение."]; }); return;
            }
            [controller.capture beginConfiguration];
            if ([controller.capture canSetSessionPreset:AVCaptureSessionPreset1280x720]) controller.capture.sessionPreset = AVCaptureSessionPreset1280x720;
            else if ([controller.capture canSetSessionPreset:AVCaptureSessionPreset640x480]) controller.capture.sessionPreset = AVCaptureSessionPreset640x480;
            [controller.capture addInput:input];
            AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
            output.alwaysDiscardsLateVideoFrames = YES;
            NSNumber *pixelFormat = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
            if (![output.availableVideoCVPixelFormatTypes containsObject:pixelFormat]) pixelFormat = @(kCVPixelFormatType_32BGRA);
            output.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: pixelFormat };
            [output setSampleBufferDelegate:controller queue:controller->_cameraQueue];
            if (![controller.capture canAddOutput:output]) {
                [controller.capture removeInput:input]; [controller.capture commitConfiguration];
                dispatch_async(dispatch_get_main_queue(), ^{ [controller cameraError:@"Камера не поддерживает режим сканирования."]; }); return;
            }
            controller.output = output; [controller.capture addOutput:output]; [controller.capture commitConfiguration];
            if ([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [camera lockForConfiguration:nil]) {
                camera.focusMode = AVCaptureFocusModeContinuousAutoFocus; [camera unlockForConfiguration];
            }
        }
        if (controller.visible && controller.foreground && !controller.accepting) {
            [controller.output setSampleBufferDelegate:controller queue:controller->_cameraQueue];
            [controller.capture startRunning];
        }
    });
}
- (void)focusAtTap:(UITapGestureRecognizer *)tap {
    if (self.accepting || !self.visible) return;
    CGPoint point = [self.preview captureDevicePointOfInterestForPoint:[tap locationInView:self.view]];
    AVCaptureDevice *camera = [(AVCaptureDeviceInput *)self.capture.inputs.firstObject device];
    dispatch_async(_cameraQueue, ^{
        if (![camera lockForConfiguration:nil]) return;
        if (camera.isFocusPointOfInterestSupported) camera.focusPointOfInterest = point;
        if ([camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) camera.focusMode = AVCaptureFocusModeAutoFocus;
        [camera unlockForConfiguration];
    });
}
- (void)applicationInactive:(NSNotification *)notification {
    self.foreground = NO;
    AVCaptureSession *capture = self.capture;
    dispatch_async(_cameraQueue, ^{ [capture stopRunning]; });
}
- (void)applicationActive:(NSNotification *)notification {
    self.foreground = YES;
    if (self.visible && !self.accepting) [self startCamera];
}
- (void)cameraError:(NSString *)message {
    if (!self.visible) return;
    self.hint.text = message;
    [[[RT7AlertView alloc] initWithTitle:@"Камера" message:message delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
}
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection {
    self.receivedFrame = YES;
    if (!self.visible || !self.foreground || self.accepting || CACurrentMediaTime() - _lastFrame < 0.35) return;
    _lastFrame = CACurrentMediaTime();
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sample);
    if (!buffer) return;
    BOOL planar = CVPixelBufferIsPlanar(buffer);
    OSType format = CVPixelBufferGetPixelFormatType(buffer);
    BOOL yuv = planar && (format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    BOOL bgra = !planar && format == kCVPixelFormatType_32BGRA;
    if (!yuv && !bgra) { [self reportScanHint:@"Не удалось прочитать изображение с камеры." found:NO]; return; }
    int sourceWidth = (int)CVPixelBufferGetWidth(buffer), sourceHeight = (int)CVPixelBufferGetHeight(buffer);
    // Keep the center square at useful resolution: halving an entire VGA frame
    // destroyed small QR modules and made blurred camera images undecodable.
    int cropSide = MIN(sourceWidth, sourceHeight);
    int left = (sourceWidth - cropSide) / 2, top = (sourceHeight - cropSide) / 2;
    int width = MIN(640, cropSide), height = width;
    if (width != _width || height != _height) {
        if (quirc_resize(_decoder, width, height) < 0) return;
        _width = width; _height = height;
    }
    if (CVPixelBufferLockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) return;
    const uint8_t *source = yuv ? CVPixelBufferGetBaseAddressOfPlane(buffer, 0) : CVPixelBufferGetBaseAddress(buffer);
    size_t stride = yuv ? CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) : CVPixelBufferGetBytesPerRow(buffer);
    uint8_t *image = quirc_begin(_decoder, NULL, NULL);
    for (int y = 0; y < height; y++) {
        const uint8_t *row = source + (top + y * cropSide / height) * stride;
        if (yuv && width == cropSide) memcpy(image + y * width, row + left, width);
        else for (int x = 0; x < width; x++) {
            int offset = left + x * cropSide / width;
            if (yuv) image[y * width + x] = row[offset];
            else { const uint8_t *pixel = row + offset * 4; image[y * width + x] = (77 * pixel[2] + 150 * pixel[1] + 29 * pixel[0]) >> 8; }
        }
    }
    CVPixelBufferUnlockBaseAddress(buffer, kCVPixelBufferLock_ReadOnly);
    NSData *snapshot = [NSData dataWithBytes:image length:(NSUInteger)width * height];
    quirc_end(_decoder);
    BOOL found = quirc_count(_decoder) > 0;
    if (found) {
        self.accepting = YES;
        [self readSnapshot:snapshot width:width height:height];
    } else {
        [self reportScanHint:@"Ищу QR-код. Поместите код целиком в рамку." found:NO];
    }
}
- (void)readSnapshot:(NSData *)snapshot width:(int)width height:(int)height {
    __weak TGDeviceQRController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        TGDeviceQRController *controller = weakSelf;
        if (!controller.visible) return;
        CGColorSpaceRef color = CGColorSpaceCreateDeviceGray();
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)snapshot);
        CGImageRef image = CGImageCreate(width, height, 8, 8, width, color, (CGBitmapInfo)kCGImageAlphaNone,
                                        provider, NULL, NO, kCGRenderingIntentDefault);
        if (image) controller.capturedView.image = [UIImage imageWithCGImage:image scale:1 orientation:UIImageOrientationRight];
        if (image) CGImageRelease(image);
        CGDataProviderRelease(provider); CGColorSpaceRelease(color);
        controller.capturedView.hidden = NO;
        controller.frameView.layer.borderColor = [UIColor greenColor].CGColor;
        controller.hint.text = @"QR-код сфотографирован. Можно убрать телефон — читаю снимок…";
        [controller.spinner startAnimating];
    });
    // Run after the capture delegate returns, so stopping the camera cannot
    // wait on its own callback. All decode passes operate on the saved image.
    dispatch_async(_cameraQueue, ^{
        TGDeviceQRController *controller = weakSelf;
        if (!controller.visible) return;
        [controller.capture stopRunning];
        NSData *token = TGDecodeLoginQRStill(snapshot, width, height, ^BOOL{
            return controller.visible;
        });
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!controller.visible) return;
            if (token) [controller acceptToken:token];
            else {
                [controller.spinner stopAnimating];
                [[[RT7AlertView alloc] initWithTitle:@"Не удалось прочитать снимок"
                    message:@"Код нечёткий или не является QR-кодом входа в Telegram. Попробуйте снять его чуть ближе."
                    delegate:controller cancelButtonTitle:@"Снять ещё раз" otherButtonTitles:nil] show];
            }
        });
    });
}
- (void)reportScanHint:(NSString *)hint found:(BOOL)found {
    if (CACurrentMediaTime() - _lastHint < 1) return;
    _lastHint = CACurrentMediaTime();
    __weak TGDeviceQRController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        TGDeviceQRController *controller = weakSelf;
        if (!controller.visible || controller.accepting) return;
        controller.hint.text = hint;
        controller.frameView.layer.borderColor = (found ? [UIColor colorWithRed:1 green:0.7 blue:0.2 alpha:1] : RT7Surface()).CGColor;
    });
}
- (void)acceptToken:(NSData *)token {
    [self.spinner startAnimating]; self.hint.text = @"Подключаем устройство…";
    __weak TGDeviceQRController *weakSelf = self;
    [self.client acceptDeviceLoginToken:token completion:^(NSDictionary *result, NSString *error) {
        TGDeviceQRController *controller = weakSelf;
        if (!controller || !controller.visible) return;
        [controller.spinner stopAnimating];
        if (!error && ![result[@"_"] isEqual:@"authorization"]) error = @"Telegram не подтвердил вход.";
        if (error) {
            if ([error hasPrefix:@"AUTH_TOKEN_EXPIRED"]) error = @"QR-код устарел. Наведите камеру на обновлённый код.";
            else if ([error hasPrefix:@"AUTH_TOKEN_ALREADY_ACCEPTED"]) error = @"Этот код уже использован. Обновите его на другом устройстве.";
            else if ([error hasPrefix:@"AUTH_TOKEN_INVALID"]) error = @"Неверный QR-код входа. Обновите его в Telegram.";
            [[[RT7AlertView alloc] initWithTitle:@"Подключение устройства" message:error delegate:controller cancelButtonTitle:@"ОК" otherButtonTitles:nil] show];
        } else {
            void (^linked)(NSDictionary *) = controller.linked;
            [controller.navigationController popViewControllerAnimated:YES];
            if (linked) linked(result);
        }
    }];
}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    self.accepting = NO;
    self.capturedView.hidden = YES; self.capturedView.image = nil;
    self.frameView.layer.borderColor = RT7Surface().CGColor;
    self.hint.text = @"Наведите камеру на QR-код входа в Telegram.";
    if (self.visible) [self startCamera];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_output setSampleBufferDelegate:nil queue:NULL];
    quirc_destroy(_decoder);
}
@end
