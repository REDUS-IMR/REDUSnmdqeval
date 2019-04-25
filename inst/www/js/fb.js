// Mostly adapted from https://github.com/sumitchawla/file-browser

var extensionsMap = {
                      ".zip" : "fa-file-archive-o",         
                      ".gz" : "fa-file-archive-o",         
                      ".bz2" : "fa-file-archive-o",         
                      ".xz" : "fa-file-archive-o",         
                      ".rar" : "fa-file-archive-o",         
                      ".tar" : "fa-file-archive-o",         
                      ".tgz" : "fa-file-archive-o",         
                      ".tbz2" : "fa-file-archive-o",         
                      ".z" : "fa-file-archive-o",         
                      ".7z" : "fa-file-archive-o",         
                      ".mp3" : "fa-file-audio-o",         
                      ".cs" : "fa-file-code-o",         
                      ".c++" : "fa-file-code-o",         
                      ".cpp" : "fa-file-code-o",         
                      ".js" : "fa-file-code-o",         
                      ".xls" : "fa-file-excel-o",         
                      ".xlsx" : "fa-file-excel-o",         
                      ".png" : "fa-file-image-o",         
                      ".jpg" : "fa-file-image-o",         
                      ".jpeg" : "fa-file-image-o",         
                      ".gif" : "fa-file-image-o",         
                      ".mpeg" : "fa-file-movie-o",         
                      ".pdf" : "fa-file-pdf-o",         
                      ".ppt" : "fa-file-powerpoint-o",         
                      ".pptx" : "fa-file-powerpoint-o",         
                      ".txt" : "fa-file-text-o",         
                      ".log" : "fa-file-text-o",         
                      ".doc" : "fa-file-word-o",         
                      ".docx" : "fa-file-word-o",         
                    };

function getFileIcon(ext) {
    return ( ext && extensionsMap[ext.toLowerCase()]) || 'fa-file-o';
}

var FBtable = null;
var FBcurrentPath = null;
var FBoptions = {
	"language": {
			"processing": "Fetching file list...",
    	},
	"dom": '<"toolbar">frtip',
        "processing": true,
        "serverSide": false,
        "paging": false,
        "autoWidth": false,
        "scrollY":"250px",
        "fnCreatedRow" :  function( nRow, aData, iDataIndex ) {
          var path = aData.Path;
          
	  $(nRow).bind("click", function(e){
	     if (!aData.IsDirectory){
		$(this).toggleClass('selected');
		var FBdata = FBtable.rows('.selected').data().map(x => x.Path)
		//parent.postMessage(path,"*");
		$("#selectFileInput").val(FBdata.join())
	     }else{
	        FBtable.processing( true );
             	//$.get('/rest/files?path='+ path).then(function(data){
             	$.post( "../R/browseHere/json", {path: JSON.stringify(path)} ).then(function(data){
              	  FBtable.processing( false );
		  FBtable.clear();
		  FBtable.rows.add(data).search('').draw();
              	  FBcurrentPath = path;
		  $("#FBpanel #pathText").text(path);
            	});
	     }
             e.preventDefault();
          });
        }, 
        "aoColumns": [
          { "sTitle": "", "mData": null, "bSortable": false, "sClass": "head0", "sWidth": "55px",
            "render": function (data, type, row, meta) {
              if (data.IsDirectory) {
                return "<a href='#' target='_blank'><i class='fa fa-folder'></i>&nbsp;" + data.Name +"</a>";
              } else {
                return "<a href='" + data.Path + "' target='_blank'><i class='fa " + getFileIcon(data.Ext) + "'></i>&nbsp;" + data.Name +"</a>";
              }
            }
          }
        ]
   };

function genFBTable(table){

  if(!$.fn.dataTable.isDataTable(table)){
  	FBtable = table.DataTable(FBoptions);
	$("#FBpanel div.toolbar").html('Location: <span id="pathText">&nbsp;</span> <span class="up"><i class="fa fa-level-up"></i> Up</span>');


  	$("#FBpanel .up").bind("click", function(e){
    		if (!FBcurrentPath) return;
    		var idx  = FBcurrentPath.lastIndexOf("/");
    		var path = FBcurrentPath.substr(0, idx);
		FBtable.processing( true );
    		//$.get('/rest/files?path='+ path).then(function(data){
		$.post("../R/browseHere/json", {path: JSON.stringify(path)} ).then(function(data){
			FBtable.processing( false );
        		FBtable.clear();
        		FBtable.rows.add(data).draw();
        		FBcurrentPath = path;
			$("#FBpanel #pathText").text(path);
    		});
  	});

	FBtable.processing( true );
	//$.get('/rest/files').then(function(data){
	$.post("../R/browseHere/json").then(function(data){
	  FBtable.processing( false );
	  FBtable.clear();
	  FBtable.rows.add(data).draw();
	});
  }

}

