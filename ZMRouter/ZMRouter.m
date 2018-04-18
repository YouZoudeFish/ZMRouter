//
//  ZMRouter.m
//  ZMRouter
//
//  Created by zhangmin on 2018/4/13.
//  Copyright © 2018年 zhangmin. All rights reserved.
//

#import "ZMRouter.h"

#define ZMSharedRouter  [ZMRouter sharedZMRouter]
#define ZMLock()        dispatch_semaphore_wait(self->semaphore, DISPATCH_TIME_FOREVER)
#define ZMUnlock()      dispatch_semaphore_signal(self->semaphore)

static inline id _ZMHandleOnMainThread(ZMRouterHandler handler,NSDictionary *callBackDict) {
//    if (pthread_main_np()) {  // 需要#import <pthread.h>
    __block id returnobject = nil;
    if ([[NSThread currentThread] isMainThread]) {
        returnobject = handler(callBackDict);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            returnobject = handler(callBackDict);
        });
    }
    return returnobject;
}

static NSString * const ZMRouterDefaultScheme = @"ZMRouterScheme";
static NSString * const ZMRouterErrorDomain = @"zm.www.git.com";

static NSString * const ZMRouterParameterKey = @"parameter";
static NSString * const ZMRouterHandlerKey = @"handler";

@interface ZMRouter()

/**
 全局的Map，里面保存着注册的服务。以URL结构分层为键，传入的block为值
 */
@property (nonatomic, strong) NSMutableDictionary *registeredURLServiceMap;

@end

@implementation ZMRouter
{
    dispatch_semaphore_t semaphore;
}

#pragma mark - Init
+ (instancetype)sharedZMRouter{
    static ZMRouter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark - Public Func
+ (NSError *)registerURLPatternService:(NSString *)URLPatternString forHandler:(nonnull ZMRouterHandler)handler
{
    return [ZMSharedRouter addURLServiceIntoMapWithURLString:[self replaceChineseCharInString:URLPatternString] forHandler:handler];
}

+ (void)openURLService:(NSString *)URLString
{
    [self openURLService:URLString completionHandler:nil];
}

+ (void)openURLService:(NSString *)URLString completionHandler:(ZMRouterCompleteHandler)completionHandler
{
    [self openURLService:URLString withParameter:nil completionHandler:completionHandler];
}

+ (void)openURLService:(NSString *)URLString withParameter:(NSDictionary *)parameter completionHandler:(ZMRouterCompleteHandler)completionHandler {
    [ZMSharedRouter openURLService:[self replaceChineseCharInString:URLString] withParameter:parameter completionHandler:completionHandler];
}

+(id)objectOfRegisteredURL:(NSString *)URLString {
    return [ZMSharedRouter storedObjectOfURLString:[self replaceChineseCharInString:URLString]];
}

+ (void)deRegisterURLPatternService:(NSString *)URLString
{
    [ZMSharedRouter removeRegisteredURLPatternService:[self replaceChineseCharInString:URLString]];
}

#pragma mark - Private Func
- (NSError *)addURLServiceIntoMapWithURLString:(NSString *)URLString forHandler:(id)handler{
    ZMLock();
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    NSString *query = url.query;
    
    NSError *error = nil;
    if (handler) {
        if (scheme){
            // scheme不为空时，host可能为空，path也可能为空
            if (!self.registeredURLServiceMap[scheme]) {
                self.registeredURLServiceMap[scheme] = @{}.mutableCopy;
            }
            if (host) {
                if (!self.registeredURLServiceMap[scheme][host])
                    self.registeredURLServiceMap[scheme][host] = @{}.mutableCopy;
                if (path) {
                    if (!self.registeredURLServiceMap[scheme][host][path])
                        self.registeredURLServiceMap[scheme][host][path] = @{}.mutableCopy;
                    if (!query) {
                        self.registeredURLServiceMap[scheme][host][path] = [handler copy];
                    } else {
                        NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
                        self.registeredURLServiceMap[scheme][host][path] = @{
                                                               ZMRouterParameterKey:[parameterDict copy],
                                                               ZMRouterHandlerKey:[handler copy]
                                                               };
                    }
                } else {
                    self.registeredURLServiceMap[scheme][host] = [handler copy];
                }
            } else {
                self.registeredURLServiceMap[scheme] = [handler copy];
            }
            
        } else {
            // 如果scheme为空，那么host也为空，但path肯定不为空
            if (path) {
                if (!self.registeredURLServiceMap[path]) {
                    self.registeredURLServiceMap[path] = @{}.mutableCopy;
                }
                else {
                    if (query){
                        NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
                        self.registeredURLServiceMap[path] = @{
                                                               ZMRouterParameterKey:[parameterDict copy],
                                                               ZMRouterHandlerKey:[handler copy]
                                                               };
                    } else
                        self.registeredURLServiceMap[path] = [handler copy];
                }
            }
        }
    } else {
        error = [self generateErrorWithLocalDescription:@"无效的注册,未传入服务!"];
    }
    
    ZMUnlock();
    return error;
}

- (void)openURLService:(NSString *)URLString withParameter:(NSDictionary *)parameter completionHandler:(ZMRouterCompleteHandler)completionHandler{
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    NSString *query = url.query;
    
    ZMRouterHandler savedHandler = nil;
    NSMutableDictionary *callBackDict = [[NSMutableDictionary alloc] initWithDictionary:parameter];
    
    if (!scheme)
    {
        if (path)
            savedHandler = self.registeredURLServiceMap[path];
    } else {
        if (!host) {
            savedHandler = self.registeredURLServiceMap[scheme];
        } else {
            if (!path)
                savedHandler = self.registeredURLServiceMap[scheme][host];
            else {
                if (query) {
                    NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
                    [callBackDict setObject:parameterDict forKey:@"parameter"];
                }
                savedHandler = self.registeredURLServiceMap[scheme][host][path];
            }
        }
    }
    
    if (completionHandler) {
        [callBackDict setObject:completionHandler forKey:@"completeHandler"];
    }
//    savedHandler(callBackDict);
    _ZMHandleOnMainThread(savedHandler, callBackDict);
}

- (id)storedObjectOfURLString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    NSString *query = url.query;

    ZMRouterHandler savedHandler = nil;
    NSMutableDictionary *objectDict = @{}.mutableCopy;
    if (!scheme)
    {
        if (path)
            savedHandler = self.registeredURLServiceMap[path];
    } else {
        if (!host) {
            savedHandler = self.registeredURLServiceMap[scheme];
        } else {
            if (!path)
                savedHandler = self.registeredURLServiceMap[scheme][host];
            else {
                if (query) {
                    NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
                    [objectDict setObject:parameterDict forKey:@"parameter"];
                }
                savedHandler = self.registeredURLServiceMap[scheme][host][path];
            }
        }
    }
    
    id handlerReturnedObject = _ZMHandleOnMainThread(savedHandler, objectDict);
    if (handlerReturnedObject) {
        [objectDict setObject:handlerReturnedObject forKey:@"returnedObject"];
    }
    
    return objectDict.copy;
}

- (void)removeRegisteredURLPatternService:(NSString *)URLString
{
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
//    NSString *query = url.query;    // 存handler时并不会用query作为键
    
    ZMLock();
    if (scheme){
        if (host) {
            if (path) {
                [self.registeredURLServiceMap[scheme][host] removeObjectForKey:path];
                ZMUnlock();
                return;
            }
            [self.registeredURLServiceMap[scheme] removeObjectForKey:host];
            ZMUnlock();
            return;
        }
        [self.registeredURLServiceMap removeObjectForKey:scheme];
        ZMUnlock();
    } else {
        // 如果scheme为空，那么host也为空，但path肯定不为空
        if (path) {
            [self.registeredURLServiceMap removeObjectForKey:path];
            ZMUnlock();
        }
    }
}

#pragma mark - Lazy
- (NSMutableDictionary *)registeredURLServiceMap
{
    if (!_registeredURLServiceMap) {
        _registeredURLServiceMap = @{}.mutableCopy;
    }
    return _registeredURLServiceMap;
//    return _registeredURLServiceMap = _registeredURLServiceMap ? : @{}.mutableCopy;
}

#pragma mark - Untils
+ (NSString *)replaceChineseCharInString:(NSString *)URLString
{
    return [URLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSError *)generateErrorWithLocalDescription:(nonnull NSString *)localDescription
{
    NSError *error = [NSError errorWithDomain:ZMRouterErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:localDescription}];
    return error;
}

- (NSDictionary *)convertUrlQueryToDictionary:(NSURL *)url
{
    NSMutableDictionary *dict = nil;
    if (url) {
        NSArray<NSURLQueryItem *> *queryItems = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:false].queryItems;
        [queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (idx != queryItems.count -1) {
                dict[obj.name] = obj.value;
            }
            else
                dict[obj.name] = [obj.value componentsSeparatedByString:@"#"].firstObject;
        }];
    }
    return dict.copy;
}

@end
