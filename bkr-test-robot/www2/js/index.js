$(document).ready(function() {
    var table = $('#table01').DataTable( {
        scrollY:        "588px",
        scrollX:        true,
        scrollCollapse: true,
        paging:         false,
        columnDefs: [
	  {
            sortable: false,
            "class": "index",
            targets: 0
	  }
	],
        order: [[ 1, 'asc' ]],
        fixedColumns:   {
            leftColumns: 2
        }
    } );

    table.on( 'order.dt search.dt', function () {
        table.column(0, {search:'applied', order:'applied'}).nodes().each( function (cell, i) {
            cell.innerHTML = i+1;
        } );
    } ).draw();

} );
