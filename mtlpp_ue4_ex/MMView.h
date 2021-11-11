//
//  MMView.h
//  mtlpp_ue4_ex
//
//  Created by Noppadol Anuroje on 11/11/2564 BE.
//

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Protocol to provide resize and redraw callbacks to a delegate
@protocol MMViewDelegae <NSObject>

- (void)drawableResize:(CGSize)size;
- (void)renderToMetalLayer:(nonnull CAMetalLayer *)metalLayer;

@end

@interface MMView : UIView <CALayerDelegate>

@property (nonatomic, nonnull, readonly) CAMetalLayer *metalLayer;

@property (nonatomic, getter=isPaused) BOOL paused;

@property (nonatomic, nullable, retain) id<MMViewDelegae> delegate;

- (void)initCommon;

- (void)resizeDrawable:(CGFloat)scaleFactor;

- (void)stopRenderLoop;

- (void)render;

@end

NS_ASSUME_NONNULL_END
