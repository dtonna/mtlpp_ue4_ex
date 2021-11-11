/*
 * Copyright 2016-2017 Nikolay Aleksiev. All rights reserved.
 * License: https://github.com/naleksiev/mtlpp/blob/master/LICENSE
 */
// Copyright Epic Games, Inc. All Rights Reserved.
// Modifications for Unreal Engine

#pragma once

#include "command_encoder.hpp"
#include "device.hpp"

#ifdef __OBJC__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wduplicate-protocol"
NS_AVAILABLE(10_11, 8_0)
@protocol MTLCommandEncoder <NSObject>
@property (readonly) id <MTLDevice> device;
@property (nullable, copy, atomic) NSString *label;
- (void)endEncoding;
- (void)insertDebugSignpost:(NSString *)string;
- (void)pushDebugGroup:(NSString *)string;
- (void)popDebugGroup;
@end
#pragma clang diagnostic pop
#endif
