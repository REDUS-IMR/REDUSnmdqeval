# Script for first run, it will do:
# 1. Look for all LUF20 files from CES
# 2. Look for all LUF05 files from CES
# 3. Generate directory structure for all cruises
# 4. Download NMDechosounder file for every cruises

runUpdate <- function (cDir = "", fast){

	if(cDir!="")
		changeRootDir(cDir)
	else{
		changeRootDir("/data/tmp")
	}

	# Set the current working dir
	setwd(getRootDir())

	if(fast) {
		getPGNAPES = FALSE
	} else {
		getPGNAPES = TRUE
	
		# Get inst bin dir
		fpath <- system.file("bin", package="nmdqeval")
	
		# Run LUF20 search script	
		system(paste0(fpath, "/findAcoustics20.sh > ./csCES-L20.csv"))

		# Run LUF05 search script
		system(paste0(fpath, "/findAcoustics05.sh > ./csCES-L05.csv"))
	}

        # Make the directory structure and download all NMDEchosounder data
        dataFetch(fetchPGNAPES = getPGNAPES)

	# Later, generate LSSSDB and LSSSRAW

}

firstRun <- function (cDir = "") {
	runUpdate(cDir, fast = FALSE)
}

fastUpdate <- function(cDir) {
	runUpdate(cDir, fast = TRUE)
}

slowUpdate <- function(cDir) {
	runUpdate(cDir, fast = FALSE)
}

