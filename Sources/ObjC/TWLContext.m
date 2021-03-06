//
//  TWLContext.m
//  Tomorrowland
//
//  Created by Kevin Ballard on 12/30/17.
//  Copyright © 2017 Kevin Ballard. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
//  http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
//  <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
//  option. This file may not be copied, modified, or distributed
//  except according to those terms.
//

#import "TWLContext.h"
#import "TWLContextPrivate.h"
#import "TWLThreadLocal.h"

@interface TWLContext ()
- (nonnull instancetype)initImmediate NS_DESIGNATED_INITIALIZER;
@end

@implementation TWLContext {
    /// \c YES iff this is the main queue.
    BOOL _isMain;
    // If both of these are nil, this is the immediate context.
    // Otherwise, one of these will be non-nil (but never both).
    dispatch_queue_t _Nullable _queue;
    NSOperationQueue * _Nullable _operationQueue;
}

+ (TWLContext *)immediate {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initImmediate];
    });
    return context;
}

+ (TWLContext *)main {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_main_queue()];
        context->_isMain = YES;
    });
    return context;
}

+ (TWLContext *)background {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)];
    });
    return context;
}

+ (TWLContext *)utility {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)];
    });
    return context;
}

+ (TWLContext *)defaultQoS {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)];
    });
    return context;
}

+ (TWLContext *)userInitiated {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)];
    });
    return context;
}

+ (TWLContext *)userInteractive {
    static TWLContext *context;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        context = [[TWLContext alloc] initWithQueue:dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)];
    });
    return context;
}

+ (TWLContext *)automatic {
    if ([NSThread isMainThread]) {
        return TWLContext.main;
    } else {
        return TWLContext.defaultQoS;
    }
}

+ (TWLContext *)queue:(dispatch_queue_t)queue {
    return [[self alloc] initWithQueue:queue];
}

+ (TWLContext *)operationQueue:(NSOperationQueue *)operationQueue {
    return [[self alloc] initWithOperationQueue:operationQueue];
}

+ (TWLContext *)contextForQoS:(dispatch_qos_class_t)qos {
    switch (qos) {
        case QOS_CLASS_BACKGROUND:
            return self.background;
        case QOS_CLASS_UTILITY:
            return self.utility;
        case QOS_CLASS_USER_INITIATED:
            return self.userInitiated;
        case QOS_CLASS_USER_INTERACTIVE:
            return self.userInteractive;
        case QOS_CLASS_DEFAULT:
        case QOS_CLASS_UNSPECIFIED:
        default:
            return self.defaultQoS;
    }
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue {
    if ((self = [super init])) {
        _queue = queue;
    }
    return self;
}

- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue {
    if ((self = [super init])) {
        _operationQueue = operationQueue;
    }
    return self;
}

- (instancetype)initImmediate {
    return [super init];
}

- (BOOL)isImmediate {
    return _queue == nil && _operationQueue == nil;
}

- (void)executeBlock:(dispatch_block_t)block {
    if (_queue) {
        if (_isMain) {
            if (TWLGetMainContextThreadLocalFlag()) {
                NSAssert(NSThread.isMainThread, @"Found thread-local flag set while not executing on the main thread");
                // We're already executing on the .main context
                TWLEnqueueThreadLocalBlock(block);
            } else {
                dispatch_async(_queue, ^{
                    TWLExecuteBlockWithMainContextThreadLocalFlag(^{
                        @autoreleasepool {
                            block();
                        }
                        dispatch_block_t _Nullable block;
                        while ((block = TWLDequeueThreadLocalBlock())) {
                            @autoreleasepool {
                                block();
                            }
                        }
                    });
                });
            }
        } else {
            dispatch_async(_queue, ^{
                @autoreleasepool {
                    block();
                }
            });
        }
    } else if (_operationQueue) {
        [_operationQueue addOperationWithBlock:block];
    } else {
        // immediate
        block();
    }
}

- (nullable dispatch_queue_t)getQueue {
    if (_queue) {
        return _queue;
    } else if (_operationQueue) {
        return nil;
    } else {
        return TWLContext.automatic.getQueue;
    }
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[TWLContext class]]) return NO;
    TWLContext *other = object;
    return (_queue == other->_queue
            && _operationQueue == other->_operationQueue);
}

- (NSUInteger)hash {
    return 17 ^ _queue.hash ^ _operationQueue.hash;
}

- (NSString *)description {
    if (_queue) {
        return [NSString stringWithFormat:@"<%@: %p queue=%@>", NSStringFromClass([self class]), self, _queue];
    } else if (_operationQueue) {
        return [NSString stringWithFormat:@"<%@: %p queue=%@>", NSStringFromClass([self class]), self, _operationQueue];
    } else {
        return [NSString stringWithFormat:@"<%@: %p immediate>", NSStringFromClass([self class]), self];
    }
}

@end
