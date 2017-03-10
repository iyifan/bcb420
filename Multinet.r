# importNet.STRING.R

#' Import network data from a STRING database file.
#'
#' \code{importNet.STRING} imports network edges from a STRING database file,
#' selects the highest confidence edges, maps ENSP IDs to HGNC gene symbols, and
#' returns a weighted, directed igraph graph object of a rete gG type.
#'
#' @section Selecting edges:
#'   STRING scores are p-values * 1000, rounded to
#'   integer. The function can retrieve  the highest scored edges according to
#'   three different cutoff type. Type "xN" (default: 10000) retrieves the xN
#'   highest scored edges. Type xQ (default 0.9) retrieves the edges with scores
#'   larger than the xQ quantile. Type "xS" (default 950) retrieves all edges
#'   with scores larger or equal to xS. If different values are requested, they
#'   are passed in the parameter val. To read all edges, cutoff type should be
#'   (the default) xN, val = Inf.
#' @section Networks:
#'   STRING "protein.links.detailed.v10.txt" files contain
#'   several protein networks: neighborhood, fusion, cooccurence, coexpression,
#'   experimental, database, textmining, and combined_score. However this
#'   function is not restricted to these types, but will read one network for
#'   which the column name is requested in the function's net parameter. This
#'   allows users to define their own column.
#' @section Tax ID:
#'   The taxID parameter is used as a sanity check on the file
#'   contents. Currently only the first data record protein IDs are checked for
#'   being prefixed with the tax ID. During processing all numbers and one
#'   period prefixed to the ENSP ID are removed.
#' @section Console and log:
#'   The taxID parameter is used as a sanity check on the
#'   file contents. Currently only the first data
#' @section The gG object:
#'   The function returns a rete gG object, a weighted,
#'   directed, simple igraph graph in which HGNC gene symbols are vertex names,
#'   and the edge attributes $weight hold the network scores. Graph attributes
#'   hold metadata; use igraph::graph_attr(gG) to return: $version: the gG
#'   object version; $logFile: the filename to which log information was
#'   written; $inFile: the input filename of STRING data; $call: the complete
#'   function call with expanded arguments; and $date: when the gG object was
#'   created.
#'
#' @param fName Filename of a MultiNet Multinet.interactions.network_presence.txt file.
#' @param net The requested network. This must be a string that exists in the
#'   header. The default is "combined_score".
#' @param verbose Controls whether to print summary information after import. 
#' Defaults to TRUE.
#' @return a weighted, directed, simple igraph graph which is a rete gG object.
#'
#' @family ImportNet.STRING, importNet.MultiNet, importNet.MITAB
#'
#'   ## @seealso \code{\link{fastMap}} fastMap() is used internally to map ENSP
#'   IDs to gene symbols.
#'
#'   ## @examples ## \dontrun{ ## importNet.STRING(IN, OUT) ## }
#' @export
#' \MultiNet interactions are BIOGRID, ENCODE data, KEGG, and SignaLink database, 
#' which are good for understanding of the relationship between genomes and diseases
importNet.MultiNet <- function(fName,
                             net = "combined_score",
							 verbose = TRUE) {
                             dropUnmapped = TRUE,
                             silent = FALSE,
                             writeLog = TRUE) {

    # ToDo: can we select the number of vertices ?
    #
    # ToDo: Handle unmapped edges
    # ToDo: Remove duplicate edges and remove loops before subsetting,
    #         since this changes the number of edges above cutoff.
    # ToDo: write tests for that

    #

    # ==== PARAMETERS ==========================================================

    #cutoffTypes <- c("xS", "xQ", "xN")
    #defaultValues <- c(xS = 950, xQ = 0.9, xN = 10000)

    #if (missing(val)) {
       # val <- defaultValues[cutoffType]
    #}

    # Read header and one contents line
    tmp <- readLines(fName, n = 2)

    # Parse for requested column. STRING data is " "-delimited.
    header <- unlist(strsplit(tmp[1], " "))
    iCol <- which(net == header)  # column that contains the requested net

    data   <- unlist(strsplit(tmp[2], " "))


    # ==== VALIDATIONS =========================================================

    # General parameter checks
    checkReport <- character()
    checkReport <- c(checkReport, .checkArgs(fName, like = character()))
    checkReport <- c(checkReport, .checkArgs(net, like = character()))
    checkReport <- c(checkReport, .checkArgs(verbose, like = logical()))
    checkReport <- c(checkReport, .checkArgs(dropUnmapped, like = logical()))
    checkReport <- c(checkReport, .checkArgs(silent, like = logical()))
    checkReport <- c(checkReport, .checkArgs(writeLog, like = logical()))
    if(length(checkReport) > 0) {
        stop(checkReport)
    }

    #  Validate cutoffType parameter
   # if (!cutoffType %in% cutoffTypes) {
       # stop("Parameter error:\n   Valid cutoff types: \"",
         #    paste(cutoffTypes, collapse = "\" | \""),
          #   "\"\n   Found: \"",
           #  cutoffType,
           #  "\"\n")
    #}

    #  Validate Interactor ID format
    patt <- paste(taxID, ".ENSP", sep = "")
    if (length(grep(patt, data[1:2])) != 2) {
        stop("ID error:\n   Expected format ",
             sprintf("<%s....>", patt),
             "\n   Found: <",
             paste(data[1:2], collapse = "> and <"),
             ">\n")
    }

    #  Validate that requested network exists in data
    if (length(iCol) != 1) {
        stop("Request error:\n   Requested network type is ",
             sprintf("\"%s\"", net),
             "\n   Found network type(s): <",
             paste(header[3:length(header)], collapse = ", "),
             ">\n")
    }

    # ==== READ DATA ===========================================================

    # Create column mask for readr::read_delim()

    readMask <- paste("cc",
                      paste(rep("_", length(header) - 2), collapse = ""),
                      sep = "")
    substr(readMask, iCol, iCol) <- "i"   # set target column to integer

    # Read file into data frame, use only selected column
    netDF <- readr::read_delim(file = fName,
                               delim = " ",
                               col_types = readMask,
                               n_max = Inf)

    colnames(netDF) <- c("a", "b", "weight")

    # Remove taxID prefix
    netDF$a <- gsub("^[0-9]*\\.{0,1}", "", netDF$a)
    netDF$b <- gsub("^[0-9]*\\.{0,1}", "", netDF$b)

    # map ID to gene names
#ToDo: fix the fastMap calls
#    netDF$a <- fastMap(netDF$a, type = "ENSP")
#    netDF$b <- fastMap(netDF$b, type = "ENSP")

    # Remove values below cutoff
    #if (cutoffType == "xS") {
        # select all rows with weight >= val
        #sel <- netDF$weight >= val
    #} else if (cutoffType == "xQ") {
        # select all rows with weight >= the val-quantile
       # x <- stats::quantile(netDF$weight, probs = val)
        #sel <- netDF$weight >= x
   # } else if (cutoffType == "xN") {
        # select the val highest scores, or all, whichever is fewer
       # x <- order(netDF$weight, decreasing = TRUE)
       # sel <- x[1:min(val, length(x))]
    #}

    netDF <- netDF[sel, ]


    # Compile argument string
    fCall    <- "importNet.STRING("
    fCall[2] <- sprintf("fname = \"%s\", ", fName)
    fCall[3] <- sprintf("net = \"%s\", ", net)
    fCall[4] <- sprintf("cutoffType = \"%s\", ", cutoffType)
    fCall[5] <- sprintf("val = %s, ", as.character(val))
    #fCall[6] <- sprintf("taxID = \"%s\", ", taxID)
    fCall[7] <- sprintf("dropUnmapped = %s, ", as.character(dropUnmapped))
    fCall[8] <- sprintf("silent = %s, ", as.character(silent))
    fCall[9] <- sprintf("writeLog = %s)", as.character(writeLog))
    fCall <- paste(fCall, collapse = "")

    # ==== MAKE GRAPH ==========================================================
    gG <- .df2gG(fName, call = fCall, isDirected = TRUE, simplify = TRUE)

    # ==== WRITE LOG ===========================================================
    if(writeLog) {
        logMessage    <- sprintf("importNet.STRING()\n")
        logMessage[1] <- "    Returned gG object with"
        logMessage[2] <- sprintf("%d vertices and %d edges.\n",
                                 igraph::gorder(gG),
                                 igraph::gsize(gG))
        .appendToLog(paste(logMessage, collapse = ""))
    }

    return(gG)
}


# [END]