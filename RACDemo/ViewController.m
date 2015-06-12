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
    
    [self sideEffectDemo];
}

- (void)sideEffectDemo
{
    // side effects
    __block NSInteger counter = 0;
    RACSubject *subject = [RACSubject subject]; // perfom something like AsyncNetworkRequest
    // base signal
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        counter ++;
        NSLog(@"side effect : %@", @(counter));
        [subject subscribeNext:^(id x) {
            if ([x integerValue] == 2) {
                [subscriber sendCompleted];
            } else {
                [subscriber sendNext:x];
            }
        }];
        return nil;
    }];
    
    // print: side effct : 1
    [signal subscribeNext:^(id x) {
        NSLog(@"subscribeNext 1:%@", x);
    }];
    
    // print: side effct : 2
    [[signal map:^id(id value) {
        NSLog(@"map: %@", value);
        return @([value integerValue] * 2);
    }] subscribeNext:^(id x) {
        NSLog(@"subscribeNext 2: %@", x);
    }];
    
    // print: side effct : 3
    [[signal doNext:^(id x) {
        NSLog(@"doNext: %@", x);
    }] subscribeNext:^(id x) {
        NSLog(@"subscribeNext 3: %@", x);
    }];
    
    /**
     print:
     2015-06-12 11:40:15.536 RACDemo[1222:86864] subscribeNext 1:1
     2015-06-12 11:40:15.536 RACDemo[1222:86864] map: 1
     2015-06-12 11:40:15.536 RACDemo[1222:86864] subscribeNext 2: 2
     2015-06-12 11:40:15.536 RACDemo[1222:86864] doNext: 1
     2015-06-12 11:40:15.536 RACDemo[1222:86864] subscribeNext 3: 1
     */
    [subject sendNext:@(1)];
    
    // side effect，指的是RACSignal被subscribe的时候，base signal的didSubscribe block就会被执行，具体就是这里createSignal:函数传入的block。
    // 在这里来说，base signal的didSubscribe block内执行一个异步网络请求等操作，然后在异步网络请求完成之后，会执行subscriber的相应过程，比如[subscirber sendNext:]/[subscirber sendCompletion]等。所以说，每次subscribe产生side effect的话，实际上就会重新发起一个网络请求。
    // signal在最终subscribe发生之前，可能会经过一系列的变换，比如，base signal --operator--> A siganl --operator--> B siganl，但无论是A signal还是B signal被subscribe，base signal的didSubscribe block都会执行，即side effect都会发生。
    // 这里可以查看operator的源代码来查看了解更多细节，每个operator内部一般来说也是通过[RACSignal createSignal:]以及[self subscribeNext:error:completion:]来生成变换后的新的signal的，这里createSignal:方法的didSubscribe block也不会立即被调用，只有在这个新的signal被subscribe的时候，才会执行这个didSubscribe block，然后这个新signal会按subscribe上一级的signal，这样就实现了signal的链式传递subscribe，最终subscribe base signal。
    // 这里还有一点比较容易有误区的地方，实际上也是我一直比较困惑的地方，就是每次subscribeNext的时候，其实并不会重新生成RACSignal。只是生成一个RACSubscriber保存subcribe时候传入的block，具体实现来说，比如对于RACDynamicSignal，又会生成一个RACPassRACPassthroughSubscriber用来保持刚生成的RACSubscriber对象以及signal对象(弱引用)。这个一系列的subscribe调用过程，实际上只是生成了一系列的subscriber，并不会对RACSignal的内存有什么影响，如果最顶部的subscriber在base signal的didSubscribe block中没有被capture的话，当base signal的didSubscribe block执行完成之后，这一系列的subscriber以及didSubscribe block会立即被释放。例如 base signal didSubscriber --> subscriber --> (operator)didSubscribe --> subscriber --> didSubscribe...
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
