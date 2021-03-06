
# Modified section of Mika Braginky's "mikabr/aoa-prediction" repository on age of acquisition estimation:
# https://github.com/mikabr/aoa-prediction/blob/master/aoa_estimation/aoa_estimation.Rmd

library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(ggplot2)
library(langcog)
library(wordbankr)
library(boot)
library(lazyeval)
library(robustbase)
theme_set(theme_mikabr() +
theme(panel.grid = element_blank(),
strip.background = element_blank()))
font <- "Open Sans"

# Connect to the Wordbank database and pull out the raw data.
data_mode <- "local"

admins <- get_administration_data(mode = data_mode) %>%
select(data_id, age, language, form)

items <- get_item_data(mode = data_mode) %>%
mutate(num_item_id = as.numeric(substr(item_id, 6, nchar(item_id))),
definition = tolower(definition))

languages <- unique((items %>%
  group_by(language) %>%
  filter(!is.na(uni_lemma)) %>%
  summarise(n = n()))$language)

words <- items %>%
filter(type == "word", language %in% languages)

invalid_uni_lemmas <- words %>%
group_by(uni_lemma) %>%
filter(n() > 1,
length(unique(lexical_class)) > 1) %>%
select(language, uni_lemma, lexical_class, definition) %>%
arrange(language, uni_lemma)

get_inst_data <- function(inst_items) {
inst_language <- unique(inst_items$language)
inst_form <- unique(inst_items$form)
inst_admins <- filter(admins, language == inst_language, form == inst_form)
get_instrument_data(instrument_language = inst_language,
instrument_form = inst_form,
items = inst_items$item_id,
administrations = inst_admins,
iteminfo = inst_items,
mode = data_mode) %>%
filter(!is.na(age)) %>%
mutate(produces = !is.na(value) & value == "produces",
understands = !is.na(value) &
(value == "understands" | value == "produces")) %>%
select(-value) %>%
gather(measure, value, produces, understands) %>%
mutate(language = inst_language,
form = inst_form)
}

get_lang_data <- function(lang_items) {
lang_items %>%
split(.$form) %>%
map_df(get_inst_data) %>%
# production for WS & WG, comprehension for WG only
filter(measure == "produces" | form %in% c("WG","IC"))
}

raw_data <- words %>%
split(.$language) %>%
map(get_lang_data)





# Fit models to predict the proportion of children of each age who are reported to understands/produce each word, and the word's age of acquisition.

fit_inst_measure_uni <- function(inst_measure_uni_data) {

  ages <- min(inst_measure_uni_data$age):max(inst_measure_uni_data$age)

  constants <- inst_measure_uni_data %>%
    ungroup() %>%
    select(language, measure, uni_lemma, lexical_class, words) %>%
    distinct() %>%
    group_by(language, measure, uni_lemma) %>%
    summarise(lexical_classes = lexical_class %>% unique() %>% sort() %>%
                paste(collapse = ", "),
              words = words %>% strsplit(", ") %>% unlist() %>% unique() %>%
                paste(collapse = ", "))

  props <- inst_measure_uni_data %>%
    ungroup() %>%
    select(age, prop,n)

  tryCatch({
    model <- robustbase::glmrob(cbind(num_true, num_false) ~ age,
                                family = "binomial",
                                data = inst_measure_uni_data, y = TRUE)
    fit <- predict(model, newdata = data.frame(age = ages), se.fit = TRUE)
    aoa <- -model$coefficients[["(Intercept)"]] / model$coefficients[["age"]]
    fit_prop <- inv.logit(fit$fit)
    fit_se <- fit$se.fit
  }, error = function(e) {
    aoa <<- fit <<- fit_prop <<- fit_se <<- NA
  })

  data_frame(age = ages, fit_prop = fit_prop, fit_se = fit_se,
             aoa = aoa, language = constants$language,
             measure = constants$measure,
             uni_lemma = constants$uni_lemma,
             lexical_classes = constants$lexical_classes,
             words = constants$words) %>%
    left_join(props, by = "age")
}

fit_inst_measure <- function(inst_measure_data) {
  inst_measure_by_uni <- inst_measure_data %>%
    group_by(language, measure, lexical_class, uni_lemma, age, data_id) %>%
    summarise(uni_value = any(value),
              words = definition %>% sort() %>% paste(collapse = ", ")) %>%
    group_by(language, measure, lexical_class, uni_lemma, words, age) %>%
    summarise(num_true = sum(uni_value, na.rm = TRUE),
              num_false = n() - num_true,
              prop = mean(uni_value, na.rm = TRUE),
              n = n())
  inst_measure_by_uni %>%
    split(.$uni_lemma) %>%
    map_df(fit_inst_measure_uni)
}

fit_inst <- function(inst_data) {
  print(unique(inst_data$language))
  lang_uni_lemmas <- inst_data %>%
    select(uni_lemma, definition) %>%
    distinct() %>%
    filter(!is.na(uni_lemma))
  inst_data_mapped <- inst_data %>%
    select(-uni_lemma) %>%
    left_join(lang_uni_lemmas) %>%
    filter(!is.na(uni_lemma)) %>%
    group_by(definition) %>%
    filter("WG" %in% form | "IC" %in% form)
  inst_data_mapped %>%
    split(.$measure) %>%
    map_df(fit_inst_measure)
}


all_prop_data <- map_df(raw_data, fit_inst)
feather::write_feather(all_prop_data,"all_prop_data.feather")
write_csv(all_prop_data,"all_prop_data.csv", na = "")

