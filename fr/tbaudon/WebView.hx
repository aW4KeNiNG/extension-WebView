package fr.tbaudon ;

#if android
typedef WebView = AndroidWebView;
#elseif ios
typedef WebView = IOsWebView;
#elseif flash
typedef WebView = FlashWebView;
#else
class WebView extends AbstractWebView{
    public function new(defaultUrl : String = "http://www.google.com", w : Float = 400, h : Float = 400, close : Bool = false, userAgent : String = null){
        super(defaultUrl, w, h, close, userAgent);
    }
}
#end


