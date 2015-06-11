//
//  CYViewModel.h
//  RACDemo
//
//  Created by jason on 15/6/10.
//  Copyright (c) 2015年 chenyang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa.h>

@interface CYViewModel : NSObject

@property (nonatomic, strong) RACCommand *signalCommand;
@property (nonatomic, strong) RACCommand *cancelCommand;
@property (nonatomic, strong) NSMutableArray *dataArray;

- (RACSignal *)doRequest:(BOOL)cancelable;
- (void)cancelRequest:(void (^)())completion;

@end
