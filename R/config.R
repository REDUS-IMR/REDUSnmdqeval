# To change the rootDir
changeRootDir <- function (newRoot){
	print(paste("Old root:", getRootDir(), ", new root:", newRoot))

	if(!dir.exists(newRoot))
		dir.create(newRoot)

	options(nmdqeval.rootDir = newRoot)

}

.onLoad <- function(libname, pkgname, ...) {
  op <- options()
  op.nmdqeval <- list(
  	# Work dir root
	nmdqeval.rootDir = paste0(REDUStools::getREDUSRootDir(), "workspace/quality"),
	# Browse root dir
	nmdqeval.rootBrowse = "/delphi/felles/alle"
  )
  toset <- !(names(op.nmdqeval) %in% names(op))
  if(any(toset)) options(op.nmdqeval[toset])

  invisible()
}

getRootDir <- function(){
	getOption("nmdqeval.rootDir")
}

getBrowseDir <- function(){
	getOption("nmdqeval.rootBrowse")
}

