//
//  MetalView.m
//  mtlpp_ue4_ex
//
//  Created by Noppadol Anuroje on 11/11/2564 BE.
//

#import "MetalView.h"

@implementation MetalView
{
    CADisplayLink *_displayLink;
    NSThread *_renderThread;
    BOOL _continueRunLoop;
    UITouch *_currentTouch;
}


+ (Class)layerClass
{
    return [CAMetalLayer class];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window == nil)
    {
        [_displayLink invalidate];
        _displayLink = nil;
        return;
    }
    
    [self setupCADisplayLinkForScreen:self.window.screen];
    
    // Protect _continueRunLoop with a `@synchronized` block since it is accessed by the seperate
    // animation thread
    @synchronized (self) {
        // Stop animation loop allowing the loop to complete if it's in progress.
        _continueRunLoop = NO;
    }
    
    // Create and start a secondary NSThread which will have another run runloop.  The NSThread
    // class will call the 'runThread' method at the start of the secondary thread's execution.
    _renderThread =  [[NSThread alloc] initWithTarget:self selector:@selector(runThread) object:nil];
    _continueRunLoop = YES;
    [_renderThread start];
    
    [self resizeDrawable:self.window.screen.nativeScale];
}

//////////////////////////////////
#pragma mark - Render Loop Control
//////////////////////////////////

- (instancetype) initWithCoder:(NSCoder*)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
//        [self initCommon];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]))
    {
        self.metalLayer.device = MTLCreateSystemDefaultDevice();
        self.metalLayer.presentsWithTransaction = NO;
        self.metalLayer.drawsAsynchronously = YES;
        CGFloat components[] = { 0.0, 0.0, 0.0, 1 };
        self.metalLayer.backgroundColor = CGColorCreate(CGColorSpaceCreateDeviceRGB(), components);
        self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm; // MTLPixelFormatBGRA8Unorm_sRGB;
        //self.metalLayer.framebufferOnly = true; // Note: setting this will dissallow sampling and reading from texture.
        self.metalLayer.framebufferOnly = NO;
        self.metalLayer.frame = frameRect;

        CGSize drawableSize = self.bounds.size;

        // Since drawable size is in pixels, we need to multiply by the scale to move from points to pixels
        CGFloat scale = [UIScreen mainScreen].scale;
        drawableSize.width *= scale;
        drawableSize.height *= scale;

        self.metalLayer.drawableSize = drawableSize;
    }
    return self;
}

- (void)dealloc
{
    [_displayLink invalidate];
    [super dealloc];
}

- (BOOL)acceptsFirstResponder { return YES; }

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    _currentTouch = [touches anyObject];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    _currentTouch = nil;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _currentTouch = nil;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    _currentTouch = [touches anyObject];
}

- (void)runThread
{
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [_displayLink addToRunLoop:runLoop forMode:@"MMDisplayLinkMode"];
    
    BOOL continueRunLoop = YES;
    
    while (continueRunLoop)
    {
        @autoreleasepool {
            [runLoop runMode:@"MMDisplayLinkMode" beforeDate:[NSDate distantFuture]];
        }
        
        @synchronized (self) {
            continueRunLoop = _continueRunLoop;
        }
    }
    
}

- (void)setPaused:(BOOL)paused
{
    super.paused = paused;

    _displayLink.paused = paused;
}

- (void)setupCADisplayLinkForScreen:(UIScreen*)screen
{
    [self stopRenderLoop];

    _displayLink = [screen displayLinkWithTarget:self selector:@selector(render)];

    _displayLink.paused = self.paused;

    _displayLink.preferredFramesPerSecond = 60;
}

- (void)didEnterBackground:(NSNotification*)notification
{
    self.paused = YES;
}

- (void)willEnterForeground:(NSNotification*)notification
{
    self.paused = NO;
}

- (void)stopRenderLoop
{
    [_displayLink invalidate];
}

- (void)setContentScaleFactor:(CGFloat)contentScaleFactor
{
    [super setContentScaleFactor:contentScaleFactor];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self resizeDrawable:self.window.screen.nativeScale];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self resizeDrawable:self.window.screen.nativeScale];
}


@end
