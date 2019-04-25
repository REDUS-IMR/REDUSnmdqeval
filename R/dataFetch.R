LUF05FileList <- function(cruiseNR){

       indexFile <- paste0(getRootDir(), "/csCES-L05.csv")

       #write(paste("Looking for BEI in", indexFile, cruiseNR),stderr())

       linesRAW <- grep(paste0("S", cruiseNR), readLines(indexFile), value = TRUE)

       if(length(linesRAW)==0){
                return(NULL)
       }

       lines <- read.csv(text=linesRAW, header = FALSE, colClasses = "character", sep=",")

       # Get the smallest resolution
       res <- lines[1,4]
       print(res)

       f <- lines[lines[,4]==res,]

       return(f)

}

doLUFConvert <- function(rawFiles, type="LUF05", extra=NULL){
	# Init Java
	.jinit()
        .jaddClassPath(dir(paste0(.libPaths()[1],"/Rstox/java/"), full.names=TRUE))
	conv <- J("no.imr.stox.functions.acoustic.AcousticConverter")
	if(type == "LUF05"){
		#lufDir <- paste0(tempdir(), "/lufconvert", cruiseNR)
        	lufDir <- paste0(tempfile(),"convert")

        	#print(lufDir)

        	dir.create(lufDir)

        	file.copy(rawFiles, lufDir)

        	# Sometimes the converter produces error, just ignore it for now
        	t = tryCatch({
		       conv$convertLUF5DirToLuf20(lufDir)
		    }, error = function(e) {
		       write(e$message, stderr())
          	       return(NULL)
		    })
        	out <- list.files(lufDir, "*xml", full.names=T)

	}else if(type == "LUF03"){

		# Check extra info
		if(is.null(extra)) return(NULL)

		write(paste( extra["cruise"], extra["nation"], extra["platform"]), stderr())

		outFileName <- paste0(tempfile(), ".xml")

		write(outFileName, stderr())

		t = tryCatch({
		       conv$convertAcousticCSVFileToLuf20(rawFiles, outFileName,  extra["cruise"], extra["nation"], extra["platform"])
                    }, error = function(e) {
                       write(e$message, stderr())
		       write(e$jobj$printStackTrace(),stderr()) 
                       return(NULL)
                    })
		write("Finish convert",stderr())

		out <- c(outFileName)
	}else
		return(NULL)

        return(out[1])
}

LUF05process <- function(cruiseNR){

        f <- LUF05FileList(cruiseNR)

	if(is.null(f))
		return(NULL)

	rawFiles <- paste0(f[,2],"/",f[,3])

	out <- doLUFConvert(rawFiles, "LUF05")

        return(out)
}

PGNprocess <- function(cruisePGN, outFilePGN) {
     .jinit()
     .jaddClassPath(dir(paste0(.libPaths()[1],"/nmdqeval/java/"), full.names=TRUE))
     converter <- J("no.imr.sea2data.pgnapesclient.core.PgNapesClientConverter")
     user <- "no"#enter your pgnapes username
     pw <- "tuna5359"#enter your pgnapes password
     converter$logon(user, pw)
     converter$exportLUF20(cruisePGN, outFilePGN)
}

# Get NMD, PGNAPES, LUF05 databases, also create the folder structure if not yet created, logs and history are preserved using GIT
dataFetch <- function(fetchPGNAPES = FALSE){

# Create directory structure and download files
createCSdir <- function(name, csList){
  tmpList <- csList[[name]]
  rootCS <- file.path(paste0(getRootDir(), "/", name, "/", unique(tmpList[, "Year"])))

  lapply(rootCS, dir.create, recursive=TRUE)
  yearList <- list()
  for(idx in 1:nrow(tmpList)){
    urls <- searchNMDCruise(tmpList[idx, "Cruise"], tmpList[idx, "ShipName"], "echosounder")
    cruiseDir <- file.path(paste0(getRootDir(), "/", name, "/", tmpList[idx, "Year"], "/", tmpList[idx, "Cruise"]))
    dir.create(cruiseDir, showWarnings=FALSE)

    for(ff in seq_along(urls)){
     if(!is.na(urls[ff])){
      cat("File URL from NMD: ", urls[ff], "\n")
      url <- URLencode(urls[ff])
      cat("File URL from NMD (encoded): ",url, "\n")
      tmpfil <- tempfile()
      fil <- GET(url, write_disk(tmpfil))
      cat("\nHeaders: \n")
      print(headers(fil))
      filname <- str_match(headers(fil)$`content-disposition`, "\"(.*)\"")[2]
      if(is.na(filname)){
	filname <- paste0("echosounder_cruiseNumber_", tmpList[idx, "Cruise"], "_", tmpList[idx, "ShipName"], ".xml")
      }
      file.copy(tmpfil, file.path(paste0(cruiseDir, "/", filname)), overwrite=TRUE, copy.date=TRUE)
      unlink(tmpfil)
     }
    }

    # Record cruise
    if(!(tmpList[idx, "Year"][[1]] %in% names(yearList)))
      yearList[[tmpList[idx, "Year"][[1]]]] <- list()
    yearList[[tmpList[idx, "Year"][[1]]]][[tmpList[idx, "Cruise"][[1]]]] <- c(yearList[[tmpList[idx, "Year"][[1]]]][[tmpList[idx, "Cruise"][[1]]]], tmpList[idx, "ShipName"])

    # TODO: Sort Years

    cruisepgn <- tmpList[idx, "Cruise"]

    # Download PGNAPES too, if required
    if(fetchPGNAPES) {
        fName <- paste0("pgnapes_cruiseNumber_", tmpList[idx, "Cruise"], "_", tmpList[idx, "ShipName"])
        # Download and convert PGNAPES
        # Use cluster due to class name conflicts (TODO: ask Aasmund to integrate pgnapes convertor into the whole Rstox package)
	#PGNprocess(cruisepgn, path.expand(paste0(cruiseDir, "/", fName)))
        cl <- makeCluster(1)
        parLapply(cl, cruisepgn, PGNprocess, path.expand(paste0(cruiseDir, "/", fName)))
        stopCluster(cl)
    }

    # GET LUF05
    luf05 <- LUF05process(cruisepgn)

    if(!is.null(luf05)){
       fName <- paste0("bei_cruiseNumber_", tmpList[idx, "Cruise"], "_", tmpList[idx, "ShipName"], ".xml")
       file.copy(luf05, path.expand(paste0(cruiseDir, "/", fName)))
    }
  }
  return(yearList)
}


# Getting all cruise series
csList <- getNMDinfo("cs")

if(!dir.exists(getRootDir())){
  dir.create(getRootDir())
}

if(!in_repository(getRootDir())){
  repo <- init(getRootDir())
  config(repo, user.name="Download BOT", user.email="noname@imr.no")
}else{
  repo <- repository(getRootDir())
}

# Invoke batch download
parsedCS<-lapply(names(csList), createCSdir, csList)
names(parsedCS) <- names(csList)

# Save object for later
saveRDS(parsedCS, file=paste0(getRootDir(),"/csNMD.rds"), ascii=TRUE, compress=FALSE)

# Update GIT repo
add(repo, "*")
commit(repo, paste("Automated download script run on", Sys.time()))
}
