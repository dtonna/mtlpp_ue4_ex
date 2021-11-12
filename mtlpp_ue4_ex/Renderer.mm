//
//  Renderer.m
//  mtlpp_ue4_ex
//
//  Created by Noppadol Anuroje on 11/11/2564 BE.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>
#import "Renderer.h"

// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"
#include "renderer/mtlpp/mtlpp.hpp"

static const NSUInteger MaxBuffersInFlight = 3;

@implementation Renderer
{
    dispatch_semaphore_t _inFlightSemaphore;
//    id <MTLDevice> _device;
//    id <MTLCommandQueue> _commandQueue;
//
//    id <MTLBuffer> _dynamicUniformBuffer[MaxBuffersInFlight];
//    id <MTLRenderPipelineState> _pipelineState;
//    id <MTLDepthStencilState> _depthState;
//    id <MTLTexture> _colorMap;
//    MTLVertexDescriptor *_mtlVertexDescriptor;

    mtlpp::Device device_;
    mtlpp::CommandQueue commandQueue_;
    mtlpp::RenderPassDescriptor _drawableRenderDescriptor;
    mtlpp::Buffer _dynamicUniformBuffer[MaxBuffersInFlight];
    mtlpp::Buffer _dynamicUniformBuffer2[MaxBuffersInFlight];
    mtlpp::RenderPipelineState _pipelineState;
    mtlpp::DepthStencilState _depthState;
    mtlpp::RenderPipelineState _pipelineState2;
    mtlpp::DepthStencilState _depthState2;
    mtlpp::Texture _depthTexture;
    mtlpp::Texture _colorMap;
    mtlpp::VertexDescriptor _mtlVertexDescriptor;

    float _depth;

    uint8_t _uniformBufferIndex;

    matrix_float4x4 _projectionMatrix;

    float _rotation;

    MTKMesh *_mesh;
}

-(nonnull instancetype)initWithLayer:(CAMetalLayer *)layer
{
    self = [super init];
    if(self)
    {
        device_ = layer.device;
        _inFlightSemaphore = dispatch_semaphore_create(MaxBuffersInFlight);
        _depth = 0.0;
        [self _loadMetal];
        [self _loadAssets];
    }

    return self;
}
- (void)_loadMetal
{
    ns::Array<mtlpp::VertexBufferLayoutDescriptor> vertexLayouts = _mtlVertexDescriptor.GetLayouts();
    ns::Array<mtlpp::VertexAttributeDescriptor> attribs = _mtlVertexDescriptor.GetAttributes();
    
    unsigned int attribIdx = VertexAttributePosition;
    attribs[attribIdx].SetFormat(mtlpp::VertexFormat::Float3);
    attribs[attribIdx].SetOffset(0);
    attribs[attribIdx].SetBufferIndex(BufferIndexMeshPositions);

    attribs[(unsigned int)VertexAttributeTexcoord].SetFormat(mtlpp::VertexFormat::Float2);
    attribs[(unsigned int)VertexAttributeTexcoord].SetOffset(0);
    attribs[(unsigned int)VertexAttributeTexcoord].SetBufferIndex(BufferIndexMeshGenerics);

    vertexLayouts[(unsigned int)BufferIndexMeshPositions].SetStride(12);
    vertexLayouts[(unsigned int)BufferIndexMeshPositions].SetStepRate(1);
    vertexLayouts[(unsigned int)BufferIndexMeshPositions].SetStepFunction(mtlpp::VertexStepFunction::PerVertex);

    vertexLayouts[(unsigned int)BufferIndexMeshGenerics].SetStride(8);
    vertexLayouts[(unsigned int)BufferIndexMeshGenerics].SetStepRate(1);
    vertexLayouts[(unsigned int)BufferIndexMeshGenerics].SetStepFunction(mtlpp::VertexStepFunction::PerVertex);
    
    mtlpp::Library defaultLibrary = device_.NewDefaultLibrary();
    ns::AutoReleased<mtlpp::Function> vertexFunction(defaultLibrary.NewFunction("vertexShader"));
    ns::AutoReleased<mtlpp::Function> fragmentFunction(defaultLibrary.NewFunction("fragmentShader"));
    ns::AutoReleased<mtlpp::Function> fragmentFunction2(defaultLibrary.NewFunction("fragmentShader2"));

    mtlpp::RenderPipelineDescriptor pipelineStateDescriptor;
    pipelineStateDescriptor.SetLabel("MyPipeline");
    pipelineStateDescriptor.SetSampleCount(1);
    pipelineStateDescriptor.SetVertexFunction(vertexFunction);
    pipelineStateDescriptor.SetFragmentFunction(fragmentFunction);
    pipelineStateDescriptor.SetVertexDescriptor(_mtlVertexDescriptor);
    pipelineStateDescriptor.GetColorAttachments()[0].SetPixelFormat(mtlpp::PixelFormat::BGRA8Unorm);
    pipelineStateDescriptor.SetDepthAttachmentPixelFormat(mtlpp::PixelFormat::Depth32Float_Stencil8);
    pipelineStateDescriptor.SetStencilAttachmentPixelFormat(mtlpp::PixelFormat::Depth32Float_Stencil8);

    ns::AutoReleasedError *error = NULL;
    _pipelineState = device_.NewRenderPipelineState(pipelineStateDescriptor, error);
    if (!_pipelineState)
    {
        NSLog(@"Failed to created pipeline state, error %s", error->GetLocalizedDescription().GetCStr());
    }

    mtlpp::DepthStencilDescriptor depthStateDesc;
    depthStateDesc.SetDepthCompareFunction(mtlpp::CompareFunction::Less);
    depthStateDesc.SetDepthWriteEnabled(true);
    
    mtlpp::StencilDescriptor frontStencilDesc;
    frontStencilDesc.SetStencilCompareFunction(mtlpp::CompareFunction::Always);
    frontStencilDesc.SetStencilFailureOperation(mtlpp::StencilOperation::Keep);
    frontStencilDesc.SetDepthFailureOperation(mtlpp::StencilOperation::Keep);
    frontStencilDesc.SetDepthStencilPassOperation(mtlpp::StencilOperation::Replace);
    frontStencilDesc.SetReadMask(0xFF);
    frontStencilDesc.SetWriteMask(1);
    
    depthStateDesc.SetFrontFaceStencil(frontStencilDesc);
    depthStateDesc.SetBackFaceStencil(nil);
    
    _depthState = device_.NewDepthStencilState(depthStateDesc);
    
    /* Frame */
    mtlpp::RenderPipelineDescriptor pipelineStateDescriptor2;
    pipelineStateDescriptor2.SetLabel("MyPipeline2");
    pipelineStateDescriptor2.SetSampleCount(1);
    pipelineStateDescriptor2.SetVertexFunction(vertexFunction);
    pipelineStateDescriptor2.SetFragmentFunction(fragmentFunction2);
    pipelineStateDescriptor2.SetVertexDescriptor(_mtlVertexDescriptor);
    pipelineStateDescriptor2.GetColorAttachments()[0].SetPixelFormat(mtlpp::PixelFormat::BGRA8Unorm);
    pipelineStateDescriptor2.SetDepthAttachmentPixelFormat(mtlpp::PixelFormat::Depth32Float_Stencil8);
    pipelineStateDescriptor2.SetStencilAttachmentPixelFormat(mtlpp::PixelFormat::Depth32Float_Stencil8);

    _pipelineState2 = device_.NewRenderPipelineState(pipelineStateDescriptor2, error);
    if (!_pipelineState2)
    {
        NSLog(@"Failed to created pipeline state, error %s", error->GetLocalizedDescription().GetCStr());
    }

    mtlpp::DepthStencilDescriptor depthStateDesc2;
    depthStateDesc2.SetDepthWriteEnabled(NO);
    
    mtlpp::StencilDescriptor frontStencilDesc2;
    frontStencilDesc2.SetStencilCompareFunction(mtlpp::CompareFunction::NotEqual);
    frontStencilDesc2.SetStencilFailureOperation(mtlpp::StencilOperation::Keep);
    frontStencilDesc2.SetDepthFailureOperation(mtlpp::StencilOperation::Keep);
    frontStencilDesc2.SetDepthStencilPassOperation(mtlpp::StencilOperation::Replace);
    frontStencilDesc2.SetReadMask(0xFF);
    frontStencilDesc2.SetWriteMask(1);
    
    depthStateDesc2.SetFrontFaceStencil(frontStencilDesc2);
    depthStateDesc2.SetBackFaceStencil(nil);
    
    _depthState2 = device_.NewDepthStencilState(depthStateDesc2);

    for(NSUInteger i = 0; i < MaxBuffersInFlight; i++)
    {
        _dynamicUniformBuffer[i] = device_.NewBuffer(sizeof(Uniforms), mtlpp::ResourceOptions::StorageModeShared);
        _dynamicUniformBuffer[i].SetLabel("UniformBuffer");
        _dynamicUniformBuffer2[i] = device_.NewBuffer(sizeof(Uniforms), mtlpp::ResourceOptions::StorageModeShared);
        _dynamicUniformBuffer2[i].SetLabel("UniformBuffer2");
    }

    commandQueue_ = device_.NewCommandQueue();

    _drawableRenderDescriptor.GetColorAttachments()[0].SetLoadAction(mtlpp::LoadAction::Clear);
    _drawableRenderDescriptor.GetColorAttachments()[0].SetStoreAction(mtlpp::StoreAction::Store);
    _drawableRenderDescriptor.GetColorAttachments()[0].SetClearColor(mtlpp::ClearColor(0, 0, 0, 1.0));
}

-(void)dealloc
{
    [_colorMap release];
    [_mesh release];
    

    [super dealloc];
}

//-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;
//{
//    self = [super init];
//    if(self)
//    {
//        _device = view.device;
//        _inFlightSemaphore = dispatch_semaphore_create(MaxBuffersInFlight);
//        [self _loadMetalWithView:view];
//        [self _loadAssets];
//    }
//
//    return self;
//}

//- (void)_loadMetalWithView:(nonnull MTKView *)view;
//{
//    /// Load Metal state objects and initialize renderer dependent view properties
//
//    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
//    view.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
//    view.sampleCount = 1;
//
//    _mtlVertexDescriptor = [[MTLVertexDescriptor alloc] init];
//
//    _mtlVertexDescriptor.attributes[VertexAttributePosition].format = MTLVertexFormatFloat3;
//    _mtlVertexDescriptor.attributes[VertexAttributePosition].offset = 0;
//    _mtlVertexDescriptor.attributes[VertexAttributePosition].bufferIndex = BufferIndexMeshPositions;
//
//    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].format = MTLVertexFormatFloat2;
//    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].offset = 0;
//    _mtlVertexDescriptor.attributes[VertexAttributeTexcoord].bufferIndex = BufferIndexMeshGenerics;
//
//    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stride = 12;
//    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepRate = 1;
//    _mtlVertexDescriptor.layouts[BufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
//
//    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stride = 8;
//    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepRate = 1;
//    _mtlVertexDescriptor.layouts[BufferIndexMeshGenerics].stepFunction = MTLVertexStepFunctionPerVertex;
//
//    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
//
//    id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"];
//
//    id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"];
//
//    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
//    pipelineStateDescriptor.label = @"MyPipeline";
//    pipelineStateDescriptor.sampleCount = view.sampleCount;
//    pipelineStateDescriptor.vertexFunction = vertexFunction;
//    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
//    pipelineStateDescriptor.vertexDescriptor = _mtlVertexDescriptor;
//    pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat;
//    pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
//    pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
//
//    NSError *error = NULL;
//    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
//    if (!_pipelineState)
//    {
//        NSLog(@"Failed to created pipeline state, error %@", error);
//    }
//
//    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
//    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
//    depthStateDesc.depthWriteEnabled = YES;
//    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
//
//    for(NSUInteger i = 0; i < MaxBuffersInFlight; i++)
//    {
//        _dynamicUniformBuffer[i] = [_device newBufferWithLength:sizeof(Uniforms)
//                                                        options:MTLResourceStorageModeShared];
//
//        _dynamicUniformBuffer[i].label = @"UniformBuffer";
//    }
//
//    _commandQueue = [_device newCommandQueue];
//}

- (void)_loadAssets
{
    /// Load assets into metal objects

    NSError *error = nil; // add initialize to nil

    MTKMeshBufferAllocator *metalAllocator = [[MTKMeshBufferAllocator alloc]
                                              initWithDevice: device_];

    MDLMesh *mdlMesh = [MDLMesh newBoxWithDimensions:(vector_float3){4, 4, 4}
                                            segments:(vector_uint3){2, 2, 2}
                                        geometryType:MDLGeometryTypeTriangles
                                       inwardNormals:NO
                                           allocator:metalAllocator];

    MDLVertexDescriptor *mdlVertexDescriptor =
    MTKModelIOVertexDescriptorFromMetal(_mtlVertexDescriptor);

    mdlVertexDescriptor.attributes[VertexAttributePosition].name  = MDLVertexAttributePosition;
    mdlVertexDescriptor.attributes[VertexAttributeTexcoord].name  = MDLVertexAttributeTextureCoordinate;

    mdlMesh.vertexDescriptor = mdlVertexDescriptor;

    _mesh = [[MTKMesh alloc] initWithMesh:mdlMesh
                                   device:device_
                                    error:&error];

    if(!_mesh || error)
    {
        NSLog(@"Error creating MetalKit mesh %@", error.localizedDescription);
    }

    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:device_];

    NSDictionary *textureLoaderOptions =
    @{
      MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
      MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)
      };

    _colorMap = [textureLoader newTextureWithName:@"ColorMap"
                                      scaleFactor:1.0
                                           bundle:nil
                                          options:textureLoaderOptions
                                            error:&error];

    if(!_colorMap || error)
    {
        NSLog(@"Error creating texture %@", error.localizedDescription);
    }
}

- (void)_updateGameState
{
    /// Update any game state before encoding renderint commands to our drawable
    Uniforms * uniforms = (Uniforms*)_dynamicUniformBuffer[_uniformBufferIndex].GetContents();
    Uniforms * uniforms2 = (Uniforms*)_dynamicUniformBuffer2[_uniformBufferIndex].GetContents();
    
//    Uniforms * uniforms = (Uniforms*)_dynamicUniformBuffer[_uniformBufferIndex].contents;

    uniforms->projectionMatrix = _projectionMatrix;
    uniforms2->projectionMatrix = _projectionMatrix;

    vector_float3 rotationAxis = {1, 1, 0};
    matrix_float4x4 modelMatrix = matrix4x4_rotation(_rotation, rotationAxis);
    matrix_float4x4 viewMatrix = matrix4x4_translation(0.0, 0.0, -8.0);

    matrix_float4x4 scale = matrix4x4_scale(1.1, 1.1, 1.1);
    matrix_float4x4 modelMatrixScaled = matrix_multiply(modelMatrix, scale);
    
    uniforms->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
    uniforms2->modelViewMatrix = matrix_multiply(viewMatrix, modelMatrixScaled);

    _rotation += .01;
}

- (void)drawableResize:(CGSize)drawableSize
{
    float aspect = drawableSize.width / (float)drawableSize.height;
    _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
}
//
//- (void)drawInMTKView:(nonnull MTKView *)view
//{
//    /// Per frame updates here
//
//    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
//
//    _uniformBufferIndex = (_uniformBufferIndex + 1) % MaxBuffersInFlight;
//
//    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
//    commandBuffer.label = @"MyCommand";
//
//    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
//    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
//     {
//         dispatch_semaphore_signal(block_sema);
//     }];
//
//    [self _updateGameState];
//
//    /// Delay getting the currentRenderPassDescriptor until absolutely needed. This avoids
//    ///   holding onto the drawable and blocking the display pipeline any longer than necessary
//    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
//
//    if(renderPassDescriptor != nil)
//    {
//        /// Final pass rendering code here
//
//        id <MTLRenderCommandEncoder> renderEncoder =
//        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
//        renderEncoder.label = @"MyRenderEncoder";
//
//        [renderEncoder pushDebugGroup:@"DrawBox"];
//
//        [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
//        [renderEncoder setCullMode:MTLCullModeBack];
//        [renderEncoder setRenderPipelineState:_pipelineState];
//        [renderEncoder setDepthStencilState:_depthState];
//
//        [renderEncoder setVertexBuffer:_dynamicUniformBuffer[_uniformBufferIndex]
//                                offset:0
//                               atIndex:BufferIndexUniforms];
//
//        [renderEncoder setFragmentBuffer:_dynamicUniformBuffer[_uniformBufferIndex]
//                                  offset:0
//                                 atIndex:BufferIndexUniforms];
//
//        for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
//        {
//            MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
//            if((NSNull*)vertexBuffer != [NSNull null])
//            {
//                [renderEncoder setVertexBuffer:vertexBuffer.buffer
//                                        offset:vertexBuffer.offset
//                                       atIndex:bufferIndex];
//            }
//        }
//
//        [renderEncoder setFragmentTexture:_colorMap
//                                  atIndex:TextureIndexColor];
//
//        for(MTKSubmesh *submesh in _mesh.submeshes)
//        {
//            [renderEncoder drawIndexedPrimitives:submesh.primitiveType
//                                      indexCount:submesh.indexCount
//                                       indexType:submesh.indexType
//                                     indexBuffer:submesh.indexBuffer.buffer
//                               indexBufferOffset:submesh.indexBuffer.offset];
//        }
//
//        [renderEncoder popDebugGroup];
//
//        [renderEncoder endEncoding];
//
//        [commandBuffer presentDrawable:view.currentDrawable];
//    }
//
//    [commandBuffer commit];
//}

//- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size
//{
//    /// Respond to drawable size or orientation changes here
//
//    float aspect = size.width / (float)size.height;
//    _projectionMatrix = matrix_perspective_right_hand(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
//}

- (void)buildDepthTexture:(CGSize)drawableSize
{
    mtlpp::TextureDescriptor desc = mtlpp::TextureDescriptor::Texture2DDescriptor(mtlpp::PixelFormat::Depth32Float_Stencil8, drawableSize.width, drawableSize.height, NO);
    desc.SetUsage(mtlpp::TextureUsage::RenderTarget);
    desc.SetStorageMode(mtlpp::StorageMode::Memoryless);
    _depthTexture = device_.NewTexture(desc);
    _depthTexture.SetLabel("Depth Texture");
    
    mtlpp::RenderPassDepthAttachmentDescriptor depthAttachment;
    mtlpp::RenderPassStencilAttachmentDescriptor stencilAttachment;
    depthAttachment.SetTexture(_depthTexture);
    depthAttachment.SetLoadAction(mtlpp::LoadAction::Clear);
    depthAttachment.SetStoreAction(mtlpp::StoreAction::DontCare);
    _drawableRenderDescriptor.SetDepthAttachment(depthAttachment);
    
    stencilAttachment.SetTexture(_depthTexture);
    stencilAttachment.SetLoadAction(mtlpp::LoadAction::Clear);
    stencilAttachment.SetStoreAction(mtlpp::StoreAction::DontCare);
    _drawableRenderDescriptor.SetStencilAttachment(stencilAttachment);
}

- (void)renderToMetalLayer:(nonnull CAMetalLayer*)metalLayer
{
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);

    _uniformBufferIndex = (_uniformBufferIndex + 1) % MaxBuffersInFlight;

    mtlpp::CommandBuffer commandBuffer = commandQueue_.CommandBuffer();
    commandBuffer.SetLabel("MyCommand");

    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    commandBuffer.AddCompletedHandler(^(const mtlpp::CommandBuffer& buffer)
    {
         dispatch_semaphore_signal(block_sema);
    });

    [self _updateGameState];
    

    id<CAMetalDrawable> currentDrawable = [metalLayer nextDrawable];
    
    if (currentDrawable) {
        CGSize drawableSize = [metalLayer drawableSize];
        if ([_depthTexture.GetPtr() width] != drawableSize.width || [_depthTexture.GetPtr() height] != drawableSize.height)
        {
            [self buildDepthTexture:drawableSize];
        }
        /// Delay getting the currentRenderPassDescriptor until absolutely needed. This avoids
        ///   holding onto the drawable and blocking the display pipeline any longer than necessary

        id<MTLTexture> texture = currentDrawable.texture;
        if (!texture) {
            NSLog(@"No Texutre");
        }
        _drawableRenderDescriptor.GetColorAttachments()[0].SetTexture(texture);

        /// Final pass rendering code here
        
        mtlpp::RenderCommandEncoder renderEncoder = commandBuffer.RenderCommandEncoder(_drawableRenderDescriptor);
        renderEncoder.SetLabel("MyRenderEncoder");
        mtlpp::Viewport viewport(0, 0, (float)drawableSize.width, (float)drawableSize.height, 0.1, 1);
        renderEncoder.SetViewport(viewport);
        renderEncoder.PushDebugGroup("DrawBox");
        
        renderEncoder.SetFrontFacingWinding(mtlpp::Winding::CounterClockwise);
        renderEncoder.SetCullMode(mtlpp::CullMode::Back);
        renderEncoder.SetRenderPipelineState(_pipelineState);
        renderEncoder.SetDepthStencilState(_depthState);
        renderEncoder.SetStencilReferenceValue(1, 1);
        
        renderEncoder.SetVertexBuffer(_dynamicUniformBuffer[_uniformBufferIndex]
                                      ,0
                                      ,BufferIndexUniforms);
        
        renderEncoder.SetFragmentBuffer(_dynamicUniformBuffer[_uniformBufferIndex]
                                        ,0
                                        ,BufferIndexUniforms);
        
        for (NSUInteger bufferIndex = 0; bufferIndex < _mesh.vertexBuffers.count; bufferIndex++)
        {
            MTKMeshBuffer *vertexBuffer = _mesh.vertexBuffers[bufferIndex];
            if((NSNull*)vertexBuffer != [NSNull null])
            {
                renderEncoder.SetVertexBuffer(vertexBuffer.buffer
                                              ,uint32_t(vertexBuffer.offset)
                                              ,uint32_t(bufferIndex));
            }
        }
        
        renderEncoder.SetFragmentTexture(_colorMap, uint32_t(TextureIndexColor));
        
        for(MTKSubmesh *submesh in _mesh.submeshes)
        {
            renderEncoder.DrawIndexed(mtlpp::PrimitiveType(submesh.primitiveType)
                                      ,uint32_t(submesh.indexCount)
                                      ,mtlpp::IndexType(submesh.indexType)
                                      ,submesh.indexBuffer.buffer
                                      ,uint32_t(submesh.indexBuffer.offset));
        }
        
        renderEncoder.PopDebugGroup();
        
        renderEncoder.PushDebugGroup("Stencil");
        
//        renderEncoder.SetFrontFacingWinding(mtlpp::Winding::CounterClockwise);
//        renderEncoder.SetCullMode(mtlpp::CullMode::Back);
        renderEncoder.SetRenderPipelineState(_pipelineState2);
        renderEncoder.SetDepthStencilState(_depthState2);
        
        renderEncoder.SetVertexBuffer(_dynamicUniformBuffer2[_uniformBufferIndex]
                                      ,0
                                      ,BufferIndexUniforms);
        

        for(MTKSubmesh *submesh in _mesh.submeshes)
        {
            renderEncoder.DrawIndexed(mtlpp::PrimitiveType(submesh.primitiveType)
                                      ,uint32_t(submesh.indexCount)
                                      ,mtlpp::IndexType(submesh.indexType)
                                      ,submesh.indexBuffer.buffer
                                      ,uint32_t(submesh.indexBuffer.offset));
        }
        
        renderEncoder.PopDebugGroup();
        
        renderEncoder.EndEncoding();
        
        commandBuffer.Present(currentDrawable);
    } else {
        NSLog(@"No texture");
    }

    commandBuffer.Commit();
}

#pragma mark Matrix Math Utilities

matrix_float4x4 matrix4x4_translation(float tx, float ty, float tz)
{
    return (matrix_float4x4) {{
        { 1,   0,  0,  0 },
        { 0,   1,  0,  0 },
        { 0,   0,  1,  0 },
        { tx, ty, tz,  1 }
    }};
}

static matrix_float4x4 matrix4x4_rotation(float radians, vector_float3 axis)
{
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;

    return (matrix_float4x4) {{
        { ct + x * x * ci,     y * x * ci + z * st, z * x * ci - y * st, 0},
        { x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0},
        { x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0},
        {                   0,                   0,                   0, 1}
    }};
}

matrix_float4x4 matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);

    return (matrix_float4x4) {{
        { xs,   0,          0,  0 },
        {  0,  ys,          0,  0 },
        {  0,   0,         zs, -1 },
        {  0,   0, nearZ * zs,  0 }
    }};
}

matrix_float4x4 matrix_make_rows(
                                   float m00, float m10, float m20, float m30,
                                   float m01, float m11, float m21, float m31,
                                   float m02, float m12, float m22, float m32,
                                   float m03, float m13, float m23, float m33) {
    return (matrix_float4x4){ {
        { m00, m01, m02, m03 },     // each line here provides column data
        { m10, m11, m12, m13 },
        { m20, m21, m22, m23 },
        { m30, m31, m32, m33 } } };
}

matrix_float4x4 matrix4x4_scale(float sx, float sy, float sz) {
    return matrix_make_rows(sx,  0,  0, 0,
                             0, sy,  0, 0,
                             0,  0, sz, 0,
                             0,  0,  0, 1 );
}


@end
