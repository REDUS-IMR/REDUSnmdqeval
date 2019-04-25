browseHere <- function(path = ""){

	rootBrowse <- getBrowseDir()

	getExt <- function(file){
		ext <- file_ext(file)
		if(ext=="")
			return(NA)
		else
			return(paste0(".",ext))
	}

	# Prevent directory traversal attack
	path <- gsub("[.][.]/", "", path)

	if (path != "")
		pathUse <- paste0(rootBrowse, "/", path)
	else
		pathUse <- rootBrowse

	# Get list of dirs	
	dirs  <- list.dirs(pathUse, full.names=TRUE, recursive=FALSE)

	# Get list of files (only)
	files <- setdiff(list.files(pathUse, full.names=TRUE, include.dirs = FALSE, no..=TRUE), dirs)

	if(length(files)==0 && length(dirs)==0)
		return(NULL)

	if(length(files) > 0)
		fileList <- data.frame(Path=files, Name=basename(files), IsDirectory=FALSE, Ext=getExt(files))
	else
		fileList <- NULL
	
	if(length(dirs) > 0){
		dirList  <- data.frame(Path=paste0(path, "/", basename(dirs)), Name=basename(dirs), IsDirectory=TRUE, Ext=NA)
		listName <- rbind(fileList, dirList)
		listNameSorted <- listName[order(listName$Name),]
		return(listNameSorted)
	}else{
		return(fileList)
	}
}
