$(document).ready(function () {

  var headers = {};

  $.tablesorter.addParser({
    id : 'custkey',
    is: function(s, table, cell) {
      return false;
    },
    format : function(s, table, cell, cellIndex) {
      return $(cell).attr('data-sortkey');
    },
    parsed : false,
    type : 'numeric'
  });

  // create "headers" object for tabsorter from TH elements
  // elements that are to be sorted have custom attribute
  // "data-sorter" equal to "true" or "custkey"

  $('table#ascended thead tr th').each(function(i) {
    var sorter = $(this).data('sorter');
    if(sorter == 'custkey') {
      headers[i] = { sorter: 'custkey' };
    } else if(sorter == true) {
      return;
    } else {
      headers[i] = { sorter: false };
    }
  });

  $('TABLE#ascended').addClass('tablesorter').tablesorter(
    { headers : headers }
  );
});
