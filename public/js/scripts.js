var images = {
  'talks': 0,
  'news': 0,
};
var preloaded = {};

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

    preloaded[key] = new Image();
    preloaded[key].src = '/images/photos/borders/'+key+'.jpg';
  }

  $(window).on('scroll', function() {
    var windowTop = window.pageYOffset;
    var windowHeight = $(window).height()
    var windowBottom = windowTop + windowHeight;
    var lastBottom = lastTop + windowHeight;

    for(var key in images) {
      if ((windowBottom > images[key].top && lastBottom <= images[key].top) ||
      (windowTop <= images[key].bottom && lastTop > images[key].bottom)) {
        $('body').css("background-image", "url('/images/photos/borders/" + key + ".jpg')");
      }
    }
    lastTop = windowTop;
  });

  var news = new Firebase('https://winvin.firebaseio.com/news');
  news.on('child_added', function(snapshot) {
    var data = snapshot.val();
    if (new Date(data.datetime) < new Date()) {
      return;
    }

    data = applyFilters(data);
    var div = $('#wv-news-item-template').html();
    $(newsDivForDate(data)).append(Mustache.render(div, data));
  });

  var talks = new Firebase('https://winvin.firebaseio.com/talks');
  talks.on('child_added', function(snapshot) {
    var data = snapshot.val();
    data = applyFilters(data);
    var div = $('#wv-talk-item-template').html();
    $(talkDivForDate(data)).append(Mustache.render(div, data));
  });
});

function applyFilters(data) {
  var date = new Date(data.datetime);
  data.dow = date.strftime("%a");
  data.fulldatetime = date.strftime("%a %d %b %H:%M%p");
  data.date = date.strftime("%a %d %b %Y");
  return data;
}

var FOUR_WEEKS_IN_MS = 1000 * 60 * 60 * 24 * 28;

function talkDivForDate(data) {
  var date = new Date(data.datetime);
  var now = new Date();
  if (date >= (now - FOUR_WEEKS_IN_MS)) {
    return '#wv-talks-within-last-month';
  }

  return '#wv-talks-older';
}

function newsDivForDate(data) {
  var date = new Date(data.datetime);
  var now = new Date();
  var nextSunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (7 - now.getDay()));

  if (date < nextSunday) {
    return '#wv-news-this-week';
  }

  if (date.getMonth() == now.getMonth() && date.getFullYear() == now.getFullYear()) {
    return '#wv-news-this-month';
  }
  return '#wv-news-further-ahead';
}
