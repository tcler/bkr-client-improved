$(document).ready(function() {
    var table = $('#table01').DataTable( {
        scrollY:        "670px",
        scrollX:        true,
        scrollCollapse: true,
        paging:         false,
        fixedColumns:   {
            leftColumns: 2
        }
    } );
} );
