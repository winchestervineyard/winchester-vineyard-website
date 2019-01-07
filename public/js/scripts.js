var images = {
  'talks': 0,
  'healing': 0,
  'news': 0,
  'givehope': 0,
};
var preloaded = {};
if (typeof currentBackground == 'undefined') {
  currentBackground = "talks";
}

var lastTop = 0;

function calculateSectionHeights() {
  for (var key in images) {
    var section = $('#wv-' + key);
    if (!section.length) {
      return false;
    }
    var top = section.offset().top;
    images[key] = { top: top - 20, bottom: top + section.outerHeight() + 20 }
  }
  return true;
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

  $('body').css("background-image", "url('/images/photos/borders/" + currentBackground + ".jpg')");
  $(window).scroll(function() {
    if (!calculateSectionHeights()) {
      return;
    }

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

  //var hellobar = new Firebase('https://winvin.firebaseio.com/hellobar');
  //hellobar.on('child_added', function(snapshot) {
    //var data = snapshot.val();
    //if (div = renderHellobar(data)) {
      //$('#hellobar-here').append(div);
    //}
  //});

  //hellobar.on('child_changed', function(snapshot) {
    //$('#hellobar-here section').remove();
    //var data = snapshot.val();
    //if (div = renderHellobar(data)) {
      //$('#hellobar-here').append(div);
    //}
  //});

  var talks = new Firebase('https://winvin.firebaseio.com/talks');
  talks.on('child_added', function(snapshot) {
    var data = snapshot.val();
    if (div = renderTalk(data)) {
      $(talkDivForDate(data)).append(div);
      sortItems(talkDivForDate(data), -1);
    }
  });

  talks.on('child_changed', function(snapshot) {
    var data = snapshot.val();
    $('#talk-'+data.id).remove();
    if (div = renderTalk(data)) {
      $(talkDivForDate(data)).append(div);
      sortItems(talkDivForDate(data), -1);
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

function renderHellobar(data) {
  if (!data.published) {
    return;
  }

  var div = $('#wv-hellobar-template').html();
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

function sortItems(div, direction) {
  $(div).children().sort(function(a, b) {
    var contentA = parseInt($(a).attr('data-sort'));
    var contentB = parseInt($(b).attr('data-sort'));
    return (contentA > contentB) ? direction : (contentA < contentB) ? -direction : 0;
  }).appendTo($(div));
}

function applyFilters(data) {
  if (data.text) {
    data.text = markdown.toHTML(data.text);
  }
  var date = new Date(data.datetime);
  if (!isNaN(date)) {
    data.ms = date.getTime();
    data.dow = date.strftime("%a %e") + date.strftime(" %b");
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
