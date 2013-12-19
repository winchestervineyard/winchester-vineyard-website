var images = {
  'talks': 0,
  'news': 0,
};

var lastTop = 0;

$(document).ready(function() {
  $('#top-link').topLink({
    min: 1279,
    fadeSpeed: 100
  });

  for (var key in images) {
    var section = $('#wv-' + key);
    var top = section.offset().top;
    images[key] = { top: top, bottom: top + section.outerHeight() }
  }

  $(window).on('scroll', function() {
    var windowTop = window.pageYOffset;
    var windowHeight = $(window).height()
    var windowBottom = windowTop + windowHeight;
    var lastBottom = lastTop + windowHeight;

    for(var key in images) {
      if ((windowBottom > images[key].top && lastBottom <= images[key].top) ||
      (windowTop <= images[key].bottom && lastTop > images[key].bottom)) {
        console.log("changed image to " + key);
        $('body').css("background-image", "url('/images/photos/borders/" + key + ".jpg')");
      }
    }
    lastTop = windowTop;
  });
});
