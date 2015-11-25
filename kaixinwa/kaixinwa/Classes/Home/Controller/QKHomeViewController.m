//
//  QKHomeViewController.m
//  kaixinwa
//
//  Created by 郭庆宇 on 15/6/28.
//  Copyright (c) 2015年 郭庆宇. All rights reserved.
//
#define ScanViewWidthAndHeight QKScreenWidth * 0.6
#define QKScreenHeight [UIScreen mainScreen].bounds.size.height
#define QKCellHeight 160


#import "QKHomeViewController.h"
#import "QKQRCodeViewController.h"
#import "QKHttpTool.h"
#import "MJExtension.h"
#import "ImagePlayerView.h"
#import "QKFirstHome.h"
#import "QKLunbo.h"
#import "UIImageView+WebCache.h"
#import "QKGridView.h"
#import "QKRadioView.h"
#import "QKAnimationView.h"
#import "QKWebViewController.h"
#import "QKAccountTool.h"
#import "QKAccount.h"
#import "MBProgressHUD+MJ.h"
#import "QKGetHappyPeaTool.h"
#import "QKSignResult.h"
#import "QKLoginViewController.h"

@interface QKHomeViewController ()<ImagePlayerViewDelegate>
@property(nonatomic,strong)NSMutableArray * imageUrls;
@property(nonatomic,strong)NSMutableArray * lunboDesUrls;
@property(nonatomic,weak)UIScrollView * scrollView;
@property(nonatomic,weak)ImagePlayerView * imagePlayerView;
@property(nonatomic,weak)QKGridView * exchangeView;
@property(nonatomic,weak)QKRadioView * radioView;
@property(nonatomic,weak)QKGridView * gameView;
@property(nonatomic,weak)QKAnimationView * anView;
@end

@implementation QKHomeViewController
-(NSMutableArray *)imageUrls
{
    if (!_imageUrls) {
        _imageUrls = [NSMutableArray array];
    }
    return _imageUrls;
}
-(NSMutableArray *)lunboDesUrls
{
    if (!_lunboDesUrls) {
        _lunboDesUrls = [NSMutableArray array];
    }
    return _lunboDesUrls;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.titleView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"kaixinwa"]];
    self.navigationItem.leftBarButtonItem = [UIBarButtonItem itemWithImageName:@"meiriqiandao" highImageName:@"meiriqiandao_sel" target:self action:@selector(signEveryday:)];
    self.navigationItem.rightBarButtonItem = [UIBarButtonItem itemWithImageName:@"huoqudaan" highImageName:@"huoqudaan_sel" target:self action:@selector(toScanView)];
    
    [self creatUI];
    
    //发送请求获取首页数据
    [QKHttpTool post:@"http://101.200.173.111/kaixinwa2.0/index.php/Kxwapi/Index/getHome" params:nil success:^(id responseObj) {
//        DCLog(@"%@",responseObj);
        QKFirstHome * home = [QKFirstHome objectWithKeyValues:responseObj];
        for (QKLunbo * lunbo in home.data.lunbo) {
            [self.imageUrls addObject:lunbo.lunbo_faceurl];
            [self.lunboDesUrls addObject:lunbo.lunbo_des_url];
        }
        self.exchangeView.items = home.data.goods;
        self.radioView.radio = home.data.radio;
        self.anView.items = home.data.video;
        self.gameView.items = home.data.game;
        [self.imagePlayerView reloadData];
        
    } failure:^(NSError *error) {
        DCLog(@"%@",error);
    }];
    //注册通知处理点击游戏图
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gameMethod:) name:NotifacationToSkipGameWeb object:nil];
}

-(void)toScanView
{
    QKQRCodeViewController * qrVC = [[QKQRCodeViewController alloc]init];
    [self.navigationController pushViewController:qrVC animated:YES];
}
-(void)signEveryday:(UIBarButtonItem*)item
{
    //签到方法
    QKAccount* account = [QKAccountTool readAccount];
    if (account) {
        if (account.lasttime) {
            //发送签到请求
            NSDictionary * param = @{@"uid":account.uid};
            [QKHttpTool post:SignEverydayInterface params:param success:^(id responseObj) {
                //            DCLog(@"----%@",responseObj);
                QKSignResult * signResult =[QKSignResult objectWithKeyValues:responseObj];
                NSString * code = [signResult.code stringValue];
                //更新账号信息
                if ([code isEqualToString:@"201"]) {
                    
                    account.lasttime = signResult.data.lasttime;
                    [QKAccountTool save:account];
                    [MBProgressHUD showSuccess:signResult.message];
                    [QKGetHappyPeaTool getHappyPeaNum];
                    //发送通知完成签到任务
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"finishSignTask" object:nil];
                }else{
                    [MBProgressHUD showError:signResult.message];
                }
            } failure:^(NSError *error) {
                DCLog(@"----%@",error);
            }];
        }else{
            [MBProgressHUD showError:@"已签到"];
        };
    }else{
        QKLoginViewController* loginVc = [[QKLoginViewController alloc]init];
        UINavigationController * nav = [[UINavigationController alloc]initWithRootViewController:loginVc];
        [nav setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
        
        [self presentViewController:nav animated:YES completion:nil];
        
    }
    
    
}
#pragma mark - 通知方法
-(void)gameMethod:(NSNotification *)noti
{
    QKWebViewController * wvc = [[QKWebViewController alloc]init];
    NSString * url = noti.userInfo[GameKey];
    NSString * firstStr = @"http://";
    firstStr = [firstStr stringByAppendingString:url];
    wvc.urlStr = firstStr;
    [self.navigationController pushViewController:wvc animated:YES];
}

#pragma mark -
-(void)creatUI
{
    UIScrollView * scrollView = [[UIScrollView alloc]init];
    scrollView.backgroundColor = QKGlobalBg;
    scrollView.frame = self.view.bounds;
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
    //轮播视图
    ImagePlayerView * imagePlayerView = [[ImagePlayerView alloc]init];
    
//    imagePlayerView.backgroundColor = [UIColor cyanColor];
    imagePlayerView.frame = CGRectMake(0, 0, self.view.width, 160);
    imagePlayerView.imagePlayerViewDelegate = self;
    imagePlayerView.scrollInterval = 5.0;
    imagePlayerView.pageControlPosition = ICPageControlPosition_BottomCenter;
    imagePlayerView.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
    imagePlayerView.pageControl.currentPageIndicatorTintColor = [UIColor greenColor];
    self.imagePlayerView = imagePlayerView;
    [scrollView addSubview:imagePlayerView];
    //限时兑换
    QKGridView * exchangeView = [[QKGridView alloc]init];
    exchangeView.title = @"限时兑换";
    exchangeView.moreBtnTag = 1;
    exchangeView.x = 0;
    exchangeView.y = QKCellMargin + imagePlayerView.height;
    exchangeView.width = QKScreenWidth;
    exchangeView.height = QKCellHeight;
    self.exchangeView = exchangeView;
    [scrollView addSubview:exchangeView];
    //开心电台
    QKRadioView * radioView = [[QKRadioView alloc]init];
    radioView.title = @"开心电台";
    radioView.x = 0;
    radioView.y = CGRectGetMaxY(exchangeView.frame);
    radioView.width = QKScreenWidth;
    radioView.height = QKCellHeight;
    [scrollView addSubview:radioView];
    self.radioView = radioView;
    //开心蛙动画
    QKAnimationView * anView = [[QKAnimationView alloc]init];
    anView.title = @"开心蛙动画";
    anView.x = 0;
    anView.y = CGRectGetMaxY(radioView.frame);
    anView.width = QKScreenWidth;
    anView.height = QKCellHeight;
    [scrollView addSubview:anView];
    self.anView = anView;
    
    //开心益智游戏
    QKGridView *gameView = [[QKGridView alloc]init];
    gameView.title = @"开心益智游戏";
    gameView.moreBtnTag = 2;
    gameView.x = exchangeView.x;
    gameView.y = CGRectGetMaxY(anView.frame);
    gameView.width = QKScreenWidth;
    gameView.height = QKCellHeight;
    [scrollView addSubview:gameView];
    self.gameView = gameView;
    
    scrollView.contentSize = CGSizeMake(0, CGRectGetMaxY(gameView.frame));
    //下拉刷新
    UIRefreshControl * refreshControl = [[UIRefreshControl alloc]init];
//    refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"开始刷新"];
    [scrollView addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshHomeData:) forControlEvents:UIControlEventValueChanged];
    
}
//下拉刷新
-(void)refreshHomeData:(UIRefreshControl *)refreshControl
{
    [refreshControl beginRefreshing];
    //发送网络请求
    /* ---------- */
    CGFloat delayInSeconds = 1.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [refreshControl endRefreshing];
    });
}

//设置轮播视图代理
#pragma mark - ImagePlayerViewDelegate
- (NSInteger)numberOfItems
{
    return self.imageUrls.count;
}

- (void)imagePlayerView:(ImagePlayerView *)imagePlayerView loadImageForImageView:(UIImageView *)imageView index:(NSInteger)index
{
    [imageView sd_setImageWithURL:[NSURL URLWithString:[self.imageUrls objectAtIndex:index]] placeholderImage:[UIImage imageNamed:@"placeholder"]];
}
- (void)imagePlayerView:(ImagePlayerView *)imagePlayerView didTapAtIndex:(NSInteger)index
{
    DCLog(@"did tap index = %@", self.lunboDesUrls[index]);
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
