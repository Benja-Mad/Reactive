# Interacciones de Reactive — diagnóstico y rediseño, 21 de octubre de 2026

## Fase 0. Base observada antes de editar gameplay

Se leen `gameplay-elemental.md`, `diseno-rutinas-propiedades.md`, los registros de materia,
la simulación de recetas, reglas, armas, enemigos, editor y HUD. El árbol inicial contiene trabajo
extenso del autor, incluso los scripts survivor sin seguimiento. No se hacen commits ni reversiones.
Las capturas nuevas y los logs quedan en `authored/interactions_20261021/`.

El diagnóstico no es «todo es falso»: las esferas tienen barrido de colisión, las paredes bloquean,
las fuentes pierden volumen y el agua vuelve al suelo. Hay una base espacial aprovechable.

| Familia existente | Qué se entiende mirando | Qué exige texto o memoria | Decisión |
|---|---|---|---|
| Tomar, elevar y lanzar agua/hielo | Chorro desde fuente, esfera, impacto y restos | Demora entre pasos y fuente elegida | Conservar; simplificar instrucciones |
| Charco y escarcha | Superficie mojada / helada | Congelación del cuerpo depende de un estado mojado previo | Conservar contacto; mostrar recorrido |
| Calor y vapor | Cambio de fase y nube | A veces el calor de una fuente no actúa sobre materia: `_contact` excluye todas las fuentes | Hacer que el escenario participe |
| Fuego que se propaga | Máquinas que se encienden | Intervalo, inmunidad a reencendido y combustible | Conservar límites internos; dejar quemadura |
| Corriente | Arco y luz amarilla | No recorre conductores si no hay primero una máquina cerca del origen; arcos saltan centros y paredes | Recorrer conexiones reales desde el origen |
| Chatarra | Montón, barricada y esquirlas | Multiplicador de gravedad por material y metal frío «más metralla» sin implementación correspondiente | Conservar peso para impactos; retirar promesas falsas |
| Atracción/repulsión | Un círculo violeta; el grupo se mueve | Fuerza por masa del emisor, absorción a 0,9 m, daño con 2 cuerpos a 1,8 m | Sustituir por una pendiente dirigida |
| Ataque A | Llama / ánimas | Diez DO con otro significado, frío vuelve llama helada, drop duplica daño sin caída, gravedad es shove instantáneo | Restringir a operaciones físicas que puedan verse |
| WHEN/THEN | La secuencia en taller | eco + relay + momento de reacción + converge duplican coordinación | Dejar compatibilidad, reducir vocabulario ofrecido |
| Reserva | Cuatro iconos con tres barras | Compite con rutinas por los charcos que deberían funcionar como trampas | Mantener recarga pasiva; evitar recoger materia activa |

Las capturas `before/attack/05…` y `06…` muestran casi la misma disposición para arrastre y prensa:
el daño solo se deduce de flashes. `02_workshop_scrap_well` desborda el panel con el texto de reglas.
Los anillos sí existen (no es literalmente invisible el campo), pero no describen la dirección local
ni distinguen un movimiento de una zona que hace daño. La escena de sustancias comprueba la
legibilidad del fuego y la barricada antes del cambio. Las suites originales se guardan completas.

Hay contradicciones de documentación: la sección antigua «Materia y energía» niega fuego autónomo;
`Build.MAX_STEPS` permite cuatro DO aunque el encargo especifica tres; el editor promete metralla
extra al enfriar chatarra sin que `impact` consulte el frío. Se corrigen las promesas, no se inventan
multiplicadores para justificarlas.

## Fase 1. Principios antes de implementar

1. Una fuerza enseña su dirección **antes** de mover. Huella y alcance visuales usan la misma
   geometría que el host. Nada pierde vida por estar cerca de otra cosa sin contacto o recorrido.
2. El material determina qué deja el desplazamiento: agua moja/apaga, fuego prende/calienta,
   corriente encuentra un camino, metal obstruye/conduce/golpea. El color no es el único indicador.
3. Propiedades numéricas quedan como implementación de calor y energía, no como reglas secretas
   que el jugador deba calcular. Masa explica el impacto; no aumenta la gravedad del emisor.
4. La materia del compañero y del patio participa con las mismas reglas. No se exige sincronizar
   menús ni recoger cuatro recursos activamente para tener un arma útil.
5. Menos piezas disponibles, con un significado espacial consistente. Conservar programas antiguos
   no exige seguir ofreciendo cada pieza histórica. Un retiro debe explicar y devolver piezas.
6. Pruebas de lógica y réplica no prueban comprensión humana. La inspección visual se registra
   por separado y no se presenta como una prueba con jugadores nuevos.

### Alternativas de gravedad

Evaluación de diseño previa, no resultados medidos. Alta/media/baja expresa cuánto facilita cada
alternativa cumplir el criterio con la cámara fija y la simulación actual.

| Alternativa | Causa ≤1 s / predicción | Combinatoria | Residuo / cooperación | Coste y riesgo |
|---|---|---|---|---|
| Pendiente dirigida | Alta: carril y flechas de entrada a salida | Agua que corre, combustible transportado, cable móvil, ariete | Alta: entrega materia a trampas de otro operador | Bajo: fuerza continua y geometría rectangular compartida |
| Lente de trayectorias | Media: arco curvo legible, difícil anticipar el destino sin guía | Excelente con proyectiles de ambos | Media: no explica materia quieta; exige balística nueva para llama y ánimas | Alto: igualar daño, vuelo y dibujo de dos armas |
| Órbita | Alta en campo vacío, media con manada | Anillo cortante / barrera / agua móvil | Alta, pero quién queda atrapado y quién sale necesita otra decisión | Medio-alto: captura/liberación, colisiones y radio |
| Levantar y soltar | Alta: altura + sombra | Agua, hielo y metal; fuego/corriente poco ganan | Alta para caída compartida | Medio: buena segunda familia, no reemplaza transporte lateral |

**Elección: pendiente dirigida.** `attract` pasa a `flow`: coloca un carril de 12 × 4 m,
centrado en la materia, orientado hacia la amenaza al ejecutar el paso. `repel` invierte el flujo
sobre el mismo carril. Ambos duran 5 s; las flechas indican el sentido, límites laterales indican
la zona. No se deforma la malla del patio: el efecto mágico inclina la gravedad local. Fuentes,
muros y el emisor quedan anclados. El carril es inmóvil durante su vida y no persigue enemigos.
Se eliminan absorción del centro, multiplicador de fuerza según sustancia y daño automático de
prensa. Los choques reales y peligros del escenario conservan sus propios efectos.

No se implementan lente ni órbita en esta pasada: introducir tres modelos de gravedad aumentaría
la carga que se está intentando reducir.

### Catálogo nuevo: ve → espera → ocurre

| Interacción | El jugador ve X → espera Y → ocurre Y | Dos combinaciones distintas | Residuo |
|---|---|---|---|
| Flujo / flujo inverso | Flechas en un carril y materia suelta → viaja en ese sentido → atraviesa el carril y conserva impulso | Agua apaga fuego; chatarra choca o conecta corriente; máquina llega a peligro | Materia desplazada y estela por sustancia |
| Agua transportada | Charco que avanza hacia llamas → las apaga → vapor que vuelve a agua | Escarcha como suelo; agua como puente eléctrico | Charco / vapor / escarcha |
| Fuego autónomo | Combustible en llamas toca metal o agua → metal al rojo o fuego apagado → calor o vapor | Barricada caliente; máquina empujada a tambor arde | Quemadura del combustible agotado |
| Circuito | Fuente chispeante, agua o metal conectado y blanco al final → descarga por ese camino → arco recorre cada enlace real | Chatarra prolonga camino; agua alcanza grupos; mover conductor abre/cierra circuito | Conductores permanecen, marca de descarga |
| Barricada | Metal sólido entre perseguidor y operador → lo frena → golpea el obstáculo | Fuego lo calienta; corriente lo usa; flujo lleva cuerpos contra él | Restos de metal |
| Arma con push | Sale un impulso desde el golpe → el cuerpo sale en esa dirección → choca o entra en una superficie | Fuego del patio; charco del Sereno; metal sólido | Restos del choque o superficie usada |
| Arma con wall | Chorro de su elemento termina en suelo → queda una superficie → fuego/agua actúa allí | Agua apaga y conduce; fuego prende y calienta metal | Charco o combustible, sin pieza de inventario adicional |
| Arma con arc | Arco desde el arma al primer blanco → corre por conductores → sigue un camino visible y se detiene ante aislantes | Máquina mojada del Sereno; metal del patio | Luz de carga / marca al descargar |

Agua y fuego no son intercambiables: extinguir permite atravesar una trampa pero quita combustible
al compañero; convertir agua en vapor rompe un puente conductor y oculta visión. Transportar
chatarra acerca un ariete o termina un cable; el campo por sí solo no crea daño.

### Reducción de capas acordada para implementación

- A admite `push`, `wall` y `arc`; las operaciones de fase, forma, nanitos y gravedad pertenecen
  a materia de rutinas. Se retiran afijos de ataque con significado distinto al verbo de materia.
- Tres DO por rutina nueva. Programas heredados se normalizan conservando sobrantes en la caja.
- `eco`, `cadena` y `colapso` se conservan para cargar programas antiguos, pero no se ofrecen al
  subir de nivel. Contacto, rotura y tiempo continúan explícitos; pulso sirve a programas heredados.
- El ataque básico sigue siendo gratuito. Dejar superficie con `wall` usa el flujo del arma y una
  cadencia visible, sin competir con la reserva de rutinas.
- Mantener el compás de reacciones como presupuesto técnico (0,5 s); no añadir medidor ni menú.

## Fase 2. Rebanadas y registro de cierre

Cada rebanada debe cerrar lógica host, réplica, efectos, texto, pruebas y captura antes de continuar:

1. Pendiente, choques y residuos de movimiento.
2. Circuito autónomo y contacto térmico con el patio.
3. Arma y editor con menos significados, migración sin pérdida.

Los resultados, ajustes por inspección, tabla de soak y limitaciones se incorporan debajo al acabar.

## Revisión del 22 de octubre: lo que se mantiene y lo que se cambia

La pasada se revisó contra su propio criterio («ve X → espera Y → ocurre Y») y contra la dirección
de arte del proyecto. Se mantiene:

- **El circuito por conductores reales** (`rules._conduct`): la corriente recorre agua y metal
  desde su origen sin necesitar antes una máquina pegada, y las paredes cortan el arco.
- **El patio participa:** el agua apaga un tambor 4 s (se ve apagado) y el metal se pone al rojo
  junto a él.
- **Se retiran la absorción y la prensa ocultas.**
- **Las marcas de quemadura y descarga en el suelo**, ahora con alfa en escalones duros como el
  resto de las marcas de pixel art.

Se cambia:

- **El cauce de flechas.** Era legible, pero no se veía ni se comportaba como gravedad: era una
  cinta transportadora. Con `repel` invertido, además, traía máquinas hacia el operador. Las
  chevrones blancas sobre una losa gris se leían como señalética de interfaz, no como magia del
  patio. Lo reemplaza el remolino que suelta y la onda con burbuja (ver
  `gameplay-elemental.md`, «La gravedad se ve»). La alternativa «órbita» de la tabla de arriba,
  descartada por el coste de decidir quién sale, se resuelve soltándolo todo al final: nadie
  queda atrapado.
- **No se recorta el ataque A a tres piezas.** Las piezas del arma ya leen la misma palabra que en
  una rutina y quitar opciones no lo hace más creativo. `drop` en el arma doblaba el daño sin
  que nada cayera; ahora es la misma palabra que en una rutina: solo cae lo que se elevó, así que
  va detrás de `raise`, y lo que cae es una bola de la materia del arma que sube desde las manos
  del operador, proyecta su sombra y su alcance en el suelo durante 0,7 s y golpea a todo lo que
  pille debajo (también lo que vuela, que cae con ella). Es un golpe del arma: lleva su calor, su
  frío, su carga y sus nanitos.
- **Presupuesto de reacciones.** Con la manada y los charcos de una partida real, el tope de 24
  reacciones por compás se agotaba cientos de veces por turno (hasta 1.679 con el Sereno con
  arma). Las reacciones descartadas son exactamente lo contrario de predecible. Los contactos que
  no cambian nada ya no cuentan (`rules._settled`) y el tope pasa a 64.

Pruebas: `tests/survivor/gravity.tscn` (contrato del remolino y la onda) reemplaza a `flow.tscn`.
Capturas: `tests/survivor/gravity_look.tscn` → `authored/gravity_20261022/`.

Soak de tres semillas (8026/311/7), supervivencia media en segundos, antes y después de corregir el
presupuesto:

| Configuración | Antes | Después |
| --- | --- | --- |
| Brasa sin arma | 177 | 176 |
| Brasa con arma | 217 | 222 |
| Sereno sin arma | 188 | 188 |
| Sereno con arma | 240 | 225 |

Los dos personajes quedan a menos de 10 s entre sí en cada configuración. El soak destapó además un
fallo del repartidor: chocaba contra una máquina que había muerto a mitad de embestida
(`enemy_repartidor.gd`).
