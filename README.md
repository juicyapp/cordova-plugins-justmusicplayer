# JustMusicPlayer

Simple cordova music player

## Install:
- install the plugin 
```bash
cordova plugin add https://github.com/juicyapp/cordova-plugins-justmusicplayer.git
```


## Usage:

```javascript
// load and play the music:
cordova.plugins.JustMusicPlayer.load({
  title: 'music title',
  artist: 'music author',
  albumTitle: 'album title',
  albumImageURL: 'http://example.com/album_art.jpg',
  audioURL: 'http://example.com/music.mp3'
},
function(){
  console.log('load success');
  cordova.plugins.JustMusicPlayer.play();
},
function(){
  console.log('load failed');
});

// pause
cordova.plugins.JustMusicPlayer.pause();

// seekTo
cordova.plugins.JustMusicPlayer.seekTo(1);
```



## Events:

```javascript
// music is playing
document.addEventListener('didPlayerPlaying', function(e){
  console.log(e.detail.currentTime, e.detail.duration);
});

// music is end
document.addEventListener('didPlayerReachEnd', function(e){});

// "Next Track" clicked on iOS remoteControl
document.addEventListener('didRemoteNextTrack', function(e){});

// "Previous Track" clicked on iOS remoteControl
document.addEventListener('didRemotePreviousTrack', function(e){});

```
