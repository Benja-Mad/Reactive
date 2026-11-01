# Prueba de escenario estilizado · 16 octubre 2026

Escena jugable: `res://tests/environment/stylized_yard.tscn` (abrir en Godot y ejecutar con F6 del editor). Dentro del juego, F6 alterna entre el acabado original y el propuesto. F7 alterna entre la cámara de combate y una vista amplia para revisar la ciudad. WASD mueve al personaje; Esc abre el taller habitual. La escena principal (`res://scenes/main_scene.tscn`) ya carga por defecto la versión pulida completa, con sus correcciones de colisión. La escena de prueba conserva la comparación reversible sin duplicar los elementos.

La prueba cubre el patio, sus ampliaciones laterales y sur, y el distrito de fondo. Mantiene la cámara de combate y los personajes actuales. La iteración 10 añade reparaciones explícitas de colisión: se desactivan volúmenes de proyecciones y piezas retiradas, y se sustituyen envolventes convexas incorrectas por formas ajustadas a estructuras abiertas. F6 restaura tanto el arte como la física original. No se editan los recursos importados ni las reglas de enemigos.

- Material mate de pavimento: manchas amplias escalonadas, sin textura fotográfica ni normales de grano fino.
- Fachada: masas de color agrupadas, sin manchas pequeñas ni accesorios interiores.
- Rejillas: cuatro lamas gruesas dentro del volumen original.
- Cajas: cuerpo, dos bordes y dos cinchas, con la transformación original.
- Barreras: pintura arena mate.
- Suelo: se retiran las láminas decorativas de charcos, humedad y parches; no afecta el agua creada por jugadores.
- Se ocultan algunos cables y amarres finos del área. Se conservan cercas y otros obstáculos.

La iteración 10 registra 326 superficies, 1240 detalles ocultos y 19 modelos reconstruidos, además de la arquitectura y señalética nueva. El acabado del suelo también cubre el pavimento instanciado de la ampliación.

## Comparación reproducible

Ejecutar Godot desde el proyecto:

```sh
godot --path . res://tests/environment/stylized_yard.tscn -- capture
godot --path . res://tests/environment/stylized_yard.tscn -- capture support
```

Genera en `iteration_12/` (o en `LOOK_DIR` si se define) `before_brasa.png`, `after_brasa.png`, `before_sereno.png` y `after_sereno.png`. Cada pareja mantiene cámara, personaje y enemigos inmóviles, y pausa simulación y partículas. Las capturas proceden del motor, no de imágenes generadas. Entre personajes puede variar el estado inicial del ambiente.

## Verificación

La escena comprueba que los recursos y transformaciones de las colisiones originales se conservan; solo cambia el estado de las formas declaradas en la reparación. F6 restaura esos estados y desactiva todas las formas nuevas. `validate_city_view.gd` comprueba también cámara, materiales y visibilidad. `audit_walkable_yard.gd` comprueba espacio libre, conexiones y pasos con la cápsula real del personaje. No se ha medido rendimiento ni validado el balance de oleadas completas.

Al cerrar Godot aparecen avisos de recursos de partículas/texturas sin liberar también en una ejecución de control con el escenario original. No se han corregido dentro de este pase artístico.

## Iteración 02 · ajuste a la referencia del usuario

Se recupera el pavimento oscuro `#536166` y la iluminación escalonada de la versión intermedia preferida. Se mantienen las mejoras de fachada y utilería. Se retiran los charcos planos de contorno octogonal: vuelven las superficies reflectantes originales, con una copia local de sus materiales para moderar el brillo. El resultado busca conservar profundidad y zonas de luz dentro de un patio oscuro, evitando la extensión gris verdosa de la primera entrega.

Las imágenes de la primera entrega se conservan en esta carpeta; las nuevas están en `iteration_02/`. El cambio continúa limitado a la escena de prueba jugable.

## Iteración 03 · lectura del espacio

- Se conserva exactamente el material oscuro de pavimento de la iteración 02.
- Once cercas del área se reconstruyen con marco, zócalo bajo y cinco barrotes, sustituyendo las mallas de rombos finos. Se conservan posiciones y colisiones originales.
- Se ocultan también los tendidos largos y amarres que cruzan el área aunque su centro esté fuera de ella. Se mantienen estructuras principales y la profundidad del primer plano.
- Las piezas nuevas se registran en el sistema de visibilidad para que se desvanezcan al ocultar al operador.
- Capturas en `iteration_03/`. Añadir `south` después de `capture support` muestra un segundo encuadre desde la zona sur. Las iteraciones anteriores permanecen disponibles para comparar.

## Iteración 04 · recuperar el carácter de las cercas

Se sustituyen los barrotes de la iteración 03 por una malla de rombos abierta. Los alambres tienen 3,2 cm de grosor, separación entre líneas de 55 cm y pequeñas deformaciones deterministas. Cada panel utiliza una única malla combinada para el tejido. Se conserva el marco y sus marcas de pintura, pero se reduce el zócalo a un perfil de 12 cm. El suelo oscuro, los reflejos y la limpieza de cables se mantienen.

Captura revisada en Godot: `iteration_04/after_brasa.png`. Las comprobaciones de restauración de materiales y conservación de colisiones pasaron durante la captura. La iteración 03 sigue disponible como comparación con los barrotes.


## Iteración 05 · composición cyberpunk y limpieza del patio

Se reduce la dispersión de vegetación y fragmentos decorativos: 121 piezas adicionales ocultas, excluyendo objetos con metadatos funcionales. Se conserva el pavimento oscuro, los charcos reflectantes y las cercas de rombos abiertos.

La fachada recibe un anuncio de implantes ópticos NÁCAR de 10,8 × 3,8 m, una pantalla secundaria de transporte y un letrero vertical de hotel. Son objetos anclados al mundo con marcos, soportes y marquesina, a distintas alturas; no siguen a la cámara. Tres luces violetas locales separan los laterales del patio y la fachada. El arte de las pantallas se dibuja una vez en texturas de 960 × 400, con tipografía y gráficos sencillos y líneas de barrido discretas.

Los elementos nuevos se integran en la alternancia F6 y en el sistema de ocultación alrededor del personaje. No se cambian enemigos ni controles. La propuesta sigue en la escena de prueba; no reemplaza automáticamente la presentación de la partida principal.

Capturas del motor en `iteration_05/`: Brasa en el patio central y Sereno desde el sur. Las comprobaciones de colisiones y restauración de materiales se ejecutan en cada captura. Esta pasada mejora el carácter de la fachada próxima; una ampliación del skyline y la arquitectura distante sigue siendo trabajo posterior.


## Iteración 06 · distrito en profundidad y anuncios en inglés

- Se incorporan doce torres en tres planos, con retranqueos de azotea, antenas puntuales y grupos de ventanas encendidas. Las ventanas se agrupan en un MultiMesh por torre. Los volúmenes distantes tienen colores más próximos a la atmósfera azul para reducir contraste.
- El bloque norte pasa a una volumetría baja, rematada con cubierta y una unidad de ventilación. Para esta prueba reversible se recorta la fachada a cinco metros mediante el material y se ocultan sus piezas superiores, incluidas las que estaban en grupos reactivos separados. Las colisiones originales no se alteran; esta sustitución visual no es una reexportación del modelo.
- Se sustituye visualmente el fondo bg_block_b y el viaducto macizo por las capas del distrito y una vía elevada más estrecha con tres vagones estáticos. Se retiran bandejas y pasarelas superiores del encuadre central. No se modifican recorridos ni obstáculos del suelo jugable.
- AFTERHUMAN: campaña de implantes con rostro angular, visor cian, halo rosa y el lema “YOUR EYES. NO LIMITS.”. GHOST RAMEN: identidad naranja, cuenco con vapor y “REAL HEAT. SYNTH MEAT.”. DREAM: neón vertical violeta. Todo el texto de los anuncios nuevos está en inglés.
- F7 permite revisar la ciudad con un encuadre de 26° de inclinación, distancia 66 y FOV 44; al volver se recuperan los valores de combate 38°/50/38. No se cambia la escena principal. El encuadre estrecho de combate muestra solo una parte del distrito; la vista amplia es una herramienta de revisión, no una decisión definitiva de cámara para el survivor.

Capturas finales: `iteration_06/after_brasa.png` usa la cámara habitual; `iteration_06/after_sereno_vista.png` usa la vista amplia. Sus imágenes `before_` mantienen el mismo encuadre para comparar. Se obtienen con `capture` y `capture support vista`, respectivamente. El argumento `overview` es una vista de diagnóstico de conjunto, no una captura de gameplay.

Se comprobaron las colisiones al aplicar el arte, la restauración de materiales/visibilidad con F6 y el retorno de F7 a la cámara de combate. Las capturas fuerzan un dibujo antes de leer la imagen para no depender de que macOS mantenga la ventana en primer plano. Persisten los avisos de cierre ya documentados de partículas y texturas.

Validación reproducible de cámara y reversibilidad: `godot --headless --path . --fixed-fps 60 --quit-after 600 --script res://tests/environment/validate_city_view.gd`.


## Iteración 07 · profundidad desde combate y suelo sin parches reflectantes

Se retiran del decorado importado las piezas Puddle, Ground_Damp, Ground_Patch y Road_Patch. Se mantiene el pavimento oscuro bajo ellas. La selección se limita al escenario importado, de modo que no elimina agua ni efectos creados por los jugadores.

Se abre un tramo de nueve metros en la fachada norte, incluyendo jambas, rellenos y placas de ventilación que estaban repartidos entre grupos del modelo. El material de prueba recorta esa franja de la fachada. Detrás se colocan dos fachadas laterales a distancias distintas, una pasarela y ventanas de fondo, con acentos cian/violeta. Un antepecho y barandilla conservan la lectura de límite escénico: no se añade una salida jugable. El anuncio AFTERHUMAN se reduce y desplaza hacia la derecha para dejar visible esa profundidad.

Las capturas `iteration_07/after_brasa.png` y `after_sereno_south.png` emplean la cámara normal de combate (38° de inclinación, distancia 50, FOV 38), sin el argumento vista ni cambios al seguimiento. La apertura se compone para el sector norte del patio; al desplazarse hacia el sur entra y sale del borde superior como el resto de la arquitectura. F7 sigue disponible únicamente como herramienta opcional de revisión.

Las comprobaciones de conservación de colisiones y restauración de materiales/visibilidad pasan en las capturas. `validate_city_view.gd` también comprueba que los parches decorativos seleccionados están ocultos y que se recupera la cámara de combate al regresar de la vista amplia. Los avisos conocidos de recursos al cerrar Godot persisten.


## Iteración 08 · torre industrial y jerarquía de luces

La torre conserva el emplazamiento y la escala aproximada de la pila original. Se sustituye visualmente su cuerpo y accesorios por una silueta octogonal escalonada: placas mates, zócalo sólido, refuerzos, conducto de servicio y panel “COOLANT 08”. La luz cian se concentra en dos ranuras pequeñas y un relleno local sin componente especular ni volumétrica. No se añade vapor nuevo en esta pasada.

Se ocultan, solo en la presentación alternativa, la luz SpineCyan, su haz, el volumen SpineAir, la condensación continua y las partículas SpineHalo/SpineAsh. Los estados originales de visibilidad se registran y restauran con F6, sin modificar las curvas de energía del controlador. Se conserva el resto de la lluvia y la atmósfera del escenario.

Se reduce la luminosidad del anuncio AFTERHUMAN, el neón DREAM y algunos acentos del pasaje. GHOST RAMEN baja y se desplaza para no tapar la identificación de la torre. El suelo continúa sin parches reflectantes y la apertura arquitectónica permanece en la cámara de combate.

Capturas: `iteration_08/after_brasa.png` y `after_sereno_south.png`, ambas con cámara normal. La validación comprueba colisiones, ausencia de parches, retorno de cámara y restauración de materiales, visibilidad y atmósfera. No se cambian enemigos, controles ni la presentación de la escena principal. Persisten los avisos de recursos al cerrar Godot ya documentados; no se ha medido rendimiento.

## Iteración 09 · despejar el primer plano y las zonas de servicio

Se retiran las dos tuberías elevadas del frente sur y sus abrazaderas, limitando la selección a piezas por encima de cinco metros que atraviesan el patio. Los obstáculos del suelo y sus colisiones se mantienen. Los labios del canal reciben un acabado mate oscuro para reducir las líneas claras que atravesaban la composición.

La vegetación, el musgo y los fragmentos inertes dejan de distribuirse por todo el suelo: se conservan pequeñas agrupaciones en tres bolsillos del perímetro. Se excluyen los elementos con metadatos funcionales. En ContainmentCourt se retiran las baldosas decorativas y dos de las cinco costillas de cada pilar; se comprueba que esas piezas no contienen colisiones. Las superficies cerámicas y las bases pasan a grises azulados mates, manteniendo las siluetas, los huecos transitables y los núcleos sólidos originales.

Resultado: 1222 detalles ocultos, 218 superficies con acabado alternativo y 18 modelos reconstruidos. Capturas desde cámara de combate en `iteration_09/after_brasa.png` y `iteration_09/after_sereno_south.png`; las imágenes `before_` muestran el escenario original, no la iteración 08. Esta última conserva sus capturas para comparar entre pasadas.

Validación de cámara, colisiones, parches ausentes y restauración de materiales/visibilidad superada. Revisadas ambas capturas del motor. La propuesta permanece en `tests/environment/stylized_yard.tscn`, con F6 para comparar; no se modifican enemigos ni la escena principal. Persisten los avisos de recursos al cerrar Godot documentados anteriormente.


## Iteración 10 · barrios conectados y obstáculos legibles

Oeste: DRIFT CLINIC y mural pintado “STAY HUMAN”; este: MEMORY BANKS sobre las estructuras de servicio; sur: NIGHTLINE en el acceso existente. Los anuncios comparten marcos, resolución y tratamiento de luz, con identidades cian, violeta y transporte. Cuatro bloques exteriores prolongan la arquitectura lateral. No se añaden muebles ni obstáculos al suelo jugable. Todos los textos nuevos están en inglés.

El pavimento mate se extiende a todos los Yard_Slab/Apron importados y a PerimeterGroundFill y su cimentación. Esta última es suelo de soporte visual, no un parche reflectante: permanece visible. Cerámicas, bases, cajas, bidones, bolardos y bordes de jardineras ganan contraste moderado y un relleno tenue de material para conservar su lectura en sombra. La jerarquía mantiene el personaje y la señalética por encima de los detalles.

### Reparación física

El generador original construía colisiones incluso para Barrier_Field, Hologram_001 y Stack_Diagnostic, que estaban invisibles. Sus proyecciones, los diagnósticos y las caras de carteles dejan de ser barreras físicas. Se retiran conos y abrazaderas bajas decorativas junto a sus colisiones. Las piezas visuales eliminadas en las pasadas anteriores ya no conservan obstáculos fantasma.

Los faroles, el poste de servicio, las barandillas de escalera y Barrier_Frame pasan de una envolvente convexa a colisión de triángulos: el espacio bajo sus brazos y dentro de los marcos deja de ser sólido. En Barrier_Frame se excluye el umbral bajo, tratándolo como bordillo transitable. Una prueba barre la cápsula a través de la abertura y otra contra el poste: el hueco permite pasar y el poste continúa sólido. La torre usa nueve formas convexas derivadas de sus volúmenes visibles inferiores.

En conjunto, se desactivan 41 colisiones originales y se habilitan 19 formas de sustitución (nueve de torre y diez de estructuras abiertas). Estas cifras no equivalen a 41 obstáculos retirados: parte son sustituciones más precisas. Los recursos originales permanecen intactos y F6 recupera sus estados.

### Superficie y pruebas

Rectángulo nominal: 68 × 54 m, 3672 m². Muestreo con la cápsula del personaje cada 0,5 m, exclusión del propio jugador y barridos entre celdas vecinas: aproximadamente 2576 m² conectados, con acceso a centro, oeste, este y sur. No se detectan puntos transitables sin suelo. Los cuatro lados del perímetro detienen la cápsula. El informe `iteration_10/walkability.json` incluye las componentes secundarias y sus límites: quedan bolsillos detrás de arquitectura y entre objetos; una rejilla finita no certifica cada separación ni sustituye probar oleadas. Algunos bolsillos pequeños se solapan con el rectángulo de aparición actual, por lo que la validación de aparición y navegación de los nuevos enemigos sigue pendiente del trabajo de gameplay.

Cruzar las dimensiones nominales a 3,5 m/s toma 19,4 y 15,4 segundos antes de rodear obstáculos. Se conserva este tamaño: las rutas principales tienen espacio y continuidad; no se afirma balance definitivo de densidad de enemigos.

Capturas finales, todas desde la cámara normal: `after_brasa.png`, `after_brasa_west.png`, `after_brasa_east.png`, `after_brasa_far_south.png`. Para reproducir: `godot --path . res://tests/environment/stylized_yard.tscn -- capture clean west` (cambiar west por east o far_south, u omitir para centro). `clean` omite los enemigos estáticos añadidos por el capturador. Las imágenes `before_` comparan con el escenario original, no con la iteración 09.

Validaciones: `godot --headless --path . --fixed-fps 60 --quit-after 900 --script res://tests/environment/audit_walkable_yard.gd` y la misma orden con `validate_city_view.gd`. Continúan los avisos de recursos al cerrar el motor documentados previamente. Todo permanece en la escena de prueba, sin cambios en la escena principal ni en los enemigos.


## Iteración 11 · graffiti real en la fachada oeste

Se sustituyen los dos Label3D de “STAY HUMAN” por una textura original de graffiti con transparencia: letras angulares dibujadas, pintura desgastada y goteos. El recurso se guarda dentro del proyecto en `stylized/art/stay_human_graffiti.png`. La superficie recibe la iluminación de la escena, sin emisión ni reflejo especular, y no proyecta una sombra rectangular. Se conserva la pared, su posición y todas las colisiones.

Captura revisada desde la cámara normal: `iteration_11/after_brasa_west.png`, generada con `capture west clean`. El capturador comprobó integridad y restauración de las colisiones originales. La propuesta continúa en la escena de prueba.


## Iteración 12 · mobiliario urbano con función reconocible

Se retira completa la composición ContainmentCourt: tres arcos dentados, tres particiones de bloques, tres torres de placas y sus mosaicos. Se ocultan sus piezas y se desactivan sus 18 formas originales, conservando la restauración mediante F6. Las divisiones centrales y el arco duplicado del oeste desaparecen sin sustituto.

La nueva composición utiliza tres destinos compactos: un puesto de atención de la clínica cerca del edificio oeste, dos armarios de refrigeración con ventiladores visibles en el este y una marquesina con banco y frente abierto al sur. Se reutilizan y reducen los tres anuncios existentes, sin añadir carteles ni graffiti. Se mantiene el mural de la iteración 11. Los armarios tienen una envolvente continua y la marquesina usa pilares delgados; desaparece la silueta de cubos y placas apiladas.

Las nueve formas nuevas coinciden con las dimensiones y transformaciones de sus piezas sólidas visibles. Las cubiertas altas y los pequeños remates no añaden bloqueos. La prueba física comprueba que todas las colisiones del conjunto retirado estén desactivadas, que el nuevo mobiliario corresponda con sus cajas físicas y que las cuatro zonas sigan conectadas. La superficie principal conectada medida en la rejilla de 0,5 m pasa de aproximadamente 2576 a 2619 m², unos 43 m² más; es una estimación de circulación con cápsula, no superficie geométrica exacta.

Capturas revisadas desde la cámara habitual: `iteration_12/after_brasa_west.png`, `after_brasa_east.png` y `after_brasa_far_south.png`. Informe físico: `iteration_12/walkability.json`. Pasan la auditoría de recorridos y la prueba de restauración con F6 y cámara con F7. Se mantienen las limitaciones de balance y de muestreo descritas en la iteración 10. La escena principal y los enemigos no se modifican.

## Integración en la escena principal · 17 octubre 2026

La partida normal aplica todas las pasadas hasta la iteración 12 después de construir el perímetro y antes de anunciar que el jugador está listo. Incluye suelo mate, rejas, torre de refrigeración, profundidad urbana, anuncios ingleses, graffiti y mobiliario de los laterales y sur; también las 59 colisiones originales retiradas y 28 formas de reemplazo. La cámara habitual permanece a distancia 50, inclinación 38° y FOV 38°.

El sistema que desvanece objetos delante del personaje registra los elementos nuevos una sola vez, tanto al arrancar la partida como al abrir la comparación. La prueba visual desactiva explícitamente la integración automática para conservar F6/F7.

Validación: `tests/environment/validate_main_environment.gd` comprueba dos cargas consecutivas de la escena principal, jugador y partida activos, cámara, colisiones y ausencia de registros visuales duplicados. También pasan `validate_city_view.gd` y `audit_walkable_yard.gd`: 2619 m² conectados, cuatro sectores accesibles, sin huecos en el suelo y perímetro cerrado. Las reglas de aparición y comportamiento de enemigos no se modifican.

## Descarga de materiales y retorno al menú · 18 octubre 2026

El acabado restaura los materiales originales al salir del árbol, mientras la geometría fuente sigue viva. Esto elimina los cuatro avisos de material nulo por descarga que aparecían con la presentación pulida; no se silencian errores del motor.

`tests/environment/validate_menu_roundtrip.gd` recorre tres veces los callbacks reales de menú, selección de operador, inicio y botón Menú del HUD. Alterna Brasa/Sereno/Brasa y salida en pausa/en marcha/en pausa. Comprueba que se libera la escena anterior, se vacían los grupos de partida y el registro de jugadores, se recuperan el renderizado 3D del menú y su MSAA, y cada nueva partida tiene un solo jugador y reloj nuevo. Pasó en headless y con Metal/Forward+. No aparecieron errores de material durante las transiciones. Al cerrar el proceso completo siguen los avisos previos de ParticlesShaderRD, siete texturas y un shader; no forman parte del fallo de materiales nulos corregido.

## Cierre limpio y regresiones · 18 octubre 2026

Resueltos los avisos restantes en las pruebas gráficas con Godot 4.7.2 / Metal / Forward+:

- Polvo ambiental, polvo cinematográfico, lluvia y vapor asignan su material de proceso antes de precalentar partículas. El orden anterior dejaba un shader de partículas pendiente al cerrar; la prueba aislada del módulo reproduce el fallo y confirma la corrección.
- Retirada la captura local de reflejos del antiguo patio húmedo. Se conservan el cielo, SSR, niebla, sombras y partículas. Esa captura activaba la fuga del atlas de reflejos descrita en https://github.com/godotengine/godot/issues/122498 (seis vistas y un buffer de color). La captura actual de la escena principal se revisó visualmente tras el cambio.
- La comprobación de «on kill» vacía las muertes de casos anteriores antes de introducir su evento y verifica su posición exacta y consumo único. No se cambiaron las reglas de combate.

Evidencia guardada en `validation_20261018/`: tres ciclos completos de menú/partida, dos cargas de la escena principal y la batería de combate con el renderizador real. Los tres procesos terminaron sin ERROR, WARNING ni errores de script. La batería de especialistas también pasó en headless. Los avisos de certificados que aparecen al ejecutar headless dentro del sandbox de macOS no se reproducen en las ejecuciones gráficas normales.

## Iteración 13 · iluminación y lectura de sectores · 18 octubre 2026

Las luces locales pasan de rellenos omnidireccionales poco perceptibles a luminarias montadas en el mobiliario existente: clínica verde azulada, refrigeradores violeta y marquesina sur cálida. Proyectan sombras sobre superficies mates; no hay nuevas colisiones ni carteles. Una luminaria de pared ilumina el graffiti occidental sin convertirlo en un anuncio emisivo. El punto de mantenimiento COOLANT 08 recupera una influencia azul suave.

Se reducen la autoiluminación y las manchas del pavimento para que la luz determine más sus valores. La luz principal mantiene planos escalonados; los focos locales mezclan suavemente los escalones para evitar anillos que parezcan charcos. Las carcasas de clínica, refrigeradores y banco del sur tienen paletas propias dentro de la misma gama urbana.

Validación: cámara normal en oeste, este y sur; 2619 m² conectados, cero muestras sin suelo, las mismas 59 colisiones retiradas y 28 sustitutas. Continúa pasando la comparación reversible F6/F7. Se aplica automáticamente en la escena principal.

## Iteración 14 · transiciones de luz · 18 octubre 2026

Se eliminan los escalones restantes en la respuesta a luces locales (la luz direccional conserva el acabado por planos), se suavizan los límites angulares y de alcance de los focos y se da tamaño a las fuentes para suavizar sus sombras. Se compensa la intensidad para conservar la influencia de color.

El corte recto bajo la parada Nightline provenía del marco del cartel: dos piezas interceptaban el cono entre el foco y el suelo. Se comprobó con intersecciones de rayos contra triángulos y una captura temporal sin sombras. La luminaria queda ahora debajo del travesaño inferior, conservando las sombras del mobiliario. Los cambios experimentales a los materiales y sombras del pavimento se descartaron; geometría y colisiones siguen intactas.

Capturas revisadas con la cámara normal en este y oeste. La comparación reversible sigue funcionando.


## Iteración 15 · pavimento de tránsito y retornos urbanos

El sur incorpora una franja continua de asfalto mate y un área de espera alineadas con la marquesina (34,38°), con juntas espaciadas y una línea de borde tenue. Las superficies se recortan contra los límites existentes; son únicamente acabado visual, sin elevar el suelo físico ni añadir colisiones. Se conserva el pavimento original fuera de estas franjas.

La parada gana una cubierta más profunda, nervios y remate trasero; el anuncio Nightline se reduce. Los apoyos y el banco conservan exactamente sus formas físicas. Dos edificios de servicio exteriores, con accesos retranqueados, ventanas agrupadas y volúmenes altos desplazados hacia el fondo, dan continuidad a los bordes. Sus huellas empiezan un metro fuera de los límites laterales. Se revisó y retiró del primer plano la posición inicial del edificio oriental, cuya cubierta invadía la vista de combate. No se añadieron anuncios, graffiti ni focos.

Capturas con cámara habitual en `iteration_15/after_brasa_far_south.png`, `after_brasa_east.png` y `after_brasa_west.png`. La arquitectura nueva se aprecia especialmente en el borde oeste; el cambio del sur central es principalmente el pavimento y la marquesina. Auditoría de circulación: 2619 m² conectados, cuatro sectores accesibles, cero muestras sin suelo, 28 formas de reemplazo y 59 colisiones retiradas, sin cambios. Integración a través del acabado que ya carga la escena principal.


## Iteración 16 · luz neutra y suelo continuo

Se reduce la dominante azul de las luces existentes: principal casi neutra (0.82, 0.84, 0.86; energía 1.75), relleno lavanda moderado (0.58, 0.57, 0.68; 0.55) y ambiente gris frío más legible (0.32, 0.34, 0.36; 0.55). El contraste baja de 1.10 a 1.06 y la niebla mantiene un tono frío menos saturado. Se conservan las fuentes locales cian, violeta y ámbar, que ahora se distinguen de los materiales. No se añaden luces en esta pasada.

La superposición del sur se corrige reemplazando las franjas geométricas separadas por una superficie continua: asfalto, área de espera, juntas y líneas se dibujan en el mismo material. Las caras originales de losas, rellenos y pavimento se recortan en el shader dentro de la misma huella y los mismos límites, evitando que sus aristas crucen el acabado nuevo. Se mantiene la física original del suelo. La zona conserva una unión de materiales y orientaciones en su límite, pero no dos cuadrículas superpuestas dentro del pavimento nuevo.

Revisadas capturas finales de centro, oeste y sur en `iteration_16/`. Pasó `validate_city_view.gd`: cámara normal/amplia, colisiones estables y restauración de materiales/visibilidad. Las tres ejecuciones gráficas finales terminaron sin errores. Todo está en la escena principal; el ejecutable de Windows anterior no se ha vuelto a exportar.


## Iteración 17 · acentos cyberpunk localizados

Se mantiene la luz principal neutra de la iteración 16 y se baja ligeramente el ambiente (0.55 a 0.50). Se refuerzan las fuentes existentes de clínica (turquesa), refrigeración (violeta), marquesina (ámbar) y fachadas (violeta/rosa). Una única luminaria violeta nueva, con carcasa visible, se monta en el extremo frontal de la marquesina; su cono queda delante del borde de cubierta, con la misma atenuación suave y sombras que las luminarias de servicio. La luz cálida principal de la parada sigue siendo dominante.

La intervención conserva pavimento, colisiones y número de anuncios. Capturas revisadas desde cámara normal en centro y este (`iteration_17/after_brasa.png`, `after_brasa_east.png`); ambas ejecuciones gráficas terminan sin errores. Pasa `validate_city_view.gd`, incluyendo restauración de materiales, visibilidad y colisiones. Integrado en la escena principal.

## Iteración 18 · marquesina gráfica y patrulla aérea

La marquesina sustituye sus dos focos difusos por una barra cálida con proyección rectangular de lamas: área de espera delimitada, divisiones gráficas y caída corta. El extremo violeta queda como detalle emisivo de la estructura, sin otra mancha sobre el pavimento. Se conservan apoyos, cubierta, banco y colisiones.

`aerial_patrol.gd` añade un reflector aéreo ambiental a la escena principal. Empieza cinco segundos después de crear el acabado, recorre la zona durante nueve segundos y repite cada 38 segundos. Al comenzar toma la zona del jugador como referencia, pero fija su recorrido en el mundo durante toda la pasada. La apertura octagonal tiene niveles de intensidad, sombras reales y entrada/salida suaves. Un volumen facetado transparente hace visible el haz desde la cámara habitual incluso con niebla tenue. No hay daño, marcas de ataque, colisiones, modelo de helicóptero ni sonido nuevo. Se pausa con el juego y se libera con el escenario.

Capturas de centro y este en `iteration_18`, con fases 30 % y 65 % del recorrido. La escena de comparación permite `capture east clean patrol` para reproducirlas. Se corrigió el capturador para congelar explícitamente el reloj de la patrulla al muestrear una fase. La captura central final incluye el volumen facetado; las capturas del este anteriores muestran la proyección y la marquesina.

Pasa `validate_aerial_patrol.gd`: arranque diferido, desplazamiento, ruta fija aunque se mueva el jugador, repetición, fundidos, pausa, ocultación, colisiones del entorno intactas y descarga del nodo. Las ejecuciones gráficas finales no reportan errores. El ejecutable de Windows anterior no se reexportó.

## Iteración 19 · estudio de composición de la parada

Diagnóstico: la cubierta plana y clara dominaba la imagen; la cámara de combate ocultaba el interior y las luces estaban orientadas al pavimento. El ajuste de color por sí solo no resolvía la jerarquía. Se desarrolla una zona piloto alrededor de Nightline, sin aplicar el nuevo lenguaje al resto del mapa.

La nueva composición usa una cubierta carbón, una franja arquitectónica ámbar dividida por montantes, una luz lateral sobre banco y pilares y un contraluz verde mineral. Se retira el anuncio Nightline. La cubierta se eleva 0.9 m y reduce su profundidad; extensiones de los postes y tirantes conectan las piezas altas sin nuevos bloqueos. La franja queda por encima del volumen del jugador. Un material específico sustituye el ambiente uniforme por valores de sombra propios y tres respuestas amplias por orientación, manteniendo sombras geométricas y respuesta a luces dinámicas. El suelo próximo y las jardineras locales bajan de protagonismo; el asfalto sigue siendo una superficie continua.

El reflector, cuando pasa cerca de esta zona, eleva su recorrido sobre la cubierta y el frente. En las capturas se ve cómo descubre planos antes oscuros y desplaza la sombra del edificio. El evento conserva calendario, recorrido fijo durante la pasada y pausa.

Capturas normales: `iteration_19/after_brasa_transit.png`, `after_sereno_transit.png`, `after_brasa_east.png`; fases del reflector en `patrol_30_brasa_transit.png` y `patrol_65_brasa_transit.png`. El estudio con combate está en `iteration_19/combat/`: se verificaron enemigos, fuego y hielo, antes de reducir ligeramente la altura del panel luminoso y bajar el contraste de la jardinera cercana. `reference/` conserva una captura inicial de esta cámara; los efectos transitorios de aparición de enemigos de esa referencia no deben confundirse con diferencias de iluminación.

El capturador ahora pausa el subárbol del juego y deja terminar la aparición de enemigos antes de congelarlos; antes seguían ejecutándose procesos al heredar el modo ALWAYS del capturador.

Validación: auditoría de circulación con 2619 m² conectados, cero muestras sin suelo, cuatro sectores accesibles y mismas 28 formas sustitutas; `validate_city_view.gd` y `validate_aerial_patrol.gd` pasan. La luz principal global y las zonas central/oeste no se rediseñan en esta iteración. La propuesta piloto está integrada en la partida normal. Windows no se reexporta.

## Iteración 20 · dirección de iluminación del distrito completo

La intervención pasa del estudio de la parada a una composición global. Se retiran las luces locales anteriores que generaban lavados circulares; se conservan las dos luces arquitectónicas de la marquesina y la patrulla. Cinco proyecciones recortadas, ancladas al mundo, atraviesan el frente norte, el muro oeste, el retorno este, las estructuras del sur y las caras de la torre. Las aperturas tienen divisiones oscuras y sombras reales. La luz principal baja su ángulo para separar caras y prolongar sombras; las zonas abiertas conservan un fondo tranquilo para leer combate.

`district_lighting.gd` organiza esta composición y restaura luces, ambiente y capas al desactivar la presentación. `district_ink.gdshaderinc` comparte una respuesta por tres valores amplios según la orientación y una base de sombra coloreada. El pavimento, las fachadas principales originales y los volúmenes nuevos adoptan este lenguaje. Las masas de fachadas originales sustituyen el acabado horneado por pigmentos planos; ventanas, publicidad, graffiti, transparencias y texturas de objetos secundarios se conservan. Los edificios distantes nuevos reciben menos contraste y una base gris verdosa. El pavimento pasa a un carbón ciruela y reduce su respuesta a luces rasantes: los focos describen arquitectura sin convertir toda la calle en una mancha luminosa. No se agregan planos de suelo ni obstáculos.

Las proyecciones de composición iluminan exclusivamente geometría del escenario mediante una capa reversible. Esto evita quemar los píxeles del personaje al atravesarlas. Personajes y enemigos siguen recibiendo la iluminación general y el reflector aéreo, cuyo recorrido y calendario se mantienen. Esta separación es deliberadamente artística.

Revisión visual final desde la cámara normal, distancia 50 / inclinación 38 / FOV 38: centro, oeste, este, extremo sur y frente norte en `iteration_20/`. Capturas con combate de Brasa en el este y Sereno en el centro en `iteration_20/combat/`; incluyen fuego, hielo, enemigos y dos fases del reflector. El oeste muestra franjas sobre la fachada y sus salientes; el norte conecta la iluminación de fachada, reja y suelo; el sur permanece más contenido y el reflector revela su cubierta y sombras. Las imágenes `before_*` corresponden al escenario sin el acabado completo, no a la iteración 19.

Validación final: `validate_city_view.gd` pasa con restauración de materiales/visibilidad y colisiones estables; `validate_main_environment.gd` pasa dos ciclos de carga y descarga con partida activa. Siete ejecuciones gráficas finales sin errores ni avisos. La ejecución headless conserva el aviso del sistema de certificados de macOS, ajeno al escenario. Integrado automáticamente en la escena principal. No se reexporta Windows en esta pasada.

## Iteración 21 · bidones y profundidad del pasaje

Se identificó la placa cuadrada como `Drum_Fire`, un plano horizontal importado de aproximadamente 0.71 m situado a 0.9 m sobre `OilDrum_004`. Aparecía como un cuadrado luminoso sólido. Se oculta explícitamente en la presentación del escenario y se restaura al desactivarla. Además se reconstruyen los cuatro bidones del suelo con cuerpos de doce lados, aros, tapa hundida y tapón circular dentro de su envolvente original. Se conservan los obstáculos originales asociados a esos bidones. Se retiran los dos bidones decorativos elevados; uno intersectaba el pretil del cobertizo.

El pasaje norte sustituye los pequeños volúmenes con líneas de neón por tres pórticos en profundidad, paredes laterales, pisos descendentes y ventanas cálidas al fondo. Se ajustaron anchura, altura y separación después de comprobar la oclusión desde la cámara normal: la primera versión quedaba demasiado oculta. La intervención permanece detrás de la baranda existente y no añade colisiones ni invade el área de combate.

Capturas en `iteration_21/`: el grupo de bidones y el centro corresponden a la versión final; norte y este documentan la revisión intermedia anterior al último ajuste de color de bidones y altura de ventanas. `validate_city_view.gd` pasa con restauración de materiales/visibilidad y colisiones estables. Las capturas gráficas terminan sin errores ni avisos. Integración automática en la escena principal; Windows no se reexportó.

## Iteración 22 · contraste, silueta y luz transversal

Diagnóstico: el pavimento ciruela y la iluminación de relleno mantenían gran parte del cuadro en valores medios similares. Los acentos se concentraban en anuncios y pequeños focos, mientras las caras arquitectónicas y las calles seguían planas. Esta pasada introduce una composición de grandes diagonales y sombras, conservando áreas de calma visual.

Dos fuentes altas con aperturas recortadas atraviesan el distrito: luz cálida en el eje central/oeste y mineral fría en el este. La fuente del sur se recoloca para recortar la aproximación a la marquesina y la escalera. Las fuentes proyectan sombras reales sobre suelo, objetos y fachadas; los recortes permanecen anclados al mundo. Se reduce la luz de relleno y se cambia la base del suelo a un carbón frío, con menos emisión constante y mayor respuesta direccional. Las franjas iluminadas y sus sombras se leen desde la cámara habitual sin depender del reflector móvil.

El material arquitectónico usa normales de cara para que las superficies facetadas de la torre se perciban como planos. La respuesta por orientación tiene más separación entre sombra, medios tonos y luz. Los materiales importados secundarios conservan sus texturas, pero reciben copias mates sin metalicidad, brillo especular ni relieve normal que producía destellos. Barreras, etiquetas y elementos emisivos se ajustan para que no se quemen bajo los nuevos focos. La capa de iluminación arquitectónica sigue excluyendo a personajes; las etiquetas también quedan fuera y el identificador de la torre usa un valor gráfico estable.

Las torres de fondo ganan variación de altura, huecos verticales, nervios y balcones asimétricos conectados a sus fachadas. Estas adiciones están fuera del área de combate; no se agregan obstáculos ni superficies de suelo superpuestas. Los bidones corregidos y la retirada de `Drum_Fire` se conservan.

Verificación visual final en `iteration_22/`: centro, oeste, este, norte y sur desde cámara normal. `combat/` incluye cuatro pruebas con 18 enemigos (Brasa en centro/sur; Sereno en este/oeste), habilidades activas y dos fases del reflector en el centro. La vista norte amplia es suplementaria para revisar arquitectura; la composición se evalúa principalmente en las cámaras de combate. Las imágenes `before_*` siguen siendo el escenario sin todo el acabado; para comparar con la pasada anterior se deben usar los `after_*` de `iteration_21`.

Validación: `validate_city_view.gd`, `audit_walkable_yard.gd` y dos ciclos de `validate_main_environment.gd` pasan. Circulación: 2619 m² conectados, cero muestras sin suelo, cuatro sectores accesibles y 28 formas sustitutas. Diez ejecuciones gráficas finales sin errores ni avisos. Headless conserva el aviso de certificados de macOS. Integrado en la escena principal; no se reexportó Windows ni se realizó un perfil de rendimiento en otros equipos.

## Pasada 23 — retirar la franja negra del patio

Se elimina la ranura interior del proyector FoundryCrosslight: producía una banda casi negra diagonal sin un objeto que justificara su silueta. Se conserva la apertura exterior, el contraste de la composición y las sombras reales de la arquitectura y los objetos. No se cambian materiales, colisiones ni iluminación de personajes.

Capturas reales desde cámara de combate en `iteration_23/`: centro y oeste. Ambas ejecuciones gráficas finalizan sin errores ni avisos; la franja desaparece y vuelve a verse el pavimento que cruzaba. Integrado en la escena principal mediante el director existente.

## Pasada 24 — eliminar el contorno circular de incidencia

El círculo del patio procedía de aplicar `district_face` por tramos a la incidencia de luces locales sobre un plano: el umbral angular de 0.65 dibujaba un arco sobre el pavimento aunque no hubiera geometría que lo justificase. El suelo ahora usa una respuesta continua para fuentes locales; las caras arquitectónicas y la luz direccional mantienen su tratamiento gráfico. Las sombras proyectadas, las aperturas y los materiales mates se conservan.

Verificación visual en `iteration_24/`: centro limpio y este con 18 enemigos y habilidades activas desde la cámara habitual. El arco artificial del patio desaparece. Ambas ejecuciones finalizan sin errores ni avisos. Cambio integrado mediante el material compartido; sin cambios de geometría ni colisiones.

## Pasada 25 — continuidad de luz en el distrito

Extendido el criterio de la pasada 24 a fachadas y estructuras: las luces locales conservan una respuesta estilizada con valores amplios, pero interpolan los umbrales de incidencia para evitar bandas dentro de una misma cara. La iluminación direccional conserva sus planos marcados. Se retiran las ranuras internas de los proyectores de norte, oeste, este y sur: dibujaban sombras sin oclusores, incluida la banda que cruzaba STAY HUMAN. Las aperturas exteriores tienen una penumbra corta de cuatro texeles; las sombras reales siguen activas.

La marquesina usa transiciones continuas en su material y en el borde de su luz lateral. La modulación de color del pavimento sur ya no se cuantiza en ocho escalones. El reflector aéreo conserva su apertura octogonal, trayectoria y sombras, pero pierde los anillos internos de intensidad. No se añaden fuentes, obstáculos ni cambios de gameplay.

Capturas en `iteration_25/`: oeste, este, sur y norte limpios; centro con 18 enemigos y habilidades; dos fases del reflector. Revisados desde cámara normal. Cinco ejecuciones gráficas sin errores ni avisos. `validate_city_view.gd` pasa la restauración de materiales y visibilidad, encuadres y colisiones estables; headless mantiene el aviso conocido de certificados de macOS. Integrado en la escena principal, sin nueva exportación Windows.

## Pasada 26 — identidad cromática y luminarias del sur

La parada combina un interior amarillo ácido con una cubierta bañada en fucsia. La luz lateral se sitúa junto a la tira luminosa de su jamba; el foco de cubierta se monta sobre una ménsula conectada a la estructura existente, con poste, carcasa y lente. Se eleva y abre el haz para alcanzar el plano de la cubierta sin concentrarlo en una pequeña mancha ni bloquearlo con el nervio trasero. Un acento emisivo estrecho continúa el borde del techo. El acceso sur adopta índigo contenido, frente al ámbar del patio central; conserva la transición continua de la pasada anterior.

Los dos edificios laterales de servicio incorporan luminarias bajo sus marquesinas, coral y violeta, orientadas hacia los huecos de carga y sus jambas. Una marca explícita permite conservar estas fuentes arquitectónicas al desactivar las luces ambientales antiguas. No se añaden obstáculos en el área de combate.

Capturas finales en `iteration_26/`: parada, sur y este; `combat/` incluye 18 enemigos con habilidades activas junto a la parada. Revisadas desde la cámara habitual, sin errores ni avisos gráficos. `validate_city_view.gd` pasa restauración de materiales, visibilidad y estabilidad de colisiones (aviso de certificados de macOS conocido en headless). Integrado en la escena principal; no se reexportó Windows.

## Pasada 27 — fuentes de color en laterales y fondo

El oeste recupera la luminaria física sobre STAY HUMAN, ahora violeta, y reduce el baño neutro de la fachada. El este enciende la luminaria del banco de refrigeración con coral rosado: se orienta hacia las carcasas y ventiladores y limita su alcance a cinco metros. Ambas fuentes conservan sombras reales. Las fachadas del norte toman coral y la torre turquesa, manteniendo el patio y sus sombras como área de menor saturación.

Los pórticos del fondo tienen tiras coral, rosa y mineral; dos de ellas iluminan sus jambas desde el dintel. Dos torres lejanas incorporan focos ascendentes montados en balcones, con carcasa y lente; las ventanas distinguen edificios con ámbar, lavanda, verde mineral y lima contenidos. Los planos más lejanos conservan menor emisión. No se añaden carteles ni colisiones.

Durante la primera prueba, las nuevas luces con máscara exclusiva provocaron un error de desvinculación del renderer al liberar la escena. Las luminarias pertenecientes a subárboles arquitectónicos ahora conservan la máscara estándar; su orientación y alcance limitan el efecto sobre el combate. Las ejecuciones posteriores del oeste, este, centro, vista del fondo y combate cierran sin errores ni avisos. Dos ciclos de `validate_main_environment.gd` pasan; headless mantiene el aviso conocido de certificados de macOS.

Evidencia en `iteration_27/`: laterales, centro y norte desde cámara normal; vista norte amplia suplementaria para edificios distantes. `combat/after_brasa_east.png` muestra 18 enemigos y habilidades junto a las nuevas fuentes. Integrado en la escena principal, sin exportación Windows ni perfil de rendimiento adicional.

## Pasada 28 — textura de luz y limpieza de sombras artificiales

Los materiales del distrito, pavimento y marquesina incorporan un tramado ordenado muy tenue en la contribución de luz. La trama de 4×4 está anclada a coordenadas del mundo y proyectada sobre el plano dominante de la superficie. Se cuantiza luminosidad relativa (ocho niveles por paso de exposición, mezcla 0.45), no atenuación lineal: la primera prueba lineal producía puntos excesivos con fuentes potentes y se descartó. Se conservan los colores, las transiciones continuas y la oscuridad completa; no se cambia el shader de personajes, anuncios ni interfaz. Es una textura discreta, no un pixelado grueso de sombras.

Retirado el oscurecimiento rectangular adicional del material del sur: la composición de esa zona queda en manos de las fuentes y las sombras geométricas. El volumen del reflector aéreo genera normales suavizadas, atenúa su silueta según el ángulo de visión y reduce su opacidad de 0.045 a 0.018, para evitar la apariencia de una lámina sobre la arquitectura. Se mantienen intactas su luz y sombras proyectadas.

Revisión visual de centro, oeste, este, norte y sur desde cámara de combate en `iteration_28/`. `combat/` contiene 18 enemigos, habilidades y dos fases del reflector. Los registros gráficos finales no muestran errores ni avisos. No se modifican colisiones, fuentes ni elementos de gameplay. La intensidad del tramado se mantiene baja para preservar la lectura y evitar una textura dominante; no se ha perfilado su coste GPU en otros equipos.

## Pasada 29 — pixelado espacial real de luces y sombras

Sustituido el tramado casi imperceptible de la pasada 28 por muestreo espacial de iluminación. Los tres materiales principales escriben `LIGHT_VERTEX` usando una retícula de 20 cm anclada al mundo. Todos los fragmentos de una celda reciben la misma muestra de luz/sombra; aparecen escalones visibles en las sombras de personajes, barreras, equipos y postes, y bloques en las transiciones luminosas. La posición de muestra se proyecta sobre el plano receptor para conservar su profundidad. No se mueve la geometría ni se reduce la resolución de texturas, personajes o interfaz. Tampoco se cuantiza la intensidad, evitando reintroducir anillos de luz.

Referencia de la API: https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html (`LIGHT_VERTEX`, posición modificable para luz y sombras).

Evidencia en `iteration_29/`: centro, oeste, este y sur desde cámara normal; comparar los `after_*` con `iteration_28/`, no con los `before_*` que desactivan todo el acabado. `combat/` muestra 18 enemigos y dos fases del reflector en el este. Cinco ejecuciones gráficas finales sin errores ni avisos. Las sombras en el pavimento muestran claramente la retícula; la paleta y la composición se conservan. No se modifican luces, colisiones ni gameplay.

## Pasada 30 — restaurar siluetas y recuperar el tramado marcado

Retirado completamente el desplazamiento de `LIGHT_VERTEX` de la pasada 29. Las sombras vuelven a sus coordenadas reales; desaparecen los dientes de sierra grandes y las deformaciones de sombras sobre tejados y equipos. La estilización vuelve a actuar sobre luminosidad mediante un tramado ordenado de 4×4 anclado al mundo, con celdas de 12.5 cm, tres niveles por paso de exposición y mezcla 0.9. Es considerablemente más visible que la pasada 28, pero limita el contraste relativo para no reproducir los puntos excesivamente brillantes del primer experimento lineal. La oscuridad completa se conserva y el contorno de las sombras no se altera.

Capturas reales en `iteration_30/`: centro, este y combate con 18 enemigos. Revisadas visualmente; registros gráficos sin errores ni avisos. No hay cambios de geometría, fuentes ni gameplay. Esta pasada reemplaza el pixelado espacial rechazado por el usuario, no lo complementa.
