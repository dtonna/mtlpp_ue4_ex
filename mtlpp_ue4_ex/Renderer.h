//
//  Renderer.h
//  mtlpp_ue4_ex
//
//  Created by Noppadol Anuroje on 11/11/2564 BE.
//

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject

- (void)renderToMetalLayer:(nonnull CAMetalLayer*)metalLayer;

- (void)drawableResize:(CGSize)drawableSize;

@end

