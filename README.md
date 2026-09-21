# Bitácora del proyecto — Pass-through de la urea en Uruguay

**Materia:** Introducción a la Ciencia de Datos — Universidad de Montevideo
**Repositorio:** `lab-proyecto-sector-productivo`
**Última actualización:** setiembre 2026

---

## 1. El proyecto

**Sector:** agroindustria — mercado uruguayo de fertilizantes.

**Tema:** el *pass-through* de la urea, es decir, cómo se trasladan los cambios del
precio **internacional** de la urea al precio **local** (de importación) en Uruguay.

**Pregunta principal:**
> ¿Cuánto del aumento o caída del precio internacional de la urea termina reflejándose
> en Uruguay, y cuánto demora en hacerlo?

**Por qué importa:** Uruguay importa casi toda la urea que consume, así que es *tomador
de precios*. En teoría, lo que pasa en el mercado internacional debería reflejarse en el
precio local, pero ese traslado no tiene por qué ser completo ni inmediato. Medir ese
mecanismo ayuda a anticipar costos del sector agropecuario.

**Enfoque:** trabajamos con un solo fertilizante, la **urea** (un nitrogenado *simple*),
para que la serie de precios sea homogénea y la comparación consistente. La variable a
explicar se mide en **dólares (USD)**, lo que aísla el pass-through internacional del
ruido cambiario.

### Variables

| Rol | Variable | Fuente |
|---|---|---|
| **Y** (a explicar) | Precio de importación de la urea (USD/ton, CIF) | Comtrade + Datamyne |
| **X** | Precio internacional de la urea (USD/ton) | World Bank (Pink Sheet) |
| **X** | Gas natural (USD/mmbtu) — insumo de la urea | World Bank (Pink Sheet) |
| **X** | Petróleo Brent (USD/bbl) — proxy energético/flete | World Bank (Pink Sheet) |
| **X** (control) | Tipo de cambio USD/UYU | BCU / INE |

Las tres preguntas que buscamos responder al final:
**¿Cuánto se transmite? → ¿Cuánto demora? → ¿Qué variables influyen?**

---

## 2. Método de trabajo

Cada dataset se procesa por separado con el mismo circuito de *data profiling*
antes de unir la base:

**carga → estructura → identidad → completitud → duplicados → tipos → coherencia**

Recién cuando cada fuente está limpia y validada se unen todas por la columna `periodo`
(una fila = un mes). Perfilar cada una por separado aísla los problemas en su fuente y
evita arrastrarlos a la tabla final.

---

## 3. Registro de avances

### 3.1 Recolección de datos

- **Precio de importación de urea (Y).** Se descargó de dos fuentes que comparten origen
  (la aduana uruguaya): **UN Comtrade** para 2022–2023 (código HS `310210`, reporter
  Uruguay, importaciones, partner World, mensual) y **Datamyne** para 2024 en adelante
  (a nivel operación). Se decidió arrancar en 2022 para dejar afuera la pandemia.
- **Precios internacionales (X).** *Pink Sheet* del World Bank
  (`CMO-Historical-Data-Monthly.xlsx`): urea, gas natural y petróleo Brent.
- **Tipo de cambio.** BCU / INE (`Cotización monedas.xlsx`).

### 3.2 Construcción de la base de la Y

Comtrade viene **agregado** (un total por mes) y Datamyne viene **por operación**, así
que a Datamyne hubo que agregarlo a total mensual (sumando todas las empresas y orígenes)
para dejarlo al mismo nivel que Comtrade. El precio se calcula como
`valor CIF (USD) ÷ toneladas`.

**Chequeo de compatibilidad entre fuentes:** ambas usan el mismo criterio de valor
(**CIF, USD**) y la misma unidad de peso (kg), y el empalme 2023→2024 es continuo, sin
saltos artificiales — lo que confirma que se pueden pegar en una sola serie. Resultado:
una base mensual de **57 meses** (2022-01 a 2026-09).

### 3.3 Profiling de la Y — hallazgos

- **Estructura:** 57 filas × 9 columnas. Unidad de observación: un mes.
- **Clave primaria:** `periodo` (57 valores únicos, sin nulos ni repetidos).
- **Completitud:** la única columna con nulos es `n_ops` (24 NA). Son **NA estructurales**,
  no datos perdidos: corresponden a las filas de Comtrade, que al ser agregado no trae el
  conteo de operaciones. No se rellenan ni se borran.
- **Tipos:** `periodo` venía como texto y se convirtió a fecha (`ym()`).
- **Coherencia:** el precio coincide con `valor ÷ toneladas` en todas las filas; sin
  valores negativos ni ceros; **serie mensual continua, sin huecos** (condición necesaria
  para el análisis de rezagos).
- **A vigilar:** 3 meses de **bajo volumen** (ene-2022, mar-2025, ene-2026) marcados con
  `flag_bajo_volumen`. Se importó tan poco esos meses que el precio unitario sale ruidoso.
  No se corrigen ahora: se dejan marcados y se decide en la etapa de modelado (por ejemplo,
  corriendo el modelo con y sin ellos como chequeo de robustez).

### 3.4 Profiling de las X del World Bank — hallazgos

El *Pink Sheet* no es una tabla limpia: trae 6 filas de encabezado, decenas de columnas
(de las que se usan 3) y datos desde 1960. La limpieza estructural consistió en saltar el
encabezado, seleccionar las columnas de urea/gas/petróleo, parsear la fecha (`1960M01` →
fecha) y **tratar los `…` como NA** (falsos nulos: si no, R leería esas columnas como texto).

- **Estructura (ya limpia):** 48 filas × 5 columnas (`periodo` + urea + gas US + gas Europa
  + Brent), todas numéricas.
- **Completitud:** sin nulos en la ventana 2022–2025 (los `…` estaban en datos viejos).
- **Duplicados:** ninguno. **Coherencia:** serie continua, rangos plausibles (urea
  285–925 USD/ton, gas US 1,5–8,8, gas Europa 8–70, Brent 63–120).
- **Observación:** la versión inicial del Pink Sheet llegaba solo hasta **dic-2025**,
  mientras la Y llega hasta set-2026 → se detectó una brecha de cobertura.

### 3.5 Actualización y unión de la base

- Se **actualizó el Pink Sheet a agosto-2026**, CUIDADO PQ PENSAMOS QUE LO ACTUALIZAMOS A SETIEMBRE PERO TODAVÍA NO ESTAN LOS DATOS DE SETIEMBRE
- Tenemos 2 bases de datos sobre el **gas natural** o sea, esta duplicado, ya que la base de 
datos del "pink sheet" ya lo tiene a ese dato, hay que elegir con 
cuál nos quedamos y cuál borramos, yo (Flor) me quedaría con el 
pink sheet porque tiene el precio del gas de europa y 
el de EEUU --> más completo
- Se perfilo también el **tipo de cambio**.
- Se **unió la base mensual** (Y + X) por `periodo`, dejando la tabla lista para el análisis.

## 3.6 Análisis exploratorio gráfico de gas natural y tipo de cambio

Como parte del análisis preliminar de las variables explicativas, se realizaron gráficos individuales de evolución temporal para el precio del gas natural y el tipo de cambio. El objetivo fue visualizar el comportamiento de cada serie antes de analizar su relación con el precio de la urea.

Gas natural: se graficó la serie mensual del precio Henry Hub (gas_hh_usd_mmbtu), expresada en USD/MMBtu. El gráfico permite observar su evolución, volatilidad y posibles períodos atípicos durante el período analizado.
Tipo de cambio: se graficó la serie mensual USD/UYU utilizando tc_medio, calculado a partir del promedio mensual de las cotizaciones de compra y venta del BROU. Esto permite analizar visualmente la evolución del dólar durante el mismo período.
Formato: para ambas variables se utilizó un gráfico de líneas con observaciones mensuales, manteniendo el mismo criterio temporal que el resto de las variables del proyecto.
Objetivo de esta etapa: detectar tendencias, variaciones fuertes o posibles valores atípicos y comprobar visualmente la continuidad de las series antes de avanzar hacia el análisis conjunto y la regresión.

Resultado: las dos variables quedaron graficadas y listas para ser comparadas posteriormente con el precio internacional y el precio de importación de la urea. En esta etapa no se busca todavía determinar relaciones causales, sino realizar una primera exploración visual de los datos.

## 3.7 Análisis exploratorio gráfico de precio internacional y precio de importación de la urea

A si mismo como se hizo con el gas natural y el tipo de cambio, también se evaluaron gráficamente las variables del precio internacional de la urea, y el precio de importación. Esto se llevó a cabo con el mismo objetivo mencionado anteriormente, evaluar y analizar el comportamiento de cada variable.
Precio internacional: se graficó la serie mensual del precio internacional de venta de la urea, expresado en USD/MT. Se puede apreciar como en 2022 se encontraba en un alto, con un máximo de xxx, y luego se aprecia una caída en el precio desde 2023 a 2026. En 2026 vuelve a retomar la tendencia alcista y sube a un máximo de xxx, para luevo volver a bajar. Se detecta una fuerte variación entre enero 2022 y agosto 2026.
Precio de importación: se graficó la serie mensual del precio importación de la urea, expresado en USD/tonelada. Se puede ver la misma tendencia en los precios de importación que en los precios internacionales del producto, con una fuetrre caída entre 2023 y 2026, y dos subidas en 2022 y mediados de 2026. Se puede notar, por lo menos en los picos, que el precio de importación es siempre más alto que el precio internacional.

Queda concluído el primer análisis meramente superficial de ambas variables, en la cual no llegamos a realizar ninguna conclusión, solamente visualizar el comportamiento de los datos, observar tendencias, para luego realizar un análisis conjunto de todas las variables.

## 3.8 Exploración exhaustiva de la base unida — Pass-through y márgenes

Una vez que unimos la base (56 meses × 13 columnas, 2022-01 a 2026-08), empezamos a ver 
cómo se relacionan las variables. El objetivo es responder las tres preguntas clave antes 
de meterse en la modelización.

### Estadísticas descriptivas y volatilidad

Calculamos la media, mediana, desviación estándar y coeficiente de variación de cada 
variable. Esto permite ver cuáles cambian mucho de mes a mes (ruidosas) y cuáles se 
mantienen estables.

| Variable | Media | CV (%) | Rango | Qué significa |
|---|---|---|---|---|
| Toneladas importadas | 27.483 | 73,9 | 48–74.945 | Uruguay importa cantidades muy distintas cada mes |
| Gas EU (USD/mmbtu) | 18,6 | 70,7 | 8–70 | Explota con el shock energético de 2022 |
| Gas US (USD/mmbtu) | 3,65 | 49,7 | 1,5–8,8 | Varía bastante, pero menos que el europeo |
| Urea intl (USD/ton) | 470 | 35,9 | 285–925 | Moderadamente volátil |
| **Precio de importación (USD/ton)** | **512** | **31,3** | **343–961** | Menos volátil que el internacional |
| Petróleo Brent (USD/bbl) | 84,2 | 17 | 63–120 | Bastante estable en este período |
| Tipo de cambio (UYU/USD) | 41,5 | 3,8 | 39–46 | Casi no se mueve |

Lo interesante es que el precio local (CV 31,3%) es menos volátil que el internacional 
(CV 35,9%). Eso sugiere que hay algo que amortigua las fluctuaciones — probablemente 
contratos de plazo o márgenes que se ajustan sin que el precio nominal suba tanto.

La brecha promedio es de $42/ton (512 – 470). Eso significa que Uruguay paga ~9% más 
que el precio internacional. Tiene lógica: hay que sumarle flete, seguros, derechos 
aduanales y márgenes de los intermediarios.

### Correlaciones entre variables

Miramos cuáles variables se mueven juntas. La matriz de correlaciones (Pearson) nos dice 
si suben/bajan al mismo tiempo o de forma desacoplada.

| Relación | Correlación | Qué pasa |
|---|---|---|
| Precio local ↔ Precio intl | **0,81** | Fuerte. No es perfecta (hay desfases y márgenes), pero se nota que siguen la misma tendencia |
| Precio local ↔ Gas US | 0,77 | Fuerte. Tiene sentido: la urea se fabrica con gas natural |
| Precio local ↔ Gas EU | 0,69 | Moderada-fuerte. El gas europeo subió un montón en 2022 y eso impacta el costo global |
| Precio local ↔ Brent | 0,70 | Moderada-fuerte. El petróleo es un indicador general de costos energéticos |
| Precio local ↔ Tipo de cambio | 0,15 | Muy débil. Prácticamente no hay relación |

El resultado del tipo de cambio tan bajo tiene un mensaje importante: como se negocia 
todo en USD, el peso del dólar casi no importa. Medir en dólares fue una buena decisión 
porque aisla el pass-through del ruido cambiario.

### Pass-through con rezagos — el hallazgo central

La pregunta grande es: ¿cuánto tarda el precio internacional en reflejarse en el precio 
local?

Lo que hicimos fue calcular la correlación del precio local de hoy con el precio 
internacional de hace 0 meses, 1 mes, 2 meses y 3 meses. El rezago que da la correlación 
más alta es donde ocurre la transmisión más completa.

| Rezago | Correlación |
|---|---|
| 0 meses (mismo mes) | 0,8086 |
| **1 mes** | **0,9324** |
| 2 meses | 0,9137 |
| 3 meses | 0,8050 |

La correlación salta de 0,81 (contemporáneo) a 0,93 (un mes después). Eso es casi 
perfecta. Cuando sube el precio en el mercado internacional en enero, Uruguay ajusta 
sus precios de importación principalmente en febrero.

¿Por qué 1 mes? Los contratos internacionales típicamente se cierran con plazo de 
entrega de un mes. Los proveedores renegocian precios con ese ciclo. Uruguay no tarda 
años en ajustarse — es rápido. Y no es "pegajoso" (sticky): no hay una inercia 
exagerada que frene la transmisión.

### Margen local vs internacional

Calculamos el ratio `precio_local ÷ precio_intl` para ver cuántas veces más caro paga 
Uruguay respecto al precio internacional puro.

| Estadístico | Valor | Qué significa |
|---|---|---|
| Ratio medio | 1,12 | En promedio, Uruguay paga 12% más que el precio internacional |
| Mínimo | 0,63 | Hubo meses donde pagó 37% menos (cuando la intl sube rápido y Uruguay tiene stock viejo) |
| Máximo | 1,65 | Hubo meses donde pagó 65% más (cuando la intl cae pero Uruguay tiene compromisos de precio alto) |

El margen promedio de 12% es razonable. Pero la variabilidad es alta (de 63% a 165%). 
Eso refleja un dato de la realidad: los contratos no se renegocian todos los meses. 
Algunos meses el precio internacional sube pero Uruguay sigue pagando lo que acordó 
hace un tiempo (ratio bajo). Otros meses es al revés.

### Validación técnica: flag de bajo volumen y empalme de fuentes

Hay 3 meses donde importó menos de 1.000 toneladas: enero de 2022, marzo de 2025 y 
enero de 2026. El precio unitario en esos meses sale ruidoso porque poca cantidad = 
más volatilidad relativa. Los marcamos con una bandera para que después, al modelar, 
se pueda decidir si incluirlos o no (un chequeo común es correr el modelo con y sin 
ellos para ver si son outliers que distorsionan).


**Ahora tenemos respuestas provisionales a las 3 preguntas del proyecto:**
1. **¿Cuánto se transmite?** → 81–93%. Casi completo, no hay pérdida significativa.
2. **¿Cuánto demora?** → Aproximadamente 1 mes. Rápido, sin inercia.
3. **¿Qué variables influyen?** → El precio internacional es lo principal (0,81). La 
energía también (gas 0,69–0,77, Brent 0,70). El tipo de cambio casi no cuenta (0,15).



## 4. Decisiones tomadas

- **Un solo fertilizante (urea)** para homogeneidad de la serie.
- **Variable Y en USD** → el tipo de cambio queda como control secundario, no protagonista.
- **Valor CIF** en ambas fuentes de la Y, para que el empalme sea comparable.
- **Ventana desde 2022** (deja afuera la pandemia).
- **Meses de bajo volumen** marcados, no eliminados (se deciden en el modelado).

### Decisiones pendientes

- **Qué serie de gas usar:** US (más estable) o Europa (capta mejor el shock energético de
  2022). Se resuelve al modelar, probando ambas.

---

## 5. Aprendizajes de datos (para el informe)

- **El dataset es la salida de un proceso, no la realidad.** Comtrade, Datamyne y el Pink
  Sheet fueron armados para otros fines; hubo que interpretarlos y adaptarlos.
- **Distinguir "falta el dato" de "no corresponde".** Los NA de `n_ops` son estructurales.
- **Los falsos nulos disfrazados de texto** (`…` del World Bank) cambian el tipo de toda
  una columna si no se los trata.
- **Compatibilidad entre fuentes:** al combinar dos orígenes (Comtrade + Datamyne) hay que
  verificar que midan lo mismo (mismo criterio de valor, unidad y producto) antes de pegarlos.
- **Un outlier real no se borra en la limpieza:** se marca y se decide en el análisis.

