# Construcción elemental: propuesta de prototipo, no implementada

La fantasía es transformar materiales mediante operaciones combinables. El jugador elige el lugar y la forma; el programa determina la secuencia y sus condiciones. La primera prueba debería admitir una sola cadena completa, agua → elevación → hielo, antes de sumar tierra.

## Modelo acotado

Representar cada depósito como una entidad: material, cantidad, forma, estado, propietario y duración. La lluvia aumenta la cantidad de un depósito dentro de un área limitada. Elevar transforma parte de ese depósito en una lámina entre dos puntos; congelar cambia su material a hielo y habilita su colisión. Las partículas representan el agua, pero no transportan volumen físico ni requieren una simulación de fluidos.

- Lluvia: radio y duración limitados; acumula agua en zonas válidas del suelo.
- Elevación: dos anclas con una distancia máxima; consume una cantidad proporcional a la longitud y altura. Muestra la forma prevista antes de ejecutarse.
- Congelación: actúa sobre agua existente, tanto charco como lámina. Un charco congelado y una lámina sólida pueden compartir material pero tener comportamientos distintos.
- Tierra, después: reutiliza las dos anclas para delimitar un segmento sobre suelo apto. No deforma la malla base: una pieza de terreno emerge y oculta su unión con ella.

La composición debe pertenecer al sistema, no ser un hechizo fijo disfrazado con tres animaciones. Por ejemplo, congelar sin elevar deja una superficie helada; elevar sin congelar mantiene una lámina temporal que no bloquea como una pared sólida. Estas alternativas se deben probar antes de generalizar el lenguaje.

## Experiencia de usuario

Seleccionar el área o las dos runas en el mundo, con una previsualización; sus referencias quedan disponibles para el programa. No escribir coordenadas. Un tutorial construye una rutina paso a paso y luego permite guardarla y activarla con un gesto durante el combate. Así se programa una vez y se reutiliza mientras se esquiva.

Cada operación devuelve éxito o una causa concreta: falta agua, distancia excesiva, espacio ocupado. La interfaz muestra el paso activo, los recursos disponibles y el resultado previsto. No consumir recursos si la creación sólida no cabe. Nunca habilitar una pared encima de un personaje; comprobar el volumen antes de solidificar y conservar el agua si falla.

## Límites iniciales propuestos

Un depósito y una pared por jugador; tres longitudes prefijadas con orientación libre; altura fija; duración y vida limitadas. Destrucción con fragmentos visuales y retiro de la colisión, sin fractura física. Estos límites son parámetros de prototipo, no compromisos de diseño final.

En multijugador el servidor valida recursos, colocación y transiciones. Replica identidad, anclas, estado y tiempo; cada cliente reproduce lluvia y animaciones. No replicar partículas. Decidir explícitamente si las coberturas bloquean aliados, enemigos y proyectiles, y evitar encerrar spawns o cortar todo el espacio transitable.

## Orden de validación

1. Una cadena manual con previsualización y colisión: demostrar que construir bajo presión es divertido.
2. Las mismas operaciones desde el sistema de programación. Actualmente sólo se reconocen cadenas exactas fire()/heal(); esta propuesta requiere ampliar ese modelo, no ejecutar código arbitrario del jugador.
3. Estados alternativos (charco helado, lámina temporal) para comprobar combinabilidad.
4. Red y límites de recursos.
5. Tierra y nuevos materiales sólo si la primera cadena sigue siendo legible.

La lluvia ambiental del escenario es decorativa. No debe generar recursos infinitos accidentalmente: distinguir los depósitos de juego o definir una regeneración ambiental limitada antes de conectarlas.
