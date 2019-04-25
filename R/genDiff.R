makeDiffR <- function (files){

# Code below are adapted from from 
# https://codereview.stackexchange.com/questions/94253/identify-changes-between-two-data-frames-explain-deltas-for-x-columns

df.changes <- function(df.old, df.new, 
                       KEYS = c("id"),
                       VAL = NULL,
                       retain.columns = NULL) {
  # input checks 
  stopifnot(KEYS %in% names(df.old),
            KEYS %in% names(df.new),
            VAL %in% names(df.old),
            VAL %in% names(df.new),
            retain.columns %in% names(df.new),
            retain.columns %in% names(df.old))

  cat("Add columns")

  # Anticipate empty data.frame, populate with correct type from other table and then zero it
  # TODO: What if both are empty?

  if(nrow(df.new)==0){
        df.new[1,] <- df.old[1,]
        df.new[1,] <- 0
  }

  if(nrow(df.old)==0){
        df.old[1,] <- df.new[1,]
	df.old[1,] <- 0
  }

  # add columns to help us track new/old provenance
  N <- df.new
  O <- df.old
  N$is <- TRUE
  O$is <- TRUE

cat("Merge")
  # merge
  #M <- merge(N, O, by = KEYS, all = TRUE, suffixes = c(".new",".old"))
  M <- dplyr::full_join(N, O, by = KEYS, suffix = c(".new",".old"))
  M$is.new <- !is.na(M$is.new) # replace NA with FALSE
  M$is.old <- !is.na(M$is.old) # replace NA with FALSE

cat("KEYS")
  # this will be our output
  O <- M[KEYS]

cat("Changed")
  # add rows.changed
  O$row.changed <- with(M, ifelse(is.old & is.new, "Modified",
                           ifelse(is.old,          "Deleted",
                                                   "Added")))

cat("Add data from new")
  # add data from new
  original.vars <- setdiff(names(df.new), KEYS)
  for (var in original.vars)
     O[[var]] <- M[[paste0(var, ".new")]]

cat("Modify data")
  # modify data for retain.columns
  for (var in retain.columns)
    O[[var]] <- ifelse(M$is.new, M[[paste0(var, ".new")]],
                                 M[[paste0(var, ".old")]])
  rNA <- function(x){
        #test.na <- is.na(x)
        #x[test.na] <- 0                                       
        #test <- as.numeric(x)
        #test.na <- is.na(test)
        #x[test.na] <- sapply(x[test.na], utf8ToInt)
	return(as.numeric(x))
  }

cat("Comparisons")
  # add comparisons
  for (var in VAL) {
    old.var <- paste0(var, ".old")
    new.var <- paste0(var, ".new")
    del.var <- paste0(var, ".delta")

    #M[[new.var]] <- rNA(M[[new.var]])
    #M[[old.var]] <- rNA(M[[old.var]])
    O[[del.var]] <- ifelse(is.na(M[[new.var]])&&is.na(M[[old.var]]), 0, M[[new.var]] - M[[old.var]])

    O[[old.var]] <- M[[old.var]]
    O[[new.var]] <- M[[new.var]]
  }

cat("Reorder rows")
  # reorder rows
  O[order(O$row.changed), ]
}

setNum <- function(DF){
	DF$cruise <- as.integer(DF$cruise)
	DF$log_start <- as.integer(DF$log_start)
	DF$start_time <- as.integer(as.POSIXct(DF$start_time))

	return(DF)
}

doDiffpair <- function (a, b, dataInfo){
	
	out <- list()
	
	for( i in 1:length(dataInfo)){
		src <- names(dataInfo)[[i]]

		DF1 <- b[[a[1]]]$outputData$FilterAcoustic[[src]]
		DF2 <- b[[a[2]]]$outputData$FilterAcoustic[[src]]

		colnames <- names(DF1)

		colsort <- dataInfo[[src]]

		coldiff <- setdiff(colnames, colsort)
        
		cat("\nDiffing1 ", src, max(nrow(DF1),nrow(DF2)), "\n")

		#DF1<-setNum(DF1)
		#DF2<-setNum(DF2)

		DFDIFF <- df.changes(DF1, DF2, colsort, coldiff)

		# Remove unwanted columns
		DFDIFF <- DFDIFF[ , !(names(DFDIFF) %in% coldiff)]

 		# change column names
                names(DFDIFF) <- gsub(x=names(DFDIFF), pattern="\\.old", replacement=paste0(".",names(b[a[1]])))
                names(DFDIFF) <- gsub(x=names(DFDIFF), pattern="\\.new", replacement=paste0(".",names(b[a[2]])))

		cat("\nDiffing2 ", src, nrow(DFDIFF), "\n")
		out[[src]] <- filter_at(DFDIFF, vars(ends_with("delta")), any_vars(. != 0 | is.na(.)))

	}
	return(out)
}


processBase <- function(file, project){
	getBaseline(project, parlist=list(
                            ReadAcousticXML=list(functionName="ReadAcousticXML",
                                    FileName1=file),
                            FilterAcoustic=list(functionName="FilterAcoustic",
                                                FreqExpr="frequency eq 38000")))  
}

dataInfo<- list("FilterAcoustic_AcousticData_DistanceFrequency.txt"=c("cruise","log_start","start_time","freq"),
             "FilterAcoustic_AcousticData_NASC.txt"=c("cruise","log_start","start_time","ch_type", "acocat", "ch"))

# Project file is now included in the package
# assuming the R package name is "nmdqeval"
pTemp <- system.file("stox", "ESCompare", package="nmdqeval")

#write(print(files), stderr())

# Check if all the files are available
allExist <- unlist(lapply(files, file.exists))

# Filter unavailable files
files <- files[allExist]

# Don't do the comparison if there is only one file
if(length(files) > 1){
	#baselineData <- lapply(files, processBase, pTemp)
	cores <- detectCores()
	if(is.na(cores)) cores <- 2
	write(paste("Diffing using",cores,"cores"), stderr())

	# Do baseline in parallel
	cl <- makeCluster(cores, type="PSOCK", methods=TRUE)
	clusterEvalQ(cl, library(Rstox))
	baselineData <- parLapply(cl, files, processBase, pTemp)

	names(baselineData) <- names(files)

	combList <- combn(baselineData, 2, simplify=FALSE, names)
	#write(combList, stderr())

	#diffOut <- combn(c(1:length(baselineData)), 2, simplify=FALSE, doDiffpair, baselineData, dataInfo)
	diffOut <- parLapply(cl, combList, doDiffpair, baselineData, dataInfo)
	stopCluster(cl)
}else{
	diffOut <- NULL
}
#write(getBaselineParameters(pTemp), stderr())

return(diffOut)

}

diffFilesR <- function (result, files){

#files <- c("NMD"="/data/workspace/quality/Norwegian Sea International ecosystem cruise in May/2015/2015108/echosounder_cruiseNumber_2015108_G O Sars.xml", 
#	   "CES"="/ces/cruise_data/2015/S2015108_PGOSARS_4174/ACOUSTIC_DATA/LSSS/REPORTS/ListUserFile20__L5380.0-815.0.txt", 
#	   "PGN"="/ces/cruise_data/2015/S2015108_PGOSARS_4174/ACOUSTIC_DATA/LSSS/REPORTS/ListUserFile20__L5380.0-815.0.txt"
#)

#result <- makeDiffR("NMD"=NMD, "CES"=CES, ...)

msg <- ""

if(length(result) == 0){
	msg <- "<p><b>NOTE</b>:\nMatrix is not available. Only one file is available for comparison.</p>"
	return(msg)
}

# Check missing files
allExist <- unlist(lapply(files,file.exists), use.names=F)

# Add info about missing files
if(!all(allExist)){
	msg <- as.character(kable(data.frame(Type=names(files),File=unlist(files,use.names=F), Available=allExist),
                                format="html", table.attr="class=\"table table-bordered\""))
	msg <- paste0("<p><b>ERROR</b>, one or more file is not available</p>", msg)
}

# Filter missing files
files <- files[allExist]

fileCount <-length(files)

outMatrix <- matrix(rep("", fileCount*fileCount), nrow=fileCount, ncol=fileCount)
dimnames(outMatrix)<-list(names(files), names(files))

ctr <- 1

for(i in combn(c(1:length(files)),2,simplify=FALSE)) {
	if( nrow(result[[ctr]][[1]]) == 0 && nrow(result[[ctr]][[2]]) == 0)
		outMatrix[i[1],i[2]] <- "eq"
	else
		outMatrix[i[1],i[2]] <- "neq"
	ctr <- ctr + 1
	#write(paste0("ctr:",ctr), stderr())
}

#write(outMatrix, stderr())

# Remove NMD column and the last row
if(length(files)>2)
	outMatrix <- outMatrix[-c(nrow(outMatrix)),-c(1)]


return (paste0(as.character(knitr::kable(outMatrix, "html", table.attr="id=\"diffMatrix\" class=\"table table-bordered\"")),msg))
}

prettyDiffX <- function (f1, f2){

	files <- c(f1, f2)

	binDir <- paste0(.libPaths(), "/nmdqeval/bin/")	
	tmpFiles <- c()
	for(file in files){
		tmp <- tempfile()
		system(paste0("java -Xmx512m -jar ", binDir, "saxon9he.jar '", file,"' -xsl:", binDir, "xmlsort.xsl -o:", tmp))
		tmpFiles <- c(tmpFiles, tmp)
	}

	out <- system2("node", paste0(binDir, "prettydiff/node-local.js source:\"", tmpFiles[1],"\" mode:\"diff\" diff:\"", tmpFiles[2],"\" context:0 lang:\"xml\" diffcli:false"), stdout = TRUE)
	return(out)

}

prettyDiffR <- function (result, files, f1, f2, type="csv", order=1){

	name <- c(f1, f2)

	cName <- combn(names(files), 2)

	#write(ls.str(result), stderr())

	data <- c("DistanceFrequency", "NASC")
	
	out <- list()

	for(nr in 1:ncol(cName)){
		if(!length(setdiff(cName[,nr], name))){
			write(nr, stderr())
			out <- result[[nr]]
			break
		}
	}

	write(type, stderr())

	wd <- getwd()
	fn = paste0("diff_", nmdFile2CruiseNR(files[[1]]), "_", f1, "_", f2, "_", data[[order]], ".csv")

	if(type == "csv"){
        	write.csv(out[[order]], file=paste0(wd,"/",fn), row.names = FALSE)
		return(fn)
	}else{
		tbl <- kable(out[[order]], "html", table.attr="class=\"diffR table table-bordered\"")
		return(tbl)
	}
}

