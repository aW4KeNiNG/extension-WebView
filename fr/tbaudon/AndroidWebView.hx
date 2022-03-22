package fr.tbaudon ;

import openfl.display.Stage;
import openfl.events.Event;
import openfl.display.Sprite;
import openfl.events.ErrorEvent;
import openfl.events.FocusEvent;
import openfl.events.KeyboardEvent;
import openfl.events.ProgressEvent;
import openfl.Lib;
import openfl.system.Capabilities;
import openfl.system.System;

import lime.system.JNI;

class AndroidWebView extends AbstractWebView{
	
	/**************************************************************/
	// JNI LINKING
	/*
	 * jni type cheat sheet :
	 * parameter type beetween (), return type after ()
	 * nonBasicObject : Lpath/to/class;
	 * void : V
	 * bool : Z
	 * int : I
	 * Sample : (Ljava/lang/String;I)Z = function(String, Int) : bool
	 */
	// STATIC METHOD
	private static var create_jni = JNI.createStaticMethod("fr.tbaudon.OpenFLWebView", "create", "(Lorg/haxe/lime/HaxeObject;IIZLjava/lang/String;)Lfr/tbaudon/WebViewObject;");
	private static var getRealHeight_jni = JNI.createStaticMethod("fr.tbaudon.OpenFLWebView", "getRealHeight", "()I");
	private static var getRealWidth_jni = JNI.createStaticMethod("fr.tbaudon.OpenFLWebView", "getRealWidth", "()I");
	private static var setPreventBack_jni = JNI.createStaticMethod("fr.tbaudon.OpenFLWebView", "setPreventBack", "(Z)V");

	// MEMBER METHOD
	private static var add_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "onAdded", "()V");
	private static var remove_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "onRemoved", "()V");
	private static var pause_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "onPaused", "()V");
	private static var resume_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "onResumed", "()V");
	private static var loadUrl_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "loadUrl", "(Ljava/lang/String;)V");
	private static var loadJavascript_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "loadJavascript", "(Ljava/lang/String;)V");
	private static var setPos_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "setPosition", "(II)V");
	private static var setDim_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "setDim", "(II)V");
	private static var setVerbose_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "setVerbose", "(Z)V");
	private static var dispose_jni = JNI.createMemberMethod("fr.tbaudon.WebViewObject", "dispose", "()V");
	
	/*************************************************************/
	
	// Members
	var mJNIInstance : Dynamic;

    /** Queue WebView call untill the webView isn't ready **/
	var mQueue : Array<{func : Dynamic, params : Array<Dynamic>}>;
	var mWebViewReady : Bool;
	
	public function new(defaultUrl : String = "http://www.baudon.me", w : Float = 400, h : Float = 400, close : Bool = false, userAgent : String = null) {
        mJNIInstance = create_jni(this, mWidth, mHeight, close, userAgent);
        mQueue = new Array<{func : Dynamic, params : Array<Dynamic>}>();
        mWebViewReady = false;

        super(defaultUrl, w, h);
	}

    public function setPreventBack(preventBack : Bool) {
        setPreventBack_jni(preventBack);
    }
	
	override public function setVerbose(verbose : Bool) {
		setVerbose_jni(mJNIInstance, verbose);
	}

    override public function loadUrl(url : String) {
        this.url = url;
		if (mWebViewReady)
			loadUrl_jni(mJNIInstance, url);
		else
			addToQueue(loadUrl_jni, [mJNIInstance, url]);
	}

    override public function loadJavascript(code : String) {
        if(mWebViewReady)
            loadJavascript_jni(mJNIInstance, code);
        else
            addToQueue(loadJavascript_jni, [mJNIInstance, code]);
    }

    override public function addCloseBtn(){
        trace("Nothing happens.,,");
    }
	
	function onWebViewInited() {
		mWebViewReady = true;
		while (mQueue.length > 0)
		{
			var call = mQueue.shift();
			Reflect.callMethod(Type.getClass(this), call.func, call.params);
		}
	}
	
	function onJNIEvent(event : String, param : Dynamic ):String {  //TODO - Lime JNI only support a string as return. Check Java_org_haxe_lime_Lime_callObjectFunction
		switch(event) {
			case 'progress' :
				var progress : Int = param;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS, false, false, progress, 100));
            case 'complete' :
                dispatchEvent(new Event(Event.COMPLETE));
            case 'error' :
				var description : String = param;
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, description));
			case 'close' : 
				dispatchEvent(new Event(Event.CLOSE));
            case 'change' :
                var allowUrl:Bool = true;
                if(onUrlChanging != null)
                {
                    allowUrl = onUrlChanging(param, "");
                }

                if(allowUrl)
                {
                    url = param;
                    dispatchEvent(new Event(Event.CHANGE));
                }

                return allowUrl ? url : null;
            case 'javascript':
                if(onJavascriptResult != null)
                {
                    onJavascriptResult(param);
                }
			default :
				trace(event);
		}

        return null;
	}

//    override function onPause(e : Event){
//        if (mWebViewReady)
//            pause_jni(mJNIInstance);
//        else
//            addToQueue(pause_jni, [mJNIInstance]);
//    }
//
//
//    override function onResume(e : Event){
//        if (mWebViewReady)
//            resume_jni(mJNIInstance);
//        else
//            addToQueue(resume_jni, [mJNIInstance]);
//    }

    override function onRemovedFromStage(e:Event):Void
	{
		if (mWebViewReady)
			remove_jni(mJNIInstance);
		else
			addToQueue(remove_jni, [mJNIInstance]);
	}

    override function onAddedToStage(e:Event):Void
	{
		if (mWebViewReady)
			add_jni(mJNIInstance);
		else
			addToQueue(add_jni, [mJNIInstance]);
	}

    override function setPos(x : Float, y : Float) {	
		if (mWebViewReady)
			setPos_jni(mJNIInstance, Std.int(x), Std.int(y));
		else
			addToQueue(setPos_jni, [mJNIInstance, Std.int(x), Std.int(y)]);
	}
	
	override function applyDim(w : Float, h : Float) {
		if (mWebViewReady)
			setDim_jni(mJNIInstance, Std.int(w), Std.int(h));
		else
			addToQueue(setDim_jni, [mJNIInstance, Std.int(w), Std.int(h)]);
	}
	
	override public function dispose() {
		if(mJNIInstance != null){
				
			dispose_jni(mJNIInstance);
				
			mJNIInstance = null;
			mQueue = null;
			
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
			Lib.current.stage.removeEventListener(Event.RESIZE, computeScale);
			Lib.current.stage.removeEventListener(Event.ACTIVATE, onResume);
			Lib.current.stage.removeEventListener(Event.DEACTIVATE, onPause);

			System.gc();
		}
	}
	
	function addToQueue(object : Dynamic, array:Array<Dynamic>) 
	{
		// don't push the same method twice, change the params instead
		var canPush : Bool = true;
		for (obj in mQueue) {
				if (obj.func == object){
					canPush = false;
					obj.params = array;
					break;
				}
		}
		if(canPush)
			mQueue.push( { func:object, params:array } );
	}
	
	override function computeScale(e : Event = null)
    {
		var screenWidth : Int = getRealWidth_jni();
		var screenHeight : Int = getRealHeight_jni();
		
        var ratio = Lib.current.stage.stageWidth / Lib.current.stage.stageHeight;
        var screenRatio = screenWidth / screenHeight;

        trace(ratio, screenRatio);

        var displayWidth : Float;
        var displayHeight : Float;

        // landscape app
        if(screenRatio >= 1){
            displayWidth = screenWidth;
            displayHeight = displayWidth / ratio;
            if(displayHeight >= screenHeight){
                displayHeight = screenHeight;
                displayWidth = displayHeight * ratio;
            }

//            mOffsetX = (screenWidth - displayWidth) / 2;
//            mOffsetY = (screenHeight - displayHeight) / 2;
        }else {
            displayHeight = screenHeight;
            displayWidth = displayHeight * ratio;
            if(displayWidth >= screenWidth){
                displayWidth = screenWidth;
                displayHeight = screenWidth / ratio;
            }

//            mOffsetX = (screenWidth - displayWidth) / 2;
//            mOffsetY = (screenHeight - displayHeight) / 2;
        }

        mScaleX = displayWidth / Lib.current.stage.stageWidth;
        mScaleY = displayHeight / Lib.current.stage.stageHeight;

        if (e != null)
        {
            setDim(cast width, cast height);
            x = x;
            y = y;
        }
    }
	
}