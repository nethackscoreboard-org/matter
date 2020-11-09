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
  $('TABLE#ascended').add('TABLE.sortasc').addClass('tablesorter').tablesorter(
  {
    headers : {
      3 : { sorter : 'custkey' },
      5 : { sorter : 'custkey' },
      6 : { sorter : 'custkey' },
      7 : { sorter : 'custkey' }
    }
  });
  $('TABLE.sortplr').addClass('tablesorter').tablesorter(
  {
    headers : {
      4 : { sorter : 'custkey' },
      5 : { sorter : 'custkey' }
    }
  });
});
