#!/usr/bin/Rscript

rm(list=ls())
graphics.off()

####################################################################################################
### START OF FUNCTIONS
####################################################################################################


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


scripts.dir=getwd()

## read the clinical measures from a CSV file. Note that it has had an
## ID column with subjects IDs of the form CMIT_?? added to facilitate
## creation of a data frame for with all clinical measures
## clinical.measures=read.csv("../FOSI_widedata_rr_grief_depression_subset.csv", header=TRUE)
## clinical.measures=read.csv("../FOSI_widedata_rr_dirty17.csv", header=TRUE) 
followup.clinical.measures=read.csv("../FOSI_widedata_rr_grief_depression_subset.csv", header=TRUE)
baseline.clinical.measures=read.csv("../FOSI_outcomes_array_rr_base_all.csv",          header=TRUE)

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

parent.directory=dirname(getwd())
group.data.dir=file.path(parent.directory, "Group.data")
if ( ! dir.exists(group.data.dir)) {
    cat("*** Creating group data dir\n")
    dir.create(group.data.dir)
}

## the default number of threads to tell the robust regression script to use
thread.count=10
cat("*** Thread count set to", thread.count, "\n")

debug=FALSE

### These two variables control which set of regressions are to have
### files created
do.baseline.to.followup.change.regressions=FALSE
do.baseline.only.regressions=TRUE

####################################################################################################
### CHANGE FROM BASELINE TO FOLLOW-UP REGRESSIONS
####################################################################################################
if (do.baseline.to.followup.change.regressions ) {
    ## now bind the data frame just created above with all of teh data
    ## from the clinical measures data frame
    ## 
    ## match looks up its first argument in its second argument and
    ## returns the index from the second argument where the first argument
    ## is found (NA if not found)
    subjects.df=cbind(subjects.df,
                      followup.clinical.measures[match(subjects.df$ID, followup.clinical.measures$ID), colnames(followup.clinical.measures)[-c(1:2)]])
    ## print(subjects.df)

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

    subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("stats.", subjects.df$subject, "_REML+tlrc.HEAD", sep=""))
    subjects.df$stats.file.exists=file.exists(subjects.df$stats.file)
    subjects.df=droplevels(subjects.df)
    ## print(subjects.df)
    
    if ( ! isTRUE(all(subjects.df$stats.file.exists)) ) {
        stop("Some of the stats files do not exist. Cannot continue\n")
    }

    ## now keep only group 1
    subjects.df=subset(subjects.df, Group == 1)
    subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
    rownames(subjects.df)=NULL
    
    group.results.dir=normalizePath(file.path("..", "Group.results", "Grief", "regressions"))
    mask.filename=file.path(group.results.dir, "final_mask+tlrc.HEAD")

    for ( glt in c("relativeVsStanger", "relativeGriefVsRelativeNeutral", "relativeGriefVsStrangerGrief") ) {
        ## for ( glt in c("rg", "sg") ) {
        glt.sub.brik.label=paste(substring(glt, 1, 32), "#0_Coef", sep="")
        
        input.files=list()
        
        for ( subject in levels(subjects.df$ID) ) {
            difference.prefix=sprintf("%s.minus.%s.%s", 
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "B" , "subject"],
                                      subjects.df[subjects.df$ID == subject & subjects.df$timepoint == "A" , "subject"],
                                      glt)
            difference.creation.command=
                sprintf("3dcalc -a %s[%s] -b %s[%s] -prefix %s -expr \"b-a\"",
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
        data.table=data.frame("Subj"                 = subjects.df[rids, "ID"],
                              "delta.grief.scaled"   = subjects.df[rids, "mm_delta_scaled"],
                              "delta.grief.b.scaled" = subjects.df[rids, "mm_b_delta_scaled"],                          
                              "delta.hamd.scaled"    = subjects.df[rids, "ham_total_delta_scaled"],
                              "age"                  = subjects.df[rids, "Age.0"],
                              "InputFile"            = unlist(input.files))
        if (debug) {
            cat("*** Before complete cases\n")
            print(data.table)
        }
        ## drop rows with missing data
        data.table=data.table[complete.cases(data.table), ]
            
        if (debug) {
            cat("*** After complete cases\n")
            print(data.table)
            stop()
        }
        
        if ( ! file.exists( mask.filename) ) {
            stop(paste("Mask file", mask.filename, "does not exist. Cannot continue until this is fixed!\n"))
        }

### ANALYSIS 1
        infix=paste(glt, "analysis.one.delta.grief.scaled", sep=".")
        regression.formula="mri ~ delta.grief.scaled"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled"), mask.filename)
        
### ANALYSIS 2
        infix=paste(glt, "analysis.two.delta.grief.scaled.and.grief.delta.hamd", sep=".")
        regression.formula="mri ~ delta.grief.scaled + delta.hamd.scaled"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled", "delta.hamd.scaled"), mask.filename)
        
### ANALYSIS 3
        infix=paste(glt, "analysis.three.delta.grief.scaled.and.age", sep=".")
        regression.formula="mri ~ delta.grief.scaled + age"
        data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
        
        make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c("delta.grief.scaled", "age"), mask.filename)
        
        ## stop()
        
    } ## end of for ( glt in c("relativeVsStanger", "relativeGriefVsRelativeNeutral", "relativeGriefVsStrangerGrief") ) {
} ## end of if (do.baseline.to.followup.change.regressions ) {


####################################################################################################
### BASELINE REGRESSIONS
####################################################################################################
if (do.baseline.only.regressions ) {
    ## now bind the data frame just created above with all of teh data
    ## from the clinical measures data frame
    ## 
    ## match looks up its first argument in its second argument and
    ## returns the index from the second argument where the first argument
    ## is found (NA if not found)
    subjects.df=cbind(subjects.df,
                      baseline.clinical.measures[match(subjects.df$ID, baseline.clinical.measures$ID), colnames(baseline.clinical.measures)[-c(1:2)]])
    ## print(subjects.df)

    ## now for each GLT of interest we need to add a column to the
    ## subjects data frame with the HEAD filename. This will facilitate
    ## the creation of difference files later

    subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("stats.", subjects.df$subject, "_REML+tlrc.HEAD", sep=""))
    subjects.df$stats.file.exists=file.exists(subjects.df$stats.file)
    subjects.df=droplevels(subjects.df)
    ## print(subjects.df)
    
    subjects.df=subjects.df[order(subjects.df$ID, subjects.df$timepoint), ]
    rownames(subjects.df)=NULL
    group.results.dir=normalizePath(file.path("..", "Group.results", "Grief", "baseline.regressions"))
    mask.filename=file.path(group.results.dir, "final_mask+tlrc.HEAD")
    
    ## only interested in baseline timepoint
    subjects.df=subset(subjects.df, timepoint=="A")
    
    for ( glt in c("relativeVsStanger", "relativeGriefVsRelativeNeutral", "relativeGriefVsStrangerGrief") ) {
        ## for ( glt in c("rg", "sg") ) {
        glt.sub.brik.label=paste(substring(glt, 1, 32), "#0_Coef", sep="")

        
        ## row ids
        rids=which(subjects.df$timepoint=="A")
        ## setup the data tbale with all columns needed for the various sub-analyses
        data.table=data.frame("Subj"                 = subjects.df[rids, "ID"],
                              "subject"              = subjects.df[rids, "subject"],
                              "grief"                = subjects.df[rids, "mm"],
                              "grief.a"              = subjects.df[rids, "mm_a"],
                              "grief.b"              = subjects.df[rids, "mm_b"],
                              "grief.c"              = subjects.df[rids, "mm_c"],
                              "iri_pt"               = subjects.df[rids, "iri_pt"],
                              "iri_ec"               = subjects.df[rids, "iri_ec"],                              
                              "hamd"                 = subjects.df[rids, "ham_total"],
                              "age"                  = subjects.df[rids, "Age"],
                              "stats.file"           = subjects.df[rids, "stats.file"],
                              "stats.file.exists"    = subjects.df[rids, "stats.file.exists"])
        data.table=subset(data.table, stats.file.exists==TRUE)

        if (debug) {
            cat("*** Before complete cases\n")
            print(data.table)
        }
        ## drop rows with missing data
        data.table=data.table[complete.cases(data.table$grief), ]

        if (debug) {
            cat("*** After complete cases\n")
            rownames(data.table)=NULL
            print(data.table)
            stop()
        }
        
        input.files=list()
        for ( ii in seq.int(1, dim(data.table)[1]) ) {
            ## subjects.df$stats.file=file.path(parent.directory, subjects.df$subject, "afniGriefPreprocessed.NL", paste("stats.", subjects.df$subject, "_REML+tlrc.HEAD", sep=""))
            bucket.prefix=file.path(parent.directory, as.character(data.table[ii, "subject"]), "afniGriefPreprocessed.NL", paste(data.table[ii, "subject"], ".", glt, sep=""))
            bucket.command=sprintf("3dcalc -a %s\'[%s]\' -expr a -prefix %s ", data.table[ii, "stats.file"], glt.sub.brik.label, bucket.prefix)
            
            if (! file.exists(file.path(paste(bucket.prefix, "+tlrc.HEAD", sep="")))) {
                cat("*** Running: ", "\n")
                cat(bucket.command, "\n")
                system(bucket.command)
            } else {
                cat("*** Bucket file for", as.character(data.table[ii, "subject"]), "already exists. Skipping creation.\n")
            }
            input.files[[ii]] = file.path(paste(bucket.prefix, "+tlrc.HEAD", sep=""))
        }

        data.table$InputFile = unlist(input.files)

        ## CMIT_04 has a baseline Grief (mm.0) score of 27 which may
        ## be driving the regression results in the whole sample. So
        ## this like is added to facilitate its removal so that the
        ## regressions can be run without this subject
        data.table=subset(data.table, ! Subj %in% c("CMIT_04"))
        
        ## stop()
        
        if ( ! isTRUE(all(sapply(data.table$InputFile, function (xx) { file.exists(as.character(xx)) } )) ) ) {
            stop("Some of the InputFiles files do not exist. Cannot continue\n")
        }


        for (variable in c("grief", "grief.a", "grief.b", "grief.c", "iri_pt", "iri_ec")) {
### ANALYSIS 1
            infix=paste(glt, "baseline.analysis.one", variable, sep=".")
            regression.formula=sprintf("mri ~ %s", variable)
            data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
            make.data.table.and.regression.script(infix, regression.formula, data.table.filename, variable, mask.filename)

### ANALYSIS 2
            infix=paste(glt, "baseline.analysis.two", variable, "and.hamd", sep=".")
            regression.formula=sprintf("mri ~ %s + hamd", variable)
            data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
            make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c(variable, "hamd"), mask.filename)
            
### ANALYSIS 3
            infix=paste(glt, "baseline.analysis.three", variable, "and.age", sep=".")
            regression.formula=sprintf("mri ~ %s + age", variable)
            data.table.filename=file.path(group.data.dir, paste("dataTable", infix, "tab", sep="."))
            
            make.data.table.and.regression.script(infix, regression.formula, data.table.filename, c(variable, "age"), mask.filename)    
        }
    }

}
