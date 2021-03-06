# to get this to work
# 1. run this:
#    download.file("http://simonsoftware.se/other/xkcd.ttf", dest="~/Desktop/xkcd.ttf", mode="wb")
# 2. double click on font file and hit install
# 3. run:
#    font_import(pattern = "xkcd", prompt=FALSE)

source("../shiny_apps/vocab_norms/predictQR_fixed.R")
library(tidyverse)
library(quantregGrowth)
library(wordbankr)
library(xkcd)
library(stringr)
library(directlabels)

d <- get_administration_data(language = "English", form = "WG")

taus <-  c(0.1, 0.25, 0.5, 0.75, 0.9)
text.size <- 28
cex.size <- 1.6

mod <- gcrq(formula = comprehension ~ ps(age, monotone = 1, lambda = 1000), 
            tau = taus, data = d)

ages <- 8:18
newdata <- data.frame(age = ages)

preds <- predictQR_fixed(mod, newdata = newdata) %>%
  data.frame %>%
  mutate(age = ages) %>%
  gather(percentile, pred, starts_with("X")) %>%
  mutate(percentile = as.character(as.numeric(str_replace(percentile, "X", "")) * 100))


baby_words <- c("dog", "zebra", "rooster")

j <- get_item_data(language = "English", form = "WS") %>% filter(definition %in% baby_words)

item_data <- get_instrument_data(instrument_language = "English", instrument_form = "WS", items = j$item_id, iteminfo = T, administrations = T) %>%
  filter(!is.na(data_id)) %>%
  mutate(numvalue = ifelse(value == "produces",1,0))

group_data <- item_data %>%
  group_by(definition, age) %>%
  summarise(prop = mean(numvalue, na.rm=T))


vocab_xkcd <- ggplot(preds, aes(x = age, y = pred)) + 
  geom_line(aes(col = percentile)) + 
  ylab("VOCAB") + 
  xkcdaxis(xrange = c(7,19), yrange = c(0,400)) + 
  theme_xkcd() + 
  theme(axis.line.x = element_blank(), 
        panel.border = element_blank(),
        text = element_text(size = text.size))

vocab_standard <- ggplot(preds, aes(x = age, y = pred)) + 
  geom_line(aes(col = percentile)) + 
  ylab("Vocab") +
  xlab("Age") +
  xlim(c(7,19)) +
  ylim(c(0,400)) +
  labs(colour = "Percentile") +
  theme(panel.grid.major = element_blank(), 
        axis.ticks = element_line(colour = "black"), 
        panel.background = element_blank(), 
        panel.grid.minor = element_blank(), 
        legend.key = element_blank(), 
        strip.background = element_blank(), 
        text = element_text(size = text.size), 
        axis.line = element_line(color = "black"))

items_standard <- ggplot(group_data, aes(x = age, y = prop, colour = definition, fill = definition, label = definition)) +
  geom_smooth(method = "loess",
              se = FALSE) +
  scale_x_continuous(name = "Age",
                     breaks = seq(min(group_data$age),max(group_data$age),4),
                     limits = c(min(group_data$age), max(group_data$age) + 3)) +
  scale_y_continuous(name = sprintf("%s\n", "Proportion of\nChildren Producing"),
                     limits = c(-0.01, 1),
                     breaks = seq(0, 1, 0.25)) +
  geom_dl(method = list(dl.trans(x = x + 0.3), "last.qp", cex = cex.size,
                        fontfamily = "OpenSans")) +
  theme(panel.grid.major = element_blank(), 
        axis.ticks = element_line(colour = "black"), 
        panel.background = element_blank(), 
        panel.grid.minor = element_blank(), 
        legend.key = element_blank(), 
        strip.background = element_blank(), 
        text = element_text(size = text.size), 
        axis.line = element_line(color = "black"),
        legend.position = "none")

items_xkcd <- ggplot(group_data, aes(x = age, y = prop)) +
  geom_smooth(method = "loess",
              se = FALSE, aes(colour = definition)) +
  ylab("Proportion of\nChildren Producing") +
  geom_dl(method = list(dl.trans(x = x + 0.3), "last.qp", cex = cex.size,
                        fontfamily = "xkcd"), aes(label = definition, colour = definition)) +
  xkcdaxis(xrange = c(min(group_data$age),max(group_data$age) + 3), yrange = c(-0.01, 1)) + 
  theme_xkcd() + 
  theme(axis.line.x = element_blank(), 
        panel.border = element_blank(),
        text = element_text(size = text.size),
        legend.position = "none")

object_list <- ls()

for (i in object_list) {
  temp_obj <- get(i)
  if (is.ggplot(temp_obj)) {
    ggsave(temp_obj, filename = paste0(i,".png"), width = 7, height = 5, units = "in")
  }
}