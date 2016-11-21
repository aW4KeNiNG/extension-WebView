package fr.tbaudon;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.RelativeLayout.LayoutParams;
import fr.tbaudon.openflwebview.R;
import org.haxe.lime.HaxeObject;

public class WebViewObject extends Object implements Runnable{

	private int mWidth;
	private int mHeight;

	private int mX;
	private int mY;

	private boolean mVerbose;
	private boolean mAddClose;
	private boolean mWebViewAdded;

	private State mState;

    private WebView mWebView;
    private ImageView mClose;
    private RelativeLayout mLayout;
    private Activity mActivity;
    private HaxeObject mObject;
    private LayoutParams mLayoutParams;
    private LayoutParams mCloseLayoutParams;

    private int mCloseOffsetX;
    private int mCloseOffsetY;

	public WebViewObject(Activity mainActivity, HaxeObject object, int width, int height, boolean closeBtn){
		super();

        setDim(width, height);
		setPosition(0, 0);
		setVerbose(false);

		mWebViewAdded = false;

		mObject = object;
		mAddClose = closeBtn;

		mActivity = mainActivity;
		runState(State.INIT);
	}

	public void setVerbose(boolean verbose){
		mVerbose = verbose;
	}

	public void setPosition(int x, int y){
		mX = x;
		mY = y;

		if(mVerbose)
			Log.i("trace","WebView : pos("+mX+"; "+mY+")");

		if(mWebView != null) runState(State.UPDATE);
	}

	public void setDim(int w, int h){
		mWidth = w;
		mHeight = h;

		if(mVerbose)
			Log.i("trace","WebView : dim("+mWidth+"; "+mHeight+")");

		if(mWebView != null) runState(State.UPDATE);
	}

	public void loadUrl(final String url){
		mActivity.runOnUiThread(new Runnable() {
			public void run() {
				mWebView.loadUrl(url);
			}
		});
	}

	public void onAdded() {
		runState(State.ADD);
	}

	public void onRemoved() {
		runState(State.REMOVE);
	}

	public void onOrientationChange(){
		runState(State.UPDATE);
	}

	public void dispose(){
		runState(State.DESTROY);
	}

	@Override
	public void run() {
		switch (mState){
			case INIT :
				initWebView();
				break;
			case ADD :
				add();
				break;
			case REMOVE :
				remove();
				break;
			case UPDATE :
				update();
				break;
			case DESTROY :
				destroy();
				break;
			default :
				break;
		}
	}

	private void runState(State state){
		mState = state;
		mActivity.runOnUiThread(this);
	}

	private void initWebView(){
		mWebView = new WebView(mActivity);

		DisplayMetrics metrics = new DisplayMetrics();
		mActivity.getWindowManager().getDefaultDisplay().getMetrics(metrics);

		mLayoutParams = new LayoutParams(mWidth,mHeight);
		mLayout = new RelativeLayout(mActivity);

		mActivity.addContentView(mLayout, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

		// close button
		if(mAddClose)
        {
            mClose = new ImageView(mActivity);

            mClose.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View arg0) {
                    mObject.call2("onJNIEvent", "close", null);
                }
            });

            RelativeLayout closeLayout = new RelativeLayout(mActivity);
            LayoutParams closeLP = new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT);
            mWebView.addView(closeLayout, closeLP);

            mCloseLayoutParams = new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
            mCloseLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_RIGHT);
            mClose.setLayoutParams(mCloseLayoutParams);

            mClose.setImageResource(R.drawable.close);

            closeLayout.addView(mClose);
        }

		// webChromeClient
		mWebView.setWebChromeClient(new WebChromeClient() {
            FrameLayout.LayoutParams LayoutParameters = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT);

            private View mCustomView;
            private FrameLayout mCustomViewContainer;
            private CustomViewCallback mCustomViewCallback;
            private int mScreenOrientationBackup;

            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                // if a view already exists then immediately terminate the new one
                if (mCustomView != null) {
                    callback.onCustomViewHidden();
                    return;
                }

                mScreenOrientationBackup = mActivity.getRequestedOrientation();
                mActivity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR); //Allow landscape and portrait

                mLayout.setVisibility(View.INVISIBLE);
                mCustomViewContainer = new FrameLayout(mActivity);
                mCustomViewContainer.setBackgroundResource(android.R.color.black);
                view.setLayoutParams(LayoutParameters);
                mCustomViewContainer.addView(view);
                mCustomView = view;
                mCustomViewCallback = callback;
                mCustomViewContainer.setVisibility(View.VISIBLE);
                mActivity.addContentView(mCustomViewContainer, LayoutParameters);
            }

            @Override
            public void onHideCustomView() {
                if (mCustomView == null) {
                    return;
                } else {
                    mCustomView.setVisibility(View.GONE);
                    mCustomViewContainer.removeView(mCustomView);
                    mCustomView = null;
                    mCustomViewContainer.setVisibility(View.GONE);
                    mCustomViewCallback.onCustomViewHidden();
                    mCustomViewCallback = null;

                    mLayout.setVisibility(View.VISIBLE);
                    mActivity.setRequestedOrientation(mScreenOrientationBackup);
                }
            }

            @Override
            public void onProgressChanged(WebView view, int progress) {
                mObject.call2("onJNIEvent", "progress", progress);
            }
		});
		
		// webClient
		mWebView.setWebViewClient(new WebViewClient() {
             @Override
             public void onReceivedError(WebView view, int errorCode, String description, String failingUrl)
             {
            	 mObject.call2("onJNIEvent", "error", description);
             }

             @Override
             public void onPageFinished (WebView view, String url)
             {
                 super.onPageFinished(view, url);

                 mObject.call2("onJNIEvent", "complete", url);
             }

             @Override
             public boolean shouldOverrideUrlLoading(WebView view, String url)
             {
                 boolean allowUrl = mObject.call2("onJNIEvent", "change" , url) != null;

                 if(allowUrl)
                 {
                     view.loadUrl(url);
                 }

                 return !allowUrl;
             }
         });

        WebSettings webSettings = mWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        webSettings.setLoadsImagesAutomatically(true);
        webSettings.setUseWideViewPort(true);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowUniversalAccessFromFileURLs(true);
        if (android.os.Build.VERSION.SDK_INT > 16)
            webSettings.setMediaPlaybackRequiresUserGesture(false);
        mWebView.setBackgroundColor(0x00000000);
		mObject.call0("onWebViewInited");

        if(mVerbose)
			Log.i("trace","WebView : Created new webview.");
	}
	
	private void add(){
		DisplayMetrics metrics = new DisplayMetrics();
		mActivity.getWindowManager().getDefaultDisplay().getMetrics(metrics);

		if(!mWebViewAdded){
			mLayout.addView(mWebView, mLayoutParams);
			mWebViewAdded = true;
		}
					
		if(mVerbose)
			Log.i("trace","WebView : Added webview.");
	}
	
	private void remove(){
		if(mVerbose)
			Log.i("trace","WebView : Removed webview.");
        if(mLayout != null)
		    mLayout.removeAllViews();
		mWebViewAdded = false;
	}
	
	private void update() {
		mLayoutParams.setMargins(mX, mY, 0, 0);
		mLayoutParams.width = mWidth;
		mLayoutParams.height = mHeight;
		
		mLayout.requestLayout();
		if(mVerbose)
			Log.i("trace","WebView : Update webview transformation : ("+mX+", "+mY+", "+mWidth+", "+mHeight+")");
	}
	
	private void destroy() {
        if(mWebView != null)
        {
            remove();

            mObject = null;
            mWebView.clearHistory();
            mWebView.pauseTimers();
            mWebView.destroy();
            mWebView = null;
            mLayout = null;

            System.gc();

            if(mVerbose)
                Log.i("trace","WebView : Dispose.");
        }
	}
}