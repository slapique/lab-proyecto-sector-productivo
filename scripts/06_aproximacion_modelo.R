
library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

base <- read_csv(here("Datos", "procesados", "base_mensual_urea.csv"),
                 show_col_types = FALSE) %>%
  mutate(periodo = as.Date(periodo)) %>%
  arrange(periodo)

# Estimamos un modelo sin restricciones para ver somo se ajusta

linear_model <- lm(precio_import_usd_mt ~ tc_dias + gas_us_usd_mmbtu + urea_int_usd_mt, data = base)          
summary(linear_model)

# De esto concluimos que:
# * Si aumenta en 1 unidad el tipo de cambio, se espera que el precio de importación de la
# la urea, disminuya 5.31
# * Si aumenta en 1 unidad el precio del gas en dolares de Estados Unidos, se espera que
# el precio de importación de la urea aumente 41.10
# * Si aumenta en 1 unidad el precio internacional de la urea, se espera que el precio 
# de importación de la urea aumente 0.49

# Además, al evualar el R^2, que me indica que tan bien se ajusta el modelo a los datos,
# obtenemos que el modelo explica el 79.1% de la variabilidad de los datos

# Como estamos considerando precios, podemos implementar una escala logaritmica, 
# ya que los valores no pueden ser positivo y trata los cambios de forma porcentual
lm_porcent <- lm(log(precio_import_usd_mt) ~ log(tc_dias) + log(gas_us_usd_mmbtu) + log(urea_int_usd_mt), data = base)          
summary(lm_porcent)

# De esta forma, obtenemos que:
# * Al aumentar 1% el tipo de cambio, se espera que el el precio de importación 
# de la urea disminuya 0.19%
# * Al aumentar 1% el precio del gas en dolares de Estados Unidos, se espera que 
# el el precio de importación de la urea aumente 0.24%
# * Al aumentar 1% el precio internacional de la urea, se espera que 
# el el precio de importación de la urea aumente 0.51%
# El R^2 obtenido es 78.66%, es decir, mayor que el del modelo nivel-nivel.
# Esto indica que este modelo explica mejor la variación del precio de importación 
# de la urea. Como tengo la misma cantidad de variables en ambos modelos, 
# comparo el R^2 y no el R^2 ajustado.
