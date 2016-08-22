# HttpsTest
iOS https trust CA(Certificate Authority) 
## iOS开发信任SSL证书和自签名证书实现HTTPS

### 首先来分析一下什么是HTTPS以及了解HTTPS对于iOS开发者的意义

* HTTPS 以及SSL/TSL

1.  什么是SSL？

SSL(Secure Sockets Layer, 安全套接字层)，因为原先互联网上使用的 HTTP 协议是明文的，存在很多缺点，比如传输内容会被偷窥（嗅探）和篡改。 SSL 协议的作用就是在传输层对网络连接进行加密。

2. 何为TLS？

到了1999年，SSL 因为应用广泛，已经成为互联网上的事实标准。IETF 就在那年把 SSL 标准化。标准化之后的名称改为 TLS（Transport Layer Security，传输层安全协议）。**SSL与TLS可以视作同一个东西的不同阶段**



3. HTTPS

简单来说，HTTPS = HTTP + SSL/TLS, 也就是 HTTP over SSL 或 HTTP over TLS，这是后面加 S 的由来 。

**HTTPS和HTTP异同：HTTP和HTTPS使用的是完全不同的连接方式，用的端口也不一样，前者是80，后者是443。HTTP的连接很简单，是无状态的；HTTPS协议是由SSL+HTTP协议构建的可进行加密传输、身份认证的网络协议，比HTTP协议安全。**



> 在WWDC 2016开发者大会上，苹果[宣布了一个最后期限](https://techcrunch.com/2016/06/14/apple-will-require-https-connections-for-ios-apps-by-the-end-of-2016/)：到2017年1月1日 App Store中的所有应用都必须启用 App Transport Security安全功能。App Transport Security（ATS）是苹果在iOS 9中引入的一项隐私保护功能，屏蔽明文HTTP资源加载，连接必须经过更安全的HTTPS。苹果目前允许开发者暂时关闭ATS，可以继续使用HTTP连接，但到年底所有官方商店的应用都必须强制性使用ATS。



**所以对于iOS开发者来说，需要尽早解决HTTPS请求的问题。**





### 发送HTTPS请求信任SSL证书和自签名证书，分为三种情况

1. 如果你的app服务端安装的是SLL颁发的CA，可以使用系统方法直接实现信任SSL证书，关于Apple对SSL证书的要求请参考：[苹果官方文档CertKeyTrustProgGuide](https://developer.apple.com/library/mac/documentation/Security/Conceptual/CertKeyTrustProgGuide/iPhone_Tasks/iPhone_Tasks.html)

这种方式不需要在Bundle中引入CA文件，可以交给系统去判断服务器端的证书是不是SSL证书，验证过程也不需要我们去具体实现。

示例代码：

```

NSURL *URL = [NSURL URLWithString:URLString];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:10];
    if (self.isSlideUpdated && type == 1) {
        request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:10];
    }
    //创建同步连接
    NSError *error = nil;
    NSData *receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
    NSString *receivedInfo = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
```

> 当然，如果你需要同时信任SSL证书和自签名证书的话还是需要在代码中实现CA的验证，这种情况在后面会提到。



2. 基于AFNetWorking的SSL特定服务器证书信任处理，重写AFNetWorking的customSecurityPolicy方法,这里我创建了一个HttpRequest类，分别对GET和POST方法进行了封装，以GET方法为例：



```


+ (void)get:(NSString *)url params:(NSDictionary *)params success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    // 1.获得请求管理者
    AFHTTPRequestOperationManager *mgr = [AFHTTPRequestOperationManager manager];
    // 2.申明返回的结果是text/html类型
    mgr.responseSerializer = [AFHTTPResponseSerializer serializer];
    // 3.设置超时时间为10s
    mgr.requestSerializer.timeoutInterval = 10;
    
    // 加上这行代码，https ssl 验证。
    if(openHttpsSSL) {
        [mgr setSecurityPolicy:[self customSecurityPolicy]];
    }
    
    // 4.发送GET请求
    [mgr GET:url parameters:params success:^(AFHTTPRequestOperation *operation, id responseObj){
        if (success) {
            success(responseObj);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (error) {
            failure(error);
        }
    }];
}
```
```
+ (AFSecurityPolicy*)customSecurityPolicy {
    // /先导入证书
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:certificate ofType:@"cer"];//证书的路径
    NSData *certData = [NSData dataWithContentsOfFile:cerPath];
    
    // AFSSLPinningModeCertificate 使用证书验证模式
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    
    // allowInvalidCertificates 是否允许无效证书（也就是自建的证书），默认为NO
    // 如果是需要验证自建证书，需要设置为YES
    securityPolicy.allowInvalidCertificates = YES;
    
    //validatesDomainName 是否需要验证域名，默认为YES；
    //假如证书的域名与你请求的域名不一致，需把该项设置为NO；如设成NO的话，即服务器使用其他可信任机构颁发的证书，也可以建立连接，这个非常危险，建议打开。
    //置为NO，主要用于这种情况：客户端请求的是子域名，而证书上的是另外一个域名。因为SSL证书上的域名是独立的，假如证书上注册的域名是www.google.com，那么mail.google.com是无法验证通过的；当然，有钱可以注册通配符的域名*.google.com，但这个还是比较贵的。
    //如置为NO，建议自己添加对应域名的校验逻辑。
    securityPolicy.validatesDomainName = NO;
    
    securityPolicy.pinnedCertificates = @[certData];
    
    return securityPolicy;
}


```

**其中的cerPath就是app bundle中证书路径，certificate为证书名称的宏，仅支持cer格式，securityPolicy的相关配置尤为重要，请仔细阅读customSecurityPolicy方法并根据实际情况设置其属性。**

> 这样，就能够在AFNetWorking的基础上使用HTTPS协议访问特定服务器，但是不能信任根证书的CA文件，因此这种方式存在风险，读取pinnedCertificates中的证书数组的时候有可能失败，如果证书不符合，certData就会为nil。



3.更改系统方法，发送异步NSURLConnection请求。



```


- (void)getDataWithURLRequest {
    //connection
    NSString *urlStr = @"https://developer.apple.com/cn/";
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self];
    [connection start];
}
```

> 重点在于处理NSURLConnection的didReceiveAuthenticationChallenge代理方法，对CA文件进行验证，并建立信任连接。



``` 

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
 /*
    //直接验证服务器是否被认证（serverTrust），这种方式直接忽略证书验证，直接建立连接，但不能过滤其它URL连接，可以理解为一种折衷的处理方式，实际上并不安全，因此不推荐。
    SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
    return [[challenge sender] useCredential: [NSURLCredential credentialForTrust: serverTrust]
                  forAuthenticationChallenge: challenge];
     */
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        do
        {
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            NSCAssert(serverTrust != nil, @"serverTrust is nil");
            if(nil == serverTrust)
                break; /* failed */
            /**
             *  导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA）
             */
            NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"cloudwin" ofType:@"cer"];//自签名证书
            NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
            
            NSString *cerPath2 = [[NSBundle mainBundle] pathForResource:@"apple" ofType:@"cer"];//SSL证书
            NSData * caCert2 = [NSData dataWithContentsOfFile:cerPath2];
            
            NSCAssert(caCert != nil, @"caCert is nil");
            if(nil == caCert)
                break; /* failed */
            
            NSCAssert(caCert2 != nil, @"caCert2 is nil");
            if (nil == caCert2) {
                break;
            }
            
            SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
            NSCAssert(caRef != nil, @"caRef is nil");
            if(nil == caRef)
                break; /* failed */
            
            SecCertificateRef caRef2 = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert2);
            NSCAssert(caRef2 != nil, @"caRef2 is nil");
            if(nil == caRef2)
                break; /* failed */
            
            NSArray *caArray = @[(__bridge id)(caRef),(__bridge id)(caRef2)];
        
            NSCAssert(caArray != nil, @"caArray is nil");
            if(nil == caArray)
                break; /* failed */
            
            OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
            NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
            if(!(errSecSuccess == status))
                break; /* failed */
            
            SecTrustResultType result = -1;
            status = SecTrustEvaluate(serverTrust, &result);
            if(!(errSecSuccess == status))
                break; /* failed */
            NSLog(@"stutas:%d",(int)status);
            NSLog(@"Result: %d", result);
            
            BOOL allowConnect = (result == kSecTrustResultUnspecified) || (result == kSecTrustResultProceed);
            if (allowConnect) {
                NSLog(@"success");
            }else {
                NSLog(@"error");
            }
            /* https://developer.apple.com/library/ios/technotes/tn2232/_index.html */
            /* https://developer.apple.com/library/mac/qa/qa1360/_index.html */
            /* kSecTrustResultUnspecified and kSecTrustResultProceed are success */
            if(! allowConnect)
            {
            break; /* failed */
            }
            
#if 0
            /* Treat kSecTrustResultConfirm and kSecTrustResultRecoverableTrustFailure as success */
            /*   since the user will likely tap-through to see the dancing bunnies */
            if(result == kSecTrustResultDeny || result == kSecTrustResultFatalTrustFailure || result == kSecTrustResultOtherError)
                break; /* failed to trust cert (good in this case) */
#endif
            
            // The only good exit point
            return [[challenge sender] useCredential: [NSURLCredential credentialForTrust: serverTrust]
                          forAuthenticationChallenge: challenge];
            
        } while(0);
    }
    
    // Bad dog
    return [[challenge sender] cancelAuthenticationChallenge: challenge];
    
}
```

> 这里的关键在于result参数的值，根据官方文档的说明，判断(result == kSecTrustResultUnspecified) || (result == kSecTrustResultProceed)的值，若为1，则该网站的CA被app信任成功，可以建立数据连接，这意味着所有由该CA签发的各个服务器证书都被信任，而访问其它没有被信任的任何网站都会连接失败。该CA文件既可以是SLL也可以是自签名。

**NSURLConnection的其它代理方法实现**

```

#pragma mark -- connect的异步代理方法
-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"请求被响应");
    _mData = [[NSMutableData alloc]init];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(nonnull NSData *)data {
    NSLog(@"开始返回数据片段");
    
    [_mData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"链接完成");
    //可以在此解析数据
    NSString *receiveInfo = [NSJSONSerialization JSONObjectWithData:self.mData options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"received data:\n%@",self.mData);
    NSLog(@"received info:\n%@",receiveInfo);
}

//链接出错
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"error - %@",error);
}
```

**至此，HTTPS信任证书的问题得以解决，这不仅是为了响应Apple强制性使用ATS的要求，也是为了实际生产环境安全性的考虑，HTTPS是未来的趋势，建议今早支持。**
