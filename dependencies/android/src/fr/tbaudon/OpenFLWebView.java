package fr.tbaudon;

import android.graphics.Point;
import android.util.Log;
import org.haxe.extension.Extension;
import org.haxe.lime.HaxeObject;

public class OpenFLWebView extends Extension{

    private static boolean mPreventBack = false;

    public static WebViewObject create(HaxeObject object, int width, int height, boolean closeBtn){
        return new WebViewObject(mainActivity, object, width, height, closeBtn);
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
}