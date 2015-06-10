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

@property (nonatomic, strong) RACCommand *signalCommand;
@property (nonatomic, strong) RACCommand *cancelCommand;

@end

@implementation CYViewModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dataArray = [NSMutableArray new];
        _isExecuting = NO;
        
        @weakify(self);
        _signalCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
            @strongify(self);
            NSLog(@"signal command");
            self.isExecuting = YES;
            // use takeUntil: for cancellation: https://github.com/ReactiveCocoa/ReactiveCocoa/issues/1326
            RACSignal *signal = [[self urlRequestSignal] takeUntil:self.cancelCommand.executionSignals];
            self.disposable = [signal subscribeNext:^(id x) {
                NSLog(@"next");
                NSMutableArray *tmpArray = [[NSMutableArray alloc] initWithArray:self.dataArray];
                for (NSInteger i = 0; i < 10; i ++) {
                    [tmpArray addObject:@(i)];
                }
                self.dataArray = tmpArray;
            } error:^(NSError *error) {
                NSLog(@"error: %@", [error localizedDescription]);
                self.disposable = nil;
                self.isExecuting = NO;
            } completed:^{
                NSLog(@"complete");
                self.disposable = nil;
                self.isExecuting = NO;
            }];
            return signal;
        }];
        
        _cancelCommand = [[RACCommand alloc] initWithSignalBlock:^RACSignal *(id input) {
            @strongify(self);
            NSLog(@"cancel command: dispose");
            [self.disposable dispose];
            self.disposable = nil;
            self.isExecuting = NO;
            return [RACSignal empty];
        }];

    }
    return self;
}

- (RACSignal *)urlRequestSignal
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
    }] multicast:subject] autoconnect]; // don't use replay* / connect, can't be disposed
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

- (RACSignal *)doRequest
{
    __block RACSignal *signal;
    @weakify(self);
    [self cancelRequest:^{
        @strongify(self);
        signal = [self.signalCommand execute:nil];
    }];
    return signal;
}

@end
