/* Copyright Airship and Contributors */

#import "UAAsyncOperation.h"

@interface UAAsyncOperation()

/**
 * Indicates whether the operation is currently executing.
 */
@property (nonatomic, assign) BOOL isExecuting;

/**
 * Indicates whether the operation has finished.
 */
@property (nonatomic, assign) BOOL isFinished;

/**
 * Block operation to run.
 */
@property (nonatomic, copy) void (^block)(UAAsyncOperation *);
@end

@implementation UAAsyncOperation

- (instancetype)initWithBlock:(void (^)(UAAsyncOperation *))block {
    self = [super init];

    if (self) {
        self.block = block;
    }

    return self;
}

+ (instancetype)operationWithBlock:(void (^)(UAAsyncOperation *))block {
    return [[UAAsyncOperation alloc] initWithBlock:block];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (void)setIsExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setIsFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)dealloc {
    self.block = nil;
    self.cancelBlock = nil;
}

- (void)cancel {
    @synchronized (self) {
        if (!self.isCancelled && self.cancelBlock) {
            [super cancel];
            self.cancelBlock();
            self.cancelBlock = nil;
        } else {
            [super cancel];
        }
    }
}

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            [self finish];
            return;
        }

        self.isExecuting = YES;
        [self startAsyncOperation];
    }
}

- (void)startAsyncOperation {
    if (self.block) {
        self.block(self);
    } else {
        [self finish];
    }
}

- (void)finish {
    @synchronized (self) {
        self.block = nil;
        self.cancelBlock = nil;

        if (self.isExecuting) {
            self.isExecuting = NO;
        }

        if (!self.isFinished) {
            self.isFinished = YES;
        }
    }
}

@end

