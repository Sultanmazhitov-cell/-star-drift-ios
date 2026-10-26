package com.stardrift.game;

import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import android.webkit.WebView;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class GameSmokeTest {
    private String evaluate(ActivityScenario<MainActivity> scenario, String script) throws Exception {
        AtomicReference<String> result = new AtomicReference<>();
        CountDownLatch latch = new CountDownLatch(1);
        scenario.onActivity(activity -> ((WebView)activity.findViewById(R.id.game_view)).evaluateJavascript(script, value -> {result.set(value); latch.countDown();}));
        assertTrue("JavaScript completed", latch.await(10,TimeUnit.SECONDS));
        return result.get();
    }
    @Test public void bundledOfflineGameStartsAndPauses() throws Exception {
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            String phase = "null";
            for(int i=0;i<50;i++) {
                phase=evaluate(scenario,"window.StarDrift ? StarDrift.getState().status : null");
                if ("\"ready\"".equals(phase)) break;
                Thread.sleep(200);
            }
            assertEquals("Bundled game loaded", "\"ready\"",phase);
            assertEquals("\"playing\"",evaluate(scenario,"StarDrift.start(); StarDrift.getState().status"));
            assertEquals("\"paused\"",evaluate(scenario,"StarDrift.pause(); StarDrift.getState().status"));
            assertEquals("\"playing\"",evaluate(scenario,"StarDrift.resume(); StarDrift.getState().status"));
            assertEquals("true", evaluate(scenario,"document.documentElement.scrollWidth <= innerWidth"));
            assertEquals("true", evaluate(scenario,"!!document.querySelector('link[href=\"android.css\"]')"));
            evaluate(scenario,"StarDrift.pause()");
        }
    }
}
