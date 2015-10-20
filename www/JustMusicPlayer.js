var exec = require('cordova/exec');

/*
  Configurations
*/
exports.config = function() {};

/*
  Source control
*/
exports.load = function(item, success, error) {
 exec(success, error, 'JustMusicPlayer', 'load', [
   item.title,
   item.artist,
   item.albumTitle,
   item.albumImageURL,
   item.audioURL
   ]);
};

/*
  Player control
*/
exports.play = function(success, error) {
  exec(success, error, 'JustMusicPlayer', 'play', ['a']);
};

exports.pause = function(success, error) {
  exec(success, error, 'JustMusicPlayer', 'pause', []);
};

exports.seekTo = function(time, success, error) {
  exec(success, error, 'JustMusicPlayer', 'seekTo', [time]);
};

exports.setVolume = function(volume, success, error) {
  exec(success, error, 'JustMusicPlayer', 'setVolume', [volume]);
};

/*
  Player private callback (DONT OVERRIDE)
*/
exports.didPlayerPlaying = function(currentTime, duration) {
  document.dispatchEvent(new CustomEvent('didPlayerPlaying', { 
    detail: {
      currentTime: currentTime,
      duration: duration
    },
    bubbles: false,
  }));
};

exports.didPlayerReachEnd = function(currentTime, duration) {
  document.dispatchEvent(new CustomEvent('didPlayerReachEnd', { 
    detail: {
      currentTime: currentTime,
      duration: duration
    },
    bubbles: false,
  }));
};
exports.didRemoteNextTrack = function() {
  document.dispatchEvent(new CustomEvent('didRemoteNextTrack', {}));
};
exports.didRemotePreviousTrack = function() {
  document.dispatchEvent(new CustomEvent('didRemotePreviousTrack', {}));
};
