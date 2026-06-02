String buildEmbedUrl(String videoId) {
  return 'https://www.youtube.com/embed/$videoId'
      '?playsinline=1&rel=0&fs=1&modestbranding=1&controls=1&autoplay=1';
}

String seekScript(int seconds) {
  return '''
(function() {
  var v = document.querySelector('video');
  if (v) {
    var t = v.currentTime + $seconds;
    if (t < 0) t = 0;
    if (t > v.duration) t = v.duration;
    v.currentTime = t;
  }
})();
''';
}

String statusQuery() {
  return '''
(function() {
  var v = document.querySelector('video');
  if (v) {
    window.SkipButtons.postMessage(JSON.stringify({
      type: 'timeupdate',
      currentTime: v.currentTime,
      duration: v.duration,
      ready: true
    }));
  }
})();
''';
}

String readyDetector() {
  return '''
var _ccReady = setInterval(function() {
  var v = document.querySelector('video');
  if (v && v.duration) {
    clearInterval(_ccReady);
    window.SkipButtons.postMessage(JSON.stringify({ type: 'ready', duration: v.duration }));
  }
}, 200);
''';
}
