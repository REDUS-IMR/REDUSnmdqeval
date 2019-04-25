setOfficialFile <- function(path, file, tag, ip, email){

	time <- as.numeric(as.POSIXct(Sys.time()))

	nmd <- path.expand(paste0(getRootDir(), path))

	src <- tail(unlist(strsplit(tag, "[-]")), n=1)

	userFilePath <- paste0(dirname(nmd), "/selection.rds")

	# Read the file, make sure to lock it first to prevent race condition
	file.lock <- lock(paste0(userFilePath, ".lock"))
	if(file.exists(userFilePath)){
		userFile <- readRDS(userFilePath)
	}else{
		userFile <- list()
        }

	userFile[["selection"]] <- list()

	userFile[["selection"]][["time"]] <- time
	userFile[["selection"]][["type"]] <- src
	userFile[["selection"]][["tag"]] <- tag
	userFile[["selection"]][["file"]] <- file
	userFile[["selection"]][["email"]] <- email
	userFile[["selection"]][["ip"]]	<- ip

	saveRDS(userFile, file=userFilePath, ascii = TRUE, compress=FALSE)

        # Unlock file
        unlock(file.lock)

	return(TRUE)
}

# Getting official file
getOfficialFile <- function(path){
        nmd <- path.expand(paste0(getRootDir(), path))
        userFilePath <- paste0(dirname(nmd), "/selection.rds")
        if(file.exists(userFilePath)){
		userFile <- readRDS(userFilePath)
		return(userFile[["selection"]])
	}else{
		return(FALSE)
	}
}


# Getting sources for user file (LUF05 or LUF03)
getUserSource <- function(key, path){
	# TODO: Should move this together with session, considering if the record is removed by other and user will get wrong data

	order <- as.numeric(unlist(strsplit(key, "[-]"))[[2]])
	nmd <- path.expand(paste0(getRootDir(), path))
	userFilePath <- paste0(dirname(nmd), "/user.rds")
	userFile <- readRDS(userFilePath)

	return(userFile[[order]][["source"]])
}

extractNMDinfo <- function(nmdFile){

	#write(nmdFile, stderr())
	
	xmlFile <- xmlParse(nmdFile)
	xmlTop <- xmlRoot(xmlFile)


	#write(paste("Nation",xmlValue(xmlTop[["nation"]])), stderr())


	platform <- xmlValue(xmlTop[["platform"]])
	nation <- xmlValue(xmlTop[["nation"]])
	cruise <- xmlValue(xmlTop[["cruise"]])

	info <- c(cruise=cruise, platform = platform, nation = nation)

	write(info, stderr())

	return(info)
}

saveUserFile <- function(files, path, type){

	nmd <- path.expand(paste0(getRootDir(), path))

	isValid <- FALSE

	# Placeholder for metadata
	meta <- list()

	# LUF20 here
	if(type=="LUF20"){

	   schemaFile <- paste0(path.package("nmdqeval"), "/bin/valid_echosounder.xml")

	   # Only take the first file for LUF20
	   file <- files[[1]]

	   # Check file exist and valid using XML schema in schemaFile
	   if(file.exists(file)){
		# Parse the file, make sure it's an XML
		doc = tryCatch({
    				xmlParse(file)
			}, error = function(e) {
    				return(FALSE)
			})

		if(is.logical(doc)) return(FALSE)

		# Parse echosounder schema file
		schema <- xmlSchemaParse(schemaFile)
		
		# We remove all namespaces and get the data
		nodes<-getNodeSet(doc, "//*[local-name() = 'echosounder_dataset']")
		# Invalid if there is no date taken
		if(length(nodes)<1) return(FALSE)

		removeXMLNamespaces(nodes[[1]], all=TRUE)
		valid <- xmlSchemaValidate(schema, doc)

		# If valid then prepare the metadata for that
		if(valid[['status']]==0){
			meta <- list("filename"=file, "type"=type)
			isValid <- TRUE
		}
	   }
	}else if(type=="LUF05"){
	   # For LUF05, convert the files
	   outFile <- doLUFConvert(files, type="LUF05")
	   if(!is.null(outFile) && file.exists(outFile)){
		# Generate file name and copy
		rnd <- sample(111111:999999, 1)[[1]]
		file <- paste0(dirname(nmd), "/luf05_user_", rnd, ".xml")
		file.copy(outFile, file)

		# Create metdata and set flag isValid
		meta <- list("filename"=file, "type"=type, "source"=files)
		isValid <- TRUE
	   }
	}else if(type=="LUF03"){

	   # For LUF03, convert the file (only one)
           file <- files[[1]]

	   # We must extract cruise, platform, and country information
	   extra <- extractNMDinfo(nmd)

           outFile <- doLUFConvert(file, type="LUF03", extra)
           if(!is.null(outFile) && file.exists(outFile)){
                # Generate file name and copy
                rnd <- sample(111111:999999, 1)[[1]]
                file <- paste0(dirname(nmd), "/luf03_user_", rnd, ".xml")
                file.copy(outFile, file)

                # Create metdata and set flag isValid
                meta <- list("filename"=file, "type"=type, "source"=files)
                isValid <- TRUE
           }

	}

	if(isValid == TRUE){
		userFilePath <- paste0(dirname(nmd), "/user.rds")

		# Read the file, make sure to lock it first to prevent race condition
		file.lock <- lock(paste0(userFilePath, ".lock"))
		if(file.exists(userFilePath)){
			userFile <- readRDS(userFilePath)
		}else{
			userFile <- list()
		}

		# Upgrade old user file (vector to list)
		if(!is.list(userFile)){
			userFile[["type"]] <- "LUF20"
			userFile <- list(as.list(userFile))
		}

		# Append meta and save the userfile
		ll <- length(userFile)
		userFile[[ll+1]] <- meta
		saveRDS(userFile, file=userFilePath, ascii = TRUE, compress=FALSE)

		# Unlock file
		unlock(file.lock)
		return(TRUE)
	}else{
		return(FALSE)
	}
}

removeUserFile <- function(path, tag){
	nmd <- path.expand(paste0(getRootDir(), path))
	userFilePath <- paste0(dirname(nmd), "/user.rds")
	isSuccess <- FALSE

	# Process tag
	tags <- unlist(strsplit(tag, "[-]"))
	fileNo <- as.numeric(tags[2])

	# Read the file, make sure to lock it first to prevent race condition
        file.lock <- lock(paste0(userFilePath, ".lock"))
        if(file.exists(userFilePath)){
           userFile <- readRDS(userFilePath)

           # Upgrade old user file (vector to list)
           if(!is.list(userFile))
	      userFile <- list(as.list(userFile))

	   # Process deletion
	   userFile[[fileNo]] <- NULL

	   # Save file
	   saveRDS(userFile, file=userFilePath, ascii = TRUE, compress=FALSE)

	   isSuccess <- TRUE
	}
        # Unlock file
        unlock(file.lock)

        return(isSuccess)
}


getXML <- function(file){
	# TODO: Add robust file checking (dir, name, etc.)
	wd <- getwd()
        zip(paste0(wd,"/" , basename(file), ".zip"), file, flags = "-j6X")
}


getRAW <- function(file, type){
	if(type=="NMD")
		fileName <- paste0(getRootDir(),file)
	else
		fileName <- file

	tmp <- tempfile()
	
        binDir <- paste0(.libPaths(), "/nmdqeval/bin/")	

	system(paste0("java -Xmx512m -jar ", binDir, "saxon9he.jar '", path.expand(fileName),"' -xsl:", binDir, "xmlsort.xsl -o:", tmp))
        #system(paste0("xsltproc ", binDir, "xmlsort2.xsl '", path.expand(fileName),"' > ", tmp))
	readChar(tmp, file.info(tmp)$size)
}

getNodes <- function(root=NULL, compareCounter = NULL){

	processCounter <- function(ctr) {

		processLogical <- function(x) {
			y <- unlist(x)
			return(c(length(y), length(y[y & !is.na(y)]), length(y[!y & !is.na(y)]), length(y[is.na(y)])))
		}

		processText <- function(x) {
			paste0("<span class=\"badge badge-info\">", x[1], "</span> ",
				"<span class=\"badge badge-success\">", x[2], "</span> ",
				"<span class=\"badge badge-danger\">", x[3], "</span> ",
				"<span class=\"badge badge-warning\">", x[4], "</span>")
		}

		lapply(lapply(ctr, processLogical), processText)
	}

	counters <- ""
	ctr <- NULL

	parsedCS <- readRDS(paste0(getRootDir(),"/csNMD.rds"))

	if(!is.null(compareCounter)) {
		if(compareCounter == "biotic")
			ctrList <- paste0(getRootDir(), "/csNMDcompareBiotic.rds")
		else
			ctrList <- paste0(getRootDir(), "/csNMDcompareEchosounder.rds")	

		if(file.exists(ctrList))
			ctr <- readRDS(ctrList)
	}

	if(is.null(root)) {
		if(!is.null(ctr)) {
			counters <- processCounter(ctr)
		}

		return(data.frame(title=paste(names(parsedCS), counters), key=names(parsedCS), folder=TRUE, expanded=FALSE, lazy=TRUE))
	} else {
		objName <- paste0("parsedCS$'",gsub("[$]", "'$'", root),"'")
		obj <- eval(parse(text=objName))

		if(!is.null(ctr)) {
			ctrName <- paste0("ctr$'",gsub("[$]", "'$'", root),"'")
			ctr <- eval(parse(text=ctrName))
			counters <- processCounter(ctr)
		}

		if(is.list(obj))
			return(data.frame(title=paste(names(obj), counters), key=paste0(root,"$",names(obj)), folder=TRUE, expanded=FALSE, lazy=TRUE))
		else
			return(data.frame(title=paste("<i class=\"fas fa-ship\"></i>", obj, "- Click to compare <i class=\"fa fa-arrow-right\" aria-hidden=\"true\"></i>"), key=paste0(root,"$",obj)))
	}
}

nmdFile2CruiseNR <- function(nmdFile){
	return(str_match(nmdFile, "(?:\\_)(\\d{7})")[,2])
}

refreshNMDfile <- function(nmdFile){

	destFileName <- basename(nmdFile)
	fileInfo <- unlist(strsplit(unlist(strsplit(destFileName, "[.]"))[[1]], "[_]"))

	urls <- searchNMDCruise(fileInfo[[3]], fileInfo[[4]], "echosounder")[[1]]
    	
	# TODO: Check for multiple files
	if(!is.na(urls)){
     		for(ff in seq_along(urls)){
			url <- utils::URLencode(urls[ff])
      			tmpfil <- tempfile()
      			fil <- GET(url, write_disk(tmpfil))
      			# Replace the file, make sure to lock it first to prevent race condition
                	file.lock <- lock(paste0(nmdFile, ".lock"))
			file.copy(tmpfil, nmdFile, overwrite=TRUE, copy.date=TRUE)
      			
			# Unlock
			unlock(file.lock)
			unlink(tmpfil)
		}
	}
}


getFileCES <- function(cruiseNR){

	indexFile <- paste0(getRootDir(),"/csCES-L20.csv")

	# Make sure to pick only the first one (latest)
	lines <- grep(paste0("S", cruiseNR), readLines(indexFile), value = TRUE)
	line <- read.csv(text=lines[1], header = FALSE, colClasses = "character", sep=",")
	out <- paste(line[1,2], line[1,3], sep="/")
		
	return(out)
}

getFilePGNAPES <- function(nmdFile){

	pFile <- path.expand(gsub("echosounder", "pgnapes",  paste0(getRootDir(), nmdFile)))
	if(file.exists(pFile))
		return(pFile)
	else
		return(NULL)

}

getFileLUF05 <- function(nmdFile){

        pFile <- path.expand(gsub("echosounder", "bei",  paste0(getRootDir(), nmdFile)))
        if(file.exists(pFile))
                return(pFile)
        else
                return(NULL)
}

getFileListLUF05 <- function(nmdFile){
	cruiseNR <- nmdFile2CruiseNR(nmdFile)
	f <- LUF05FileList(cruiseNR)
	return(paste0(f[,2], "/", f[,3]))
}


getFileLSSS <- function(nmdFile, type="db"){

	if(type=="db")
		header <- "lsssDb"
	else if(type =="raw")
		header <- "lsssRaw"
	else
		return(NULL)

	write(paste0("nmd:",nmdFile), stderr())

	# Remove tail
	nmdFile <- paste(head(unlist(strsplit(nmdFile, "_")), -1), collapse="_")

        pFile <- path.expand(gsub("echosounder", header,  paste0(getRootDir(), nmdFile, ".xml")))
	write(paste0("lsss:",pFile), stderr())

        if(file.exists(pFile))
                return(pFile)
        else
                return(NULL)
}


getFiles <- function(nmdPath){

        cruiseNR <- basename(dirname(nmdPath))
        cruiseShip <- basename(nmdPath) 

        nmdFile <- paste0(dirname(nmdPath), "/echosounder_cruiseNumber_", cruiseNR, "_", cruiseShip, ".xml")

        nmdLoc <- path.expand(paste0(getRootDir(), nmdFile))

       write(paste("nmd:",nmdFile, "loc:", nmdLoc), stderr())

        cruiseDir <- dirname(nmdLoc)

        # Refresh NMD file
        refreshNMDfile(nmdLoc)

        # If there is no NMD echosounder file
        if(!file.exists(nmdLoc))
           nmdLoc <- NULL

	out <- c("NMDechosounder"=nmdLoc,
		 "CES-LUF20"=getFileCES(cruiseNR),
		 "CES-LUF05"=getFileLUF05(nmdFile),
		 "CES-LSSSDB"=getFileLSSS(nmdFile,type="db"),
		 "CES-LSSSRAW"=getFileLSSS(nmdFile,type="raw"),
		 "PGNAPES"=getFilePGNAPES(nmdFile)
		)

	# User files
	userFile <- paste0(cruiseDir, "/user.rds")
	if(file.exists(userFile)){
		userMeta <- readRDS(userFile)
		if(length(userMeta)>0){
		   # Handle old version
		   if(!is.list(userMeta)){
			userMeta["type"] <- "LUF20"
			userMeta <- list(as.list(userMeta))
		   }
		   # Process output
		   for( ii in 1:length(userMeta)){
			uType <- userMeta[[ii]][["type"]]
			uFN <- userMeta[[ii]][["filename"]]
			out <- eval(parse(text=paste0("c(out, \"USER-", ii, "-", uType, "\"=uFN)")))
		   }
		}
	}
	return(jsonlite::toJSON(out, keep_vec_names=TRUE))
}

