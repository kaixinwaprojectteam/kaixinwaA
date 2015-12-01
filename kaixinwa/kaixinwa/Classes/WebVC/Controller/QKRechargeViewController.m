//
//  QKRechargeViewController.m
//  kaixinwa
//
//  Created by 张思源 on 15/11/26.
//  Copyright © 2015年 乾坤翰林. All rights reserved.
//

#import "QKRechargeViewController.h"
#import <StoreKit/StoreKit.h>
#import "QKLoadingView.h"
#import "QKHttpTool.h"
#import "QKAccount.h"
#import "QKAccountTool.h"

#define BuyVerifyHttps @"https://buy.itunes.apple.com/verifyReceipt"
#define SandboxVerifyHttps @"https://sandbox.itunes.apple.com/verifyReceipt"

@interface QKRechargeViewController ()<SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property(nonatomic,copy)NSString * price;
@property(nonatomic,copy)NSString * tradeNumber;

@property(nonatomic,strong)NSArray *products;
//等待视图
@property(nonatomic,weak)QKLoadingView * loadingView;
@end

@implementation QKRechargeViewController
-(NSArray *)products
{
    if (!_products) {
        _products = [NSArray array];
    }
    return _products;
}
- (void)viewDidLoad {
    [super viewDidLoad];
//    [self remotionVerify];
//    [self finishPurchasedWithTransaction];
    //添加等待视图
    QKLoadingView * loadingView = [[QKLoadingView alloc]initWithFrame:self.view.bounds];
    self.loadingView = loadingView;
    [self.view addSubview:loadingView];
    
//    [NSBundle mainBundle] appStoreReceiptURL
    // 1.加载想要销售的商品(NSArray)
    NSString *path = [[NSBundle mainBundle] pathForResource:@"products.plist" ofType:nil];
    NSArray *productsArray = [NSArray arrayWithContentsOfFile:path];
    
    // 2.取出所有想要销售商品的productId(NSArray)
    NSArray *productIdsArray = [productsArray valueForKeyPath:@"productId"];
    
    // 3.将所有的productId放入NSSet当中
    NSSet *productIdsSet = [NSSet setWithArray:productIdsArray];
    
    // 4.创建一个请求对象
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdsSet];
    
    // 4.1.设置代理
    request.delegate = self;
    
    // 5.开始请求可销售的商品
    [request start];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}
/**
 *  当请求到可销售的商品的时候,会调用该方法
 */
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    [self.loadingView hideView];
    self.loadingView = nil;
    for (SKProduct *product in response.products) {
        NSLog(@"%@", product.localizedTitle);
        NSLog(@"%@", product.localizedDescription);
        NSLog(@"%@", product.price);
        NSLog(@"%@", product.productIdentifier);
    }
    
    // 1.保留所有的可销售商品
    self.products = response.products;
    [self loadUrlWithString:self.urlStr];
}
//充豆方法
-(void)recharge
{
    NSLog(@"recharge js--%@--%@",self.price,self.tradeNumber);
    QKLoadingView * loading = [[QKLoadingView alloc]initWithFrame:self.view.bounds];
    loading.backgroundColor = [UIColor blackColor];
    loading.alpha = 0.4;
    [self.navigationController.view addSubview:loading];
    self.loadingView = loading;
    
    for (SKProduct * product in self.products) {
        if ([[product.price stringValue] isEqualToString:self.price]) {
            SKPayment *payment = [SKPayment paymentWithProduct:product];
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    }
}
/**
 当交易队列当中,有交易状态发生改变的时候会执行该方法
 */
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    /*
     SKPaymentTransactionStatePurchasing, 正在购买
     SKPaymentTransactionStatePurchased, 已经购买(向服务器发送请求,给用户东西,停止该交易)
     SKPaymentTransactionStateFailed, 购买失败
     SKPaymentTransactionStateRestored 恢复购买成功(向服务器发送请求,给用户东西,停止该交易)
     SKPaymentTransactionStateDeferred (iOS8-->用户还未决定最终状态)
     */
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"用户正在购买");
                
                break;
            case SKPaymentTransactionStatePurchased:
                // 请求给用户物品
                NSLog(@"用户购买成功");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                //本地验证
//                [self verifyPruchase];
                //远程验证
                [self finishPurchasedWithTransaction];
                
                
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"用户购买失败");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                [self.loadingView hideView];
                self.loadingView = nil;
                break;
            case SKPaymentTransactionStateRestored:
                // 请求给用户物品
                NSLog(@"用户恢复购买成功");
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                [self.loadingView hideView];
                self.loadingView = nil;
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"用户还未决定");
                break;
            default:
                break;
        }
    }
}


#pragma mark - webviewDelegate 
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString * str = request.URL.absoluteString;
    DCLog(@"%@",str);
    if ([str hasPrefix:@"ios://recharge"]) {
        NSArray * array= [str componentsSeparatedByString:@"://"];
        NSString * str1 = array.lastObject;
        NSArray * str1Array = [str1 componentsSeparatedByString:@"/price/"];
        NSString * ocMethod = str1Array.firstObject;
        NSString * str2 = str1Array.lastObject;
        NSArray * priceAndTradeNo = [str2 componentsSeparatedByString:@"/out_trade_no/"];
        self.price = priceAndTradeNo.firstObject;
        self.tradeNumber = [QKHttpTool md5HexDigest:priceAndTradeNo.lastObject];
        //js通过方法名调用oc方法
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(ocMethod)];
#pragma clang diagnostic pop
        return NO;
    }
    return YES;
    
}



#pragma mark 验证票据方法
//本地验证验证票据
- (void)verifyPruchase
{
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    // 发送网络POST请求，对购买凭据进行验证
    NSURL *url = [NSURL URLWithString:BuyVerifyHttps];
    // 国内访问苹果服务器比较慢，timeoutInterval需要长一点
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    request.HTTPMethod = @"POST";
    
    // 在网络中传输数据，大多情况下是传输的字符串而不是二进制数据
    // 传输的是BASE64编码的字符串
    /**
     20      BASE64 常用的编码方案，通常用于数据传输，以及加密算法的基础算法，传输过程中能够保证数据传输的稳定性
     21      BASE64是可以编码和解码的
     22      */
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = payloadData;
    
    // 提交验证请求，并获得官方的验证JSON结果
    NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];

    // 官方验证结果为空
    if (result == nil) {
        NSLog(@"验证失败");
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:result options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"%@", dict);
    if ([dict[@"status"] isEqualToNumber:@21007]) {
        NSURL *urlBuy = [NSURL URLWithString:SandboxVerifyHttps];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlBuy cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
        request.HTTPMethod = @"POST";
        request.HTTPBody = payloadData;
        NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
        if (result == nil) {
            DCLog(@"验证失败");
        }
        NSDictionary *dictBuy = [NSJSONSerialization JSONObjectWithData:result options:NSJSONReadingAllowFragments error:nil];
        DCLog(@"%@",dictBuy);
        if (dictBuy != nil) {
            DCLog(@"验证成功");
            //发送请求通知更改开心豆
            
        }
    }else{
        //沙盒环境
        NSLog(@"沙盒环境验证成功");
        //发送请求通知更改开心豆
        
    }
    
}

//服务器验证
-(void)finishPurchasedWithTransaction
{
    //    @"http://101.200.173.111/kaixinwa2.0/mall.php/Index/ios_pay"
    NSURL * url = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:url];
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    //
    [QKHttpTool postJSON:@"http://101.200.173.111/kaixinwa2.0/mall.php/Index/ios_pay" params:@{@"receipt-data":encodeStr,@"uid":[QKAccountTool readAccount].uid,@"out_trade_no":self.tradeNumber} success:^(id responseObj) {
//        DCLog(@"%@",responseObj);
        if ([responseObj[@"code"] isEqualToNumber:@0]) {
            DCLog(@"充值成功");
            [[NSNotificationCenter defaultCenter] postNotificationName:NotifacationSuccessForRecharge object:nil userInfo:@{@"price":self.price}];
        }
        [self.myWebView reload];
        [self.loadingView hideView];
        self.loadingView = nil;
        
    } failure:^(NSError *error) {
        DCLog(@"%@",error);
    }];
}


-(void)remotionVerify
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    NSURL *url = [NSURL URLWithString:@"http://101.200.173.111/kaixinwa2.0/mall.php/Index/ios_pay"];
//
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    request.HTTPMethod = @"POST";
    
    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
//    ,\"uid\":\"%@\"  ,[QKAccountTool readAccount].uid
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\",\"uid\":\"%@\",\"out_trade_no\":\"%@\"}", encodeStr,[QKAccountTool readAccount].uid,self.tradeNumber];
    NSLog(@"%@",payload);
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    request.HTTPBody = payloadData;
    
    // 提交验证请求，并获得官方的验证JSON结果
    NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    // 官方验证结果为空
    if (result == nil) {
        NSLog(@"验证失败");
    }else{
        NSError *error = nil;
        NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:result options:NSJSONReadingAllowFragments error:&error];
        NSLog(@"验证成功%@",dict);
         NSString *str1 = [[NSString alloc]initWithData:result encoding:NSUTF8StringEncoding];
        NSLog(@"------%@",str1);
    
    }
}

@end