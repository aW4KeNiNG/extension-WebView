package fr.tbaudon;

import android.graphics.Point;
import android.util.Log;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

import java.util.ArrayList;

public class OpenFLWebView extends Extension{

    private static boolean mPreventBack = false;
    private static ArrayList<WebViewObject> mWebViews = new ArrayList<WebViewObject>();

    public static WebViewObject create(HaxeObject object, int width, int height, boolean closeBtn, String userAgent){
        WebViewObject webView = new WebViewObject(mainActivity, object, width, height, closeBtn, userAgent);
        mWebViews.add(webView);
        return webView;
	}

	public static boolean delete(WebViewObject webView){
        return mWebViews.remove(webView);
    }
	
	public static int getRealHeight(){
		int height = 100;
		try {
			Point size = new Point();
			mainActivity.getWindowManager().getDefaultDisplay().getRealSize(size);
			height = size.y;
		}catch (NoSuchMethodError e){
			mainActivity.getWindowManager().getDefaultDisplay().getHeight();
		}
		return height;
	}
	
	public static int getRealWidth(){
		int width = 100;
		try {
			Point size = new Point();
			mainActivity.getWindowManager().getDefaultDisplay().getRealSize(size);
			width = size.x;
		}catch (NoSuchMethodError e){
			mainActivity.getWindowManager().getDefaultDisplay().getHeight();
		}
		return width;
	}

    public static void setPreventBack(boolean preventBack){
        mPreventBack = preventBack;
    }

	public OpenFLWebView() {
        super();
    }

    @Override
    public boolean onBackPressed () {
        return !mPreventBack;
    }

    @Override
    public void onPause () {
        for(int i = 0, count = mWebViews.size(); i<count; ++i) {
            mWebViews.get(i).pause();
        }
    }

    @Override
    public void onResume () {
        for(int i = 0, count = mWebViews.size(); i<count; ++i) {
            mWebViews.get(i).resume();
        }
    }
}