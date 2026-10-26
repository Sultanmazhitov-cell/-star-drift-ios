package com.stardrift.game;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.net.Uri;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.view.WindowInsets;
import android.view.View;
import android.widget.FrameLayout;
import androidx.webkit.WebViewAssetLoader;
import java.io.ByteArrayInputStream;

public final class MainActivity extends Activity {
    private WebView game;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        FrameLayout container = new FrameLayout(this);
        container.setBackgroundColor(Color.rgb(16,30,43));
        game = new WebView(this);
        game.setId(R.id.game_view);
        game.setBackgroundColor(Color.rgb(16,30,43));
        container.addView(game, new FrameLayout.LayoutParams(-1,-1));
        setContentView(container);
        container.setOnApplyWindowInsetsListener((view, insets) -> {
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets safe = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
                view.setPadding(safe.left,safe.top,safe.right,safe.bottom);
            } else {
                view.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());
            }
            return insets;
        });
        WebSettings settings = game.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(true);
        final WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this)).build();
        game.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                WebResourceResponse local = loader.shouldInterceptRequest(request.getUrl());
                if (local != null) return local;
                return new WebResourceResponse("text/plain", "UTF-8", 403, "Offline only", java.util.Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                return !"https".equals(uri.getScheme()) || !"appassets.androidplatform.net".equals(uri.getHost());
            }
        });
        game.loadUrl("https://appassets.androidplatform.net/assets/game/index.html");
    }

    @Override protected void onPause() {
        game.evaluateJavascript("window.StarDrift && window.StarDrift.pause();", null);
        game.onPause();
        super.onPause();
    }
    @Override protected void onResume() {
        super.onResume();
        if (game != null) game.onResume();
    }
    @Override public void onBackPressed() {
        game.evaluateJavascript("window.StarDrift && window.StarDrift.pause();", null);
        new android.app.AlertDialog.Builder(this).setTitle("Завершить полёт?")
            .setMessage("Вернуться к игре или закрыть приложение?")
            .setNegativeButton("Вернуться", (dialog, which) -> {})
            .setPositiveButton("Закрыть", (dialog, which) -> finish()).show();
    }
    @Override protected void onDestroy() {
        if (game != null) { ((android.view.ViewGroup)game.getParent()).removeView(game); game.destroy(); }
        super.onDestroy();
    }
}
