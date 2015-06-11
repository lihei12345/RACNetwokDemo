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

//@property (nonatomic, strong) RACSubject *subject;
//@property (nonatomic, strong) RACSignal *signal;

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
                NSLog(@"error: %@", [error localizedDescription]);
            } completed:^{
                NSLog(@"complete");
            }];
            return signal;
        }];
        
        _cancelCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
            NSLog(@"cancel command: dispose");
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
    /**
     * don't use replay* / connect, can't be disposed
     * 这种方式发起的请求，一方面可以通过主动调用dispose，另外一方面内存被释放之后，这里的dispose也会立即被执行，请求会被cancel
     * 同时，replay/replayLast 是 hot signal, 而autoconnect与replayLazily是cold signal，这一点需要注意
     */
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
}

- (RACSignal *)urlRequestSignal
{
    /**
     * 通过replay获得的signal，connection dispose不会被调用，也就不会触发这里source signal的dispose操作。
     * 虽然在ViewModel dealloc之后，对应的Command和Signal被释放，会触发订阅者subscribeCompleted:方法，但是这里的source signal的dispose不会被执行。
     * 只有在Operation请求结束的时候，dispose中的操作会被执行，[subscriber send**]这些操作同时也不会再被执行
     */
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
    
//    // takeUntil:的等价实现方法
//    [self.subject sendNext:nil];
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
    
//    // takeUntil: 等价方法，仅仅调用RACDispose的dispose方法进行dispose的话，subscriber的complete方法不会被运行的，因为dispose的disposed属性已经改变，所以需要通过某种方式主动调用[subscriber sendComplete]；
//    // takeUntil: 是利用RACCommand的executionSignals特性在调用execute:期间会触发一个RACObserver监听，然后发送sendNext。大致实现原理与下来代码类似。
//    // 下面的代码则是通过使用RACSubject来主动触发一个sendNext:实现同样的原理
//    self.subject = [RACSubject subject];
//    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
//        RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
//        RACDisposable *selfDisposable = [[self cancelableUrlRequestSignal] subscribeNext:^(id x) {
//            [subscriber sendNext:x];
//        } error:^(NSError *error) {
//            [subscriber sendError:error];
//        } completed:^{
//            [disposable dispose];
//            [subscriber sendCompleted];
//        }];
//        [disposable addDisposable:selfDisposable];
//        
//        [self.subject subscribeNext:^(id x) {
//            [disposable dispose];
//            [subscriber sendCompleted];
//        }];
//        return disposable;
//    }];
//    
//    [signal subscribeNext:^(id x) {
//        NSLog(@"next");
//    } error:^(NSError *error) {
//        NSLog(@"error");
//    } completed:^{
//        NSLog(@"completed");
//    }];
//    
//    return signal;
}

@end
