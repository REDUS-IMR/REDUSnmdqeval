var activeDiff = ""
var activePath = ""
var activeSession = ""


// Taken from https://stackoverflow.com/questions/46155/how-to-validate-email-address-in-javascript
function validateEmail(email) {
  var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
  return re.test(email);
}

// Customizable alert, will add alert text before the selected element
function genAlertText(alertType, id, text, element){

	var exists = $("#alertC-"+id);

	if(exists.length > 0){
		exists.remove();
	}
	alertText = '<div id="alertC-' + id + '" class="alert ' + alertType + ' alert-dismissible fade show" role="alert">' +
			'<span class="innerText">'+ text + '</span>' +
			'<button type="button" class="close" data-dismiss="alert" aria-label="Close">' +
			'<span aria-hidden="true">&times;</span>' +
			'</button>' +
			'</div>';
	element.before(alertText);
	return true;
}

function putFileContent(id, sid, name, dtype){
	$.ajax({
                url: "../R/getRAW/json",
                contentType: "application/json",
                data: JSON.stringify({file: name, type: dtype}),
                method: "POST",
                cache: false,
                dataType: "json",
                success: function(data) {
                        $(id).html(data)
			$(sid).html("&#x2714;")
                },
                error: function(data) {
                        alert(data)
                }
                })
}

function dlDiff(cmp1, cmp2, type, order){
	
	rurl = "../R/prettyDiffR"

	var req = ocpu.call(rurl, {result:activeSession, files:activeDiff, f1:cmp1, f2:cmp2, type:type, order:order}, function(session){
		loc = session.getLoc();
		session.getObject(function(data){
			if(type=="csv"){
				//alert(data)
                        	window.location = loc + '/files/' + data;
			}else
				window.location = loc + '/files/' + data;
        	})
	})
}

function processMatrix(d){
	$('tr td:first-child', d).each(function(){
  		var $td = $(this);
  		$td.replaceWith('<th>' + $td.text() + '</th>');
	});
	$('td', d).each(function(){
                var $td = $(this);
		var cmp2 = $td.closest('table').find('th').eq($(this).index()).text().trim();
                var cmp1 = $td.closest('tr').find(':first').text().trim();
		switch($td.text().trim()){
			case "eq":
				$td.html('<i class="fa fa-check-circle fa-2x" aria-hidden="true"></i>').addClass("equal");
				break;
			case "neq":
				$td.html('<a tabindex="0" class="xPop" data-toggle="popover" data-trigger="focus" data-title="Custom Title" data-content="Custom Content">'+
					 '<i class="fa fa-times-circle fa-2x" aria-hidden="true"></i></a>').addClass("nequal");
				break;
			default:
                                $td.addClass("empty");
                                break;

		}
    		$('.xPop', $td).popover({
        		placement: 'left',
			trigger: 'focus',
        		html: true,
        		title: function() {
           			return "Comparison for " + cmp1 + " and " + cmp2;
        		},
      		}).attr('data-content', "Please select the comparison category below:<br>"+
					"<button class=\"btn btn-primary btn-sm\" onClick=\"dlDiff('"+cmp1+"','"+cmp2+"','csv',1)\">DistanceFrequency</button><br>"+
					"<button class=\"btn btn-primary btn-sm\" onClick=\"dlDiff('"+cmp1+"','"+cmp2+"','csv',2)\">NASC</button>");
	        
        });

}


function generatePanel(NMDfileDir){

      // Hide panel and show loading info
      $("#panel").hide()
      $("#loadDataInfo").show()

      // Blank all texts
      $("#rdiff").text("")
      $('#fileList').text("")

      // Close all alerts
      $(".alert").alert('close');

      $("#matrixLoading").show()
      $("#detailed").hide()
      $("#selectFileInput").val("") 

      // Get file list
      $.ajax({
                url: "../R/getFiles/print",
                contentType: "application/json",
                data: JSON.stringify({ nmdPath: NMDfileDir}),
                method: "POST",
                cache: false,
                dataType: "json",
                success: function(data) {
			var fileList = $('#fileList')
			fileList.html('')
			for (var key in data) {
				var addTag = ""

				if(key.search("USER")!=-1)
				   addTag += "&nbsp;<button id=\"fileR"+key+"\" type=\"button\" data-confirm=\"Are you sure you want to remove?\""+
					     "class=\"btn btn-danger btn-sm rmvXML\">Remove</button>"

				if(key=="CES-LUF05")
				   addTag += "&nbsp;<button data-toggle=\"collapse\" type=\"button\" class=\"btn btn-sm\" data-target=\"#luf05files\">"+
					    "Show source files</button><br><span id=\"luf05files\" class=\"collapse\"></span>"

				if(/(?=.*USER)(?=.*LUF0)/.test(key))
				   addTag += "&nbsp;<button data-toggle=\"collapse\" type=\"button\" class=\"btn btn-sm\" data-target=\"#"+key+"-files\">"+
                                            "Show source files</button><br><span id=\""+key+"-files\" class=\"collapse user-files\"></span>"

				fileList.append("<p class=\"list-group-item\">File from <b>"+key+"</b>: <samp>"+data[key]+"</samp> "+
						"<button id=\"file"+key+"\" type=\"button\" class=\"btn btn-primary btn-sm getXML\">Download XML</button>"+
						addTag+"</p>");
			}

			// Process official file
			$.post('../R/getOfficialFile/json', {path: JSON.stringify(activePath)}, function(data, textStatus){
				if(data.length < 2) return false;
				$('#fileList samp').each(function( index ) {
					if($(this).text()==data.file[0])
						$(this).parent("p").prepend('<span class="badge badge-info">Official pick</span><br/>')
				})
                        }, "json");

			// Get LUF05 files
			var luf05 = $("#luf05files")

			if(luf05.length > 0){
				luf05.text("Loading...")
				var req = ocpu.rpc("getFileListLUF05",{
							nmdFile : NMDfileDir
					}, function(output){
							luf05.html(output.join("\n")).wrapInner('<pre />');
					});

			}

			// Method for others sources
			$('.user-files').on('show.bs.collapse', function () {
				var textSpan = $(this)
				if(textSpan.hasClass( "user-files" )){
				   textSpan.removeClass("user-files")
				   var userKey = textSpan.attr("id");
				   textSpan.text("Loading...")
				   var req = ocpu.rpc("getUserSource",{
                                                        path : NMDfileDir,
							key : userKey
					}, function(output){
                                                        textSpan.html(output.join("\n")).wrapInner('<pre />');
                                        });
				}
			})

			// Put on the file list in global variable
			// but check first whether user have clicked different cruise
			if(NMDfileDir == activePath){
				activeDiff = data
				$("#loadDataInfo").hide()
				$("#panel").show()
			}else{
				return false;
			}

			var req1 = ocpu.call("makeDiffR", {files: activeDiff}, function(session1){
				// Only if user have not clicked on a different cruise
				if(NMDfileDir == activePath){
					activeSession = session1
					var req2 = ocpu.call("diffFilesR", {result: session1, files:activeDiff}, function(session2){
						session2.getObject(function(data){
							// Only if user have not clicked on a different cruise
							if(NMDfileDir == activePath){
								d = $("#rdiff")
								d.html(data)
								$("#matrixLoading").hide()
								processMatrix(d)
							}else{
								return false;
							}
						})
					});
					req2.fail(function(){
						var mLoad = $("#matrixLoading")
						genAlertText("alert-danger", "genCompare", "<strong>Error!</strong> Unable to generate comparison. This can be due to several factors." +
                                        			"Please report this to the responsible developer or scientist.", mLoad);
						mLoad.hide();
					});
				}else{
					return false;
				}
			});
			req1.fail(function(){
                                var mLoad = $("#matrixLoading")
                                genAlertText("alert-danger", "genCompare", "<strong>Error!</strong> Unable to generate comparison. This can be due to several factors." +
                                                                "Please report this to the responsible developer or scientist.", mLoad);
                                mLoad.hide();
			});
                },
                error: function(data) {
                        alert(data)
                }
      })
}

$(function(){

  $.ajaxSetup({
    type: 'POST',
    headers: { "cache-control": "no-cache" }
  });

  $("#saveFileBtn").click(function(){
    // Element for injecting alerts
    var el = $(this).parentsUntil("form").last();
    var inp = $("#selectFileInput").val()
    var JSONinp = inp.split(",")
    var ty = $("#typeFileInput").val()
    if(inp=="" || activePath==""){
	genAlertText("alert-warning", "addFile", "Empty selection!", el);
	return;
    }

    // Disable button
    var btn = $(this)
    var before = btn.text();
    btn.html('<i class="fa fa-circle-o-notch fa-spin"></i> processing').prop('disabled', true);

    $.ajax({
      url: "../R/saveUserFile/json",
      contentType: "application/json",
      data: JSON.stringify({files:JSONinp, path:activePath, type:ty}),
      method: "POST",
      cache: false,
      success: function(data) {
		if(data[0]==true){
	     		generatePanel(activePath);
			genAlertText("alert-success", "addFile", "<strong>Success!</strong> File is added to the comparison.", el);
		}else
			genAlertText("alert-danger", "addFile", "<strong>Error!</strong> File is not valid. Please make sure you have select "+ 
					"a correct file type and provide a valid file for the type.", el);
      		btn.text(before).prop('disabled', false);
      },
      error: function(data) {
             alert(data)
	     btn.text(before).prop('disabled', false);
      }
      })
  })

  /* Not used anymore
  $(window).on("message onmessage", function(e) {
    var data = e.originalEvent.data;
    $("#selectFileInput").val(data)
  });*/

  $('#filepickModal').on('shown.bs.modal',function(){
	var mdl = $(this)

	var itable = $("#FBpanel .linksholder")

	genFBTable(itable)

	//var ifr = mdl.find('iframe')
 	//ifr.ready(function() {
	//	mdl.data('bs.modal').handleUpdate()
	//}) 
	//ifr.attr('src','/rest')
  })

  $("#fileList").on('click', '.rmvXML', function() {
		if(activePath=="") return;
		myID = $(this).attr("id")
		if (!$('#dataConfirmModal').length) {
			$('body').append('<div id="dataConfirmModal" class="modal" role="dialog" aria-labelledby="dataConfirmLabel" ' +
					 'aria-hidden="true"><div class="modal-dialog" role="document"><div class="modal-content"> ' +
					 '<div class="modal-header"><h4 class="modal-title">Please confirm</h4> ' +
					 '<button type="button" class="close" data-dismiss="modal" aria-label="Close"> ' +
					 '<span aria-hidden="true">&times;</span></button></div><div class="modal-body"> ' +
					 '</div><div class="modal-footer"><button class="btn btn-primary" data-dismiss="modal" aria-hidden="true">Cancel</button> '+
					 '<button class="btn btn-danger dataConfirmOK">Yes, I\'m sure</button></div></div></div></div>');


			$('#dataConfirmModal .dataConfirmOK').on('click', function(){
				var t = $(this).attr("Rtag")
				var req = ocpu.call("../R/removeUserFile", {path:activePath, tag:t}, function(session){
					$("#dataConfirmModal .close").click()
					generatePanel(activePath);
				})
			})
		}
		$('#dataConfirmModal .dataConfirmOK').attr("Rtag", myID)
		$('#dataConfirmModal').find('.modal-body').text($(this).attr('data-confirm'));
		$('#dataConfirmModal').modal({show:true});
		return false;
  })


  $("#fileList").on('click', '.setOfficial', function() {
                if(activePath=="") return;
		myID = $(this).attr("id")
                if (!$('#dataSetOfficial').length) {
                        $('body').append('<div id="dataSetOfficial" class="modal" role="dialog" aria-labelledby="dataConfirmLabel" ' +
                                         'aria-hidden="true"><div class="modal-dialog" role="document"><div class="modal-content"> ' +
                                         '<div class="modal-header"><h4 class="modal-title">Please confirm</h4> ' +
                                         '<button type="button" class="close" data-dismiss="modal" aria-label="Close"> ' +
                                         '<span aria-hidden="true">&times;</span></button></div><div class="modal-body"> ' +
					 'Are you sure you want to set this file as the official echosounder file for this cruise?<br/>' +
					 'Please enter your email address in the form below and press the confirm button.<br/>' +
                                         '<form><div class="form-group"><input type="email" placeholder="Enter email" class="form-control" id="usrEmail">' +
					 '<div class="invalid-feedback">Please provide a valid email.</div></div></form></div>' +
					 '<div class="modal-footer"><button class="btn btn-primary" data-dismiss="modal" aria-hidden="true">Cancel</button> '+
                                         '<button class="btn btn-danger dataConfirmOK">Confirm</button></div></div></div></div>');


			$('#dataSetOfficial .dataConfirmOK').on('click', function(){
				var t = $(this).attr('Rtag').replace('setFile','');
				var email = $("#usrEmail").val();
				if(validateEmail(email)==false){
					alert("Please input valid email");
					return false;
				}

				//Empty the email val
				$("#usrEmail").val("")
				//$.getJSON('/rest/getip', function(data) {
				//TODO: Get IP address here
					var ip = "1.1.1.1";
					$.ajax({
						url: "../R/setOfficialFile/json",
						contentType: "application/json",
						data: JSON.stringify({path:activePath, file:activeDiff[t], tag:t, ip:ip, email:email}),
						method: "POST",
						cache: false,
						success: function(data) {
							$("#dataSetOfficial .close").click()
							generatePanel(activePath);
						},
						error: function(data) {
							alert(data)
						}
					})

				//});
			})
		}
		$('#dataSetOfficial .dataConfirmOK').attr("Rtag", myID)
		$('#dataSetOfficial').modal({show:true});
		return false;
  })



  $("#fileList").on('click', '.getXML', function() {
                var t = $(this).attr('id').replace('file','')
                var file = activeDiff[t]
                var req = ocpu.call("../R/getXML", {file: file}, function(session){
                        loc = session.getLoc();
                        window.location = loc + '/files/' + file.split('/').reverse()[0] + '.zip';
                })
  })

  $("#fileList").on({
	'mouseenter': function() {
                var t = $(this).find(".getXML").attr('id').replace('file','');
                var file = activeDiff[t];
		$( this).children("button").last().after( $("<button id=\"setFile"+t+"\" type=\"button\" "+
				    "class=\"mx-1 btn btn-sm btn-success setOfficial\">Set as \"Official\"</button>") );
	},
	'mouseleave':function() {
		$( this ).find( ".setOfficial" ).remove();
	}
  }, "p");



  $("#tree").fancytree({
    //checkbox: true,
    //selectMode: 3,
    source: $.ajax({
        url: "../R/getNodes/json",
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
		data: JSON.stringify({ root: node.key}),
		method: "POST",
        	cache: false,
        	dataType: "json"
      		})

      }
  });

});


