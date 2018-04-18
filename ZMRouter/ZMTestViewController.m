//
//  ZMTestViewController.m
//  ZMRouter
//
//  Created by zhangmin on 2018/4/16.
//  Copyright © 2018年 zhangmin. All rights reserved.
//

#import "ZMTestViewController.h"
#import "ZMRouter.h"

@interface ZMTestViewController ()
@property (nonatomic, strong) NSDictionary *dic;
@end

@implementation ZMTestViewController

+ (void)load{
    NSError *error = [ZMRouter registerURLPatternService:@"zm://test" forHandler:^id(NSDictionary *parameter) {
        ZMTestViewController *vc = [[self alloc] init];
        vc.dic = parameter;
        UINavigationController *navigationVC = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
        [navigationVC pushViewController:vc animated:YES];
        return @{@"1":@"111"};
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
