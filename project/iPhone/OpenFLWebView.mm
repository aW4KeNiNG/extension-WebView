#include <vector>

#import <sys/utsname.h>

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#include <Utils.h>

/*
 *  System Versioning Preprocessor Macros
 */

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

// used from external interface

extern "C"{
    void openflwebview_sendEvent(const char* event, const char* params);
}

@interface OpenFLWebView : WKWebView <WKNavigationDelegate, WKUIDelegate/*, WKScriptMessageHandler*/>

@property (assign) int mId;
@property (strong) UIImageView* mCloseView;

- (id) initWithUrlAndFrame: (NSString*)url width: (int)width height: (int)height userAgent: (NSString*)userAgent;
- (int) getId;
- (void) addCloseBtn;
- (void) updateCloseFrame;
- (void) closePressed;
- (UIImageView*) getButton;

@end

@implementation OpenFLWebView

@synthesize mId;
@synthesize mCloseView;

static int mLastId = 0;

- (id)initWithUrlAndFrame:(NSString *)url width:(int)width height:(int)height userAgent:(NSString*)userAgent{
    mId = mLastId;
    ++mLastId;
    NSURL* _url = [[NSURL alloc] initWithString: url];
    NSURLRequest *req = [[NSURLRequest alloc] initWithURL:_url];
    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    [conf setAllowsInlineMediaPlayback: YES];
    conf.allowsInlineMediaPlayback = true;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {
        conf.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    } else {
        conf.mediaPlaybackRequiresUserAction = false;
    }

    /*WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"logging"];
    [conf setUserContentController:ucc];*/

    self = [self initWithFrame: CGRectMake(0,0,width,height) configuration: conf];
    self.navigationDelegate = self;
    self.UIDelegate = self;
    self.scrollView.bounces = NO;
    
    /*NSString * js = @"var console = { log: function(msg){window.webkit.messageHandlers.logging.postMessage(msg) } };";
    [self evaluateJavaScript:js completionHandler:^(id _Nullable ignored, NSError * _Nullable error) {
        if (error != nil)
            NSLog(@"installation of console.log() failed: %@", error);
    }];*/

    if(userAgent != nil)
    {
        [self evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
            NSString *newUserAgent = [result stringByAppendingString:userAgent];
            self.customUserAgent = newUserAgent;
        }];
    }
    
    [self loadRequest:req];
    
    return self;
}

- (int)getId {
    return mId;
}

- (void) addCloseBtn {
    NSString *dpi = @"mdpi";
    
    CGFloat scale = [[UIScreen mainScreen] scale];
    if(scale > 1)
        dpi = @"xhdpi";

    UIImage* closeImage = [[UIImage alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: [NSString stringWithFormat:@"assets/webviewui/close_%@.png", dpi] ofType: nil]];
    
    mCloseView = [[UIImageView alloc] initWithImage: closeImage];
    mCloseView.userInteractionEnabled = YES;
    
    [self updateCloseFrame];

    //[mCloseBtn setImageEdgeInsets: UIEdgeInsetsMake( -20, -20, -20, -20)];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closePressed)];
    tap.numberOfTapsRequired = 1;
    [mCloseView addGestureRecognizer: tap];
    [[self superview] addSubview:mCloseView];
}

- (void) updateCloseFrame {
    if(mCloseView != NULL){
        UIImage *closeImage = mCloseView.image;
    
        CGFloat offsetX = (closeImage.size.width / 1.5);
        CGFloat offsetY = (closeImage.size.height / 3);
    
        int x = self.frame.origin.x + self.frame.size.width - offsetX;
        int y = self.frame.origin.y + 0 - offsetY;
    
        mCloseView.frame = CGRectMake(x,y,closeImage.size.width, closeImage.size.height);
    }
}

- (void) closePressed {
    openflwebview_sendEvent("close", "none");
}

- (UIImageView*)getButton {
    return mCloseView;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(nonnull WKNavigationAction *)navigationAction decisionHandler:(nonnull void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (navigationAction.request.URL) {
        if(navigationAction.targetFrame.isMainFrame) {
           openflwebview_sendEvent("change", [[navigationAction.request.URL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        else {
           openflwebview_sendEvent("change_blank", [[navigationAction.request.URL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (navigationAction.request.URL) {
        if(navigationAction.targetFrame.isMainFrame) {
           openflwebview_sendEvent("change", [[navigationAction.request.URL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        else {
           openflwebview_sendEvent("change_blank", [[navigationAction.request.URL absoluteString] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }

    return nil;
}

/*- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    NSLog(@"log: %@", message.body);
}*/

@end

namespace openflwebview {
    
    static std::vector<OpenFLWebView*> webViews;
    
    //NSString* _getModel();
    //BOOL _isiPhoneX(void);
    //BOOL _isiPadPro(void);
    CGFloat _getScreenScale();

    /**
     * Create a WebView
     * @param url default url to load
     * @param width webview width
     * @param height webview height
     */
    int create(const char* url, int width, int height, const char* userAgent){
        NSString* defaultUrl = [[NSString alloc] initWithUTF8String:url];
        NSString* defaultUserAgent = (userAgent != NULL) ? [[NSString alloc] initWithUTF8String:userAgent] : nil;
        OpenFLWebView* webView = [[OpenFLWebView alloc] initWithUrlAndFrame:defaultUrl width:width height:height userAgent:defaultUserAgent];
        webViews.push_back(webView);
        return [webView getId];
    }
    
    /**
     * get the webView with corresponding id
     * @param id
     **/
    OpenFLWebView* getWebView(int id){
        std::vector<OpenFLWebView*>::iterator iter = webViews.begin();

        while(iter != webViews.end()){
            OpenFLWebView* current = *iter;
            if([current getId] == id)
                return current;
            iter++;
        }

        return NULL;
    }
    
    void onAdded(int id){
        UIWindow* win = [[UIApplication sharedApplication] keyWindow ];
        UIViewController* parentController = [win rootViewController];
        
        OpenFLWebView* view = getWebView(id);
    
        [parentController.view addSubview: view];
        
        UIImageView* button = [view getButton];
        if(button != NULL)
            [[view superview] addSubview: button];
    }
    
    void onRemoved(int id){
        OpenFLWebView* webView = getWebView(id);
        
        
        UIImageView* button = [webView getButton];
        if(button != NULL)
            [button removeFromSuperview];

        [webView stopLoading];
        [webView removeFromSuperview];
    }
    
    void setPos(int id, int x, int y){
        OpenFLWebView* webView = getWebView(id);
        CGFloat screenScale = _getScreenScale();
        CGRect newFrame = webView.frame;
		newFrame.origin = CGPointMake(x / screenScale, y / screenScale);
        
        [webView setFrame: newFrame];
    }
    
    void setDim(int id, int x, int y){
        OpenFLWebView* webView = getWebView(id);
        CGFloat screenScale = _getScreenScale();
        CGRect newFrame = webView.frame;
        newFrame.size = CGSizeMake(x / screenScale, y / screenScale);
        
        [webView setFrame: newFrame];
        [webView updateCloseFrame];
    }
    
    void dispose(int id){
        std::vector<OpenFLWebView*>::iterator iter = webViews.begin();

        while(iter != webViews.end()){
            OpenFLWebView* current = *iter;
            if([current getId] == id){
                [current release];
                webViews.erase(iter);
                break;
            }
            iter++;
        }
    }
    
    void loadUrl(int id, const char* url){
        OpenFLWebView* webView = getWebView(id);
        NSString* urlStr = [[NSString alloc] initWithUTF8String: url];
        NSURL* _url = [[NSURL alloc] initWithString:urlStr ];
        NSURLRequest *req = [[NSURLRequest alloc] initWithURL: _url];
        [webView loadRequest: req];
    }
    
    void addCloseBtn(int id){
        OpenFLWebView* webview = getWebView(id);
        [webview addCloseBtn];
    }

    /*NSString* _getModel()
    {
        static NSString *model;
        static dispatch_once_t onceToken;

        dispatch_once(&onceToken, ^{
    #if TARGET_IPHONE_SIMULATOR
            model = NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"];
    #else

            struct utsname systemInfo;
            uname(&systemInfo);

            model = [NSString stringWithCString:systemInfo.machine
                                                encoding:NSUTF8StringEncoding];
    #endif
            NSLog(@"MODEL: %@", model);
        });

        return model;
    }

    BOOL _isiPhoneX(void)
    {
        NSString *model = _getModel();
        return [model isEqualToString:@"iPhone10,3"] || [model isEqualToString:@"iPhone10,6"];
    }

    BOOL _isiPadPro(void)
    {
        NSString *model = _getModel();
        return [model isEqualToString:@"iPad6,7"] || //iPad Pro 12.9''
            [model isEqualToString:@"iPad6,8"] ||    //iPad Pro 12.9''
            [model isEqualToString:@"iPad7,1"] ||    //iPad Pro 12.9'' 2th gen
            [model isEqualToString:@"iPad7,2"];      //iPad Pro 12.9'' 2th gen  
    }*/

    CGFloat _getScreenScale()
    {
        CGFloat screenScale = [[UIScreen mainScreen] nativeScale];
        NSLog(@"WebView: Screen Scale: %.2f", screenScale);

        return screenScale;
    }
    
}