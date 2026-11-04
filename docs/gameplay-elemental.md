# Gameplay elemental: acciones que se pueden deducir

Implementado el 21 de octubre de 2026. Esta es la referencia actual del comportamiento de
materia, fuerzas y reacciones; sustituye las propuestas incompatibles del documento de etapas.

El programa manipula una materia que conserva identidad, posición, recubrimiento y conexiones.
El jugador elige cuándo crearla, qué hacer con ella, cuándo reaccionar y qué reacción ejecutar.
Una instrucción no cambia de significado a escondidas según una combinación.

## Nada sale de la nada

Revisado el 21 de octubre de 2026, tras la prueba de juego: una esfera de agua que aparecía
completa delante del operador no tenía explicación. La materia ahora tiene un origen visible, un
recorrido visible y un destino visible.

Revisado otra vez el 2 de noviembre de 2026: se retiró la recolección. Tomar del patio no daba
decisiones (en el soak el 88 % del agua se absorbía sola y las reservas de fuego, corriente y
chatarra terminaban llenas cada turno) y ataba las rutinas automáticas a dónde estaba parado el
operador. El origen sigue siendo visible: ahora son sus manos.

1. **El agua ya está en el patio.** Seis cañerías reventadas mantienen un charco lleno cada una
   (`run.SOURCES`). Un charco guarda tragos (`volume`, hasta 3); su tamaño sigue a lo que guarda.
   Las fuentes reponen un trago cada 3 s. Los charcos sueltos se secan a los 45 s, encogiéndose.
2. **Una rutina sale de las manos de su operador.** Al dispararse, el trago corre por el suelo
   desde el operador hasta el punto donde actúa (18 m/s): la lluvia del pupilo del Sereno, el
   brazo de Brasa. Las rutinas funcionan en cualquier punto del mapa; solo esperan si no hay dónde
   ponerlas. La excepción es `on wade`, que trabaja el charco donde está la máquina.
3. **Cada paso se ve ocurrir.** Los pasos se aplican uno por compás (0,28 s): el charco sube en
   esfera, después escarcha, después sale lanzado. Frío, calor, nanitos, impulso y campos salen
   del operador como un haz hacia la materia; el arco, como un rayo desde sus manos. El impulso
   apunta a la máquina más cercana a la materia en el momento de lanzarla.
4. **El agua no se pierde: vuelve al suelo.** Un salpicón, una dispersión, esquirlas que se
   derriten, una esfera que cae o caduca, un vapor que llueve: todo deja un charco donde terminó,
   que se suma a uno cercano (2,8 m). Solo beber (la Novia) y `on wade` se llevan agua.
   La pelea moja el patio donde ocurre, y eso arma trampas para `on wade` y la llama de Brasa.

El patio es de todos (`owner` 0): cualquier jugador o regla puede trabajar su agua.

### Lo que esto permite

- **`on wade`** (WHEN nuevo): cuando una máquina pisa un charco a tu alcance, la rutina usa ese
  mismo charco. `on wade → cold` congela el charco bajo la máquina mojada; `on wade → arc` lo
  electrifica y la descarga salta por todo lo mojado. Los charcos se vuelven trampas.
- **Brasa** pasa su llama a ras de suelo: hierve los charcos que lame en nubes que tapan la vista
  y, al condensarse, vuelven a ser el mismo charco.
- **El Sereno**: sus ánimas son lluvia; cada estallido deja medio trago en el patio para las
  rutinas de todo el equipo.
- **La Novia del canal** compite por el agua: bebe un trago por vez de cualquier charco, también de
  las fuentes, y lo devuelve al suelo al disparar o al caer. Tomar su charco mientras bebe la deja
  sin trago.
- **Hielo del patio**: un charco congelado no se puede tomar (tampoco beber) y hace resbalar; se
  derrite solo a los 9 s. Una placa de hielo en el suelo no es un obstáculo: se pisa.

## Cuatro sustancias, cada una con su oficio

Revisado el 21 de octubre de 2026, tras la segunda prueba: solo el agua tenía trabajo; fuego,
corriente y gravedad existían para actuar sobre ella. Ahora el patio guarda cuatro sustancias y
cada rutina elige cuál vierte (clic en su nodo de origen en el editor: agua → fuego → corriente
→ chatarra; `routine["from"]`, por defecto agua). Cada una actúa sola y sobre las demás. Desde el
2 de noviembre las fuentes del patio ya no son combustible: son peligros que actúan solos.

| Sustancia | Dónde está (`run.STORES`) | Qué hace sola |
|---|---|---|
| Agua | 6 cañerías reventadas | moja, frena, cambia de fase (ver arriba) |
| Fuego | 2 tambores de vigilia ardiendo | prende a la máquina seca que toca (+2 de temperatura, 3 de daño); se consume en 7 s |
| Corriente | 2 transformadores caídos, aún vivos | salta sola a la máquina más cercana a 4,5 m; un trago trae 2 descargas, se gasta una por vez |
| Chatarra | 2 montones de chatarra + lo que dejan los restos | pesa (masa 3), frena 35 %, conduce, guarda el calor y se rompe en metralla |

Las fuentes también actúan solas: una máquina que pasa junto a un tambor se prende, una que se
acerca a un transformador recibe la descarga (se recarga cada 5 s).

**Los depósitos se disparan** (2 de noviembre de 2026; `rules._trip`). La materia que lanza el
equipo hace estallar el depósito que toca, que después descansa 6 s antes de poder volver a
dispararse. El depósito no desaparece:

| Depósito | Lo dispara | Qué pasa |
|---|---|---|
| Tambor | fuego, o chatarra o corriente calientes | se aviva y prende a toda máquina a 3,5 m; después queda bajo y humeando 4 s |
| Transformador | agua, hielo, chatarra, corriente o fuego | se sobrecarga y descarga sobre todo lo que está a 6 m (plasma si fue fuego); queda sin carga |
| Cañería | corriente o materia cargada | la descarga recorre todo su charco y 1,5 m más |
| Cañería | hielo | congela lo que está parado en su charco |
| Chatarra | materia lanzada a 4 m/s o más (`push`, honda de un remolino) | revienta en metralla: hasta 8 de daño a 3,5 m, y empuja |

Así el patio pesa sin ser requisito. Llevar la pelea hacia un depósito y lanzarle lo justo es una
jugada, y las rutinas funcionan igual lejos de ellos. Cada máquina destruida deja
medio trago de chatarra donde cayó; dos caídas juntas hacen un montón.

**Los mismos pasos, otro resultado.** `heat` aviva el fuego (+4 s), pone la chatarra al rojo y
convierte la corriente en plasma (que además prende). `cold` apaga el fuego (humo, no queda nada),
y la corriente fría salta más lejos (+2,5 m). `raise` hace bola de fuego, rayo en bola o bola de
chatarra; `wall`, muro de llamas, valla viva o barricada sólida; `push` los lanza; `drop` prende
el suelo, descarga a todos debajo o aplasta. Los THEN también: `release` suelta chispas que
prenden a 4 m, descarga en cadena o metralla; `scatter` estalla en llamas, en descarga o en
metralla.

**Reglas nuevas, sin agua de por medio** (`rules.gd`):

- **El fuego se propaga.** Una máquina ardiendo prende a la seca que está a 1,9 m, un paso por
  compás. Una máquina que ya ardió queda chamuscada 8 s y no vuelve a prender: el fuego atraviesa
  la manada una vez, como un frente. Lo mojado no prende: se seca y le roba combustible al fuego.
- **La corriente busca tierra** en vez de esperar contacto, y recorre agua, chatarra, fuego y
  corriente que toca.
- **Materia contra materia.** El agua apaga el fuego que toca y hierve; el vapor lo sofoca. El
  fuego calienta la chatarra (al rojo en dos compases) y la corriente (plasma). La chatarra al rojo
  hierve el agua y se enfría. Cualquier cosa a +2 detona los nanitos que toca, y una descarga que
  pasa por materia con nanitos los detona: `coat` sobre fuego es una bomba de mecha corta, una
  barricada con nanitos junto a un tambor es una mina.

Combinaciones que salen solas: un muro de chatarra junto a una lengua de fuego queda al rojo y
quema a lo que lo empuja; corriente lanzada a una manada mojada en un charco la recorre entera;
un charco entre el fuego y tu barricada la protege; chispas a una manada seca la prenden y el
fuego pasa de una máquina a la siguiente.

## Controlar el programa en la partida (4 de noviembre de 2026)

Queja: todo se dispara solo y el programa se siente como algo que corre en segundo plano.

**El programa se ve correr** (`spellwork.beat`, `hud._on_beat`). Cada vez que el host aplica un
paso de una rutina, envía un pulso a quien la programó y la pieza se enciende en el programa de la
esquina en ese mismo instante: el WHEN al disparar, el cable mientras la materia cruza, cada DO al
actuar (gris con borde rosa si no cambió nada), el THEN en espera sobre una placa quieta y su
destello al soltarse. No es una animación aparte: es el mismo instante en que la materia cambia.

**On cue, el WHEN que disparas tú** (`run.cue`, `_placement "mano"`). Un clic (o Espacio) marca un
punto del suelo; en el siguiente tick salen juntas todas las rutinas *on cue* listas, en ese punto
y hasta 13 m de ti (un clic más lejos se trae al borde). Recarga 4 s; un clic sin nada listo se
pierde, no espera. Quien hace clic ve al instante cuatro esquinas en el suelo cerrándose sobre el
punto: ámbar si respondió una rutina, gris si no. El programa inicial trae una: *on cue › arc*, un
charco cargado donde apuntas. El piloto del soak hace clic sobre la máquina más cercana cada
segundo.

**Condiciones: if wet, if hot** (`Recipe.GATES`, `spellwork.gate`). Son DO que no tocan la
materia: cuando les toca, preguntan por la máquina más cercana a ella (4 m). Si está mojada (o
caliente), el DO siguiente corre; si no, se salta. *on crowd › agua › if wet › arc* moja al grupo
la primera vez y lo electrocuta cuando vuelve mojado. En el programa de la esquina la condición se
enciende si dijo que sí y, si dijo que no, ella y el DO saltado se apagan con borde rosa. No van
en el arma, no suman recarga y una condición al final de la fila es un error («no tiene un DO
detrás que decidir»).

**Lo que cambias se prueba solo** (`run._note_changes`, `run._run_trials`). Al cerrar el taller
o elegir pieza, cada rutina que cambió corre una vez al reanudarse (una cada 0,45 s), donde su
WHEN la pondría o, si no puede decirlo, sobre la máquina más cercana o unos pasos delante. Va por
cuenta de la casa: no gasta la recarga. El taller sigue siendo una pausa real: la cámara lenta se
descartó porque en multijugador el host pausa para todos y Esc tiene que seguir parando.

**Combos entre rutinas** (`spellwork.linked`, `hud._on_combo`). La materia guarda qué rutina la
hizo (`record["routine"]`). Cuando la de dos rutinas distintas de un mismo jugador reacciona entre
sí (fuego apagado en agua, hielo derretido, metal al rojo que hierve agua, vapor que ahoga fuego,
carga que cruza materia de otra rutina o revienta sus nanitos), el programa une con un trazo
ámbar los números de esas dos filas durante 0,9 s. A lo sumo una vez por segundo por pareja. Soak:
de 3 a 18 por turno según la build.

La máquina también cuenta como puente: el agua de una rutina deja su marca en lo que moja
(`spellwork.wet_by`), y si otra rutina la electrocuta o la congela mientras sigue mojada
(`spellwork.wet_and`), el combo une esas dos filas. El rayo de un arma no acredita a nadie.

## Tercera pasada: cargar menos, gravedad con peso, ataque programable

Revisado el 21 de octubre de 2026, tras la tercera prueba. Tres quejas: recolectar del patio era
excesivo (cada rutina exigía estar al lado de un tambor), la gravedad no se entendía ni tocaba a
las sustancias, y el ataque básico de cada agente estaba roto.

**Lo que llevas encima** (retirado el 2 de noviembre de 2026). Hubo una reserva de hasta 3 tragos
por sustancia que se reponía sola, absorbía la materia del patio al pasar y sumaba la chatarra de
los restos, con cuatro glifos sobre el programa. Se quitó junto con la recolección: las rutinas
vierten desde las manos (ver «Nada sale de la nada»).

**La gravedad se ve** (22-10-2026; `materials.gd` «Gravity is a whirlpool», `world._pull_toward`,
`world._release`, `spellwork._forces`, `spellwork._let_go`, `rules._ring`). La versión de la tercera
pasada tiraba según la masa del emisor, tragaba materia y aplastaba con dos máquinas a 1,8 m:
números ocultos. La pasada de Codex la cambió por un cauce rectangular de flechas, legible pero
sin nada de gravedad (una cinta transportadora) y con `repel` acercando máquinas al operador.
Ahora:

- **`attract` es un remolino de 5 s.** La materia gira en un anillo de 2,4 m y arrastra a él
  todo lo suelto a 6 m, máquinas y materia, en sentido antihorario visto desde arriba (siempre el
  mismo, así se aprende hacia dónde saldrá todo). Lo que gira **toca la materia del anillo** cada
  compás: el agua empapa, el fuego prende, el vapor escalda y la chatarra o el hielo muelen por su
  peso (1 de daño × masa). En el centro y fuera del anillo no pasa nada: no hay daño por cercanía.
- **Al terminar, lo suelta todo.** Lo que va en el anillo sale despedido a lo largo de él (honda) y
  choca con lo que pille; la materia del corazón estalla como `scatter` (el agua salpica, el fuego
  se esparce ardiendo, la chatarra y el hielo se rompen contra lo que hay alrededor, la corriente
  descarga). Un muro con remolino es solo su eje y queda en pie.
- **`repel` es una onda y una burbuja.** Un frente sale de la materia a 10 m/s hasta 6 m; lanza
  una vez lo que alcanza (11 m/s al lado, 7 m/s al borde), y lo lanzado choca con lo que pille.
  Después, 4 s de burbuja de 3 m donde no vuelve a entrar lo que ya lanzó.
- **La misma fuerza para todo.** El peso se nota en lo que golpea lo lanzado, no en cuánto tira.
- **Visible:** brazos violetas finos (la gravedad) que se enroscan hacia el anillo; el anillo, en
  el color de su materia y girando a la velocidad real; el frente de la onda en el color de la
  materia y la burbuja violeta clara. El taller dibuja lo mismo a escala.
- Lo que vuela baja al borde del remolino; un salto o una embestida se desvían hacia él.
- **Una máquina lanzada contra otra golpea a las dos** y empuja a la segunda (masa × velocidad ×
  0,45, hasta 9 de daño). El equipo nunca es un bolo.

Combinaciones que salen solas: un remolino de agua junto a un transformador hace que la corriente
salte por todos los mojados que giran; uno de fuego junto a una barricada de chatarra la pone al
rojo y la manada pasa por las llamas; un remolino que atrapa el charco del Sereno lo lleva en el
anillo; soltar el remolino junto a un muro estrella la manada contra él.

**El ataque básico se programa** (`attack.gd`, `build["attack"]["steps"]`, `run.strike`).
El arma de cada operador es su propia materia: la llama de Brasa (abanico de 6 m, 3,2 de daño
cada 0,14 s; antes 3 de daño cada 0,12 s a 7 m, prendiendo en cada tick) y las ánimas del Sereno
(5 de daño cada 0,45 s a la máquina perseguida, 60 % al resto del salpicón; antes 6 a todas). Sin piezas, la llama solo daña y calienta un paso lo que toca, y
las ánimas solo dañan y empapan. Hasta 3 piezas DO de la misma caja se enchufan en la fila
«A» del editor, encima de las rutinas, y cada una añade algo a cada golpe:

| Pieza | En la llama de Brasa | En las ánimas del Sereno |
|---|---|---|
| `heat` | avivada: prende al primer golpe | ánimas tibias: secan y calientan; dos veces, vapor que quema y no empapa |
| `cold` | templada, y con dos, chorro helado que congela lo mojado | granizo: enfría y luego empapa, así que el segundo golpe congela |
| `arc` | cada golpe descarga y salta 2 (o 3) máquinas por lo mojado y el metal | igual: con lo que empapa, la cadena llega lejos |
| `push` | empuja; dos veces, lo bastante fuerte para que choque contra otra | igual |
| `attract` | junta a las golpeadas hacia el blanco: arma grupos para «grupo» y para los remolinos | igual |
| `repel` | aparta todo lo que toca lejos de ti | igual |
| `raise` | alcanza lo que vuela | alcanza lo que vuela, 3 m más lejos |
| `wall` | deja fuego en el suelo donde golpea, como mucho cada 2,5 s | deja un charco, como mucho cada 2,5 s |
| `coat` | planta nanitos que estallan al caer la máquina o al arder | igual |
| `drop` | detrás de `raise`: cada 1,6 s alza una bola de fuego sobre donde va el blanco y la deja caer; su sombra y su alcance se ven en el suelo. Golpea a 1,8 m (9 de daño al centro), prende un paso y derriba lo que vuela debajo | igual, con una esfera de agua (10): empapa a todos los que pilla y deja un charco; si el arma es granizo, cae granizo |

Lo extra de un golpe cae en cada máquina como mucho una vez cada 0,5 s, por rápido que dispare
el arma: el daño sigue siendo de cada golpe. Las combinaciones salen solas: `coat` con la llama
caliente detona en cadena; `push` dos veces lanza máquinas contra un muro o contra otras; `cold`
en las ánimas congela; `attract` en el arma junta a la manada justo donde caerá un remolino. Una pieza en el
arma es una pieza que no está en una rutina: esa es la decisión.

Lo frío (temperatura < 0) además frena 20 % a la máquina.

**Afinado (21-10-2026).** El soak (`tests/survivor/soak.tscn`, `seed=N` para otra semilla, `support`
para el Sereno, `attackfirst` para llenar el arma antes que las rutinas) se promedia en tres
semillas (8026, 311, 7), porque una sola es caótica: un cambio chico voltea una partida entera.
Antes del afinado el Sereno ganaba el turno completo y Brasa caía a los 150-170 s; el salpicón
dañaba entero a toda la manada y los bolos llegaban a 12. Supervivencia media tras el afinado:

| Piloto | Rutinas primero | Arma primero |
|---|---|---|
| Brasa | 203 s | 233 s |
| Sereno | 193 s | 212 s |

Programar el arma rinde más que no hacerlo con los dos operadores, y ninguno gana solo el turno
con el piloto automático. Bajar los nanitos a 5,5 se probó y se descartó: hundía a Brasa con arma
(173 s) sin acercar a nadie.

## Materia y energía

La única materia es agua, y se toma del patio (ver arriba). Hielo y vapor son sus fases; calor, frío, electricidad y gravedad son
acciones o propiedades, no fuentes de materia diferentes. El nodo `heat` conserva la clave interna
`fire` para no romper las rutinas existentes. No se agregaron tierra ni fuego autónomo.

| Instrucción | Resultado deducible |
| --- | --- |
| `raise` | Recoge agua o hielo en una esfera y la sostiene sobre el suelo. Eleva una nube de vapor. No crea paredes. |
| `wall` | Da forma de muro apoyado en el suelo: cortina de agua o barrera sólida de hielo. Vapor y esquirlas no pueden sostenerlo. |
| `cold` | Vapor → agua → hielo → hielo endurecido. Conserva la suspensión: condensar una nube sostenida devuelve una esfera. |
| `heat` | Hielo → agua → vapor → vapor hirviendo. El hielo se derrite, no se hace añicos por calor. |
| `push` | Impulsa la materia en dirección a la máquina. Una esfera vuela; una placa se desliza; una nube deriva; esquirlas salen disparadas. |
| `drop` | Libera materia suspendida. Agua cae y moja; hielo cae, golpea y se fragmenta; vapor condensa en lluvia. No levanta antes un charco que ya está en el suelo. |
| `arc` | Carga eléctrica, hasta dos unidades. Descarga y conduce por agua, metal y cuerpos mojados; la descarga consume carga. |
| `coat` | Añade nanitos explosivos; una segunda aplicación aumenta su carga. No los detona. |
| `attract` | Remolino de 5 s: lo suelto a 6 m gira en un anillo de 2,4 m de esa materia; al terminar lo lanza todo y la materia estalla. |
| `repel` | Onda hasta 6 m que lanza una vez lo que alcanza; luego 4 s de burbuja de 3 m. |

Repetir una instrucción sin efecto se muestra como aviso, y los siguientes pasos siguen funcionando.
El servidor puede impedir congelar o formar hielo si el volumen sólido estaría ocupado.

## Fuerzas y contacto

Remolino y onda aplican la misma ley a materia libre y máquinas (`Catalog.orbit_velocity`,
`Catalog.blast_velocity`), con la misma fuerza para cualquier materia. La fricción y la geometría
siguen afectando el desplazamiento. Los muros, las fuentes y la materia que sostiene un campo están
anclados; agua, hielo suelto, esferas, vapor, fuego, corriente y chatarra sueltos responden. Los
especialistas que vuelan o saltan conservan sus respuestas propias. El disco del campo se dibuja
con el alcance real, el anillo a su radio real y girando a su velocidad real.

La electricidad no convierte un campo gravitatorio en un imán oculto. Ambos efectos coexisten:
atraer acerca cuerpos, y la carga descarga cuando se cumplen sus propias condiciones.

Agua en contacto moja, incluso suspendida. Frío sobre un cuerpo mojado lo congela temporalmente;
calor lo seca. Vapor normal empuja y oculta; vapor hirviendo además quema. Un impacto de materia
lanzada depende de masa y velocidad. El agua lanzada salpica y vuelve al suelo; hielo lanzado se
quiebra. Fragmentar, congelar o calentar no cambia el dueño ni crea una referencia nueva.

## Reacciones: momento explícito + acción

En el taller, el botón de la reacción permite elegir **al contacto**, **al romperse**, **tras 2 s**
o **al recibir pulso**. La elección pertenece a la rutina y no consume una pieza. El servidor la
valida y la replica. Las rutinas antiguas sin `on` usan contacto; no existe un disparador secreto
según el material. El taller avisa si se pide rotura de agua/vapor o detonar sin nanitos.

| Acción | Efecto |
| --- | --- |
| `release` | Libera la materia: hielo en esquirlas dirigidas, agua en salpicón, vapor en ráfaga. |
| `scatter` | Dispersa alrededor: agua moja y empuja; hielo golpea con esquirlas; vapor empuja y solo quema si está hirviendo. |
| `detonate` | Detona exclusivamente el recubrimiento de nanitos. Sin recubrimiento no produce explosión. El agua o vapor base permanece. |
| `relay` | Envía un pulso a la siguiente rutina activa conectada. Solo dispara una reacción configurada «al recibir pulso». Sin ella no inventa una acción. |
| `converge` | Atrae durante un segundo y luego dispersa según las propiedades de la materia. |

`release`, `scatter`, `relay` y `converge` no detonan nanitos implícitamente. Un salpicón de `release`
tiene un pequeño impacto; `scatter` de agua moja y empuja sin daño explosivo gratuito.

## Ejemplos

- `raise → cold → push`, reacción `release / al romperse`: esfera de hielo lanzada que libera
  esquirlas al impactar. Es la rutina inicial.
- `raise → arc → push`, reacción `scatter / al contacto`: esfera de agua electrificada que moja
  y dispersa; descarga antes de que la reacción consuma la materia.
- `wall → cold`: barrera deliberada, anclada y sólida.
- `raise → heat → cold`: agua suspendida que hierve y vuelve a condensarse sin perder la altura.
- `attract → coat`, reacción `detonate / tras 2 s`: atrae enemigos hacia una carga visible y la
  detona después del tiempo elegido.
- `raise → cold → drop`: cae el hielo que elevaste y se rompe contra el suelo.

## Contrato del editor y validación

`recipe.gd` produce el texto y el estado tras cada instrucción; el host compila cada paso con ese
mismo modelo y vuelve a validar la operación. La vista usa esferas reales con colisión esférica
para hielo, flujo superficial para agua y sombra de contacto para leer la suspensión.

Pruebas dedicadas: `tests/survivor/water.tscn` comprueba el origen y el destino del agua: espera
sin agua, toma un trago, el agua corre antes de llegar, un paso por compás, conservación del
volumen, residuos de salpicón y esquirlas, fusión de charcos, hielo del patio que se derrite,
fuentes que se rellenan, vapor que llueve, `on wade` y la Novia. `tests/matter/validate_bending.tscn` recorre todas las parejas de instrucciones
y cadenas de varios pasos, comparando material, forma, suspensión, movimiento, temperatura,
carga, gravedad y recubrimiento con el mundo. También prueba impactos y campos. La escena
`tests/survivor/bending_reactions.tscn` prueba los momentos de reacción, daño según material,
señales, nanitos, contacto térmico y la edición del disparador mediante un clic real de UI.

El equilibrio de combate cambia: las esferas ocupan menos espacio que los muros y dispersar agua
ya no causa una explosión genérica. Requiere valoración jugando; las comprobaciones automáticas
verifican comportamiento, no sustituyen una prueba de comprensión con jugadores.
