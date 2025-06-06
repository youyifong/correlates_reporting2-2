#Sys.setenv(TRIAL = "profiscov"); lloxs = lloqs
#Sys.setenv(TRIAL = "profiscov_all"); lloxs = llods
#Sys.setenv(TRIAL = "janssen_partA_VL");
#Sys.setenv(TRIAL = "janssen_pooled_partA")
#Sys.setenv(TRIAL = "prevent19_stage2")
#Sys.setenv(TRIAL = "vat08_combined");
#Sys.setenv(TRIAL = "nextgen_mock");
#-----------------------------------------------
# obligatory to append to the top of each script
renv::activate(project = here::here(".."))
Sys.setenv(DESCRIPTIVE = 1)
source(here::here("..", "_common.R"))
source(here::here("code", "params.R")) # load parameters
source(here::here("code", "process_violin_pair_functions.R"))
if (!is.null(config$assay_metadata)) {pos.cutoffs = assay_metadata$pos.cutoff; names(pos.cutoffs) <- assays}
if (study_name == "NextGen_Mock") {
  assays = assays[!grepl("nasal|saliva|bindN_IgA", assays)]
  assay_immuno = assay_immuno[!grepl("nasal|saliva|bindN_IgA", assay_immuno)]
  assay_metadata = assay_metadata %>% filter(!grepl("nasal|saliva|bindN_IgA", assay))
} # will remove later
#-----------------------------------------------

if (attr(config,"config")=="vat08_combined") {
  dat_proc$ph2.immuno.bAb = ifelse(dat_proc$plot_deletion_bAb==1, 0, dat_proc$ph2.immuno.bAb)
  dat_proc$ph2.immuno.nAb = ifelse(dat_proc$plot_deletion_nAb==1, 0, dat_proc$ph2.immuno.nAb)
}

Trialstage_val = 2 ###################################### need manually update "Trialstage" and line 89 in report.Rmd for vat08_combined 

# add delta variables
if (attr(config,"config")=="janssen_pooled_partA" & !any(grepl("Delta71", colnames(dat_proc)))){
  dat_proc$Delta71overBbindSpike = dat_proc$Day71bindSpike - dat_proc$BbindSpike
  dat_proc$Delta71overBbindRBD = dat_proc$Day71bindRBD - dat_proc$BbindRBD
  dat_proc$Delta71overBpseudoneutid50 = dat_proc$Day71pseudoneutid50 - dat_proc$Bpseudoneutid50
  dat_proc$Delta71overBADCP = dat_proc$Day71ADCP - dat_proc$BADCP
  dat_proc$Day71pseudoneutid50uncensored=NA; dat_proc$Delta71overBpseudoneutid50uncensored=NA
} else if (attr(config,"config")=="vat08_combined"){
  for (extra_tp in c(78, 134, 202, 292, 387)){
    for (asy in assays){
      if (!paste0("Day", extra_tp, asy) %in% colnames(dat_proc)) {dat_proc[, paste0("Day", extra_tp, asy)] = NA}
      dat_proc[, paste0("Delta", extra_tp, "overB", asy)] = dat_proc[, paste0("Day", extra_tp, asy)] - dat_proc[, paste0("B", asy)]
    }
  }
} else if (attr(config,"config") == "nextgen_mock") {
  for (extra_tp in c(31, 91, 181, 366)){
    for (asy in assays){
      dat_proc[, paste0("Delta", extra_tp, "overB", asy)] = dat_proc[, paste0("Day", extra_tp, asy)] - dat_proc[, paste0("B", asy)]
    }
  }
}

library(here)
library(dplyr)
library(stringr)
if (F){
  # adhoc for AZ, pair plot with bab spike and pseudovirus-nab side by side
  # 1. add azd1222_all with both assays in config.yml, Sys.setenv(TRIAL="azd1222_all")
  # azd1222_all: &azd1222_all
  # <<: *azd1222_base
  # assays: [bindSpike, pseudoneutid50]
  # llox_label: [LLOQ, LOD]
  # assay_labels: [Binding Antibody to Spike, PsV Neutralization 50% Titer]
  # assay_labels_short: [Anti Spike IgG (BAU/ml), Pseudovirus-nAb ID50 (IU50/ml)]
  # 2. create azd1222_all_data_processed_with_riskscore 
  # by combining azd1222_data_processed_with_riskscore.csv and azd1222_bAb_data_processed_with_riskscore.csv and assign to dat_proc
  azd1222_bAb <- read.csv(here("..", "data_clean", "azd1222_bAb_data_processed_with_riskscore.csv"), header = TRUE)
  azd1222 <- read.csv(here("..", "data_clean", "azd1222_data_processed_with_riskscore.csv"), header = TRUE)
  azd1222_bAb$Bpseudoneutid50=NULL
  azd1222_bAb$Day29pseudoneutid50=NULL
  azd1222_bAb$Day57pseudoneutid50=NULL
  azd1222_bAb$wt.subcohort=NULL
  dat_proc <- azd1222_bAb %>%
    left_join(azd1222[,c("Ptid","Bpseudoneutid50","Day29pseudoneutid50","Day57pseudoneutid50",
                         "Delta29overBpseudoneutid50","Delta57overBpseudoneutid50","Delta57over29pseudoneutid50",
                         "ph2.immuno","wt.subcohort","TwophasesampIndD29","TwophasesampIndD57")], by="Ptid")
  # wt.subcohort is from nAb dataset based on email discussion with Youyi on 7/22/2022:
  # Youyi: one based on ID50 weights because we have less ID50 samples than bAb samples
  table(dat_proc$ph2.immuno.x, dat_proc$ph2.immuno.y)
  dat_proc$ph2.immuno = with(dat_proc, ph2.immuno.x==1 & ph2.immuno.y==1, 1, 0) # 628
  dat_proc$TwophasesampIndD29 = with(dat_proc, TwophasesampIndD29.x==1 & TwophasesampIndD29.y==1, 1, 0) # 828
  dat_proc$TwophasesampIndD57 = with(dat_proc, TwophasesampIndD57.x==1 & TwophasesampIndD57.y==1, 1, 0) # 659
  
  dim(subset(dat_proc, EarlyendpointD57==0 & Perprotocol==1 & SubcohortInd==1 & 
               !is.na(Bpseudoneutid50) & !is.na(Day29pseudoneutid50) & 
               !is.na(BbindSpike) & !is.na(Day29bindSpike))) # 773, 
  # if change to EarlyendpointD29==0, save three participants by using EarlyendpointD29 instead of EarlyendpointD57 for Day 29 plots
  dim(subset(dat_proc, EarlyendpointD57==0 & Perprotocol==1 & SubcohortInd==1 & 
               !is.na(Bpseudoneutid50) & !is.na(Day29pseudoneutid50) & !is.na(Day57pseudoneutid50) & 
               !is.na(BbindSpike) & !is.na(Day29bindSpike) & !is.na(Day57bindSpike))) # 628

  # subsetting on vaccine recipients with ID50 value > LOD and with IgG spike > positivity cut-off at Day 57
  dat_proc <- subset(dat_proc, Day57bindSpike > log10(pos.cutoffs["bindSpike"]) & Day57pseudoneutid50 > log10(llods["pseudoneutid50"]))
}

if (F){
  # adhoc for profiscov_lvmn, pair plot with bab and pseudovirus-nab side by side
  # 1. add profiscov_all with both assays in config.yml, Sys.setenv(TRIAL="profiscov_all")
  # profiscov_all: &profiscov_all
  # data_cleaned: /networks/cavd/Objective 4/GH-VAP/ID127-Gast/correlates/adata/profiscov_lvmn_data_processed_with_riskscore.csv
  # <<: *profiscov_base
  # two_marker_timepoints: no
  # timepoints: [43]
  # times: [B, Day43, Delta43overB]
  # time_labels: [Day 1, Day 43, D43 fold-rise over D1]
  # assays: [liveneutmn50, bindSpike, bindSpike_B.1.1.7, bindSpike_B.1.351, bindSpike_P.1, bindRBD, bindRBD_B.1.1.7, bindRBD_B.1.351, bindRBD_P.1, bindN]
  # assay_labels: [Live Virus Micro Neut 50% Titer, Binding Antibody to Spike, Binding Antibody to Spike B.1.1.7, Binding Antibody to Spike B.1.351, Binding Antibody to Spike P.1, Binding Antibody to RBD, Binding Antibody to RBD B.1.1.7, Binding Antibody to RBD B.1.351, Binding Antibody to RBD P.1, Binding Antibody to Nucleocapsid]
  # assay_labels_short: [Live Virus-mnAb ID50 (IU50/ml), Anti Spike IgG (BAU/ml), Anti Spike B.1.1.7 IgG (BAU/ml), Anti Spike B.1.351 IgG (BAU/ml), Anti Spike P.1 IgG (BAU/ml), Anti RBD IgG (BAU/ml), Anti RBD B.1.1.7 IgG (BAU/ml), Anti RBD B.1.351 IgG (BAU/ml), Anti RBD P.1 IgG (BAU/ml), Anti N IgG (BAU/ml)]
  # llox_label: [LOD,LLOQ,LLOQ,LLOQ,LLOQ,LLOQ,LLOQ,LLOQ,LLOQ,LLOQ]
  # 2. create profiscov_all_data_processed_with_riskscore 
  # by combining profiscov_data_processed_with_riskscore.csv and profiscov_lvmn_data_processed_with_riskscore.csv and assign to dat_proc
  profiscov <- read.csv(here("..", "data_clean", "profiscov_data_processed_with_riskscore.csv"), header = TRUE)
  profiscov_lvmn <- read.csv(here("..", "data_clean", "profiscov_lvmn_data_processed_with_riskscore.csv"), header = TRUE)
  profiscov$Bliveneutmn50=NULL
  profiscov$Day43liveneutmn50=NULL
  profiscov$wt.subcohort=NULL
  dat_proc <- profiscov %>%
    left_join(profiscov_lvmn[,c("Ptid","Bliveneutmn50","Day43liveneutmn50","Delta43overBliveneutmn50",
                         "ph2.immuno","wt.subcohort","TwophasesampIndD43")], by="Ptid")
  # wt.subcohort is from nAb dataset based on email discussion with Youyi on 7/22/2022:
  # Youyi: one based on ID50 weights because we have less ID50 samples than bAb samples
  table(dat_proc$ph2.immuno.x, dat_proc$ph2.immuno.y)
  dat_proc$ph2.immuno = with(dat_proc, ph2.immuno.x==1 & ph2.immuno.y==1, 1, 0) # 240
  dat_proc$TwophasesampIndD43 = with(dat_proc, TwophasesampIndD43.x==1 & TwophasesampIndD43.y==1, 1, 0) # 564
  
  dim(subset(dat_proc, EarlyendpointD43==0 & Perprotocol==1 & SubcohortInd==1 & 
               !is.na(Bliveneutmn50) & !is.na(Day43liveneutmn50) & 
               !is.na(BbindSpike) & !is.na(Day43bindSpike))) # 344
  
}

# for unknown reason, there is no pre-set senior and race variables in the PROFISCOV (Butantan, Sinovac) dataset
if (study_name=="PROFISCOV") {
  dat_proc$Senior <- as.numeric(with(dat_proc, Age >= age.cutoff, 1, 0))
  
  dat_proc <- dat_proc %>%
    mutate(
      race = labels.race[1],
      race = case_when(
        Black == 1 ~ labels.race[2],
        Asian == 1 ~ labels.race[3],
        NatAmer == 1 ~ labels.race[4],
        PacIsl == 1 ~ labels.race[5],
        Multiracial == 1 ~ labels.race[6],
        Notreported == 1 | Unknown == 1 ~ labels.race[7],
        TRUE ~ labels.race[1]
      ),
      race = factor(race, levels = labels.race)
    )
}

if(T){ # for ENSEMBLE SA and LA reports only
  # pseudoneutid50la and pseudoneutid50sa don't have baseline variables, so
  # copy Bpseudoneutid50 to Bpseudoneutid50la & calculate delta value if Day29pseudoneutid50la exists and is required for reporting
  # copy Bpseudoneutid50 to Bpseudoneutid50sa & calculate delta value if Day29pseudoneutid50sa exists and is required for reporting
  if ("Day29pseudoneutid50la" %in% colnames(dat_proc) & "pseudoneutid50la" %in% assays) {
    dat_proc$Bpseudoneutid50la = dat_proc$Bpseudoneutid50
    dat_proc$Delta29overBpseudoneutid50la = pmin(log10(uloqs["pseudoneutid50la"]), dat_proc$Day29pseudoneutid50la) - pmin(log10(uloqs["pseudoneutid50la"]), dat_proc$Bpseudoneutid50la)
  }
  if ("Day29pseudoneutid50sa" %in% colnames(dat_proc) & "pseudoneutid50sa" %in% assays) {
    dat_proc$Bpseudoneutid50sa = dat_proc$Bpseudoneutid50
    dat_proc$Delta29overBpseudoneutid50sa = pmin(log10(uloqs["pseudoneutid50sa"]), dat_proc$Day29pseudoneutid50sa) - pmin(log10(uloqs["pseudoneutid50sa"]), dat_proc$Bpseudoneutid50sa)
  }
}

dat <- dat_proc; #dat$ph2.immuno = dat$ph2.D43.original; dat$wt.subcohort = dat$wt.D43.original

print("Data preprocess")

# For immunogenicity characterization, complete ignore any information on cases
# vs. non-cases.  The goal is to characterize immunogenicity in the random
# subcohort, which is a stratified sample of enrolled participants. So,
# immunogenicity analysis is always done in ppts that meet all of the criteria.
if (attr(config,"config")=="prevent19_stage2") {
  dat.twophase.sample <- dat %>%
    filter(ph2.immuno.D35 == 1) #| ph2.immuno.BD1 | ph2.immuno.C1 == 1) # ph2 D35 covers ph2 BD1 and ph2 C1
} else if (attr(config,"config")=="vat08_combined") {
  dat.twophase.sample <- dat %>%
    filter(ph2.immuno.nAb == 1 | ph2.immuno.bAb == 1)
} else {dat.twophase.sample <- dat %>%
  filter(ph2.immuno == 1)
}
twophase_sample_id <- dat.twophase.sample$Ptid

important.columns <- c("Ptid", "Trt", "MinorityInd", "HighRiskInd", "Age", "Sex",
  "Bserostatus", "Senior", "Bstratum", 
  colnames(dat)[grepl("wt.subcohort|wt.immuno", colnames(dat))], 
  # e.g. wt.subcohort, wt.immuno.C1, wt.immuno.D35, wt.immuno.BD1
  #      wt.immuno.nAb, wt.immuno.bAb for vat08_combined
  if(attr(config,"config") %in% c("prevent19_stage2","vat08_combined")) colnames(dat)[grepl("ph2.immuno", colnames(dat))], 
  # e.g. ph2.immuno.D35, ph2.immuno.C1, ph2.immuno.BD1 for prevent19_stage2 
  #      ph2.immuno.bAb, ph2.immuno.nAb for vat08_combined
  if(attr(config,"config") %in% c("vat08_combined")) "Trialstage",
  if(attr(config,"config") %in% c("nextgen_mock")) c("ph2.immuno", "ph2.AB.immuno", "Track", #"wt.immuno", # wt.immuno was added above
                                                     "wt.AB.immuno"), 
  "race","EthnicityHispanic","EthnicityNotreported", 
  "EthnicityUnknown", "WhiteNonHispanic", if (study_name !="COVE" & study_name!="MockCOVE") "HIVinfection", 
  if (study_name !="COVE" & study_name !="MockCOVE" & study_name !="PROFISCOV" & !grepl("NextGen", study_name)) "Country", if(attr(config,"config")=="janssen_partA_VL") "Region")

## arrange the dataset in the long form, expand by assay types
## dat.long.subject_level is the subject level covariates;
## dat.long.assay_value is the long-form time variables that differ by the assay type
dat.long.subject_level <- dat[, important.columns] %>%
  replicate(length(assay_immuno), ., simplify = FALSE) %>%
  bind_rows()

## times_ is defined in param.R

dat.long.assay_value.names <- c(times_, if(attr(config,"config")=="janssen_partA_VL") "Day71", if(attr(config,"config")=="janssen_partA_VL") "Mon6")
dat.long.assay_value <- as.data.frame(matrix(
  nrow = nrow(dat) * length(assay_immuno),
  ncol = length(dat.long.assay_value.names)
))
colnames(dat.long.assay_value) <- dat.long.assay_value.names

for (tt in seq_along(dat.long.assay_value.names)) {
  dat_mock_col_names <- paste(dat.long.assay_value.names[tt], assay_immuno, sep = "")
  dat.long.assay_value[, dat.long.assay_value.names[tt]] <- unlist(lapply(
    dat_mock_col_names,
    function(nn) {
      if (nn %in% colnames(dat)) {
        dat[, nn]
      } else {
        rep(NA, nrow(dat))
      }
    }
  ))
}

dat.long.assay_value$assay <- rep(assay_immuno, each = nrow(dat))

dat.long <- cbind(dat.long.subject_level, dat.long.assay_value)


## change the labels of the factors for plot labels
dat.long$Trt <- factor(dat.long$Trt, levels = c(1, 0), labels = trt.labels[2:1])
dat.long$Bserostatus <- factor(dat.long$Bserostatus,
  levels = c(0, 1),
  labels = bstatus.labels
)
dat.long$assay <- factor(dat.long$assay, levels = assay_immuno, labels = assay_immuno)

dat.long.twophase.sample <- dat.long[dat.long$Ptid %in% twophase_sample_id, ]
dat.twophase.sample <- subset(dat, Ptid %in% twophase_sample_id)


# labels of the demographic strata for the subgroup plotting
dat.long.twophase.sample$trt_bstatus_label <- # e.g. Placebo, Baseline Neg 
  with(
    dat.long.twophase.sample,
    factor(paste0(as.numeric(Trt), as.numeric(Bserostatus)),
      levels = c("11", "12", "21", "22"),
      labels = paste0(rep(trt.labels, each=2), ", ", rep(bstatus.labels))
    )
  )


dat.long.twophase.sample$age_geq_65_label <-
  with(
    dat.long.twophase.sample,
    factor(Senior,
      levels = c(0, 1),
      labels = paste0(c("Age < ", "Age >= "), age.cutoff)
    )
  )

dat.long.twophase.sample$highrisk_label <-
  with(
    dat.long.twophase.sample,
    factor(HighRiskInd,
      levels = c(0, 1),
      labels = c("Not at risk", "At risk")
    )
  )

dat.long.twophase.sample$age_risk_label <-
  with(
    dat.long.twophase.sample,
    factor(paste0(Senior, HighRiskInd),
      levels = c("00", "01", "10", "11"),
      labels = c(
        paste0("Age < ", age.cutoff, " not at risk"),
        paste0("Age < ", age.cutoff, " at risk"),
        paste0("Age >= ", age.cutoff, " not at risk"),
        paste0("Age >= ", age.cutoff, " at risk")
      )
    )
  )

if (study_name!="ENSEMBLE" & study_name!="MockENSEMBLE") {

  dat.long.twophase.sample$sex_label <-
    with(
      dat.long.twophase.sample,
      factor(Sex,
        levels = c(1, 0),
        labels = c("Female", "Male")
      )
    )
  
  dat.long.twophase.sample$age_sex_label <-
    with(
      dat.long.twophase.sample,
      factor(paste0(Senior, Sex),
        levels = c("00", "01", "10", "11"),
        labels = c(
          paste0("Age < ", age.cutoff, " male"),
          paste0("Age < ", age.cutoff, " female"),
          paste0("Age >= ", age.cutoff, " male"),
          paste0("Age >= ", age.cutoff, " female")
        )
      )
    )

} else if (study_name=="ENSEMBLE" | study_name=="MockENSEMBLE") {
  
  dat.long.twophase.sample$sex_label <-
    with(
      dat.long.twophase.sample,
      factor(Sex,
             levels = c(0, 1, 2, 3),
             labels = c("Male", "Female", "Undifferentiated", "Unknown")
      )
    )
  
  dat.long.twophase.sample$age_sex_label <-
    with(
      dat.long.twophase.sample,
      factor(paste0(Senior, Sex),
             levels = c("00", "01", "02", "03", "10", "11", "12", "13"),
             labels = c(
               paste0("Age < ", age.cutoff, " male"),
               paste0("Age < ", age.cutoff, " female"),
               paste0("Age < ", age.cutoff, " undifferentiated"),
               paste0("Age < ", age.cutoff, " unknown"),
               paste0("Age >= ", age.cutoff, " male"),
               paste0("Age >= ", age.cutoff, " female"),
               paste0("Age >= ", age.cutoff, " undifferentiated"),
               paste0("Age >= ", age.cutoff, " unknown")
             )
      )
    )
  
  # Ignore undifferentiated participants
  dat.long.twophase.sample$sex_label[dat.long.twophase.sample$sex_label == "Undifferentiated"] <- NA
  
  dat.long.twophase.sample$age_sex_label[endsWith(as.character(dat.long.twophase.sample$age_sex_label), "undifferentiated")] <- NA
  
  # Remove factor levels that aren't present in the data
  dat.long.twophase.sample$sex_label <- droplevels.factor(dat.long.twophase.sample$sex_label)
  
  dat.long.twophase.sample$age_sex_label <- droplevels.factor(dat.long.twophase.sample$age_sex_label)
  
}

dat.long.twophase.sample$ethnicity_label <-
  with(
    dat.long.twophase.sample,
    ifelse(
      EthnicityHispanic == 1,
      "Hispanic or Latino",
      ifelse(
        EthnicityNotreported == 0 & EthnicityUnknown == 0,
        "Not Hispanic or Latino",
        "Not reported and unknown"
      )
    )
  ) %>% factor(
    levels = c("Hispanic or Latino", "Not Hispanic or Latino", "Not reported and unknown", "Others")
  )



dat.long.twophase.sample$minority_label <-
  with(
    dat.long.twophase.sample,
    factor(MinorityInd,
      levels = c(0, 1),
      labels = c("White Non-Hispanic", "Comm. of Color")
    )
  )

dat.long.twophase.sample$age_minority_label <-
  with(
    dat.long.twophase.sample,
    factor(paste0(Senior, MinorityInd),
      levels = c("01", "00", "11", "10"),
      labels = c(
        paste0("Age < ", age.cutoff, " Comm. of Color"),
        paste0("Age < ", age.cutoff, " White Non-Hispanic"),
        paste0("Age >= ", age.cutoff, " Comm. of Color"),
        paste0("Age >= ", age.cutoff, " White Non-Hispanic")
      )
    )
  )

if(study_name=="ENSEMBLE" | study_name=="MockENSEMBLE") {
  dat.long.twophase.sample$country_label <- factor(sapply(dat.long.twophase.sample$Country, function(x) {
    names(countries.ENSEMBLE)[countries.ENSEMBLE==x]
  }), levels = names(countries.ENSEMBLE))
}

if(study_name!="COVE" & study_name!="MockCOVE") {
  dat.long.twophase.sample$hiv_label <- factor(sapply(dat.long.twophase.sample$HIVinfection, function(x) {
    ifelse(x,
         "HIV Positive",
         "HIV Negative")
}), levels=c("HIV Negative", "HIV Positive"))
}

dat.long.twophase.sample$race <- as.factor(dat.long.twophase.sample$race)
dat.twophase.sample$race <- as.factor(dat.twophase.sample$race)

dat.long.twophase.sample$Ptid <- as.character(dat.long.twophase.sample$Ptid) 
dat.twophase.sample$Ptid <- as.character(dat.twophase.sample$Ptid) 


dat.long.twophase.sample <- filter(dat.long.twophase.sample, assay %in% assay_immuno)


saveRDS(if (attr(config,"config") == "vat08_combined") {dat.long.twophase.sample %>% filter(Trialstage == Trialstage_val)
  } else {dat.long.twophase.sample},
  file = here("data_clean", "long_twophase_data.rds")
)
saveRDS(if (attr(config,"config") == "vat08_combined") {dat.twophase.sample %>% filter(Trialstage == Trialstage_val)
  } else {dat.twophase.sample},
  file = here("data_clean", "twophase_data.rds")
)

###################################################################### 
# prepare datasets for violin plots, required for janssen_partA_VL, janssen_pooled_partA
if (attr(config,"config") %in% c("janssen_partA_VL","janssen_pooled_partA","vat08_combined","nextgen_mock")){
  # longer format by assay and time
  dat.longer.immuno.subset <- dat.twophase.sample %>%
    tidyr::pivot_longer(cols = c(outer(times_, assays, "%.%"))[c(outer(times_, assays, "%.%")) %in% colnames(dat.twophase.sample)], names_to = "time_assay", values_to = "value") %>%
    mutate(time = gsub(paste0(assays, collapse = "|"), "", time_assay),
           assay = gsub(paste0("^", times_, collapse = "|"), "", time_assay))
  
  # define response rates
  resp <- getResponder(dat_proc, post_times = timepoints_, 
                       assays = assays[!grepl("T4|T8|mdw", assays)], pos.cutoffs = pos.cutoffs)
  
  # add ICS response call for NextGen
  if (study_name == "NextGen_Mock") {
    colnames(resp) <- gsub("_resp", "Resp", colnames(resp))
  }
  
  resp_by_time_assay <- resp[, c("Ptid", colnames(resp)[grepl("Resp", colnames(resp))])] %>%
    tidyr::pivot_longer(!Ptid, names_to = "category", values_to = "response")
  
  # add label = LLoQ, uloq values to show in the plot
  dat.longer.immuno.subset$LLoD = with(dat.longer.immuno.subset, log10(lods[as.character(assay)]))
  dat.longer.immuno.subset$pos.cutoffs = with(dat.longer.immuno.subset, log10(pos.cutoffs[as.character(assay)]))
  dat.longer.immuno.subset$LLoQ = with(dat.longer.immuno.subset, log10(lloqs[as.character(assay)]))
  if (attr(config,"config") %in% c("janssen_pooled_partA")){
    dat.longer.immuno.subset$lb = with(dat.longer.immuno.subset, ifelse(grepl("bind", assay), "Pos.Cut", "LoQ"))
    dat.longer.immuno.subset$lbval = with(dat.longer.immuno.subset, ifelse(grepl("bind", assay), pos.cutoffs, LLoQ))
  } else {
    dat.longer.immuno.subset$lb = with(dat.longer.immuno.subset, ifelse(grepl("bind", assay), "LoQ", "LoD"))
    dat.longer.immuno.subset$lbval = with(dat.longer.immuno.subset, ifelse(grepl("bind", assay), LLoQ, LLoD))
  }
  dat.longer.immuno.subset$ULoQ = with(dat.longer.immuno.subset, log10(uloqs[as.character(assay)]))
  dat.longer.immuno.subset$lb2 = "ULoQ"
  dat.longer.immuno.subset$lbval2 =  dat.longer.immuno.subset$ULoQ
  
  # derive variables for the figures
  dat.longer.immuno.subset <- dat.longer.immuno.subset %>%
    mutate(category=paste0(time, assay, "Resp")) %>%
    left_join(resp_by_time_assay, by=c("Ptid", "category"))
  
  dat.longer.immuno.subset <- dat.longer.immuno.subset[,c("Ptid", "time", "assay", "category", "Trt", "Bserostatus", 
                                                          "value", if(attr(config,"config")=="janssen_partA_VL") "wt.subcohort",
                                                          if(attr(config,"config")=="vat08_combined") c("wt.immuno.nAb", "wt.immuno.bAb", "ph2.immuno.nAb", "ph2.immuno.bAb", "Trialstage"), 
                                                          if(attr(config,"config")=="nextgen_mock") c("ph2.AB.immuno", "ph2.immuno", "Track", "wt.AB.immuno", "wt.immuno"),
                                                          "pos.cutoffs","lbval","lbval2", 
                                                          "lb","lb2",if(attr(config,"config")=="janssen_partA_VL") "Region", 
                                                          "response")]
  
  dat.longer.immuno.subset$nnaive <- with(dat.longer.immuno.subset, factor(Bserostatus, levels = c(0, 1), labels = bstatus.labels))
  dat.longer.immuno.subset$Trt <- with(dat.longer.immuno.subset, factor(Trt, levels = c(1, 0), labels = trt.labels[2:1]))
  dat.longer.immuno.subset$Trt_nnaive = with(dat.longer.immuno.subset, 
                                               factor(paste(Trt, nnaive), 
                      levels = paste(rep(trt.labels[2:1]), rep(bstatus.labels, each=2)),
                      labels = paste0(rep(trt.labels[2:1]), "\n", rep(bstatus.labels, each=2))))
  
  # subsets for violin/line plots
  #### figure specific data prep
  # define response rate:
  
  #### for figures 1
  if (attr(config,"config") == "vat08_combined") {
    groupby_vars1 = c("Trt", "Bserostatus", "time", "assay", "Trialstage")
  } else {groupby_vars1 = c("Trt", "Bserostatus", "time", "assay")}
  
  # define response rate
  dat.longer.immuno.subset.plot1 <- get_desc_by_group(dat.longer.immuno.subset %>% filter(!is.na(value)), groupby_vars1)
  saveRDS(if (attr(config,"config") == "vat08_combined") {dat.longer.immuno.subset.plot1 %>% filter(Trialstage == Trialstage_val)
    } else {dat.longer.immuno.subset.plot1}, 
    file = here::here("data_clean", "longer_immuno_data_plot1.rds"))
  
  # save a longer dataset with both stage1 and stage 2 for Sanofi
  if (attr(config,"config") == "vat08_combined") {saveRDS(dat.longer.immuno.subset.plot1,  file = here::here("data_clean", "longer_immuno_data_plot1_stage1_stage2.rds"))}
  
  if(attr(config,"config")=="janssen_partA_VL") {
    groupby_vars1.2=c("Trt", "Bserostatus", "Region", "time", "assay")
    
    # define response rate
    dat.longer.immuno.subset.plot1.2 <- get_desc_by_group(dat.longer.immuno.subset %>% filter(!is.na(value)), groupby_vars1.2)
    saveRDS(dat.longer.immuno.subset.plot1.2, file = here::here("data_clean", "longer_immuno_data_plot1.2.rds"))
  }
  
  if (study_name == "NextGen_Mock") {
    dat.longer.immuno.subset.plot1.3 <- get_desc_by_group(dat.longer.immuno.subset %>% filter(!is.na(value)) %>% mutate(Trt = "Pooled Arm"), groupby_vars1)
    saveRDS(dat.longer.immuno.subset.plot1.3, file = here::here("data_clean", "longer_immuno_data_plot1.3.rds"))
  }
}
