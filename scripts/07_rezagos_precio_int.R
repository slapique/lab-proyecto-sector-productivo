library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

# Ahora vamos a crear los rezagos del precio internacional e ir ajsutando el modelo 
# estimado previamente para ver como se ajusta.

# Para estudiar cuánto demora la transmisión, creamos variables 
# con el precio internacional desplazado uno, dos y tres meses.
df <- df %>%
  mutate(
    precio_int_lag1 = lag(urea_int_usd_mt, 1),
    precio_int_lag2 = lag(urea_int_usd_mt, 2),
    precio_int_lag3 = lag(urea_int_usd_mt, 3)
  )

