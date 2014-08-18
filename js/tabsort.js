$(document).ready(function () {
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
  $('TABLE#ascended').addClass('tablesorter').tablesorter(
  {
    headers : {
      1 : { sorter : false },
      2 : { sorter : false },
      4 : { sorter : 'custkey' },
      6 : { sorter : 'custkey' },
      7 : { sorter : 'custkey' },
      8 : { sorter : 'custkey' }
    }
  });
});
