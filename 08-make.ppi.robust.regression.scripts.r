#!/usr/bin/Rscript

rm(list=ls())
graphics.off()

options(error=traceback)

if (! require (getopt, quietly=TRUE) ) {
    stop("Could not load the required 'getopt' package. Install it and try running this program again\n")
}

####################################################################################################
### START OF FUNCTIONS
####################################################################################################


help <- function () {
    cat("
NAME
	To be written
")
}


## Reads the seed file and does the (crude) equivalent of BAS variable
## substitution
read.seeds.file <- function () {
    cat("*** Reading seed from", opt$seedfile, "\n")
    table=scan(opt$seedfile, what=character(), quiet=TRUE)
    ## table=gsub("$DATA", seeds.data.dir, table, fixed=TRUE)

    return (table)
}

## extracts the seed name from a file path name pointing to a NIfTI
## file containing the seed
get.seed.name <- function(in.seed.path){
    name=basename(in.seed.path)
    if (grepl("\\.nii", name)) {
        return(gsub("\\.nii.*", "", name))
    } else if (grepl("\\+tlrc", name)) {
        return(gsub("\\+tlrc.*", "", name))
    } else {
        return (name)
    }
}

process.command.line.options <- function(args=commandArgs(TRUE)) {

    if (length(args) == 0 || inherits(try(opt <- getopt(command.line.options.specification, opt=args)), "try-error")) {
        cat(getopt(command.line.options.specification, usage=TRUE), file=stderr())
        q(status=1)
    }
    
    return(opt)
}

check.command.line.arguments <- function (opt) {
    ## if help was asked for print a friendly message
    ## and exit with a non-zero error code
    if ( !is.null(opt$help) ) {
        help()
        q(status=1)
    }

    if ( is.null(opt$debug) ) {
        opt$debug=FALSE
    }

    if (opt$debug)
        cat("*** Debug output enabled\n", file=stderr())

    if (is.null(opt$glts)) {
        cat("A space-separated list of 1 or more GLTs is required.\n", file=stderr())
        cat(getopt(command.line.options.specification, usage=TRUE), file=stderr())    
        q(status=1)
    } else {
        opt$glts=unlist(strsplit(opt$glts, " "))
    }

    if (is.null(opt$seedfile)) {
        cat("A filename containing the list of seeds is required.\n", file=stderr())
        cat(getopt(command.line.options.specification, usage=TRUE), file=stderr())    
        q(status=1)
    } 

    if ( ! file.exists(opt$seedfile) ) {
        cat("The provided seed list file (", opt$seedfile, ") does not exist. Cannot continue\n", file=stderr())
        cat(getopt(command.line.options.specification, usage=TRUE), file=stderr())    
        q(status=1)
    }

    return(opt)
}

print.options.summary <- function () {
    cat("*** Script name:", get_Rscript_filename(), "\n", file=stderr())
    if (length(opt$glts) == 1) {
        cat("*** The single GLT to be processed is:", opt$glts, "\n", file=stderr())
    } else {
        cat(sprintf("*** The %02d GLTs to be processed are: %s\n", length(opt$glts), paste(opt$glts, collapse=", ")), file=stderr())
    }
    cat("*** Seed list filename is set to:", opt$seedfile, "\n", file=stderr())
}

make.data.table.and.regression.script <- function (infix, regression.formula, data.table.filename, data.table.columns, mask.filename) {

    if (is.null(data.table.columns)) {
        stop(paste("*** You must provide a vector of columns to select from the data frame to be written for regression analysis.",
                   "*** DO NOT include Subj and InputFile in this list.",
                   "*** They are included automatically.", sep="\n"))
    }
    
    cat("*** Writing data table to", data.table.filename, "\n")
    write.table(data.table[, c("Subj", data.table.columns, "InputFile")], file=data.table.filename, quote=FALSE, col.names=TRUE,  row.names=FALSE)
    
    script.file.name=sprintf("run/run-%s.sh", infix)
    cat("*** Writing regression script to", script.file.name, "\n")
    regression.command=sprintf(
        "#!/bin/bash
set -x
cd %s

./parallel.robust.regression.r -v -p --threads %d --formula \"%s\" --datatable %s --session %s --infix %s --mask %s

",
scripts.dir,
thread.count,
regression.formula,
data.table.filename,
group.results.dir,
infix,
mask.filename)
    
    cat(regression.command, file=script.file.name)
    Sys.chmod(script.file.name, mode="0774")
}

####################################################################################################
### END OF FUNCTIONS
####################################################################################################

NO_ARGUMENT="0"
REQUIRED_ARGUMENT="1"
OPTIONAL_ARGUMENT="2"

## Setup the command line arguments
command.line.options.specification = matrix(c(
    'help',             'h', NO_ARGUMENT,       "logical",
    'debug',            'd', NO_ARGUMENT,       "logical",    
    'glts',          	't', REQUIRED_ARGUMENT, "character",
    'seedfile',         's', REQUIRED_ARGUMENT, "character"
), byrow=TRUE, ncol=4)

opt=process.command.line.options()
opt=check.command.line.arguments(opt)
if (opt$debug)
    print.options.summary()

scripts.dir=getwd()
group.results.dir=normalizePath(file.path("..", "Group.results", "Grief", "ppi.regressions"))

## read the clinical measures from a CSV file. Note that it has had an
## ID column with subjects IDs of the form CMIT_?? added to facilitate
## creation of a data frame for with all clinical measures
clinical.measures=read.csv("../FOSI_widedata_rr_grief_depression_subset.csv", header=TRUE)

## list all of the subjects directories
subject.list=dir("../", pattern="CMIT_[0-9a-zA-Z]{3}$")
subject.list=subject.list[order(subject.list)]

## create a data frame with the columns:
## 1: subject column set to the subject's MRI directory
## 2: ID set to all but the last letter in the subjects's MRI directory
## 3: timepoint set the the final letter in the subject's ID
subjects.df=data.frame("subject"=subject.list, "ID"=substring(subject.list, 1, nchar(subject.list)-1), "timepoint"=substring(subject.list, 8))
subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
## print(subjects.df)

## now bind the data frame just created above with all of teh data
## from the clinical measures data frame
## 
## match looks up its first argument in its second argument and
## returns the index from the second argument where the first argument
## is found (NA if not found)
subjects.df=cbind(subjects.df,
                  clinical.measures[match(subjects.df$ID, clinical.measures$ID), colnames(clinical.measures)[-c(1:2)]])
## print(subjects.df)

## now keep only group 1
subjects.df=subset(subjects.df, Group == 1)
subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
rownames(subjects.df)=NULL
## print(subjects.df)
## stop()
## now we need to calculate some scaled (by baseline score) versions of the delta variables
subjects.df$ham_total_delta_scaled = subjects.df$ham_total_delta_t1t0 / subjects.df$ham_total.0
subjects.df$mm_delta_scaled        = subjects.df$mm_delta_t1t0        / subjects.df$mm.0
subjects.df$mm_a_delta_scaled      = subjects.df$mm_a_delta_t1t0      / subjects.df$mm_a.0
subjects.df$mm_b_delta_scaled      = subjects.df$mm_b_delta_t1t0      / subjects.df$mm_b.0
subjects.df$mm_c_delta_scaled      = subjects.df$mm_c_delta_t1t0      / subjects.df$mm_c.0


## now for each GLT of interest we need to add a column to the
## subjects data frame with the HEAD filename. This will facilitate
## the creation of difference files later

parent.directory=dirname(getwd())

## print(subjects.df)

if ( ! isTRUE(all(subjects.df$stats.file.exists)) ) {
    stop("Some of the stats files do not exist. Cannot continue\n")
}

group.data.dir=file.path(parent.directory, "Group.data")
if ( ! dir.exists(group.data.dir)) {
    cat("*** Creating group data dir\n")
    dir.create(group.data.dir)
}

## the default number of threads to tell the robust regression script to use
thread.count=10
cat("*** Thread count set to", thread.count, "\n")

seeds=read.seeds.file()

for (seed in seeds) {
    seed.name=get.seed.name(seed)

    ## ppi.post.relativeGriefVsRelativeNeutral_seed_01.stats.CMIT_01A+tlrc.HEAD 
    subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("ppi.post.", seed.name, ".stats.", subjects.df$subject, "+tlrc.HEAD", sep=""))
    subjects.df$stats.file.exists=file.exists(subjects.df$stats.file)
    subjects.df=droplevels(subjects.df)

    for ( glt in opt$glts ) {
        ## glt.sub.brik.label=paste(substring(glt, 1, 32), "_GLT#0_Coef", sep="")
        glt.sub.brik.label=paste(glt, "_GLT#0_Coef", sep="")

        cat("####################################################################################################\n")
        cat("*** Generating regression scripts and data tables for the regression of PPI subbriks analysis\n")
        cat(sprintf("*** Seed: %s GLT: %s GLT subbrik label: %s\n", seed.name, glt, glt.sub.brik.label))
        
        input.files=list()
        
        for ( subject in levels(subjects.df$ID) ) {
            difference.prefix=sprintf("%s.minus.%s.%s.%s", 
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "B" , "subject"],
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "A" , "subject"],
                                      seed.name, glt)
            difference.creation.command=
                sprintf("3dcalc -a %s\'[%s]\' -b %s\'[%s]\' -prefix %s -expr \"b-a\"",
                        subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "A" , "stats.file"],
                        glt.sub.brik.label,
                        subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "B" , "stats.file"],
                        glt.sub.brik.label,
                        difference.prefix)
            difference.creation.command = paste("(cd", group.data.dir, ";", difference.creation.command, ")")
            
            input.files[[length(input.files) + 1 ]] = file.path(group.data.dir, paste(difference.prefix, "+tlrc.HEAD", sep=""))
            
            if (! file.exists(file.path(group.data.dir, paste(difference.prefix, "+tlrc.HEAD", sep="")))) {
                cat("*** Running: ", "\n")
                cat(difference.creation.command, "\n")
                system(difference.creation.command)
            } else {
                cat("*** Difference file for", subject, "already exists. Skipping creation.\n")
            }

            ## now we can make the data table for use with the
            ## parallel.robust.regression.r script
        }

        ## row ids
        rids=which(subjects.df$timepoint=="A")
        ## setup the data tbale with all columns needed for the various sub-analyses
        data.table=data.frame("Subj"               = subjects.df[rids, "ID"],
                              "delta.grief.scaled" = subjects.df[rids, "mm_delta_scaled"],
                              "delta.hamd.scaled"  = subjects.df[rids, "ham_total_delta_scaled"],
                              "age"                = subjects.df[rids, "Age.0"],
                              "InputFile"          = unlist(input.files))
        
        ## cat("*** Before complete cases\n")
        ## print(data.table)
        ## drop rows with missing data
        data.table=data.table[complete.cases(data.table), ]
        
        ##     cat("*** After complete cases\n")
        ##     print(data.table)
        mask.filename=file.path(group.results.dir, "final_mask+tlrc.HEAD")
        if ( ! file.exists( mask.filename) ) {
            stop(paste("Mask file", mask.filename, "does not exist. Cannot continue until this is fixed!\n"))
        }
        
### ANALYSIS 1
        infix=paste(seed.name, glt, "analysis.one.delta.grief.scaled", sep=".")
        regression.formula="mri ~ delta.grief.scaled"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled"), mask.filename)
        
### ANALYSIS 2
        infix=paste(seed.name, glt, "analysis.two.delta.grief.scaled.and.grief.delta.hamd", sep=".")
        regression.formula="mri ~ delta.grief.scaled + delta.hamd.scaled"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled", "delta.hamd.scaled"), mask.filename)
        
### ANALYSIS 3
        infix=paste(seed.name, glt, "analysis.three.delta.grief.scaled.and.age", sep=".")
        regression.formula="mri ~ delta.grief.scaled + age"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled", "age"), mask.filename)
        
        ## stop()
    } ## end of for ( glt in opt$glts ) {
} ## end of for (seed in seeds) {
