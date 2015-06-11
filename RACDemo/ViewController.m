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
    self.view.backgroundColor = [UIColor whiteColor];
    
    // main refer : http://codeblog.shape.dk/blog/2013/12/05/reactivecocoa-essentials-understanding-and-using-raccommand/
    self.viewModel = [[CYViewModel alloc] init];
    
    @weakify(self);
    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendButton setTitle:@"Replay signal" forState:UIControlStateNormal];
    [sendButton setFrame:CGRectMake(10, 100, 120, 25)];
    [[sendButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel doRequest:NO];
    }];
    [self.view addSubview:sendButton];
    
    UIButton *cancelSignal = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelSignal setTitle:@"Autoconnect signal" forState:UIControlStateNormal];
    [cancelSignal setFrame:CGRectMake(140, 100, 180, 25)];
    [[cancelSignal rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel doRequest:YES];
    }];
    [self.view addSubview:cancelSignal];
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton setFrame:CGRectMake(100, 150, 60, 25)];
    [[cancelButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        @strongify(self);
        [self.viewModel cancelRequest:^{
            // do nothing
        }];
    }];
    [self.view addSubview:cancelButton];
    
    UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [nextButton setTitle:@"Next" forState:UIControlStateNormal];
    [nextButton setFrame:CGRectMake(100, 200, 60, 25)];
    [[nextButton rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(id x) {
        @strongify(self);
        ViewController *newViewController = [[ViewController alloc] init];
        [self.navigationController pushViewController:newViewController animated:YES];
    }];
    [self.view addSubview:nextButton];
    
    
    [[RACObserve(self.viewModel, dataArray) deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(id x) {
        @strongify(self);
         NSLog(@"completed : %@", @(self.viewModel.dataArray.count));
    }];
    
    [[self.viewModel.signalCommand.executing deliverOn:[RACScheduler mainThreadScheduler]] subscribeNext:^(NSNumber *isExcuting) {
        NSLog(@"isExecution: %@", [isExcuting boolValue] ? @"YES" : @"NO");
    }];
}

- (void)dealloc
{
    NSLog(@"view controller dealloc");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
