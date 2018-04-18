//
//  ViewController.m
//  ZMRouter
//
//  Created by zhangmin on 2018/4/13.
//  Copyright © 2018年 zhangmin. All rights reserved.
//

#import "ViewController.h"
#import "ZMRouter.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)testFunc:(id)sender {
    [ZMRouter openURLService:@"zm://test"];
//    id test = [ZMRouter objectOfRegisteredURL:@"zm://test"];
//    NSLog(@"%@",test);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
