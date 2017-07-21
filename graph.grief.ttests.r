#!/usr/bin/Rscript

## print a traceback on an error
options(error=traceback)

rm(list=ls())
graphics.off()

library(reshape)
library(ggplot2)
library(plyr)
##########################################################################################################################################################################
### START OF FUNCTIONS ###################################################################################################################################################
##########################################################################################################################################################################

sink.reset <- function(){
    for(i in seq_len(sink.number())){
        sink(NULL)
    }
}

sink.reset()

stderror <- function(x) sd(x)/sqrt(length(x))

## http://wiki.stdout.org/rcookbook/Graphs/Plotting%20means%20and%20error%20bars%20(ggplot2)/
## Summarizes data.
## Gives count, mean, standard deviation, standard error of the mean, and confidence interval (default 95%).
##   data: a data frame.
##   measurevar: the name of a column that contains the variable to be summariezed
##   groupvars: a vector containing names of columns that contain grouping variables
##   na.rm: a boolean that indicates whether to ignore NA's
##   conf.interval: the percent range of the confidence interval (default is 95%)
summarySE <- function(data=NULL, measurevar, groupvars=NULL, na.rm=FALSE,
                      conf.interval=.95, .drop=TRUE) {
    require(plyr)

    ## New version of length which can handle NA's: if na.rm==T, don't count them
    length2 <- function (x, na.rm=FALSE) {
        if (na.rm) sum(!is.na(x))
        else       length(x)
    }

    ## This is does the summary; it's not easy to understand...
    datac <- ddply(data, groupvars, .drop=.drop,
                   .fun= function(xx, col, na.rm) {
                       c( N    = length2(xx[,col], na.rm=na.rm),
                         mean = mean   (xx[,col], na.rm=na.rm),
                         sd   = sd     (xx[,col], na.rm=na.rm)
                         )
                   },
                   measurevar,
                   na.rm
                   )

    ## Rename the "mean" column    
    datac <- rename(datac, c("mean"=measurevar))

    datac$se <- datac$sd / sqrt(datac$N)  ## Calculate standard error of the mean

    ## Confidence interval multiplier for standard error
    ## Calculate t-statistic for confidence interval: 
    ## e.g., if conf.interval is .95, use .975 (above/below), and use df=N-1
    ciMult <- qt(conf.interval/2 + .5, datac$N-1)
    datac$ci <- datac$se * ciMult

    return(datac)
}

read.stats.table <- function (filename) {

    cat("*** Reading" , filename, "\n")
    stats.table=read.table(filename, header=TRUE, comment.char="")
    ## dump the first column as it's only the file name
    stats.table=stats.table[, -1]
    return(stats.table)
}

read.clusters.table <- function (filename){
    cat("*** Reading", file.path(filename), "\n")
    clusters=read.table(file.path(filename))
    colnames(clusters) = clust.header
    return (clusters)
}

read.cluster.locations.table <- function (filename) {
    cat("*** Reading cluster locations from", filename, "\n")
    ## the gsub here chews up multiple consequtive spaces and replaces them with a single space
    cluster.where.am.i=gsub(" +", " ", scan(file=filename, what='character', sep=','))

    return (cluster.where.am.i)
}

read.data.table <- function (filename) {
    cat("*** Reading", filename, "\n")
    data.table=read.table(filename, header=TRUE, comment.char="")

    return(data.table)
}

makePublicationTable <- function(inClusterWhereAmI, inClusters,
                                 inRoistats,
                                 inRoistats.statValue=NULL,
                                 inRoistats.contrastValue=NULL,
                                 inStatColumnName="Default Stat Name",
                                 inContrastColumnName="Default Contrast Name",
                                 in.dof=NULL,
                                 in.effect.type=c("d", "g"),
                                 inCom=TRUE) {
    
    hemisphere=gsub("[^RL]", "", substr(inClusterWhereAmI, 1, 1))
    ##print(hemisphere)
    if ( inCom ) {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "CM RL", "CM AP", "CM IS")], 0))
    } else {
        locations=cbind(gsub("^[RL] ", "", inClusterWhereAmI), hemisphere, round(inClusters[, c("Volume", "MI RL", "MI AP", "MI IS")], 0))
    }
    
    publication.table.header=c("Structure", colnames(locations)[-1])
    
    if (! is.null(inRoistats.statValue) ) {
        ## cat("Adding average t stats\n")
        pubTable=cbind(locations, round(t(inRoistats.statValue), 2))
        publication.table.header=c(publication.table.header, inStatColumnName)
        
        if ( ! is.null(in.dof)) {
            ## print((inRoistats.statValue * 2) / sqrt(in.dof))
            ## print("before")
            ## print(pubTable)
            ## ##stop()
            in.effect.type=match.arg(in.effect.type)
            print(inRoistats)
            ## n.subjects=table(inRoistats$Group)
            ## print(n.subjects)
            effect.size=sapply(inRoistats.statValue, function (xx) { tes(xx, n.subjects[1], n.subjects[2], verbose=FALSE)[[in.effect.type]] } )
            
            pubTable=cbind(pubTable, round(effect.size, 3))
            ## print("after")
            ## print(pubTable)

            publication.table.header=c(publication.table.header,
                                       switch(in.effect.type,
                                              "d"="Cohen's d",
                                              "g"="Hedge's g"))
        }
    }

    ## now add the average of the coefficient, if it is supplied
    if (! is.null(inRoistats.contrastValue) ) {
        ## cat("Adding average coefficient values\n")      
        pubTable=cbind(pubTable, round(t(inRoistats.contrastValue), 2))
        publication.table.header=c(publication.table.header, inContrastColumnName)
        ## print(pubTable)      
    }

    ## cat("Locations: Volume and coordinates\n")
    ## print(locations)

    ## cat ("Columns matching Mean: ", grep("Mean", colnames(inRoistats)), "\n")
    ## cat ("Data from the above columns:\n")
    ## print(inRoistats[, grep("Mean", colnames(inRoistats))])
    ## print(list(inRoistats$Group))
    ## agg=aggregate(inRoistats[, grep("Mean", colnames(inRoistats))], list(inRoistats$Group), mean)

    ##ddply.agg=ddply(inRoistats, .(timepoint, Group), summarise, mean)


    ## now make a summary table with the mean of each timepoint for each
    ## group. There will be one row for each timepoint x group with the
    ## means for the ROIs for each timepoint x group occupying the
    ## remaining columns
    ddply.agg=ddply(inRoistats, .(Stimulus),
                    .fun=colwise(
                        .fun=function (xx) {
                            c(mean=mean(xx))
                        },
                        ## which columns to apply the function to are listed below
                        colnames(inRoistats)[grep("Mean", colnames(inRoistats))]
                    )
                    )

    
    ## cat("ddply.agg:\n")
    ## print(ddply.agg)
    
    ## cat("t(ddply.agg):\n")
    ## print(t(ddply.agg))

    ## now transpose the means so that there are as many rows as
    ## columns. This is done so that it can be cbinded with the ROI
    ## center of mass and volumes later
    ddply.agg.means=t(ddply.agg[grep("Mean", colnames(ddply.agg))])

    ##print(which (! grepl("Mean", colnames(ddply.agg))))
    ##ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))]

    ## now make the column names
    ##
    ## the first branch handles more than two summary variables, e.g.,
    ## Group X timepoint or Group X Gender
    ##
    ## the econd branch handles only single variables as with a main
    ## effect, e.g., Group, or Gender
    if (length(which (! grepl("Mean", colnames(ddply.agg)))) > 1)
        cnames=apply(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))], 1,
                     function(xx) {
                         ## xx[1] is group, xx[2] is timepoint
                         return(sprintf("%s (%s)", xx[1], xx[2]))
                     })
    else {
        cnames=as.character(ddply.agg[, which (! grepl("Mean", colnames(ddply.agg)))])
    }
    
    ## cat("cnames:\n")
    ## print(cnames)
    publication.table.header=c(publication.table.header, cnames)
    
    colnames(ddply.agg.means)=cnames
    ## cat("ddply.agg.means:\n")
    ## print(ddply.agg.means)

    mns=round(ddply.agg.means, 2)

    pubTable=cbind(pubTable, mns)
    colnames(pubTable)=publication.table.header
    rownames(pubTable)=NULL

    ## print(pubTable)
    ## stop()
    
    return(pubTable)
}

savePublicationTable <- function (inPublicationTable, inPublicationTableFilename, append=TRUE) {
    cat("*** Writing publication table to", inPublicationTableFilename, "\n")
    if ( append ) {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=TRUE, row.names=FALSE, sep=",", append=TRUE)
    } else {
        write.table(inPublicationTable, file=inPublicationTableFilename, quote=F, col.names=FALSE, row.names=FALSE, sep=",", append=TRUE)
    }
    cat("\n", file=inPublicationTableFilename, append=TRUE)        
}

generate.graphs <- function (glt) {

    infix=sprintf("%s.%s", reg.label, glt)
    
    publication.table.filename=file.path(group.results.dir, paste("publication.table", infix, "csv", sep="."))
    if (file.exists(publication.table.filename)) {
        file.remove(publication.table.filename)
    }
    cat("*** Writing publication table to", publication.table.filename, "\n")
    
    cat("####################################################################################################\n")
    cat(sprintf("*** Graphing ROIs from the %s GLT\n", glt))
    
    roistats.glt.filename=file.path(group.results.dir, sprintf("roiStats.%s.glt.txt", infix))
    roistats.stimuli.filename=file.path(group.results.dir, sprintf("roiStats.%s.stimuli.txt", infix))                
    roistats.average.z.score.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageZscore.txt", infix))
    roistats.average.contrast.value.filename=file.path(group.results.dir, sprintf("roiStats.%s.averageContrastValue.txt", infix))
    
    if(file.exists(roistats.glt.filename)) {
        
        ## roistats contains the avergae from the contrast in each ROI,
        ## you do not what to graph this
        
        roistats.glt=read.stats.table(roistats.glt.filename)
        roistats.glt$Sub.brick=NULL

        roistats.stimuli=read.stats.table(roistats.stimuli.filename)
        roistats.stimuli$Sub.brick=NULL
        ## print(roistats.stimuli)
        
        roistats.average.z.score=read.stats.table(roistats.average.z.score.filename)
        roistats.average.contrast.value=read.stats.table(roistats.average.contrast.value.filename)
        roistats.average.z.score$Sub.brick=NULL
        roistats.average.contrast.value$Sub.brick=NULL

        cluster.count=length(grep("Mean", colnames(roistats.glt)))
        if (cluster.count > 0 ) {
            cat(sprintf("*** %d ** clusters found in %s\n", cluster.count, roistats.glt.filename))
            
### Most of the following code up the the first long row of # is book-keeping to get the data frame in order
            
            clusters.filename=file.path(group.results.dir, sprintf("clust.%s.txt", infix))
            clusters=read.clusters.table(clusters.filename)
            
            ## this table contains the locations, as text, of the clusters and is the output of a perl script
            cluster.labels.filename=file.path(group.results.dir, sprintf("clusterLocations.%s.csv", infix))
            cluster.labels=read.cluster.locations.table(cluster.labels.filename)
                        
            glt.data.table.filename=file.path(group.data.dir, paste("dataTable", reg.label, glt, "glt.ttest.all.txt", sep="."))
            glt.data.table=read.data.table(glt.data.table.filename)
            cat(sprintf("*** Read GLT data for %s unique subjects\n",  length(unique(glt.data.table$Subj))))
            ## print(glt.data.table)
            
            stimuli.data.table.filename=file.path(group.data.dir, paste("dataTable", reg.label, glt, "stimuli.ttest.all.txt", sep="."))
            stimuli.data.table=read.data.table(stimuli.data.table.filename)
            cat(sprintf("*** Read stimulus data for %s unique subjects\n",  length(unique(stimuli.data.table$Subj))))
            ## print(stimuli.data.table)
            ## print(addmargins(table(stimuli.data.table[, c("Subj", "Stimulus")])))
            
            mgd=cbind(stimuli.data.table, roistats.stimuli) ##, demographics[match(subjectOrder$subject, demographics$ID), c("Group", "Gender")])
            ## convert the stimuli levels to upper case for graphing
            mgd$Stimulus=as.factor(toupper(as.character(mgd$Stimulus)))
            
            ## drop the InputFile column
            mgd$InputFile=NULL
            ## print(head(mgd))
            ## stop()

            rownames(mgd)=NULL

            
            ## print(clusterWhereAmI)
            ## print(clusters)
            ## print(roistats)
            ## print(roistats.average.z.score)
            ## print(roistats.average.contrast.value)                
            ## print(mgd)
            cat("*** Some of the mgd data frame\n")
            print(mgd[sample.int(dim(mgd)[1], 10), ])

            ## stop("Check the mgd data frame\n")

            publicationTable=makePublicationTable(cluster.labels, clusters, mgd,
                                                  roistats.average.z.score,
                                                  roistats.average.contrast.value,
                                                  inStatColumnName="Average Z score",
                                                  inContrastColumnName="Average Contrast Value",
                                                  inCom=TRUE)
            print(publicationTable)
            savePublicationTable(publicationTable, publication.table.filename, TRUE)
            ## stop()
            ## print(publicationTable)
            ## stop("Check the publication data frame\n")
            melted.mgd=melt(mgd,  id.vars=c("Subj", "Stimulus"),
                            measure.vars=paste("Mean_", seq(1, cluster.count), sep=""),
                            variable_name="cluster")
            
            melted.mgd$cluster=factor(melted.mgd$cluster,
                                      levels=c(paste("Mean_", seq(1, cluster.count), sep="")),
                                      labels=paste(sprintf("%02d", seq(1, cluster.count)), cluster.labels))

            cat("*** Some of the melted mgd data frame\n")
            print (melted.mgd[sample.int(dim(melted.mgd)[1], 10), ])
            ## stop("Check the melted mgd data frame\n")
            
            graph.stimuli(melted.mgd, glt)
            ## stop("Do the graphs look ok?\n")
            
        } ## end of if (cluster.count > 0 ) {
    } else {
        cat("No Clusters,\n\n", file=publication.table.filename, append=TRUE)
    } ## end of if(file.exists(roistats.glt.filename)) {
    
} ## end of generate.graphs definition


graph.stimuli <-function(melted.roistats, glt) {

    imageDirectory=file.path(group.results.dir, glt)
    
    if ( ! file.exists(imageDirectory) ) {
        dir.create(imageDirectory)
    }

    for ( level in levels(melted.roistats$cluster) ) {

        ss=subset(melted.roistats, cluster==level)

        imageFilename=file.path(imageDirectory, sprintf("%s.pdf", gsub(" +", ".", level)))
        cat(paste("*** Creating", imageFilename, "\n"))
        
        roistats.summary=summarySE(ss, measurevar="value", groupvars=c("Stimulus", "cluster"))
        print(roistats.summary)
        x.axis="Stimulus"
        y.axis="value"
        ## shape="Group"
        ## color="Group"
        ## line.color="black"            
        xlabel="Stimulus"
        group=1

        plot.breaks=levels(melted.roistats$Group)
        plot.labels=levels(melted.roistats$Group)

        my.dodge=position_dodge(.2)

        ## this works for time point or group
        graph=ggplot(data=roistats.summary, aes_string(x=x.axis, y=y.axis)) +
            geom_point(data=ss) +
            geom_errorbar(aes(ymin=value-se, ymax=value+se), width=0.5, size=1, color="black", position=my.dodge) +
            geom_point(position=my.dodge, color="red") +
            labs(title = gsub("[0-9]+ ", "", level), x=xlabel, y=expression(paste(beta, "Values", sep="  "))) +
            my.theme 
        ## print(graph)
        ## stop()
        ggsave(imageFilename, graph, width=4, height=3.5, units="in")
        ## ggsave(imageFilename, graph, units="in")        
        ## ggsave(imageFilename, graph, units="in")
    } ## end of for ( level in levels(roistats.summary$cluster) )
}


##########################################################################################################################################################################
### END OF FUNCTIONS #####################################################################################################################################################
##########################################################################################################################################################################

if ( Sys.info()["sysname"] == "Darwin" ) {
    root.dir="/Volumes/data"
} else if ( Sys.info()["sysname"] == "Linux" ) {
    root.dir="/data"
} else {
    cat(paste("Sorry can't set data directories for this computer\n"))
}

data.dir=file.path(root.dir, "jain/preApril/")
group.data.dir=file.path(data.dir, "Group.results", "Grief")
group.results.dir=file.path(data.dir, "Group.results/", "Grief")

clust.header = c("Volume", "CM RL", "CM AP", "CM IS", "minRL",
                 "maxRL", "minAP", "maxAP", "minIS", "maxIS", "Mean", "SEM", "Max Int",
                 "MI RL", "MI AP", "MI IS")

my.base.size=14
my.theme=
    theme_bw(base_size =  my.base.size) +
    theme(
        legend.position="none",
        ## legend.position="bottom",        
        ## panel.grid.major = element_blank(),
        ## panel.grid.minor = element_blank(),

        ##remove the panel border
        ## panel.border = element_blank(),

        ## add back the axis lines
        axis.line=element_line(colour = "grey50"),
        
        ##axis.title.x=element_blank(),
        axis.title.x = element_text(size=my.base.size, vjust=0),
        axis.title.y = element_text(size=my.base.size, vjust=0.4, angle =  90),
        plot.title=element_text(size=my.base.size*1.2, vjust=1))

reg.label="Grief.baseline"
glts=c("relativeVsStanger", "griefVsNeutral",
       "relativeGriefVsRelativeNeutral",
       "strangerGriefVsStrangerNeutral",
       "relativeGriefVsStrangerGrief",
       "relativeNeutralVsStrangerNeutral")

for (glt in glts) { 
    generate.graphs(glt)
}
