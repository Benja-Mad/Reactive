# Qué probar del control por clic (4–5 nov 2026)

Todo esto se hizo sin que nadie lo jugara. Se verificó con pruebas, soak y capturas, pero no se
sabe cómo se siente. Cada punto dice qué hacer, qué deberías notar y qué decidir. El detalle está
en `gameplay-elemental.md`, en la sección de control.

## En partida

1. **Marcar.** Haz clic sobre una máquina. Las esquinas del clic se cierran sobre ella y quedan
   cuatro esquinas ámbar gruesas. Tus rutinas que eligen máquina la toman primero mientras esté
   en alcance, y las que llevan media recarga o más salen hacia ella en el acto (lo que se saltan
   lo pagan en la siguiente).
   *Decidir:* ¿se nota que el programa obedece la marca? ¿Que salgan todas a la vez sobre la marca
   se siente como respuesta, o como perder el escalonado? (En el soak, ahora determinista, no
   cambia la supervivencia.)
2. **THEN al clic.** Pon una rutina con el momento «al hacer clic». Lo que arma queda quieto con
   esquinas tenues. Cuando lo da por armado, se vuelven ámbar con un brillo que se oye. Un clic
   cerca lo suelta. Si lo que suelta es un lanzamiento (hielo, vapor o chatarra con *release*),
   va hacia la máquina donde hiciste clic, con una línea de puntos antes y un hilo ámbar al
   soltar.
   *Decidir:* si pasan 6 s sin clic, la trampa salta sola al contacto. ¿Debe quedarse así o
   perder su THEN? Una lectura de diseño propone quitarlo para que el clic importe. Medido el 5 nov
   (8 semillas, un piloto que suelta a tiempo frente a otro que hace clic a ciegas): con la regla
   de hoy, a tiempo saca 14 s de media (204 frente a 190 s); si la trampa caducada pierde su THEN,
   saca 18 s (199 frente a 181 s). Una misma semilla oscila 100 s entre condiciones, así que el
   soak no lo decide: hay que jugarlo.
3. **La placa.** Haz clic en una fila del programa (abajo a la izquierda): se pausa y se abre el
   taller en esa rutina. Espacio hace lo mismo si moviste el puntero hace poco. Con una máquina
   detrás, la placa se vuelve medio transparente.
4. **Lo que derriba tu programa.** Cuando el golpe de una rutina remata a una máquina, el número de
   esa fila se enciende ámbar, sale un aro del pecio y suena
   un combo agudo y suave. Pasa en cerca del 17 % de las muertes con
   support y del 19 % con showcase, porque el arma suele dar el último golpe. Cuentan el golpe,
   el arco, el calor y la quemadura de la rutina, y el choque de una máquina lanzada por su remolino.
   *Decidir:* ¿debe el programa pesar más que el arma? El arma hace el 52 % del daño de media.

## Menos texto

- Ya no hay números de daño flotando, ni palabras bajo las filas del taller, ni tiras de huecos
  en las ofertas de nivel, ni teclas impresas.
- Los números 1, 2, 3 de la placa se quedan: son lo que se enciende en combos y remates.

## Quedan para ti

- Si un invitado puede editar su programa sin que el anfitrión pause. Hoy solo se edita en pausa
  o al subir de nivel, y cada rutina cambiada se ensaya una vez gratis al reanudar. Se probó
  limitar ese ensayo a uno por recarga y se descartó: el soak se apoya en él tras cada mejora
  (una semilla bajó de 300 a 213 s).
- El sonido: todo se afinó midiendo, sin escucharlo.
