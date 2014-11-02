$(document).ready(function()
{
  var d = new Date();
  var year = d.getFullYear();
  var devstart = new Date(year, 10, 1, 0, 0, 0);
  var devend = new Date(year, 11, 1, 0, 0, 0);
  var tzoffset_s = d.getTimezoneOffset() * 60000 - 25200000;
  var tzoffset_e = d.getTimezoneOffset() * 60000 - 28800000;
  devstart.setTime(devstart.getTime() - tzoffset_s);
  devend.setTime(devend.getTime() - tzoffset_e);

  $("div#counter")
    .countdown(devstart)
    .on("update.countdown", function(event) {
      var fmt = '%-H:%M:%S';
      if(event.offset.totalDays > 0) {
        fmt = '%-D day%!D, ' + fmt;
      }
      $(this).text(
        event.strftime(fmt)
      );
    })
    .on("finish.countdown", function(event) {
      $('span#countmsg').text("The tournament ends in ");
      $("div#counter").unbind("finish.countdown");
      $("div#counter").countdown(devend);
      $("div#counter").on("finish.countdown", function(event) {
        $("div#counter").unbind("finish.countdown");
        $(this).remove();
        $("span#countmsg").text("The tournament has ended.");
      });
    });
});
