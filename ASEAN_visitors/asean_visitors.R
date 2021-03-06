## ---------------------------
##
## Purpose of script:
##
## Author: Jason Benedict
##
## Date Created: 2020-09-08
## 
## ---------------------------
##
## Notes:
##   
##
## ---------------------------

options(scipen = 6, digits = 4) # I prefer to view outputs in non-scientific notation

## ---------------------------

## load packages

library(tidyverse)
library(readxl)
library(tidylog)
library(data.table)
library(janitor)
library(lubridate)
library(myutil)
library(sf)
library(extrafont)
library(hablar)
library(ggbump)
library(rnaturalearth)
library(BBmisc)

loadfonts() 

## set working directory -----
set_wd_to_script_path()


# import data ----------------
df <- read_excel("pivot.xlsx",skip = 2,.name_repair = make_clean_names) %>%
  mutate(destination_country = case_when(destination_country == "Viet Nam" ~"Vietnam",
                                         destination_country == "Lao PDR"~ "Laos",
                                         destination_country == "Brunei Darussalam" ~ "Brunei", T ~ destination_country))

# reformat data --------------
sdf <- rnaturalearthdata::countries50 %>% 
  st_as_sf() %>% 
  st_make_valid() %>%
  st_crop(xmin = 90, xmax = 200, ymin = -10, ymax = 30) %>% 
  filter(admin %in% df$destination_country) %>% 
  left_join(df, by = c("admin" = "destination_country")) %>%
  mutate(Y2018 = x2018/1000000)
  

ranking <- st_geometry(sdf) %>% 
  st_point_on_surface() %>% 
  st_coordinates() %>% 
  as_tibble() %>% 
  bind_cols(tibble(visitor_cap = normalize(rank(sdf$x2018), range = c(0,20), method = "range"),
                   country = sdf$admin,
                   xend = 140,
                   x_axis_start = xend + 5,
                   vis_cap_x = normalize(sdf$Y2018, range = c(first(x_axis_start),180), method = "range"),
                   val_txt = paste0(format(sdf$Y2018, digits = 0, nsmall = 1)," mil")))

sdf <- sdf %>% 
  bind_cols(ranking %>% dplyr::select(visitor_cap))


# plotting -------------------
ggplot() + 
  geom_sf(data = sdf, size = .3, fill = "transparent", color = "gray17") +
  # Sigmoid from country to start of barchart
  geom_sigmoid(data = ranking,aes(x = X, y = Y, xend = x_axis_start - .2, yend = visitor_cap, group = country), 
  color = "red",alpha = .4, smooth = 10, size = 0.5) + 
  # Line from xstart to value
  geom_segment(data = ranking,aes(x = x_axis_start, y = visitor_cap, xend = vis_cap_x, yend = visitor_cap,), color = "red",alpha = .6, size = 2, 
  lineend = "round") + 
  # Y axis - black line
  geom_segment(data = ranking,aes(x = x_axis_start, y = -3, xend = x_axis_start-0.85, yend = 22), alpha = .6, size = 1.85, color = "white") +
  # dot on centroid of country in map
  geom_point(data = ranking, aes(x = X, y = Y), color = "red",size = 1) +
  # Country text
  geom_text(data = ranking, aes(x = x_axis_start-.5, y = visitor_cap, label = country), color = "red",hjust = 1, size = 2.5, nudge_y = 1,family = "Poppins") +
  # Value text
  geom_text(data = ranking, aes(x = vis_cap_x, y = visitor_cap, label = val_txt), color= "red",hjust = 0, size = 1.8 , nudge_x = 0.7,family = "Poppins") +
  #coord_sf(clip = "off") +
  scale_fill_viridis_c() +
  scale_color_viridis_c() +
  theme_void() +
  labs(title = "Visitor Arrivals in 2018",
  subtitle = str_wrap("ASEAN Member States (in person)", 100),
  caption = "Source: TidyTuesday & ASEANStatsDataPortal") + 
  theme(plot.margin = margin(.5,1.5,.5,.5, "cm"),
        text = element_text(family = "Poppins"),
        legend.position = "none",
        #plot.background = element_rect(fill = "black"),
        plot.caption = element_text(color = "gray40",size = 6),
        plot.title = element_text(color = "gray40", size = 16, face = "bold"),
        plot.subtitle = element_text(color = "gray40", size = 8))

# save plot -----------------
ggsave("ranking_visitors.png", dpi = 500,w=7, h=4,type="cairo-png")
