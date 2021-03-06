#-----------------------------------------------------------------------------------------
#  demoSets()		return filenames
#  buildDemoSets()		create the .rda of "biom" objects included as package data
#
#  set-1.tsv		7 metagenomes (in three groups)
#  set-2.tsv		24 metagenomes (in two groups)
#  set-3.tsv		32 metagenomes (in three groups)
#  set-4.tsv		16 metagenomes (in three groups)
#  set-5.tsv		1606 metagenomes (HMP)
#  set-6.tsv		4 projects of various sizes
#  set-7.tsv		10 metagenomes and 3 projects
#-----------------------------------------------------------------------------------------

demoSets <- function (n=TRUE) {
	paste (file.path (path.package ("matR"), "extdata", "set-"), 1:7, ".tsv", sep="") [n]
	}

buildDemoSets <- function (file="sample-sets.rda") {
	ee <- new.env()
	ff <- demoSets()

	li <- lapply (mget (paste0 ("li", 1:4), inherits=TRUE), biom)
	mapply (assign, paste0 ("yy", 1:length(li)), li, MoreArgs = list(ee))

	li <- list()
	li[[1]] <- biomRequest (file = ff[1], request="function", group_level="level2")
	li[[2]] <- biomRequest (file = ff[2], request="organism", group_level="phylum")
	li[[3]] <- biomRequest (file = ff[3], request="function", group_level="level1", evalue=1)
	li[[4]] <- biomRequest (file = ff[4], request="organism", group_level="domain", source="Greengenes")
#		li[[5]] <- biomRequest (file = ff[5], request="organism", group_level="domain")
	li[[5]] <- biom(list())
#		li[[6]] <- biomRequest (file = ff[6], "organism")
	li[[6]] <- biom(list())
#		li[[7]] <- biomRequest (file = ff[7], "organism")
	li[[7]] <- biom(list())

#	fix up non-ASCII characters in metadata

	li[[1]]$columns <- rapply (li[[1]]$columns, iconv, "character", how='replace', to='ASCII', sub='?')
	li[[2]]$columns <- rapply (li[[2]]$columns, iconv, "character", how='replace', to='ASCII', sub='?')
	li[[3]]$columns <- rapply (li[[3]]$columns, iconv, "character", how='replace', to='ASCII', sub='?')
	li[[4]]$columns <- rapply (li[[4]]$columns, iconv, "character", how='replace', to='ASCII', sub='?')

	mapply (assign, paste0 ("xx", 1:length(li)), li, MoreArgs = list(ee))


	save (list=ls(ee), file=file, envir=ee)
	message (
		"Created file \"", file, "\" in ", getwd(),
		".\nFor package build move to \"matR/data\"")
	file
	}

#---------------------------------------------------------------------------------
#  readSet()		read ids/metadata from a tsv file		(character or data.frame)
#  scrubSet()		clean up a specification of "ids"		(character)
#  scrapeSet()		return "resources" per specification	(character)
#  expandSet()		expand projects to metagenomes			(character or data.frame)
#---------------------------------------------------------------------------------

readSet <- function (file) {
	df <- read.table(file, header=F, sep="\t", colClasses="character", stringsAsFactors=TRUE)
	if(ncol(df) > 1) {
		colnames(df) <- df[1, , drop=TRUE]
		rownames(df) <- df[, 1, drop=TRUE]
		df[-1, -1, drop=FALSE]
	} else df[, , drop=TRUE]
	}

scrubSet <- function (x, resources = "metagenome") {
	if (is.data.frame (x)) {
		scrubSet (rownames (x), resources)
	} else {
		y <- strsplit (collapse (as.character (x)), "[[:space:]+]") [[1]]
		y <- y [y != ""]
		pfx <- match.arg(
			rep(resources, len=length(y)),
			c("metagenome", "project"),
			several.ok = TRUE)
		paste0(
			ifelse (substr(y,1,3) %in% c("mgm", "mgp"), 
				"",
				c (metagenome="mgm", project="mgp") [pfx]), 
			y)
		}
	}

scrapeSet <- function (x) {
	if (is.data.frame (x)) {
		scrapeSet (rownames (x))
	} else
		c("metagenome", "project") [match (substr(x, 1, 3), c("mgm", "mgp"), nomatch=1)]
	}

expandSet <- function (x) {
	if (is.data.frame (x)) {
		rownames (x) <- scrubSet (rownames (x))
		y <- scrapeSet (rownames (x))
		if (!any (y == "project")) return (x)
		z <- as.list (rownames (x))
		z [y == "project"] <- metadata (rownames (x) [y == "project"])
		j <- rep (1:length(z), sapply(z, length))
		x <- x [j, , drop=FALSE]
 		rownames (x) <- unlist (z)
 		x
	} else {
		x <- scrubSet (x)
		y <- scrapeSet (x)
		if (!any (y == "project")) return (x)
		z <- as.list (x)
		z [y == "project"] <- metadata (x [y == "project"])
		unlist (z)
		}
	}

list2df <- function (li) {
#-----------------------------------------------------------------------------------------
#  support for bringing nested list structures into a data.frame with NAs where needed
#
#  unlist to depth one, while keeping names of top-level list entries
#  the df variables will be the union of all names
#  data.frame has one row per element of the original list; one column per variable
#  don't apply t() in case of a single variable
#  final result:  NA placed wherever a variable is missing from a list entry
#-----------------------------------------------------------------------------------------
	li <- sapply (li, unlist, simplify=FALSE)				
	vars <- sort (unique (unlist (lapply (li, names))))		
	y <- sapply (li, "[", vars)
	if (is.matrix (y)) y <- t(y)
	as.data.frame (y, stringsAsFactors=FALSE)
	}

tagline <- function () {
#-----------------------------------------------------------------------------------------
#  package name.
#  preprocess source with:
#	 sed s/XXXBUILDXXX/$commit/g matR/R/init.R > init.Rtemp
#	 mv init.Rtemp matR/R/init.R
#-----------------------------------------------------------------------------------------
	ss <- " XXXBUILDXXX"
	if (substr (ss, 2, 9) == "XXXBUILD") ss <- ""
	paste0 ("matR: metagenomics analysis tools for R (", packageVersion("matR"), ss, ")")
	}

warning <- function (...) {
#-----------------------------------------------------------------------------------------
#  stylish warnings
#-----------------------------------------------------------------------------------------
	base::warning ("matR: ", ...,  call.=FALSE)
	}

collapse <- function (x, ..., sep = " ") {
#-----------------------------------------------------------------------------------------
#  make length-one string from a character vector
#-----------------------------------------------------------------------------------------
	paste(x, ..., sep = sep, collapse = sep)
	}

#-----------------------------------------------------------------------------------------
#  handle "suggested dependencies".
#  official dependencies are minimized to remove obstacles to installation.
#-----------------------------------------------------------------------------------------

hazPackages <- function() {
	me <- packageDescription ("matR")
	need <- unlist (strsplit (c (me$Imports, me$Suggests), "[^[:alnum:]\\.]+"))
	sapply (need, function (x) length (find.package (x, quiet = TRUE)) > 0)
	}

dependencies <- function (prompt = TRUE) {
	need <- !hazPackages()
	if (any (need)) {
		message("matR uses other software.. blah blah blah.. here is what we\'ll do")
		message("Suggested package(s) missing: ", collapse (names(need) [need]), "\n")
		if (prompt) {
			chooseBioCmirror (graphics = FALSE)
			cat ("\n")
			chooseCRANmirror (graphics = FALSE)
			cat ("\n")
			setRepositories (graphics = FALSE)
			cat ("\n")
			}
		install.packages (names (need) [need])
		haz <- hazPackages()
		if (all (haz)) {
			message("\nAll suggested packages have been installed.\nNow quit and restart R.")
		} else message("\nPackage(s) could not be installed: ", collapse (names(haz) [!haz]))
	} else 
		message ("All suggested packages appear to be installed.")
	}

#---------------------------------------------------------------------------------
# 'step' function to help with demo'ing.
#  read the file as text and echoes each line exactly.
#  each command must fit on a line, and blank lines are simply echoed.
#---------------------------------------------------------------------------------

stepper <- function (file) {
	lines <- readLines (file)
	for (j in 1:length (lines))
		if (lines [j] != "") {
			cat (getOption ("prompt"), lines [j], sep = "")
			readLines (n = 1, warn = FALSE)
# NOTE: probably change eval() to occur in parent environment
			R <- withVisible (eval.parent (parse (text = lines [j])))
			if (R$visible && !is.null (R$value)) print (R$value)
			}
		else cat ("\n")
	}

#---------------------------------------------------------------------------------
# 'step' function to help with demo'ing.
#  parses the whole file first.  commands may span lines.
#  comments are not displayed.  commands are reformatted to standard appearance.
#---------------------------------------------------------------------------------

stepper2 <- function (file) {
	exprs <- parse (file = file)
	for (j in 1:length (exprs)) {
		cat (getOption ("prompt"), as.character (exprs [j]), sep = "")
		readLines (n = 1, warn = FALSE)
		eval (exprs [j])
		}
	}

step.through <- function (s) {
	stepper (file.path (path.package ("matR"), "demo", paste0 (s, ".R")))
	}

#---------------------------------------------------------------------------------
# abbreviates each element of a character vector to fit a given width
#  adds "..." where text is omitted (left, middle, or right)
#---------------------------------------------------------------------------------

abbrev <- function (s, n, where = "right") {
	toolong <- function (s, n) sapply (s, function (x) { nchar (x) > n - 3 }, USE.NAMES = FALSE)
	paste (strtrim (s, width = n - 3), 
		ifelse (toolong (s, n), "...", ""), 
		sep = "")
### ... need abbrev from middle and left ...
	}

#---------------------------------------------------------------------------------
#  utilities for docs
#---------------------------------------------------------------------------------

seeDoc <- function (f) {
	outfile <- tempfile (fileext = ".html")
	browseURL (tools::Rd2HTML (f, outfile))
	}

buildHTMLDocs <- function (docs) {
	for (d in docs) tools::Rd2HTML (d, paste ("./html/", unlist (strsplit (d, ".", fixed = TRUE)) [1], ".html", sep=""), Links = tools::findHTMLlinks ())
	}
