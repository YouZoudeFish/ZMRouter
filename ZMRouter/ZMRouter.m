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

static inline void _ZMHandleOnMainThread(ZMRouterHandler handler,NSDictionary *callBackDict) {
//    if (pthread_main_np()) {  // 需要#import <pthread.h>
    if ([[NSThread currentThread] isMainThread]) {
        handler(callBackDict);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(callBackDict);
        });
    }
}

static NSString * const ZMRouterErrorDomain = @"zm.www.git.com";

static NSString * const ZMRouterParameterKey = @"parameter";
static NSString * const ZMRouterHandlerKey = @"handler";
static NSString * const ZMRouterObjectKey = @"object";

@interface ZMRouter()
/**
 全局的Map，里面保存着注册的服务。以URL结构分层为键，传入的block或return的object为值
 */
@property (nonatomic, strong) NSMutableDictionary *registeredURLServiceMap;

@end

@implementation ZMRouter
{
    dispatch_semaphore_t semaphore;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored  "-Wunused-variable"

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
+ (NSError *)registerURLPatternService:(NSString *)URLPatternString forObject:(ZMRouterObjectHandler)handler
{
    return [ZMSharedRouter addURLServiceIntoMapWithURLString:[self replaceChineseCharInString:URLPatternString] forObject:handler];
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
- (NSError *)addURLServiceIntoMapWithURLString:(NSString *)URLString forHandler:(ZMRouterHandler)handler{
    ZMLock();
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    
    if (!handler) return [self generateErrorWithLocalDescription:@"无效的注册,未传入服务!"];
    NSError *error = nil;

    NSMutableArray <NSString *> *keyPathArray = @[].mutableCopy;
    if (scheme)  [keyPathArray addObject:scheme];
    if (host)  [keyPathArray addObject:host];
    if (path)  [keyPathArray addObject:path];
    
    __block NSString *keyPath;
    [keyPathArray enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0)
            keyPath = key;
        else
            keyPath = [NSString stringWithFormat:@"%@.%@",keyPath,key];
        
        if (![self.registeredURLServiceMap valueForKeyPath:keyPath]) {
            [self.registeredURLServiceMap setValue:[[NSMutableDictionary alloc] init] forKeyPath:keyPath];
        }
        
        if (idx == keyPathArray.count-1) {
            NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
            [self.registeredURLServiceMap setValue:@{
                                                     ZMRouterParameterKey:[parameterDict copy],
                                                     ZMRouterHandlerKey:[handler copy]
                                                     }
                                        forKeyPath:keyPath];
        }
    }];
    
//    if (handler) {
//        if (scheme){
//            // scheme不为空时，host可能为空，path也可能为空
//            if (!self.registeredURLServiceMap[scheme]) {
//                self.registeredURLServiceMap[scheme] = @{}.mutableCopy;
//            }
//            if (host) {
//                if (!self.registeredURLServiceMap[scheme][host])
//                    self.registeredURLServiceMap[scheme][host] = @{}.mutableCopy;
//                if (path) {
//                    if (!self.registeredURLServiceMap[scheme][host][path])
//                        self.registeredURLServiceMap[scheme][host][path] = @{}.mutableCopy;
//                    if (!query) {
//                        self.registeredURLServiceMap[scheme][host][path] = [handler copy];
//                    } else {
//                        NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
//                        self.registeredURLServiceMap[scheme][host][path] = @{
//                                                               ZMRouterParameterKey:[parameterDict copy],
//                                                               ZMRouterHandlerKey:[handler copy]
//                                                               };
//                    }
//                } else {
//                    self.registeredURLServiceMap[scheme][host] = [handler copy];
//                }
//            } else {
//                self.registeredURLServiceMap[scheme] = [handler copy];
//            }
//            
//        } else {
//            // 如果scheme为空，那么host也为空，但path肯定不为空
//            if (path) {
//                if (!self.registeredURLServiceMap[path]) {
//                    self.registeredURLServiceMap[path] = @{}.mutableCopy;
//                }
//                else {
//                    if (query){
//                        NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
//                        self.registeredURLServiceMap[path] = @{
//                                                               ZMRouterParameterKey:[parameterDict copy],
//                                                               ZMRouterHandlerKey:[handler copy]
//                                                               };
//                    } else
//                        self.registeredURLServiceMap[path] = [handler copy];
//                }
//            }
//        }
//    } else {
//        error = [self generateErrorWithLocalDescription:@"无效的注册,未传入服务!"];
//    }
    
    ZMUnlock();
    return error;
}

- (NSError *)addURLServiceIntoMapWithURLString:(NSString *)URLString forObject:(ZMRouterObjectHandler)handler {
    ZMLock();
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    
    if (!handler) return [self generateErrorWithLocalDescription:@"无效的注册,未传入服务!"];
    NSError *error = nil;
    
    NSMutableArray <NSString *> *keyPathArray = @[].mutableCopy;
    if (scheme)  [keyPathArray addObject:scheme];
    if (host)  [keyPathArray addObject:host];
    if (path)  [keyPathArray addObject:path];
    
    __block NSString *keyPath;
    
    NSDictionary *dic = [self convertUrlQueryToDictionary:url];
    id objectToStore = handler(dic);
    
    [keyPathArray enumerateObjectsUsingBlock:^(NSString * _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx == 0)
            keyPath = key;
        else
            keyPath = [NSString stringWithFormat:@"%@.%@",keyPath,key];
        
        if (![self.registeredURLServiceMap valueForKeyPath:keyPath]) {
            [self.registeredURLServiceMap setValue:[[NSMutableDictionary alloc] init] forKeyPath:keyPath];
        }
        
        if (idx == keyPathArray.count-1) {
            [self.registeredURLServiceMap setValue:@{
                                                     ZMRouterParameterKey:[dic copy],
                                                     ZMRouterHandlerKey:[handler copy],
                                                     ZMRouterObjectKey:objectToStore
                                                         }
                                        forKeyPath:keyPath];
        }
    }];
    
    ZMUnlock();
    return error;
}

- (void)openURLService:(NSString *)URLString withParameter:(NSDictionary *)parameter completionHandler:(ZMRouterCompleteHandler)completionHandler{
    NSURL *url = [NSURL URLWithString:URLString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    NSString *query = url.query;
    
    NSDictionary *savedDict = nil;
    
    NSMutableDictionary *callBackDict = [[NSMutableDictionary alloc] initWithDictionary:parameter];
    if (!scheme)
    {
        if (path)
            savedDict = self.registeredURLServiceMap[path];
    } else {
        if (!host) {
            savedDict = self.registeredURLServiceMap[scheme];
        } else {
            if (!path)
                savedDict = self.registeredURLServiceMap[scheme][host];
            else {
                if (query) {
                    NSDictionary *queryDict = [self convertUrlQueryToDictionary:url];
                    [callBackDict addEntriesFromDictionary:queryDict];
                }
                savedDict = self.registeredURLServiceMap[scheme][host][path];
            }
        }
    }
    
    if (completionHandler) {
        [callBackDict setObject:completionHandler forKey:@"completeHandler"];
    }
    
    if (!savedDict[ZMRouterObjectKey]) {
        _ZMHandleOnMainThread(savedDict[ZMRouterHandlerKey], callBackDict);
    } else {
        ((ZMRouterObjectHandler)savedDict[ZMRouterHandlerKey])(callBackDict);
    }
}

- (id)storedObjectOfURLString:(NSString *)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *path = url.path;
    NSString *query = url.query;

    NSDictionary *savedDict;
    NSMutableDictionary *objectDict = @{}.mutableCopy;
    if (!scheme)
    {
        if (path)
            savedDict = self.registeredURLServiceMap[path];
    } else {
        if (!host) {
            savedDict = self.registeredURLServiceMap[scheme];
        } else {
            if (!path)
                savedDict = self.registeredURLServiceMap[scheme][host];
            else {
                if (query) {
                    NSDictionary *parameterDict = [self convertUrlQueryToDictionary:url];
                    [objectDict setObject:parameterDict forKey:@"parameter"];
                }
                savedDict = self.registeredURLServiceMap[scheme][host][path];
            }
        }
    }
    
    return savedDict.copy;
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
    NSMutableDictionary *dict = @{}.mutableCopy;
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

#pragma clang diagnostic pop
@end
