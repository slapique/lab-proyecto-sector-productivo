
linear_model <- lm(precio_import_usd_mt ~ tc_dias + gas_us_usd_mmbtu + urea_int_usd_mt, data = base)          
summary(linear_model)

