//
//  ZMRouter.h
//  ZMRouter
//
//  Created by zhangmin on 2018/4/13.
//  Copyright © 2018年 zhangmin. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 注册服务的回调

 @param parameter 返回url中可能传入的参数
 */
typedef id(^ZMRouterHandler)(NSDictionary * _Nullable parameter);
/**
 注册对象的回调

 @param parameter url中传入的参数,以及completeHandler形成字典
 */
typedef void (^ZMRouterCompleteHandler)(NSDictionary *parameter);

NS_ASSUME_NONNULL_BEGIN
@interface ZMRouter : NSObject

+ (instancetype)sharedZMRouter;
- (instancetype)init __attribute__((unavailable("Use [ZMRouter sharedZMRouter] to get a shared instance")));
+ (instancetype)new __attribute__((unavailable("Use [ZMRouter sharedZMRouter] to get a shared instance")));

/**
 为handlerBlock注册服务

 @param URLPatternString URL格式的string
 @param handler 需要注册的服务
 */
+ (NSError *)registerURLPatternService:(NSString *)URLPatternString forHandler:(ZMRouterHandler)handler __attribute__((warn_unused_result));

/**
 通过URL启用注册过的服务

 @param URLString 注册过的URL
 */
+ (void)openURLService:(NSString *)URLString;
+ (void)openURLService:(NSString *)URLString completionHandler:(nullable ZMRouterCompleteHandler)completionHandler;
+ (void)openURLService:(NSString *)URLString withParameter:(nullable NSDictionary *)parameter completionHandler:(ZMRouterCompleteHandler)completionHandler;

/**
 获取注册的服务对象
 */
+ (id)objectOfRegisteredURL:(NSString *)URLString;

/**
 移除某个注册的服务

 @param URLString 注册服务的URLString
 */
+ (void)deRegisterURLPatternService:(NSString *)URLString;

@end
NS_ASSUME_NONNULL_END
