package fr.tbaudon;

import android.app.Activity;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;
import android.webkit.*;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.RelativeLayout.LayoutParams;
import fr.tbaudon.openflwebview.R;
import org.haxe.lime.HaxeObject;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public class WebViewObject extends Object implements Runnable{

	private int mWidth;
	private int mHeight;

	private int mX;
	private int mY;

    private String mUserAgent;

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

	public WebViewObject(Activity mainActivity, HaxeObject object, int width, int height, boolean closeBtn, String userAgent){
		super();

        setDim(width, height);
		setPosition(0, 0);
		setVerbose(false);
        mUserAgent = userAgent;

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

    public void loadJavascript(String code) {
        mWebView.loadUrl("javascript:android.sendJSON((function(){" + code + "})())");
    }

    @JavascriptInterface
    public void sendJSON(String value) {
        if(mObject != null)
            mObject.call2("onJNIEvent", "javascript", value);
    }

	public void onAdded() {
		runState(State.ADD);
	}

	public void onRemoved() {
		runState(State.REMOVE);
	}

    public void onPaused() {
        runState(State.PAUSE);
    }

    public void onResumed() {
        runState(State.RESUME);
    }

    public void onOrientationChange(){
		runState(State.UPDATE);
	}

	public void dispose(){
		runState(State.DESTROY);
	}

    private void callHiddenWebViewMethod(String name)
    {
        if (mWebView != null)
        {
            try
            {
                Method method = WebView.class.getMethod(name);
                method.invoke(mWebView);
            }
            catch (NoSuchMethodException e)
            {
                Log.e("No such method: " + name, e.toString());
            }
            catch (IllegalAccessException e)
            {
                Log.e("Illegal Access: " + name, e.toString());
            }
            catch (InvocationTargetException e)
            {
                Log.e("Invocation Target Exception: " + name, e.toString());
            }
        }
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
            case PAUSE :
                pause();
                break;
            case RESUME :
                resume();
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
        mWebView.resumeTimers();

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
                    if(mObject != null)
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
                if(mObject != null)
                    mObject.call2("onJNIEvent", "progress", progress);
            }

            @Override
            public Bitmap getDefaultVideoPoster() {
                return Bitmap.createBitmap(10, 10, Bitmap.Config.ARGB_8888);
            }

            @Override
            public boolean onConsoleMessage(ConsoleMessage cm) {
                if(mVerbose)
                    Log.i("trace", cm.message() + " -- From line "
                        + cm.lineNumber() + " of "
                        + cm.sourceId() );
                return true;
            }
		});
		
		// webClient
		mWebView.setWebViewClient(new WebViewClient() {
             @Override
             public void onReceivedError(WebView view, int errorCode, String description, String failingUrl)
             {
                 if(mObject != null)
            	    mObject.call2("onJNIEvent", "error", description);
             }

             @Override
             public void onPageFinished (WebView view, String url)
             {
                 super.onPageFinished(view, url);

                 if(mObject != null)
                     mObject.call2("onJNIEvent", "complete", url);
             }

             @Override
             public boolean shouldOverrideUrlLoading(WebView view, String url)
             {
                 boolean allowUrl = mObject != null ? mObject.call2("onJNIEvent", "change" , url) != null : false;

                 if(allowUrl)
                 {
                     view.loadUrl(url);
                 }

                 return !allowUrl;
             }

             //Track changes with hash
             @Override
             public void doUpdateVisitedHistory(WebView view, String url, boolean isReload) {
                 super.doUpdateVisitedHistory(view, url, isReload);

                  if(mObject != null)
                      mObject.call2("onJNIEvent", "change" , url);
             }
         });

        WebSettings webSettings = mWebView.getSettings();
        webSettings.setJavaScriptEnabled(true);
        webSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        webSettings.setLoadsImagesAutomatically(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setUseWideViewPort(true);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowUniversalAccessFromFileURLs(true);
        if(mUserAgent != null)
            webSettings.setUserAgentString(webSettings.getUserAgentString() + " " + mUserAgent);
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN) {
            webSettings.setMediaPlaybackRequiresUserGesture(false);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true);
        }
        mWebView.setBackgroundColor(0x00000000);
        mWebView.addJavascriptInterface(this, "android");
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

	public void pause() {
        if(mWebView != null) {
	        mWebView.pauseTimers();
            callHiddenWebViewMethod("onPause");
        }
    }

    public void resume() {
	    if(mWebView != null) {
            mWebView.resumeTimers();
            callHiddenWebViewMethod("onResume");
        }
    }
	
	private void destroy() {
        if(mWebView != null)
        {
            remove();

            mObject = null;
            mWebView.clearHistory();
            mWebView.destroy();
            mWebView = null;
            mLayout = null;

            OpenFLWebView.delete(this);

            System.gc();

            if(mVerbose)
                Log.i("trace","WebView : Dispose.");
        }
	}
}