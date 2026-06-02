(function () {
  function getVideo() {
    return document.querySelector('video');
  }

  document.addEventListener('keydown', function (e) {
    const active = document.activeElement;
    const isInput =
      active &&
      (active.tagName === 'INPUT' ||
        active.tagName === 'TEXTAREA' ||
        active.isContentEditable);

    if (isInput) return;

    const video = getVideo();
    if (!video) return;

    if (e.key === 'a' || e.key === 'A') {
      e.preventDefault();
      video.currentTime = Math.max(0, video.currentTime - 1);
      return;
    }

    if (e.key === 'd' || e.key === 'D') {
      e.preventDefault();
      video.currentTime = Math.min(video.duration || Infinity, video.currentTime + 1);
      return;
    }

    if (e.key === ' ') {
      e.preventDefault();
      if (video.paused) {
        video.play();
      } else {
        video.pause();
      }
    }
  });

  document.addEventListener('keyup', function (e) {
    if (e.key === ' ') {
      const active = document.activeElement;
      const isInput =
        active &&
        (active.tagName === 'INPUT' ||
          active.tagName === 'TEXTAREA' ||
          active.isContentEditable);
      if (!isInput) {
        e.preventDefault();
      }
    }
  });
})();
