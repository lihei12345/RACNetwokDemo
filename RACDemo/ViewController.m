//
//  ViewController.m
//  RACDemo
//
//  Created by jason on 15/6/2.
//  Copyright (c) 2015年 chenyang. All rights reserved.
//

#import "ViewController.h"
#import "SecondViewController.h"
#import "CYViewModel.h"

// third
#import <extobjc.h>
#import <ReactiveCocoa.h>

@interface ViewController ()

@property (nonatomic, strong) CYViewModel *viewModel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // refer : http://codeblog.shape.dk/blog/2013/12/05/reactivecocoa-essentials-understanding-and-using-raccommand/
    self.viewModel = [[CYViewModel alloc] init];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *normalImage = [UIImage imageNamed:@"icon_food_increase_small"];
    [button setImage:normalImage forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"icon_food_increase_small_highlighted.png"] forState:UIControlStateHighlighted];
    [button setImage:[UIImage imageNamed:@"icon_food_increase_small_disable"] forState:UIControlStateDisabled];
    [button setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    button.frame = CGRectMake(100, 100, normalImage.size.width + 20, normalImage.size.height + 20);
    
    @weakify(self);
    [[button rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel doRequest];
    }];
    [self.view addSubview:button];
    
    [[[RACObserve(self.viewModel, dataArray) skip:1] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(id x) {
         NSLog(@"completed : %@", @(self.viewModel.dataArray.count));
    }];
    
    [[[RACObserve(self.viewModel, isExecuting) skip:1] deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(NSNumber *isExcuting) {
        NSLog(@"isExecution: %@", [isExcuting boolValue] ? @"YES" : @"NO");
    }];
}

- (void)dealloc
{
    [self.viewModel cancelRequest:^{
        // do nothing
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
