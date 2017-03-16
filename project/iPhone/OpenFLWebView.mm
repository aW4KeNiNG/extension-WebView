#include <vector>

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#include <Utils.h>

// used from external interface

extern "C"{
    void openflwebview_sendEvent(const char* event, const char* params);
}

@interface OpenFLWebView : WKWebView <WKNavigationDelegate>

@property (assign) int mId;
@property (strong) UIImageView* mCloseView;

- (id) initWithUrlAndFrame: (NSString*)url width: (int)width height: (int)height;
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

- (id)initWithUrlAndFrame:(NSString *)url width:(int)width height:(int)height{
    mId = mLastId;
    ++mLastId;
    NSURL* _url = [[NSURL alloc] initWithString: url];
    NSURLRequest *req = [[NSURLRequest alloc] initWithURL:_url];
    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    conf.allowsInlineMediaPlayback = true;
    conf.mediaPlaybackRequiresUserAction = false;
    //conf.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;       //TODO ios10
    self = [self initWithFrame: CGRectMake(0,0,width,height) configuration: conf];
    self.navigationDelegate = self;
    self.scrollView.bounces = NO;
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

@end

namespace openflwebview {
    
    static std::vector<OpenFLWebView*> webViews;
    
    /**
     * Create a WebView
     * @param url default url to load
     * @param width webview width
     * @param height webview height
     */
    int create(const char* url, int width, int height){
        NSString* defaultUrl = [[NSString alloc] initWithUTF8String:url];
        OpenFLWebView* webView = [[OpenFLWebView alloc] initWithUrlAndFrame:defaultUrl width:width height:height];
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

        CGRect newFrame = webView.frame;
		newFrame.origin = CGPointMake(x,y);
        
        [webView setFrame: newFrame];
    }
    
    void setDim(int id, int x, int y){
        OpenFLWebView* webView = getWebView(id);

        CGRect newFrame = webView.frame;
        newFrame.size = CGSizeMake(x,y);
        
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
    
}