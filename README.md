---
output:
  word_document: default
  html_document: default
  pdf_document: default
---
# Pass-through del precio internacional de la urea en Uruguay

**Materia:** Introducción a la Ciencia de Datos — Universidad de Montevideo
**Repositorio:** `lab-proyecto-sector-productivo`
**Última actualización:** octubre 2026

---

## 1. El proyecto

**Sector:** agroindustria — mercado uruguayo de fertilizantes.

**Pregunta:** ¿cuánto del aumento o caída del precio internacional de la urea termina
reflejándose en el precio de importación en Uruguay, y cuánto demora en hacerlo?

**Por qué importa:** Uruguay importa casi toda la urea que consume, así que es tomador de
precios. Lo que pasa en el mercado internacional debería reflejarse en el precio local,
pero ese traslado no tiene por qué ser completo ni inmediato. Medirlo ayuda a anticipar
costos del sector agropecuario.

**Enfoque:** un solo fertilizante (urea, nitrogenado simple) para que la serie sea
homogénea. La variable a explicar se mide en dólares, lo que aísla el pass-through
internacional del ruido cambiario.

### Variables

| Rol | Variable | Unidad | Fuente |
|---|---|---|---|
| **Y** | Precio de importación de la urea (CIF) | USD/ton | Comtrade (2022-23) + Datamyne (2024-26) |
| **X principal** | Precio internacional de la urea | USD/ton | Banco Mundial, Pink Sheet |
| X complementaria | Gas natural Henry Hub (insumo de la urea) | USD/MMBtu | EIA |
| X complementaria | Petróleo Brent (proxy de energía y flete) | USD/barril | Banco Mundial, Pink Sheet |
| X control | Tipo de cambio venta, promedio mensual | UYU por USD | BROU |

**Qué es el precio CIF.** Las dos fuentes de la Y informan el valor de las importaciones
en términos CIF (*Cost, Insurance and Freight*): el valor de la mercadería puesta en el
puerto de llegada, con el flete y el seguro incluidos, pero **antes** de aranceles, IVA,
descarga, logística interna y margen del importador. Es decir, es el precio al que la
urea llega al país, no el que paga el productor. El precio internacional del Pink Sheet,
en cambio, es un precio FOB (*Free on Board*: puesto en el barco en el puerto de origen,
sin flete ni seguro); según la hoja "Description" del archivo, es urea granulada *spot*
f.o.b. Medio Oriente desde marzo de 2022 (antes, Mar Negro). Por eso es esperable que el
CIF uruguayo esté por encima, y así es: en promedio 12% más alto (sección 3.3).

**Ventana:** enero 2022 a agosto 2026, 56 meses. Se arranca en 2022 para dejar afuera la
pandemia; agosto 2026 es el último mes con todas las X disponibles.

---

## 2. Cómo está organizado el trabajo

El avance sigue los 7 pasos de la materia. Cada paso tiene su script en `scripts/`, con
la explicación en comentarios, y las figuras se guardan en `figuras/`.

| Paso | Qué se hizo | Script | Figuras |
|---|---|---|---|
| 1. Generar / cargar | Descarga de las cuatro fuentes | `bitacora_pasos_1_a_3.R` | — |
| 2. Ordenar y limpiar | Perfilado de cada fuente por separado y base mensual unida | `profiling_*.R`, `ProfilingDatos_x_worldbank.R`, `03_preparar_base_mensual.R`, `bitacora_pasos_1_a_3.R` | 01, 02, 03 |
| 3. Explorar | Descriptivas, correlaciones, rezagos en niveles, margen local/internacional | `04_exploracion_base.R` | — |
| 4. Transformar | Variaciones porcentuales (diferencias de logaritmos) y rezagos | `07_variaciones_porcentuales.R` | — |
| 5. Generar información | Modelo preliminar en niveles, robustez, modelo con rezagos, modelo final | `06_aproximacion_modelo.R`, `09_valores_atipicos.R`, `10_rezagos.R`, `11_modelo_final.R` | 06, 11a-11d |
| 6. Visualizar | Gráficos de relaciones entre variables | `05_relacion_entre_variables.R` | 05a-05f |
| 7. Comunicar | Este README, sección 5 | — | — |

La numeración de los scripts refleja el orden en que se fueron escribiendo, no el de los
pasos; la tabla de arriba es la que manda.

**Método de limpieza.** Cada fuente se procesó por separado con el mismo circuito de
*data profiling* (estructura → identidad → completitud → duplicados → tipos → coherencia)
antes de unirla a la base. Perfilar por separado aísla los problemas en su fuente y evita
arrastrarlos a la tabla final. La base unida es `Datos/procesados/base_mensual_urea.csv`:
56 filas (una por mes) × 11 columnas, sin nulos, sin duplicados y sin huecos en la serie.

---

## 3. Registro de avances

### 3.1 Pasos 1 y 2 — datos y limpieza

**Precio de importación (Y).** Dos fuentes que comparten origen (la aduana uruguaya):
Comtrade para 2022-2023 (HS 310210, importaciones, mensual, agregado) y Datamyne para
2024 en adelante (a nivel operación, agregado a total mensual sumando empresas y
orígenes). El precio se calcula como valor CIF en USD ÷ toneladas. Las dos fuentes usan
el mismo criterio de valor (CIF) y la misma unidad de peso, y el empalme 2023→2024 es
continuo, sin saltos.

Hallazgos del perfilado: clave `periodo` única y sin nulos; los únicos NA están en
`n_ops` (cantidad de operaciones), que son estructurales porque Comtrade no la informa;
el precio coincide con valor ÷ toneladas en todas las filas; serie mensual continua.
**Tres meses de bajo volumen** (menos de 1.000 toneladas: ene-2022, mar-2025 y ene-2026)
tienen un precio unitario ruidoso. Se marcaron con `flag_bajo_volumen` y no se borraron:
se decide en el modelado (sección 3.5).

**Pink Sheet (urea internacional y Brent).** Trae 6 filas de encabezado, decenas de
columnas y datos desde 1960, con los faltantes marcados como `…` (si no se tratan como NA,
R lee la columna entera como texto). Se actualizó a la edición de setiembre 2026, con
datos hasta agosto 2026. Sin nulos ni duplicados en la ventana del trabajo; rangos
plausibles (urea 285-925 USD/ton, Brent 63-120 USD/barril).

**Gas natural.** Se usa la serie Henry Hub de la EIA. El Pink Sheet trae también un gas
US (que es la misma serie Henry Hub: correlación 0,9999 con la de la EIA) y un gas
Europa. **Decisión del grupo (oct-2026): el proyecto trabaja con una sola serie de gas,
Henry Hub; el gas Europa queda afuera.** El motivo es que el gas, cualquiera sea, explica
por qué se mueve el precio internacional de la urea, no cómo se transmite a Uruguay; es
una variable de contexto, no la variable central, y dos series de gas muy correlacionadas
entre sí (0,80) serían redundantes en el modelo. Queda anotado como posible extensión:
el gas Europa capta el shock energético de 2022 (llegó a 70 USD/MMBtu contra 8,8 del
americano) y podría servir para explicar el pico de precios de ese año.

**Tipo de cambio.** Cotización diaria del BROU, promediada por mes (compra y venta; se
usa la venta). Serie completa.

**Figuras del paso 2:** `01_urea_importacion_vs_internacional.png` (las dos series de
urea), `02_variables_explicativas.png` (gas, Brent y tipo de cambio) y
`03_toneladas_importadas.png` (volumen mensual, donde se ven los tres meses de bajo
volumen).

### 3.2 Paso 3 — exploración de la base unida

**Descriptivas y volatilidad** (coeficiente de variación = desvío ÷ media):

| Variable | Media | CV (%) | Rango |
|---|---|---|---|
| Toneladas importadas | 27.483 | 73,9 | 48 – 74.945 |
| Gas Henry Hub (USD/MMBtu) | 3,7 | 50,0 | 1,5 – 8,8 |
| Urea internacional (USD/ton) | 470 | 35,9 | 285 – 925 |
| **Precio de importación (USD/ton)** | **512** | **31,3** | **343 – 961** |
| Brent (USD/barril) | 84,2 | 17,0 | 63 – 120 |
| Tipo de cambio (UYU/USD) | 41,5 | 3,8 | 39 – 46 |

El precio local es algo menos volátil que el internacional (CV 31% contra 36%): algo
amortigua las fluctuaciones, probablemente contratos que no se renegocian todos los meses.
El tipo de cambio casi no se mueve en el período.

**Correlaciones** (Pearson, en niveles):

| Relación | r |
|---|---|
| Precio local ↔ precio internacional | **0,81** |
| Precio local ↔ gas Henry Hub | 0,77 |
| Precio local ↔ Brent | 0,70 |
| Precio local ↔ tipo de cambio | 0,15 |

El tipo de cambio casi no se relaciona con el precio local: como todo se negocia en
dólares, medir la Y en USD aísla el pass-through del ruido cambiario.

**Correlación del precio local con el precio internacional rezagado:**

| Rezago (meses) | 0 | 1 | 2 | 3 | 4 | 6 | 8 | 10 | 12 |
|---|---|---|---|---|---|---|---|---|---|
| r | 0,81 | **0,93** | 0,91 | 0,81 | 0,71 | 0,63 | 0,50 | 0,31 | -0,01 |

La correlación máxima está en el rezago 1: el precio local de un mes se parece más al
precio internacional del mes anterior que al del mismo mes. Es la primera señal de que la
transmisión no es instantánea. Esta tabla es **exploratoria**: son correlaciones entre
niveles de precio, y dos series con tendencia parecida se correlacionan alto aunque no
haya efecto directo, por lo que no sirve para decir cuánto se transmite ni cuándo termina
el efecto. Eso lo responde la regresión en variaciones (sección 3.5).

### 3.3 Margen entre precio local e internacional

| Ratio precio local ÷ internacional | Valor |
|---|---|
| Promedio | 1,12 |
| Mínimo | 0,63 |
| Máximo | 1,65 |

En promedio Uruguay paga 12% más que el precio internacional, lo que es coherente con la
diferencia CIF–FOB (flete y seguro) más algún margen. La variabilidad es alta: hay meses
en que el precio local está muy por debajo del internacional (cuando el internacional
sube rápido y lo que llega al puerto se compró a precio viejo) y meses en que está muy
por encima (cuando el internacional cae y llegan compromisos tomados a precio alto). Es la
misma historia de la demora en la transmisión, vista desde el margen.

### 3.4 Paso 6 — gráficos de relaciones entre variables

Script `05_relacion_entre_variables.R`, figuras `05a` a `05f`:

- **05a / 05b — local vs. internacional, mismo mes y con 1 mes de rezago.** Con el rezago
  los puntos se alinean mucho más cerca de la recta (0,81 → 0,93).
- **05c — las dos series en el tiempo.** Los picos del precio local llegan uno o dos meses
  después que los del internacional; se ve claro en 2022 y en 2026.
- **05d — local vs. gas y Brent.** Relaciones positivas pero con más dispersión que con la
  urea internacional: son variables relacionadas de forma indirecta, vía el costo de
  producción.
- **05e — local vs. tipo de cambio.** Nube sin patrón.
- **05f — mapa de calor** con todas las correlaciones.

### 3.5 Pasos 4 y 5 — transformación y modelos

**Por qué variaciones porcentuales.** Se pasa de niveles a diferencias de logaritmos
(`dlog_uy`, `dlog_int`), que aproximan la variación porcentual mensual. Dos motivos: los
coeficientes se leen directamente como elasticidades (cuánto % cambia el precio local
cuando el internacional cambia 1%), y se elimina la tendencia común de las series, que en
niveles infla la relación. Es válido porque los precios nunca son negativos. El primer
mes queda NA porque no tiene mes anterior.

**Test de raíz unitaria** (Dickey-Fuller aumentado, `07_variaciones_porcentuales.R`). En
niveles no se rechaza que las series tengan raíz unitaria; en variaciones sí. Las dos
series son integradas de orden 1, y por eso el modelo tiene que estimarse en variaciones:
en niveles la regresión sería espuria.

| Serie | p-valor en niveles | p-valor en variaciones |
|---|---|---|
| Precio de importación (log) | 0,63 | < 0,01 |
| Urea internacional (log) | 0,37 | < 0,01 |

**Modelo preliminar en niveles** (`06_aproximacion_modelo.R`). Precio de importación
contra urea internacional, gas y tipo de cambio del mismo mes: R² = 0,82; urea 0,57
USD/ton por USD/ton, gas 40 USD/ton por USD/MMBtu, tipo de cambio -18. La versión
log-log da elasticidades de 0,58 (urea), 0,25 (gas) y -1,6 (tipo de cambio). El problema
de estos modelos es que los residuos están fuertemente autocorrelacionados
(`06_acf_residuos_modelo_niveles.png`): el modelo deja afuera la dinámica temporal y sus
p-valores son demasiado optimistas. Por eso el modelo definitivo es el de variaciones.

**Robustez del modelo en niveles con y sin atípicos** (`09_valores_atipicos.R`). Sin los
tres meses de bajo volumen: urea 0,57 → 0,60, gas 40,1 → 40,1, tipo de cambio -18 → -14;
R² 0,815 → 0,836. Los coeficientes que importan no cambian; el tipo de cambio es el único
inestable, otra razón para no apoyarse en él.

**Modelo con rezagos** (`10_rezagos.R`). Cuatro modelos en variaciones, agregando un
rezago por vez, sobre los mismos 52 meses:

| Modelo | Rezagos | Coeficientes (p-valor) | R² |
|---|---|---|---|
| 1 | t | 0,29 (0,011) | 0,12 |
| 2 | t, t-1 | 0,17 (0,09) · 0,38 (0,0004) | 0,32 |
| **3** | **t, t-1, t-2** | **0,24 (0,010) · 0,25 (0,010) · 0,35 (0,0003)** | **0,49** |
| 4 | t, t-1, t-2, t-3 | 0,24 · 0,25 · 0,36 · **-0,03 (0,78)** | 0,49 |

El rezago 3 no aporta nada (coeficiente nulo, R² igual). El modelo 3 es el elegido.

**Modelo final** (`11_modelo_final.R`), que responde los tres pedidos de la profesora:

*A. ¿Hasta qué rezago dura el efecto?* Se estimaron modelos con 0 a 6 rezagos sobre la
misma muestra (49 meses) y se compararon con AIC y BIC:

| Rezagos | Coef. del último rezago (p) | Pass-through acumulado | R² aj. | AIC | BIC |
|---|---|---|---|---|---|
| 0 | 0,29 (0,016) | 0,29 | 0,10 | -72,8 | -67,1 |
| 1 | 0,42 (0,0003) | 0,56 | 0,31 | -85,2 | -77,6 |
| **2** | **0,33 (0,002)** | **0,83** | **0,44** | **-94,1** | **-84,7** |
| 3 | -0,05 (0,68) | 0,78 | 0,43 | -92,3 | -81,0 |
| 4 | -0,03 (0,81) | 0,75 | 0,42 | -90,4 | -77,2 |
| 5 | 0,08 (0,50) | 0,85 | 0,41 | -88,9 | -73,8 |
| 6 | 0,16 (0,21) | 1,01 | 0,42 | -88,9 | -71,8 |

Del rezago 3 en adelante ningún coeficiente es distinto de cero, el pass-through
acumulado deja de crecer y AIC y BIC empeoran. **El efecto se reparte entre el mes del
cambio y los dos siguientes; al tercer mes ya terminó.** Figura `11a`.

*B. Pass-through acumulado.* Suma de los tres coeficientes del modelo final:
**0,85, con intervalo de confianza al 95% de [0,60 ; 1,10]**. Un aumento de 1% en el
precio internacional se traslada en 0,24 puntos el mismo mes, 0,25 al mes siguiente y
0,35 dos meses después. El intervalo de mínimos cuadrados incluye el 1, pero con errores estándar Newey-West
(sección *Diagnóstico*) se angosta a [0,74 ; 0,96] y el 1 queda afuera: la transmisión
es alta (claramente mayor que 0,5), probablemente incompleta, y tarda tres meses. Figura `11b`.

*C. Con y sin atípicos, sobre el modelo final.* Como cada variación compara un mes con el
anterior, un precio ruidoso contamina dos variaciones; se sacan los tres meses de bajo
volumen y el siguiente a cada uno (48 meses quedan).

| | Con atípicos | Sin atípicos |
|---|---|---|
| Coeficientes t, t-1, t-2 | 0,24 · 0,25 · 0,35 | 0,24 · 0,31 · 0,32 |
| Pass-through acumulado (IC 95%) | 0,85 [0,60 ; 1,10] | 0,87 [0,70 ; 1,04] |
| R² | 0,49 | 0,71 |

Los coeficientes casi no se mueven y el pass-through pasa de 0,85 a 0,87: **las
conclusiones no dependen de esos meses**. El R² salta de 0,49 a 0,71, lo que confirma que
los meses de bajo volumen son la principal fuente de ruido, pero no sesgan el resultado.

*Diagnóstico.* Los residuos del modelo final tienen **autocorrelación negativa de primer
orden**: ACF de -0,38 en el rezago 1, Durbin-Watson 2,75 y Ljung-Box p = 0,005 (a 6
rezagos, p = 0,12). No es dinámica que el modelo deje afuera (los rezagos 3 a 6 no
aportan) sino ruido de medición: la Y es un precio implícito (valor ÷ toneladas), y un
mes de poco volumen produce una variación demasiado alta seguida de una demasiado baja.
La prueba es que sin los meses de bajo volumen la autocorrelación casi desaparece (ACF
-0,22, p = 0,11). Los coeficientes siguen siendo insesgados, pero los errores estándar de
mínimos cuadrados no son confiables, así que se recalcularon con **errores estándar
Newey-West**: los tres rezagos siguen siendo significativos (p < 0,001) y el intervalo del
pass-through se angosta a **[0,74 ; 0,96]** (con autocorrelación negativa, mínimos
cuadrados sobreestima la incertidumbre). Con ese intervalo el 1 queda afuera: la
transmisión es alta pero no completa.

La varianza de los residuos es constante (Breusch-Pagan p = 0,85). Los residuos no son
normales (Shapiro p < 0,001) por dos observaciones extremas: enero 2026, el mes de menor
volumen de toda la serie (48 toneladas), y febrero 2026, el siguiente. Eso no invalida los
coeficientes pero justifica mostrar la versión sin atípicos. Figura `11c`.

*¿El empalme de fuentes sesga el resultado?* Agregando al modelo final una variable 0/1
que vale 1 en los meses de Datamyne, su coeficiente es 0,016 (p = 0,52) y los
coeficientes de la urea no se mueven (0,23 / 0,25 / 0,35). El cambio de fuente no
desplaza la serie ni altera el pass-through.

*¿Aportan las otras variables?* Agregando las variaciones de gas, Brent y tipo de cambio
al modelo final: el gas sí aporta (elasticidad 0,19, p = 0,0002; el AIC mejora de -103 a
-115), Brent (p = 0,13) y tipo de cambio (p = 0,43) no. Los rezagos 1 y 2 de la urea se
mantienen; el contemporáneo baja porque parte de su efecto lo absorbe el gas del mismo
mes. El modelo final se queda con los dos rezagos de la urea internacional, que es la
pregunta del trabajo; el gas queda documentado como complemento válido. Figura `11d`:
variación observada vs. ajustada por el modelo.

---

## 4. Decisiones tomadas

- **Un solo fertilizante (urea)** para homogeneidad de la serie.
- **Y en dólares**, lo que deja al tipo de cambio como control secundario.
- **Valor CIF** en ambas fuentes de la Y, para que el empalme sea comparable.
- **Ventana desde 2022**, para dejar afuera la pandemia.
- **Meses de bajo volumen marcados, no eliminados.** El modelo final se reporta con y sin
  ellos.
- **Una sola serie de gas: Henry Hub (EIA).** El gas Europa queda fuera del proyecto
  (sección 3.1).
- **Modelo definitivo en variaciones porcentuales con dos rezagos**, elegido por
  significación de los coeficientes y por AIC/BIC. Los modelos en niveles (06 y 09) quedan
  como aproximación preliminar.
- **Scripts que corren solos.** Cada script carga la base al inicio; ninguno depende de
  haber corrido otro antes. Los que necesitan paquetes los cargan con `library()`; ninguno
  instala paquetes. Los scripts 07 y 11 usan `tseries`, `sandwich` y `lmtest`, que hay que instalar una vez
con `install.packages()`.

---

## 5. Conclusiones (paso 7)

**¿Cuánto se transmite?** Un cambio de 1% en el precio internacional de la urea se
traslada en un **0,85%** al precio de importación en Uruguay (IC 95%: 0,60 a 1,10 con
mínimos cuadrados; 0,74 a 0,96 con errores estándar robustos). La transmisión es alta y,
con el intervalo robusto, incompleta.

**¿Cuánto demora?** Se reparte en **tres meses**: alrededor de un cuarto el mismo mes,
otro cuarto al mes siguiente y algo más de un tercio dos meses después. Del tercer mes en
adelante no hay efecto. Una explicación plausible, que el trabajo no verifica, es el
ciclo de compra: lo que se cierra hoy a precio internacional llega al puerto y se registra
en aduana uno o dos meses después.

**¿Es robusto?** Sin los meses de bajo volumen el pass-through es 0,87. Los residuos
tienen autocorrelación negativa de primer orden, que viene del ruido del precio implícito
en los meses de poco volumen; con errores estándar Newey-West los coeficientes siguen
siendo significativos y el intervalo del pass-through es [0,74 ; 0,96]. El empalme
Comtrade-Datamyne no sesga el resultado. El modelo con dos rezagos es el mejor por AIC y
BIC entre los siete probados.

**¿Qué otras variables influyen?** El gas natural, principal insumo de la urea, agrega
información (elasticidad 0,19). El Brent y el tipo de cambio no: medir en dólares fue la
decisión correcta.

**Límites.** 56 meses es una muestra corta, y por eso el intervalo del pass-through es
ancho. La Y es un precio implícito (valor ÷ toneladas) que se vuelve ruidoso en meses de
poco volumen. El precio CIF no es el que paga el productor: faltan aranceles, logística
interna y márgenes, que podrían agregar demora o amortiguación que este trabajo no mide. La importación de urea es estacional: el volumen se concentra entre junio y octubre y es
mínimo entre diciembre y febrero (figura `03`), donde caen dos de los tres meses de bajo
volumen. Con 56 meses, menos de cinco ciclos anuales, no hay datos suficientes para
modelarla con variables mensuales; trabajar en variaciones mensuales atenúa el problema,
pero no lo elimina.

---

## 6. Aprendizajes sobre los datos

- **El dataset es la salida de un proceso, no la realidad.** Comtrade, Datamyne y el Pink
  Sheet fueron armados para otros fines; hubo que interpretarlos y adaptarlos.
- **Distinguir "falta el dato" de "no corresponde".** Los NA de `n_ops` son estructurales.
- **Los falsos nulos disfrazados de texto** (`…` del Pink Sheet) cambian el tipo de toda
  una columna si no se los trata.
- **Compatibilidad entre fuentes:** al pegar Comtrade con Datamyne hay que verificar que
  midan lo mismo (criterio de valor, unidad y producto).
- **Un outlier real no se borra en la limpieza:** se marca y se decide en el análisis,
  mostrando el resultado con y sin él.
- **El nombre de una columna no dice lo que contiene.** Una versión anterior de los
  modelos usó `tc_dias` (días con cotización en el mes) como si fuera el tipo de cambio.
  Hay que mirar los valores, no solo el nombre.
- **Correlación alta en niveles no es pass-through.** Dos series con tendencia se
  correlacionan alto aunque no haya efecto directo; la magnitud y la demora de la
  transmisión salen de la regresión en variaciones, no de la correlación.
- **Niveles vs. logaritmos no se comparan por R².** Son variables dependientes distintas;
  la elección se hace por interpretación y por el comportamiento de los residuos.
