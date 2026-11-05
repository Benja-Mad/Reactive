# Qué probar del control por clic (4–5 nov 2026)

Todo esto se hizo sin que nadie lo jugara. Se verificó con pruebas, soak y capturas, pero no se
sabe cómo se siente. Cada punto dice qué hacer, qué deberías notar y qué decidir. El detalle está
en `gameplay-elemental.md`, en la sección de control.

## En partida

1. **Marcar.** Haz clic sobre una máquina. Las esquinas del clic se cierran sobre ella y quedan
   cuatro esquinas ámbar gruesas. Tus rutinas que eligen máquina la toman primero mientras esté
   en alcance.
   *Decidir:* ¿se nota que el programa obedece la marca, o hace falta algo más inmediato? (Se
   probó que la marca adelantara las rutinas medio cargadas y se descartó: bajaba la
   supervivencia un 20 % en el soak.)
2. **THEN al clic.** Pon una rutina con el momento «al hacer clic». Lo que arma queda quieto con
   esquinas tenues. Cuando lo da por armado, se vuelven ámbar con un brillo que se oye. Un clic
   cerca lo suelta. Si lo que suelta es un lanzamiento (hielo, vapor o chatarra con *release*),
   va hacia la máquina donde hiciste clic, con una línea de puntos antes y un hilo ámbar al
   soltar.
   *Decidir:* si pasan 6 s sin clic, la trampa salta sola al contacto. ¿Debe quedarse así o
   perder su THEN? Una lectura de diseño propone quitarlo para que el clic importe. En el soak,
   disparar a ciegas rinde igual o mejor que hacerlo a tiempo.
3. **La placa.** Haz clic en una fila del programa (abajo a la izquierda): se pausa y se abre el
   taller en esa rutina. Espacio hace lo mismo si moviste el puntero hace poco. Con una máquina
   detrás, la placa se vuelve medio transparente.
4. **Lo que derriba tu programa.** Cuando el golpe de una rutina remata a una máquina, el número de
   esa fila se enciende ámbar y sale un aro del pecio. Pasa en el 11 % de las muertes con support
   y en el 28 % con showcase, porque el arma suele dar el último golpe.
   *Decidir:* ¿debe el programa pesar más que el arma? El arma hace el 52 % del daño de media.

## Menos texto

- Ya no hay números de daño flotando, ni palabras bajo las filas del taller, ni tiras de huecos
  en las ofertas de nivel, ni teclas impresas.
- Los números 1, 2, 3 de la placa se quedan: son lo que se enciende en combos y remates.

## Quedan para ti

- Si un invitado puede editar su programa en plena partida. Hoy puede, y un cambio dispara al
  momento lo que estaba recargando.
- El sonido: todo se afinó midiendo, sin escucharlo.
