#import "Seven/RT7UIKit.h"
#import "TGTransparentAnimationView.h"
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGLES/ES2/glext.h>

static GLuint TGAlphaShader(GLenum type, const GLchar *source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint compiled = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) { glDeleteShader(shader); return 0; }
    return shader;
}

@interface TGTransparentAnimationView () <GLKViewDelegate>
@end

@implementation TGTransparentAnimationView {
    NSString *_resourceName;
    UIImageView *_poster;
    AVPlayer *_player;
    AVPlayerItemVideoOutput *_output;
    EAGLContext *_context;
    GLKView *_canvas;
    CADisplayLink *_displayLink;
    CVOpenGLESTextureCacheRef _cache;
    CVOpenGLESTextureRef _luma, _chroma;
    GLuint _program;
    GLint _rangeUniform;
    BOOL _wantsPlayback, _finished, _videoRange;
}
- (instancetype)initWithFrame:(CGRect)frame resourceName:(NSString *)resourceName {
    self = [super initWithFrame:frame];
    if (self) {
        _resourceName = [resourceName copy];
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        _poster = [[UIImageView alloc] initWithImage:RT7ImageNamed([resourceName stringByAppendingString:@"Poster.png"])];
        _poster.frame = self.bounds;
        _poster.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _poster.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_poster];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inactive:)
            name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(active:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}
- (BOOL)preparePlayback {
    if (_player) return YES;
    NSString *path = [[NSBundle mainBundle] pathForResource:_resourceName ofType:@"mp4"];
    if (!path) return NO;
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) return NO;
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    const GLchar *vertex =
        "attribute vec2 position; attribute vec2 coordinate; varying vec2 uv;"
        "void main(){ gl_Position=vec4(position,0.0,1.0); uv=coordinate; }";
    // The left half stores premultiplied color, the right half stores opacity.
    // Native YUV decoder surfaces are sampled directly without CPU image copies.
    const GLchar *fragment =
        "precision mediump float; varying vec2 uv;"
        "uniform sampler2D luma; uniform sampler2D chroma; uniform float limited;"
        "void main(){"
        "vec2 c=vec2(uv.x*0.5,uv.y); vec2 m=vec2(c.x+0.5,c.y);"
        "float ys=mix(1.0,255.0/219.0,limited); float off=limited*16.0/255.0;"
        "float y=(texture2D(luma,c).r-off)*ys;"
        "vec2 cbcr=(texture2D(chroma,c).ra-vec2(128.0/255.0))*mix(1.0,255.0/224.0,limited);"
        "vec3 rgb=vec3(y+1.402*cbcr.y,y-0.344136*cbcr.x-0.714136*cbcr.y,y+1.772*cbcr.x);"
        "float a=clamp((texture2D(luma,m).r-off)*ys,0.0,1.0);"
        "if(a<0.004){ a=0.0; }"
        "gl_FragColor=vec4(clamp(rgb,vec3(0.0),vec3(a)),a); }";
    GLuint vs = TGAlphaShader(GL_VERTEX_SHADER, vertex), fs = TGAlphaShader(GL_FRAGMENT_SHADER, fragment);
    if (vs && fs) {
        _program = glCreateProgram();
        glAttachShader(_program, vs); glAttachShader(_program, fs);
        glBindAttribLocation(_program, 0, "position");
        glBindAttribLocation(_program, 1, "coordinate");
        glLinkProgram(_program);
        GLint linked = 0; glGetProgramiv(_program, GL_LINK_STATUS, &linked);
        if (!linked) { glDeleteProgram(_program); _program = 0; }
    }
    if (vs) glDeleteShader(vs);
    if (fs) glDeleteShader(fs);
    CVReturn result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_cache);
    if (!_program || result != kCVReturnSuccess) {
        [self releaseRenderer];
        [EAGLContext setCurrentContext:previous];
        return NO;
    }
    glUseProgram(_program);
    glUniform1i(glGetUniformLocation(_program, "luma"), 0);
    glUniform1i(glGetUniformLocation(_program, "chroma"), 1);
    _rangeUniform = glGetUniformLocation(_program, "limited");
    [EAGLContext setCurrentContext:previous];
    _canvas = [[GLKView alloc] initWithFrame:self.bounds context:_context];
    _canvas.delegate = self;
    _canvas.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _canvas.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    _canvas.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    _canvas.enableSetNeedsDisplay = NO;
    _canvas.opaque = NO;
    _canvas.layer.opaque = NO;
    _canvas.backgroundColor = [UIColor clearColor];
    [self insertSubview:_canvas belowSubview:_poster];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:path]];
    _output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        (id)kCVPixelBufferOpenGLESCompatibilityKey: @YES
    }];
    _output.suppressesPlayerRendering = YES;
    [item addOutput:_output];
    _player = [AVPlayer playerWithPlayerItem:item];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finish:)
        name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    return YES;
}
- (void)play {
    if (_finished) return;
    _wantsPlayback = YES;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive || !self.window) return;
    if (![self preparePlayback]) { [self finish:nil]; return; }
    [_player play];
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)stopDisplayLink { [_displayLink invalidate]; _displayLink = nil; }
- (void)pause { _wantsPlayback = NO; [_player pause]; [self stopDisplayLink]; }
- (void)inactive:(NSNotification *)notification { [_player pause]; [self stopDisplayLink]; }
- (void)active:(NSNotification *)notification { if (_wantsPlayback && self.window) [self play]; }
- (void)tick:(CADisplayLink *)link {
    CMTime time = [_output itemTimeForHostTime:link.timestamp + link.duration];
    if (![_output hasNewPixelBufferForItemTime:time]) return;
    CVPixelBufferRef buffer = [_output copyPixelBufferForItemTime:time itemTimeForDisplay:NULL];
    if (!buffer) return;
    if (CVPixelBufferGetPlaneCount(buffer) != 2) { CVPixelBufferRelease(buffer); return; }
    EAGLContext *previous = [EAGLContext currentContext];
    [EAGLContext setCurrentContext:_context];
    if (_luma) { CFRelease(_luma); _luma = NULL; }
    if (_chroma) { CFRelease(_chroma); _chroma = NULL; }
    CVOpenGLESTextureCacheFlush(_cache, 0);
    CVReturn y = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _cache, buffer, NULL,
        GL_TEXTURE_2D, GL_LUMINANCE, (GLsizei)CVPixelBufferGetWidthOfPlane(buffer, 0),
        (GLsizei)CVPixelBufferGetHeightOfPlane(buffer, 0), GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &_luma);
    CVReturn uv = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _cache, buffer, NULL,
        GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, (GLsizei)CVPixelBufferGetWidthOfPlane(buffer, 1),
        (GLsizei)CVPixelBufferGetHeightOfPlane(buffer, 1), GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_chroma);
    _videoRange = CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    CVPixelBufferRelease(buffer);
    if (y == kCVReturnSuccess && uv == kCVReturnSuccess) {
        [_canvas display];
        _poster.hidden = YES;
    }
    [EAGLContext setCurrentContext:previous];
}
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glViewport(0, 0, (GLsizei)view.drawableWidth, (GLsizei)view.drawableHeight);
    glClearColor(0, 0, 0, 0); glClear(GL_COLOR_BUFFER_BIT);
    if (!_luma || !_chroma) return;
    glDisable(GL_BLEND); glDisable(GL_DEPTH_TEST);
    glUseProgram(_program);
    glUniform1f(_rangeUniform, _videoRange ? 1.0f : 0.0f);
    CVOpenGLESTextureRef textures[] = {_luma, _chroma};
    for (NSUInteger i = 0; i < 2; i++) {
        glActiveTexture(GL_TEXTURE0 + (GLenum)i);
        glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(textures[i]));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    const GLfloat positions[] = {-1,-1, 1,-1, -1,1, 1,1};
    GLfloat ll[2], lr[2], ur[2], ul[2];
    CVOpenGLESTextureGetCleanTexCoords(_luma, ll, lr, ur, ul);
    GLfloat coordinates[] = {ll[0],ll[1], lr[0],lr[1], ul[0],ul[1], ur[0],ur[1]};
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, positions);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, coordinates);
    glEnableVertexAttribArray(0); glEnableVertexAttribArray(1);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(0); glDisableVertexAttribArray(1);
}
- (void)finish:(NSNotification *)notification {
    if (![NSThread isMainThread]) {
        __weak TGTransparentAnimationView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf finish:notification]; });
        return;
    }
    _finished = YES;
    [self pause];
    _poster.image = RT7ImageNamed([_resourceName stringByAppendingString:@"Last.png"]);
    _poster.hidden = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    if (_output) [_player.currentItem removeOutput:_output];
    _player = nil; _output = nil;
    [self releaseRenderer];
}
- (void)releaseRenderer {
    EAGLContext *previous = [EAGLContext currentContext];
    if (_context) [EAGLContext setCurrentContext:_context];
    _canvas.delegate = nil;
    [_canvas deleteDrawable];
    [_canvas removeFromSuperview]; _canvas = nil;
    if (_luma) { CFRelease(_luma); _luma = NULL; }
    if (_chroma) { CFRelease(_chroma); _chroma = NULL; }
    if (_cache) { CFRelease(_cache); _cache = NULL; }
    if (_program) { glDeleteProgram(_program); _program = 0; }
    [EAGLContext setCurrentContext:previous == _context ? nil : previous];
    _context = nil;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopDisplayLink];
    [_player pause];
    [self releaseRenderer];
}
@end
