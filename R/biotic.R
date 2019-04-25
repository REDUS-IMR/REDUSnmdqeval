getFilesBioticCore <- function(nmdPath, simpleOutput = FALSE) {

	getSnap <- function(url, requestTime) {
		url <- URLencode(url)
		write(paste("extract: ", url), stderr())
		tmp <- httr::GET(url)

		tmpSnap <- httr::content(tmp, "text")

		snapshots <- xml2::xml_text(xml2::xml_find_all(xml2::read_xml(tmpSnap), ".//d1:element"))

		# Clean "latest" keyword and sort it (descending)
		snapshots <- snapshots[!(snapshots=="latest")]
		snapshots <- snapshots[order(lubridate::ymd_hms(snapshots), decreasing = TRUE)] #sort(snapshots, decreasing = TRUE)

		if(requestTime == "earliest")
			cutOff <- snapshots[length(snapshots)]
		else if(requestTime == "latest")
			cutOff <- snapshots[1]
		else
			cutOff <- lubridate::ymd_hms(requestTime, tz = "Europe/Oslo")

		cutOff <- lubridate::ymd_hms(cutOff, tz = "Europe/Oslo")

		for(j in 1:length(snapshots))
			if(lubridate::ymd_hms(snapshots[j], tz = "Europe/Oslo") <= cutOff)
				break

		snapshot <- snapshots[j]
		write(requestTime, stderr())
		write(snapshot, stderr())

		return(snapshot)
	}

	processBase <- function(file, project){
		getBaseline(project, parlist=list(
                            ReadBioticXML=list(functionName="ReadBioticXML",
                                    FileName1=file)))
	}

        cruiseNR <- basename(dirname(nmdPath))
        cruiseShip <- basename(nmdPath)

        #write(paste("nmd:",nmdFile, "loc:", nmdLoc), stderr())

        # Download from NMD
	combination <- list(c(API="http://tomcat7.imr.no:8080/apis/nmdapi", APIver="2",  DATAver="1.4" , snapshot="latest"),
			c(API="http://tomcat7.imr.no:8080/apis/nmdapi", APIver="3", DATAver="3.0", snapshot="latest"))

	ref_ver <- getRstoxDef("ver")

	urls <- list()
	data <- list()
	vers <- list()
	snapshots <- list()

	tempDir <- tempdir()
	
	# Prepare comparison
     	pTemp <- system.file("stox", "BCompare", package="nmdqeval")

	for( i in 1:length(combination)) {
		ref_ver$biotic <- combination[[i]][["DATAver"]]
		ref_ver$API$biotic <- combination[[i]][["APIver"]]
		ref_ver$snapshot <- combination[[i]][["snapshot"]]

		# Hack in testing some cruises (TODO: remove this in prod)
		#newGenCruises <- c("2017210","2018838","2018203","2018207","2018210","2018623","2013826")
		#if(cruiseNR %in% newGenCruises)
		#	ref_ver$snapshot <- "latest"
		
		# Find URL
		url <- searchNMDCruise(cruisenr=cruiseNR, shipname=cruiseShip, ver=ref_ver, server=combination[[i]][["API"]])[[1]]

		if(is.na(url)) {
			if(simpleOutput)
				return(NA)
			else
				return(list(urls = urls, vers = vers, snapshots = snapshots, html = "", detail = "At least one file is missing!"))
		}

		write(paste("given:", url), stderr())

		# Get snapshot lists
		urlSnap <- paste0(gsub("snapshot.+$|dataset.+$", "snapshot", url), "?version=", ref_ver$biotic)

		snapshot <- getSnap(urlSnap, ref_ver$snapshot)

		# Always use snapshot (TODO: change when Rstox supports it)
		url <- paste0(gsub("snapshot.+$|dataset.+$", paste0("snapshot/", snapshot), url), "?version=", ref_ver$biotic)

		write("Downloading", stderr())
		write(url, stderr())
 		
		# Download files
		url <- URLencode(url)
                tmpfil <- tempfile(tmpdir = tempDir)
                getStat <- GET(url, write_disk(tmpfil))
		write(tmpfil, stderr())

		write("Processing", stderr())
		data[[i]] <- Rstox::getBaseline(pTemp, parlist=list(ReadBioticXML=list(functionName="ReadBioticXML", FileName1=tmpfil)))

		urls[[i]] <- url
		vers[[i]] <- ref_ver$biotic
		snapshots[[i]] <- snapshot
	}

	test <- c("ReadBioticXML_BioticData_FishStation.txt", "ReadBioticXML_BioticData_Individual.txt", "ReadBioticXML_BioticData_CatchSample.txt")

	results <- lapply(test, function(x) all.equal(data[[1]]$outputData$ReadBioticXML[[x]], data[[2]]$outputData$ReadBioticXML[[x]]))
	resultsLogical <- lapply(results, isTRUE)

	names(results) <- test

	if(simpleOutput)
		return(all(resultsLogical))

	refData <- data[[1]]$outputData$ReadBioticXML

	resultsLogical <- cbind(test, t(as.data.frame(resultsLogical)))
        colnames(resultsLogical) <- c("Category", "Equal?")
	rownames(resultsLogical) <- c()

	htmlTable <- knitr::kable(resultsLogical, "html", table.attr="class=\"table table-bordered\"")

	options(markdown.HTML.options="fragment_only")
	detail <- knitr::knit2html(text=paste0("```{r, mychunk, eval=TRUE}\n lapply(refData, nrow) \n results \n```"))

	out <- list(urls = urls, vers = vers, snapshots = snapshots, html = paste(htmlTable), detail = detail)

	return(out)
}

getFilesBiotic <- function(nmdPath) {
	out <- getFilesBioticCore(nmdPath)
        return(jsonlite::toJSON(out))
}


checkAllBioticCruise <- function(refFile = paste0(getRootDir(),"/csNMD.rds"), out = paste0(getRootDir(),"/csNMDcompareBiotic.rds")) {

	process <- function(name, x) {

		y <- names(x)
		if(is.list(x)) {
			out <- lapply(y, function(z) process(z, x[[z]]))
		} else {
			out <- x
		}

		out <- paste0(name, "/", unlist(out, recursive = FALSE))
		return(out)
	}


	checkData <- function(nmdPath, x){

		cruiseShip <- basename(nmdPath)
		cruiseNo <- basename(dirname(nmdPath))
		cruiseYear <- basename(dirname(dirname(nmdPath)))
		cruiseSeries <- basename(dirname(dirname(dirname(nmdPath))))

		out <- getFilesBioticCore(nmdPath, simpleOutput = TRUE)

		if(!is.list(x[[cruiseSeries]][[cruiseYear]][[cruiseNo]]))
			x[[cruiseSeries]][[cruiseYear]][[cruiseNo]] <- list()
		x[[cruiseSeries]][[cruiseYear]][[cruiseNo]][[cruiseShip]] <- out
		return(x)
	}

	x <- readRDS(refFile)
	y <- x
	z <- process("", x)

	for(i in 1:length(z))
		y <- checkData(z[[i]], y)

	saveRDS(y, out)
}
