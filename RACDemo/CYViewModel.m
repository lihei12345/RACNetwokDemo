//
//  CYViewModel.m
//  RACDemo
//
//  Created by jason on 15/6/10.
//  Copyright (c) 2015年 chenyang. All rights reserved.
//

#import "CYViewModel.h"

// third
#import <extobjc.h>
#import <AFNetworking.h>

@interface CYViewModel ()

@property (nonatomic, strong) RACSignal *signal;
@property (nonatomic, strong) RACDisposable *disposable;

@end

@implementation CYViewModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray new];
        
        @weakify(self);
        _signalCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(NSNumber *cancelable) {
            @strongify(self);
            NSLog(@"signal command");
            // use takeUntil: for cancellation: https://github.com/ReactiveCocoa/ReactiveCocoa/issues/1326
            RACSignal *signal = nil;
            if ([cancelable boolValue]) {
                signal = [[self cancelableUrlRequestSignal] takeUntil:self.cancelCommand.executionSignals];
            } else {
                signal = [[self urlRequestSignal] takeUntil:self.cancelCommand.executionSignals];
            }
            [signal subscribeNext:^(id x) {
                @strongify(self);
                NSLog(@"next");
                NSMutableArray *tmpArray = [[NSMutableArray alloc] initWithArray:self.dataArray];
                for (NSInteger i = 0; i < 10; i ++) {
                    [tmpArray addObject:@(i)];
                }
                self.dataArray = tmpArray;
            } error:^(NSError *error) {
                @strongify(self);
                NSLog(@"error: %@", [error localizedDescription]);
                self.disposable = nil;
            } completed:^{
                @strongify(self);
                NSLog(@"complete");
                self.disposable = nil;
            }];
            return signal;
        }];
        
        _cancelCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
            @strongify(self);
            NSLog(@"cancel command: dispose");
            [self.disposable dispose];
            self.disposable = nil;
            return [RACSignal empty];
        }];

    }
    return self;
}

- (void)dealloc
{
    NSLog(@"ViewModel dealloc");
}

- (RACSignal *)cancelableUrlRequestSignal
{
    RACReplaySubject *subject = [RACReplaySubject subject];
    return [[[RACSignal createSignal:^RACDisposable *(id subscriber) {
        NSLog(@"subscriber: operation start");
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperationManager manager] GET:@"http://homestead.app/api/gallery/new/1/2" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [subscriber sendNext:responseObject];
            [subscriber sendCompleted];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [subscriber sendError:error];
        }];
        [operation start];
        RACDisposable *dispose = [RACDisposable disposableWithBlock:^{
            NSLog(@"operation cancel");
            [operation cancel];
        }];
        return dispose;
    }] multicast:subject] autoconnect];
    // don't use replay* / connect, can't be disposed
    // 这种方式发起的请求，一方面可以通过主动调用dispose，另外一方面内存被释放之后，这里的dispose也会立即被执行，请求会被cancel
}

- (RACSignal *)urlRequestSignal
{
    return [[RACSignal createSignal:^RACDisposable *(id subscriber) {
        NSLog(@"subscriber: operation start");
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperationManager manager] GET:@"http://homestead.app/api/gallery/new/1/2" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            [subscriber sendNext:responseObject];
            [subscriber sendCompleted];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [subscriber sendError:error];
        }];
        [operation start];
        RACDisposable *dispose = [RACDisposable disposableWithBlock:^{
            NSLog(@"operation cancel");
            [operation cancel];
        }];
        return dispose;
    }] replay];
    // 通过replay发起的signal，由于无法主动调用dispose，在ViewModel dealloc之后，会触发订阅者completed:，对应的Command和Signal被释放，但是dispose不会被执行。
    // 只有在Operation请求结束的时候，dispose中的操作会被执行，[subscriber send**]这些操作同时也不会再被执行
}

- (void)cancelRequest:(void (^)())completion
{
    if ([[self.signalCommand.executing first] boolValue]) {
        [[self.cancelCommand execute:nil] subscribeCompleted:^{
            completion();
        }];
    } else {
        completion();
    }
}

- (RACSignal *)doRequest:(BOOL)cancelable
{
    __block RACSignal *signal;
    @weakify(self);
    [self cancelRequest:^{
        @strongify(self);
        signal = [self.signalCommand execute:@(cancelable)];
    }];
    return signal;
}

@end
