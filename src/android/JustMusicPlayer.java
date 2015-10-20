// http://stackoverflow.com/questions/1965784/streaming-audio-from-a-url-in-android-using-mediaplayer
// http://www.hrupin.com/2011/02/example-of-streaming-mp3-mediafile-with-android-mediaplayer-class
// http://stackoverflow.com/questions/23443946/music-player-control-in-notification

package org.juicyapp.justmusicplayer;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaWebView;

import java.util.Timer;
import java.util.TimerTask;

import org.apache.cordova.LOG;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.util.Log;

import android.media.MediaPlayer;
import android.media.AudioManager;
import android.media.MediaPlayer.OnBufferingUpdateListener;
import android.media.MediaPlayer.OnCompletionListener;
import android.media.MediaPlayer.OnPreparedListener;

/**
 * Android implementation of cordova JustMusicPlayer
 */
public class JustMusicPlayer extends CordovaPlugin implements OnBufferingUpdateListener, OnCompletionListener, OnPreparedListener{

    public static final String JS_FUNCTION_NAMESPACE = "cordova.plugins.JustMusicPlayer";
    public static final int PLAYER_TIMER_TICK_INTERVAL = 500;

    private MediaPlayer mediaPlayer;
    private CallbackContext currentPlayerLoadCallbackContext;
    private Timer timer;

    private TimerTask timerTask = new TimerTask() {
        @Override
        public void run() {
            // http://stackoverflow.com/questions/22607657/webview-methods-on-same-thread-error
            webView.getView().post(new Runnable() {
                @Override
                public void run() {
                    int currentTime = mediaPlayer.getCurrentPosition();
                    int duration = mediaPlayer.getDuration();
                    String jsCallback = JS_FUNCTION_NAMESPACE + ".didPlayerPlaying(" + currentTime + ", " + duration + ");";
                    webView.loadUrl("javascript:" + jsCallback);
                }
            });
        }
    };

    // plugin initialize
    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        // your init code here

        // init mediaPlayer
        mediaPlayer = new MediaPlayer();
        mediaPlayer.setOnBufferingUpdateListener(this);
        mediaPlayer.setOnCompletionListener(this);
        mediaPlayer.setOnPreparedListener(this);
        mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);

        // init timer
        timer = new Timer();
    }

    // media player callbacks
    @Override
    public void onCompletion(MediaPlayer mp) {
        stopTimer();
        // http://stackoverflow.com/questions/22607657/webview-methods-on-same-thread-error
        webView.getView().post(new Runnable() {
            @Override
            public void run() {
                int currentTime = mediaPlayer.getCurrentPosition();
                int duration = mediaPlayer.getDuration();
                String jsCallback = JS_FUNCTION_NAMESPACE + ".didPlayerReachEnd(" + currentTime + ", " + duration + ");";
                webView.loadUrl("javascript:" + jsCallback);
            }
        });
    }

    @Override
    public void onBufferingUpdate(MediaPlayer mp, int percent) {}

    /**
     * timer control
     */
    private void startTimer(){
        timer.scheduleAtFixedRate(timerTask, PLAYER_TIMER_TICK_INTERVAL, PLAYER_TIMER_TICK_INTERVAL);
    }

    /**
     * timer control
     */
    private void stopTimer() {
        timer.cancel();
    }

    @Override
    public void onPrepared(MediaPlayer mp) {
        currentPlayerLoadCallbackContext.success();
        currentPlayerLoadCallbackContext = null;
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        if (action.equals("load")) {
            this.load(
                args.getString(0),
                args.getString(1),
                args.getString(2),
                args.getString(3),
                args.getString(4),
                callbackContext);
            return true;
        }
        if (action.equals("play")) {
            this.play(callbackContext);
        }
        if (action.equals("pause")) {
            this.pause(callbackContext);
        }
        if (action.equals("seekTo")) {
            this.seekTo(args.getInt(0), callbackContext);
        }
        if (action.equals("setVolume")) {
            this.setVolume((float)args.getDouble(0), callbackContext);
        }
        // no function found
        return false;
    }

    /**
     * source control
     *
     * @param title music name
     * @param artist author
     * @param albumTitle album name
     * @param albumImagePath album url path
     * @param audioPath audio url path
     * @param callbackContext cordova bridge callback
     */
    private void load(String title, String artist, String albumTitle, String albumImagePath, String audioPath, CallbackContext callbackContext) {

        try {
            mediaPlayer.reset();
            mediaPlayer.setDataSource(audioPath);
            mediaPlayer.prepareAsync();
            currentPlayerLoadCallbackContext = callbackContext;
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error("");
            currentPlayerLoadCallbackContext = null;
        }
    }

    /**
     * play
     * @param callbackContext cordova bridge callback
     */
    private void play(CallbackContext callbackContext) {
        try {
            mediaPlayer.start();
            startTimer();
            callbackContext.success();
        } catch (Exception e) {
            callbackContext.error(e.getMessage());
        }
    }

    /**
     * pause
     * @param callbackContext cordova bridge callback
     */
    private void pause(CallbackContext callbackContext) {
        try {
            mediaPlayer.pause();
            stopTimer();
            callbackContext.success();
        } catch (Exception e) {
            callbackContext.error(e.getMessage());
        }
    }

    /**
     * seekTo
     * @param time in sec
     * @param callbackContext cordova bridge callback
     */
    private void seekTo(int time, CallbackContext callbackContext) {
        try {
            mediaPlayer.seekTo(time);
            callbackContext.success();
        } catch (Exception e) {
            callbackContext.error(e.getMessage());
        }
    }

    /**
     * setVolume
     * @param volume 0 to 1 volume ratio
     * @param callbackContext cordova bridge callback
     */
    private void setVolume(float volume, CallbackContext callbackContext) {
        try {
            mediaPlayer.setVolume(volume, volume);
            callbackContext.success();
        } catch (Exception e) {
            callbackContext.error(e.getMessage());
        }
    }

}
