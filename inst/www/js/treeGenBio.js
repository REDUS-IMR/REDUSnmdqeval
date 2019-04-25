function generatePanel(NMDfileDir){

      /* Hide panel and show loading info */

      $("#panel").hide()
      $("#loadDataInfo").show()

      /* Blank all texts */
      $('#fileList').text("")

      /* Close all alerts */
      $(".alert").alert('close');

      /* Get Files */
      $.ajax({
                url: "../R/getFilesBiotic/print",
                contentType: "application/json",
                data: JSON.stringify({ nmdPath: NMDfileDir}),
                method: "POST",
                cache: false,
                dataType: "json",
                success: function(data) {
			var fileList = $('#fileList')
			fileList.html('')
			if(!jQuery.isEmptyObject(data)) {
                        	for (var key in data.urls) {
					fileList.append("<p class=\"list-group-item\"><span class=\"badge badge-info\">" + data.vers[key] + "</span>&nbsp;"
							+ "<span class=\"badge badge-secondary\">" + data.snapshots[key] + "</span><br/>"
							+ data.urls[key] + "</p>");
                        	}
				$('#tableDiff').html(data.html[0])
				$('#tableDiff tr td:last-child').each(function(){
					var $td = $(this);
					switch($td.text().trim()){
					case "TRUE":
						$td.html('<i class="fa fa-check-circle fa-2x" aria-hidden="true"></i>').addClass("equal");
						break;
					case "FALSE":
						$td.html('<i class="fa fa-times-circle fa-2x" aria-hidden="true"></i>').addClass("nequal");
						break;
					}
				});
				$("#detailDiff").html(data.detail[0])
			}else{
				fileList.html('No file(s) available for comparison. Please select different cruise.')
			}
			$('pre code').each(function(i, block) {
    				hljs.highlightBlock(block);
  			});
			$("#panel").show()
 			$("#loadDataInfo").hide()
		}
       })

}

$(function(){

  $.ajaxSetup({
    type: 'POST',
    headers: { "cache-control": "no-cache" }
  });

  $("#tree").fancytree({
    //checkbox: true,
    //selectMode: 3,
    source: $.ajax({
        url: "../R/getNodes/json",
	data: { compareCounter: "\"biotic\"" },
	method: "POST",
	cache: false,
        dataType: "json"
      }),
    click: function(event, data){
      var NMDfile = data.node
      if(NMDfile.isFolder()){
          NMDfile.toggleExpanded();
          return false;
      }
    },
    activate: function(event, data){
      var NMDfile = data.node
      if(NMDfile.isFolder()){
	  return false;
      }
      //$("#statusLine").text(event.type + ": " + NMDfile);

      // Process NMD File
      var NMDfileDir = '/' + NMDfile.key.replace(/\$/g,"/")
      activePath = NMDfileDir
      $("#cruise").text(NMDfile.key.split("$").slice(0,3).join(" - "))
      //putFileContent("#input", "#f1", "/"+ NMDfileDir, "NMD")
      generatePanel(NMDfileDir)
    },
    select: function(event, data){
      $("#statusLine").text(event.type + ": " + data.node.isSelected() +
                            " " + data.node);
    },
    lazyLoad: function(event, data) {
        var node = data.node;
        data.result = $.ajax({
        	url: "../R/getNodes/json",
		contentType: "application/json",       	 	
		data: JSON.stringify({ root: node.key, compareCounter:"biotic" }),
		method: "POST",
        	cache: false,
        	dataType: "json"
      		})

      }
  });

});


