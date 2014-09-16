var images = {
  'talks': 0,
  'growing': 0,
  'news': 0,
};
var preloaded = {};
var currentBackground = "";

var lastTop = 0;

function calculateSectionHeights() {
  for (var key in images) {
    var section = $('#wv-' + key);
    var top = section.offset().top;
    images[key] = { top: top - 20, bottom: top + section.outerHeight() + 20 }
  }
}

for (var key in images) {
  preloaded[key] = new Image();
  preloaded[key].src = '/images/photos/borders/'+key+'.jpg';
}

$(document).ready(function() {
  // Ensure navbar closes on a click
  $(".nav li a:not('.dropdown-toggle')").on('click',function(){
    $('.navbar-collapse.in').collapse('hide');
  });

  $('body').css("background-image", "url('/images/photos/borders/talks.jpg')");
  currentBackground = "talks";
  $(window).scroll(function() {
    calculateSectionHeights();

    var windowTop = window.pageYOffset;
    var windowHeight = $(window).height()
    var windowBottom = windowTop + windowHeight;
    var lastBottom = lastTop + windowHeight;

    for(var key in images) {
      if (currentBackground == key) {
        continue;
      }

      if ((windowBottom > images[key].top && lastBottom <= images[key].top) ||
      (windowTop <= images[key].bottom && lastTop > images[key].bottom)) {
        currentBackground = key;
        lastTop = windowTop;
        $('body').css("background-image", "url('/images/photos/borders/" + key + ".jpg')");
        return;
      }
    }
  });

  var news = new Firebase('https://winvin.firebaseio.com/news');
  news.on('child_added', function(snapshot) {
    var data = snapshot.val();
    if (div = renderNews(data)) {
      $(newsDivForDate(data)).append(div);
      sortItems(newsDivForDate(data));
    }
  });

  news.on('child_changed', function(snapshot) {
    var data = snapshot.val();
    $('#news-'+data.id).remove();
    if (div = renderNews(data)) {
      $(newsDivForDate(data)).append(div);
      sortItems(newsDivForDate(data));
    }
  });

  var talks = new Firebase('https://winvin.firebaseio.com/talks');
  talks.on('child_added', function(snapshot) {
    var data = snapshot.val();
    if (div = renderTalk(data)) {
      $(talkDivForDate(data)).append(div);
      sortItems(talkDivForDate(data));
    }
  });

  talks.on('child_changed', function(snapshot) {
    var data = snapshot.val();
    $('#talk-'+data.id).remove();
    if (div = renderTalk(data)) {
      $(talkDivForDate(data)).append(div);
      sortItems(talkDivForDate(data));
    }
  });
});

function renderTalk(data) {
  if (!data.published) {
    return;
  }

  data = applyFilters(data);
  var div = $('#wv-talk-item-template').html();
  return Mustache.render(div, data);
}

function renderNews(data) {
  if (!data.published) {
    return;
  }

  if (new Date(data.datetime) < new Date()) {
    return;
  }

  data = applyFilters(data);
  var div = $('#wv-news-item-template').html();
  return Mustache.render(div, data);
}

function sortItems(div) {
  $(div).children().sort(function(a, b) {
    var contentA = parseInt($(a).attr('data-sort'));
    var contentB = parseInt($(b).attr('data-sort'));
    return (contentA < contentB) ? -1 : (contentA > contentB) ? 1 : 0;
  }).appendTo($(div));
}

function applyFilters(data) {
  if (data.text) {
    data.text = markdown.toHTML(data.text);
  }
  var date = new Date(data.datetime);
  if (!isNaN(date)) {
    data.ms = date.getTime();
    data.dow = date.strftime("%a %e") + get_nth_suffix(date) + date.strftime(" %b");
    data.fulldatetime = date.strftime("%a %e %b %H:%M%p");
    data.date = date.strftime("%a %d %b %Y");
  }
  var enddate = new Date(data.enddatetime);
  if (!isNaN(enddate)) {
    data.dow = "";
    data.fulldatetime = date.strftime("%a %e %b") + " - " + enddate.strftime("%a %e %b");
  }
  return data;
}

function get_nth_suffix(date) {
   switch (date) {
     case 1:
     case 21:
     case 31:
        return 'st';
     case 2:
     case 22:
        return 'nd';
     case 3:
     case 23:
        return 'rd';
     default:
        return 'th';
   }
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

var MS_IN_DAY = 85400000;

function newsDivForDate(data) {
  var date = new Date(data.datetime);
  var now = new Date();
  var nextSunday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (7 - now.getDay()));

  if ((date - now)/MS_IN_DAY <= 30) {
    return '#wv-news-this-month';
  }

  return '#wv-news-further-ahead';
}
