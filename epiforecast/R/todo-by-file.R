## author_header begin
## Copyright (C) 2016 Logan C. Brooks
##
## This file is part of epiforecast.  Algorithms included in epiforecast were developed by Logan C. Brooks, David C. Farrow, Sangwon Hyun, Shannon Gallagher, Ryan J. Tibshirani, Roni Rosenfeld, and Rob Tibshirani (Stanford University), members of the Delphi group at Carnegie Mellon University.
##
## Research reported in this publication was supported by the National Institute Of General Medical Sciences of the National Institutes of Health under Award Number U54 GM088491. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health. This material is based upon work supported by the National Science Foundation Graduate Research Fellowship Program under Grant No. DGE-1252522. Any opinions, findings, and conclusions or recommendations expressed in this material are those of the authors and do not necessarily reflect the views of the National Science Foundation. David C. Farrow was a predoctoral trainee supported by NIH T32 training grant T32 EB009403 as part of the HHMI-NIBIB Interfaces Initiative. Ryan J. Tibshirani was supported by NSF grant DMS-1309174.
## author_header end
## license_header begin
## epiforecast is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, version 2 of the License.
##
## epiforecast is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with epiforecast.  If not, see <http://www.gnu.org/licenses/>.
## license_header end

######################
## interface.R #######
######################

## todo length checks --- time.of.forecast not only with dat, but with fit
## todo remove n.out arg --- determine by min fit length

## ## source("../sample/sample_config_flu_1516.R")
## source("loaders.R")
## source("fitters.R")
## source("nidss/nidss_fetch_data.R", chdir=TRUE)

## nidss.datfit = fetchNIDSSDatFit("flu", "nationwide")

## olddatplus = nidss.datfit$olddatplus
## oldfit = nidss.datfit$fit
## include.ss = nidss.datfit$include.ss
## current.s = nidss.datfit$current.s
## first.year = nidss.datfit$first.year
## first.model.week = nidss.datfit$first.model.week

## fit.ss = include.ss[include.ss < current.s]
## exclude.2009.pandemic.season=TRUE
## if (exclude.2009.pandemic.season) {
##     fit.ss <- fit.ss[-2]
##     oldfit <- list(f=oldfit$f[,-2], tau=oldfit$tau[-2])
## }
## train.ss = fit.ss
## test.s = max(train.ss)+1

## newdat = olddatplus.to.newdat(olddatplus)
## newdat.attributes = attributes(newdat)
## newdat <- newdat[match(fit.ss, include.ss)]
## newdat.attributes$names <- names(newdat)
## attributes(newdat) <- newdat.attributes

## qwer = fit.eb.control.list(oldfit.to.newfit(oldfit), get.eb.control.list())
## asdf = eb.createForecasts(newdat, olddatplus$wili[olddatplus$season==test.s], oldfit.to.newfit(oldfit), 0)
## asdf = eb.createForecasts(newdat, olddatplus$wili[olddatplus$season==test.s], oldfit.to.newfit(oldfit), 1L)
## source("plotters.R")
## newfit = smooth.curves.to.newfit(eb.fitSmoothCurves(newdat))
## matplot.newdat(newdat)
## matplot.newfit(newdat, newfit)
## seriesplot.newfit(newdat, smooth.curves.to.newfit(eb.fitSmoothCurves(newdat)))

## xxx instead of n.out, allow NA's in the future trajectories, just fill in all; use !is.na as another ii.match mask?
## todo explicitly make object that represents a distribution of curves, corresponding fitting functions, then the conditioning method?
## todo rename forecast time to something with "ind"?
## todo documentation
## todo imports
## todo examples

######################
## loaders.R #########
######################

## xxx consider fetching by issue instead in fetchEpidataHistoryDF; at least for
## fluview, the set of all issues should be a subset of the set of all epiweeks
## from the current data frame

## todo version of mimicPastEpidataDF that never uses future data, instead
## taking the seasonally-expected change from the last available data point or
## stopping if there is no available data point beforehand (will need to handle finalized versions inputted later with lags outside the =lags= range... override their lag with the max lag in =lag= and update =issue= accordingly?)

## ## todo turn into test
## history.dt = fetchEpidataHistoryDT("fluview", "hhs1", 0:51,
##                            first.week.of.season = 31L,
##                            cache.file.prefix="~/.epiforecast-cache/fluview_hhs1")
## list(mimicPastEpidataDF1, mimicPastEpidataDF2) %>>%
##   lapply(function(mimicPastEpidataDFn) {
##     ## mimicPastEpidataDFn(history.dt, 201540L) %>>%
##     mimicPastEpidataDFn(history.dt, 201040L) %>>%
##       dplyr::arrange(-epiweek) %>>%
##       dplyr::select(epiweek, issue, forecast.epiweek, wili)
##   }) %>>%
##   do.call(what=identical) %>>%
##   {.}

## todo conversion operations for epidata df's to full dats & epidata history df's to dt's
## todo fail gracefully with curl errors in Epidata
## todo check augmentWeeklyDF input
## todo trimPartialPastSeasons setting to trim all incomplete (like min # being # of weeks in season)
## todo check fetching input, add default caching
## todo baseline as attr to trajectory, first.week.of.season and is.part.of.season.of.length function as attr's to full.dat?

#######################
## simclass.R #########
#######################

## todo: sim objects (/ something with a new name) should include at least two
## options: (a) a constant, and (b) a list of ys and weights; this will require
## some refactoring. The br method should map constants to constants unless
## bootstrapping. Constants should not be represented as a single column with
## weight 1, because this cannot be distinguished from a single draw from a
## distribution with importance weight 1.

## todo make sure the weights for all the sim methods can be interpreted as
## effective number of draws

## todo proper metrics for multibin scores (including multi pwk)

## todo special treatment of new.dat whenever turned into a new.dat.sim

## xxx upsample_sim: concat sample to single copy of sim object, versus
## repeating the existing sim object as many times as possible and just filling
## in the remainder with samples

######################################
## retrospective_forecasts.R #########
######################################

## fixme better dataset representation... list of data sources (history df's? ilinet, fluview baselines, metadata?, in.season, ...) and auxiliary information indexed in a uniform way for location and time
## todo interface for multiresolution (seasonal vs. weekly vs. ..., national vs. regions vs. ...) datasets and metadata, targets
## todo instead of faking new.dat when given a new.dat.sim, store and use one in new.dat.sim
## todo effective number of particles impacted by number of seasons used (as well as widths...)
## todo try the weighted bw function instead of the bw.SJnrd0 --- issue: needs
## to be called many times (more than the unweighted version --- the weights
## change) and would be slow (half the time appeared to be spent in bw
## calculations last check).
## todo test some changes on earlier seasons
## todo kernel HMM approach
## todo GP approach
## todo curve decomposition (+ random walk) approach, regression onto #seasons approach

#####################################
## empirical.trajectories.R #########
#####################################

## todo due to different seasons having different baselines,
## empirical.trajectories.sim will not produce the historical distribution for
## onsets (but will for the other flusight targets); optional scaling based on
## current and historical baselines to give historical onset distribution, to
## adjust percentages for differences in network composition from season to
## season (but changing the output from the historical distributions) (perhaps
## this scaling could happen during a pre-processing step for full.dat)

#######################
## cv_apply.R #########
#######################

## todo better cv_apply interface
## todo object-oriented iterator design
## todo other iterator structures: not one iterator per input dim, but one output dim per iterator (+ the result dimensionality dims)
## todo non-CV versions
## todo similar functions on cartesian products
## xxx option for warm starts?
## xxx option for parallelism?
## xxx decide on dropping behavior (especially in some cases, LHS will always have 1 index in a given dimension)
## todo fix issues with dimension combining and naming behavior when there are single outputs; when to run simplify2array vs. not...

## todo better operations on scalar/vector/matrix/arrays: scalars
## distinguishable from length-1 vectors, drop=FALSE whenever it is an option,
## uniform interface for length/dim & names/dimnames, dplyr operations if
## possible. Look into tbl_cube.

####################
## twkde.R #########
####################

## todo select twkde params
## todo fully parameterized bandwidth matrix, especially
## todo try ks package's kcde, reichlab/kcde
## xxx a single variable to balance between x and diff(x): a convex combination of the two

#######################
## ensemble.R #########
#######################

## todo calculate degen EM results in log space, in Rcpp
## todo ridge penalty on point prediction coef's
## xxx should use =rq= for constrainedLADPtPredFit with the R= r= args if
## possible; it's probably faster
## todo weighted versions of ensemble weight fitting algorithms
