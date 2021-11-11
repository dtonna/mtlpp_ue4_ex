//
//  GameViewController.m
//  mtlpp_ue4_ex
//
//  Created by Noppadol Anuroje on 11/11/2564 BE.
//

#import <QuartzCore/CAMetalLayer.h>
#import "GameViewController.h"
#import "Renderer.h"
#import "MetalView.h"

@implementation GameViewController
{
    MetalView *_view;
    Renderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    CGRect contentSize = self.view.bounds;

    _view = [[MetalView alloc] initWithFrame:contentSize];
    _view.bounds = contentSize;
    _view.delegate = self;
    [self.view addSubview:_view];
    
    _renderer = [[Renderer alloc] initWithLayer:_view.metalLayer];
    
    [_renderer drawableResize:_view.bounds.size];
}

-(void)dealloc
{
    [_renderer dealloc];
    [_view dealloc];
    [super dealloc];
}

-(BOOL)prefersStatusBarHidden
{
    return YES;
}

-(BOOL)prefersHomeIndicatorAutoHidden
{
    return YES;
}

- (void)drawableResize:(CGSize)size
{
    [_renderer drawableResize:size];
}

- (void)renderToMetalLayer:(nonnull CAMetalLayer *)layer
{
    [_renderer renderToMetalLayer:layer];
}

@end
