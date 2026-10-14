// Feature carousel, 2010 style: one feature at a time, arrows, dots, keyboard and swipe. Without JS the features stack.
(function () {
  var wraps = document.querySelectorAll('.wrap');
  for (var w = 0; w < wraps.length; w++) {
    var feats = [];
    for (var c = 0; c < wraps[w].children.length; c++) if (/\bfeature\b/.test(wraps[w].children[c].className)) feats.push(wraps[w].children[c]);
    if (feats.length < 2) continue;
    var car = document.createElement('div'); car.className = 'carousel';
    var track = document.createElement('div'); track.className = 'track'; car.appendChild(track);
    feats[0].parentNode.insertBefore(car, feats[0]);
    for (var i = 0; i < feats.length; i++) { var slide = document.createElement('div'); slide.className = 'slide'; slide.appendChild(feats[i]); track.appendChild(slide); }
    var prev = document.createElement('a'); prev.className = 'arrow prev'; prev.href = '#'; prev.innerHTML = '&#9664;'; prev.title = 'Previous';
    var next = document.createElement('a'); next.className = 'arrow next'; next.href = '#'; next.innerHTML = '&#9654;'; next.title = 'Next';
    var dots = document.createElement('div'); dots.className = 'dots';
    car.appendChild(prev); car.appendChild(next); car.appendChild(dots);
    (function (car, track, dots, n) {
      var cur = 0, timer;
      for (var i = 0; i < n; i++) { var d = document.createElement('a'); d.href = '#'; d.setAttribute('data-i', i); dots.appendChild(d); d.onclick = function (e) { e.preventDefault(); go(parseInt(this.getAttribute('data-i'), 10), true); }; }
      function go(i, manual) { cur = (i + n) % n; track.style.marginLeft = (-cur * 100) + '%'; for (var k = 0; k < n; k++) dots.children[k].className = k === cur ? 'on' : ''; if (manual) rest(); }
      function rest() { clearInterval(timer); timer = setInterval(function () { go(cur + 1); }, 7000); }
      car.querySelector('.prev').onclick = function (e) { e.preventDefault(); go(cur - 1, true); };
      car.querySelector('.next').onclick = function (e) { e.preventDefault(); go(cur + 1, true); };
      var x0 = null;
      car.addEventListener('touchstart', function (e) { x0 = e.touches[0].clientX; }, false);
      car.addEventListener('touchend', function (e) { if (x0 === null) return; var dx = e.changedTouches[0].clientX - x0; if (Math.abs(dx) > 40) go(cur + (dx < 0 ? 1 : -1), true); x0 = null; }, false);
      document.addEventListener('keydown', function (e) { if (e.keyCode === 37) go(cur - 1, true); else if (e.keyCode === 39) go(cur + 1, true); });
      go(0); rest();
    })(car, track, dots, feats.length);
  }
})();
