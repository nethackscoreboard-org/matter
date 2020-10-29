$(document).ready(function()
{
  var d = new Date();
  var year = d.getFullYear();
  var devstart = new Date(year, 10, 0, 0, 0, 0);
  var devend = new Date(year, 11, 0, 0, 0, 0);
  var tzoffset = d.getTimezoneOffset() * 1000 + 240000;
  devstart.setTime(devstart.getTime() + tzoffset);
  devend.setTime(devend.getTime() + tzoffset);

  $('span#start').text(devstart);
  $('span#end').text(devend);
  
  $("div#clock")
    .countdown(devstart)
    .on("update.countdown", function(event) {
      var fmt = '%-H:%M:%S.';
      if(event.offset.days > 0) {
        fmt = '%-D day%!D, ' + fmt;
      }
      $(this).text(
        event.strftime(fmt)
      );
    })
    .on("finish.countdown", function(event) {
      $('span#anno').text("The tournament ends in");
      $("div#clock").unbind("finish.countdown");
      $("div#clock").countdown(devend);
      $("div#clock").on("finish.countdown", function(event) {
        $("div#clock").unbind("finish.countdown");
        $(this).remove();
        $("span#anno").text("The tournament has ended.");  
      });
    });
});
