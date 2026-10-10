# Brief para el diseñador — arte de cosméticos

Este documento explica qué necesitamos para que el arte funcione dentro del juego. Si algo de aquí no se puede cumplir, avísanos antes de producir: casi todo se puede ajustar, pero las reglas de la sección 1 no.

## 1. Reglas que NO se pueden romper (afectan la jugabilidad)
1. **Nunca revelar qué hay debajo de una ficha.** Una casilla cubierta solo muestra *que* hay algo debajo (un collar fino gris) y cuántas capas, nunca de quién ni de qué nivel. No dibujar sombras, bordes ni detalles que insinúen la ficha tapada.
2. **Los tamaños de las fichas son fijos.** Nivel 1 = 52 % de la casilla, nivel 2 = 66 %, nivel 3 = 80 %, nivel 4 = 94 %. El juego aplica el tamaño; el arte no debe verse "más grande" ni "más pequeño" por su cuenta (deja siempre el mismo margen interno en los 4 niveles).
3. **El nivel debe leerse de un vistazo** por al menos dos señales: tamaño, cantidad de anillos/elementos, número. Los 4 niveles deben ser claramente distintos entre sí, también en tamaño pequeño y para daltónicos.
4. **Los dos jugadores deben distinguirse sin depender solo del color**: forma o símbolo distinto (hoy: punto central vs. cruz pequeña). Colores de jugador: azul índigo `#1B4B7A` (jugador 1) y ámbar `#C9601F` (jugador 2).
5. **El tablero no puede tapar ni confundir** lo que el juego dibuja encima: resaltado de jugadas legales (color del jugador al ~15 %), borde de selección, brillo de la última jugada, collar de fichas enterradas. Todo debe seguir viéndose con contraste suficiente sobre el arte.

## 2. Formato general de cualquier imagen
- **PNG o WebP con transparencia** (fondo realmente transparente, sin halo de color en los bordes: el halo rojo/amarillo que tiene `rock_board.png` se nota sobre fondos oscuros).
- **Canvas cuadrado.** Tamaño de entrega: **1536 × 1536 px** para tableros; **1024 × 1024 px** para fichas. No más: una imagen de 3758 × 3625 pesa ~54 MB en memoria y puede cerrar la app en móviles.
- **Peso objetivo: menos de 400 KB por imagen.**
- Sin sombra proyectada incrustada (la app pone la suya, así se ve igual sobre cualquier fondo). Se aceptan sombras internas/relieves.
- Vista cenital (desde arriba), luz desde arriba-izquierda, igual para todo el set.
- Contenido centrado con un margen de ~4 % para que no se corte.
- Nombres de archivo en minúsculas, sin espacios ni tildes, con guion bajo.

## 3. Tableros (nuevo) — `assets/boards/<id>.png`
Tablero 3×3 para los modos Stack-Static y Stack-Movable. (Ultimate usa otro diseño; por ahora no se toca.)

**Qué necesitamos**
- Una sola imagen cuadrada: la losa/superficie completa con la cuadrícula 3×3.
- **La cuadrícula debe estar centrada en el canvas** y ser lo más **uniforme** posible: 9 casillas de tamaño parecido, separadas por surcos/líneas de grosor constante. El juego coloca las casillas sobre una rejilla uniforme; si las tuyas son desiguales (en `rock_board.png` varían entre ~420 y ~540 px), las fichas se verán descentradas.
- **Casillas planas, lisas y lo más grandes posible.** La ficha de nivel 4 ocupa el 94 % de la casilla y las demás van centradas; los detalles fuertes (grietas, agujeros, rebabas) en el centro de la casilla compiten con la ficha. Deja los detalles en bordes y surcos.
- **Contraste con las fichas.** Las fichas son azul índigo y ámbar quemado; el arte no debe usar esos tonos en grandes zonas. Un tablero muy beige/ocre reduce el contraste del collar gris (`#6B6D65`) y del resaltado: revisaremos juntos.
- Los surcos/líneas no deben ser tan profundos o contrastados que parezcan "huecos" donde caería la ficha.
- Margen transparente alrededor de la losa de ~4 % por lado; sin elementos que sobresalgan del canvas.
- **Un único estado por tablero.** No pintes jugadas, marcas ni resaltados en la imagen.

**Entrega por cada tablero nuevo**
1. `<id>.png` a 1536 × 1536 px.
2. Una miniatura/preview 512 × 512 px (si es distinta de recortar el tablero; si no, la generamos nosotros).
3. Nombre e idea en una frase (lo traducimos a inglés/español).
4. Indica si es **gratis, de fragmentos (cofre diario) o de tienda**. Esto aún está por decidir.

**Estado actual de `rock_board.png`**: sirve como base, pero hay que (a) reducirlo a 1536 px, (b) centrar la cuadrícula en un canvas cuadrado, (c) limpiar el halo rojo/amarillo de los bordes, (d) quitar la sombra proyectada si la tiene, (e) idealmente igualar el tamaño de las 9 casillas. Con (a)–(d) ya lo podemos usar.

## 4. Fichas de Stacking (skins de fichas) — `assets/skins/<id>/`
Referencia real: la skin "Burger Stack" (`assets/chips/burguer1.png`…`burguer4.png`, 1570 × 1585 px; conviene unificar a 1024 × 1024).
- **4 imágenes por skin, una por nivel**: `chip_l1.png` … `chip_l4.png`. Si queréis que cada jugador tenga diseño distinto: `chip_p1_l1…l4.png` y `chip_p2_l1…l4.png` (8 imágenes).
- El **mismo lienzo y el mismo margen interno en los 4 niveles** (el juego ya los escala al 52/66/80/94 %). Si el nivel 1 y el 4 tienen el mismo tamaño en el canvas, el juego los hará distintos solo.
- **El nivel 4 también se usa como "marca" en Ultimate** (casillas muy pequeñas, 81 en pantalla): debe tener silueta clara y legible a ~30 px.
- Debe distinguirse del fondo claro (`#B7B3B2`) y del oscuro; evita fichas del color del tablero.
- Ficha redonda o casi; el juego deja el sitio como si fuera un círculo.
- Mostrar el nivel con elementos contables (capas, anillos, pisos, etc.), no solo con tamaño.
- Si el skin es de cartas/símbolos sin capas (como X/O clásico) avísanos: es excepción y el número de nivel es obligatorio.

## 5. Emotes — `assets/emotes/<id>.png`
- Un PNG por emote, **512 × 512 px**, transparente, legible a ~48 px (se muestran en burbujas pequeñas sobre el tablero).
- Expresivos y reconocibles por silueta; sin texto incrustado (se traduce por código).
- Cada jugador lleva **4 emotes equipados**; hoy hay 4 gratis y los demás se desbloquean con fragmentos (20 por emote).
- Aún no hay arte entregado: la app muestra iconos provisionales hasta que lleguen. Los ids definitivos de los emotes los da el equipo; manda los nombres de archivo y los renombramos.

## 6. Celebraciones ("flexing") — `assets/celebrations/<id>.png`
- Son animaciones/escenas que se reproducen al ganar. **El formato aún no está decidido** (imagen fija, secuencia de sprites o vídeo). Por ahora necesitamos **un fotograma de preview, 512 × 512 px, transparente** por celebración, para mostrarlo en el selector.
- Si propones un formato (sprite sheet, Lottie, vídeo corto), dinos peso y duración (idealmente < 3 s) para decidirlo juntos.
- 16 celebraciones planificadas (4 gratis, 12 por fragmentos de 30). Ids actuales: happy, cheer, dance, bow, flex, wave, spin, jump, salute, shrug, facepalm, fistbump, crown, trophy, sparkle, rocket.

## 7. Packs de la tienda (referencia)
La tienda tiene 6 packs (`fire`, `troll`, `loser`, `apple`, `elements`, `sakura`). `sakura` está pensado como el pack de **tablero**; `apple`/`elements`/`sakura` aún no tienen contenido. Si diseñas un pack, entrega: miniatura 512 × 512, y el contenido (fichas / emotes / tablero / celebración) con las reglas de arriba.

## 8. Paleta y tono visual de la app
Fondo de la app `#B7B3B2` (gris piedra), superficies `#E3DBD3`, texto `#303032`, jugador 1 `#1B4B7A`, jugador 2 `#C9601F`, neutro `#6B6D65`. Evita rojo/verde como único diferenciador. Tablero tipo piedra/madera cálida sobre fondo gris: el arte debe sentirse "material físico", no UI plana.

## 9. Lista de comprobación antes de entregar
- [ ] PNG/WebP transparente, sin halo, canvas cuadrado, tamaño correcto, < 400 KB.
- [ ] Nombres en minúsculas con guion bajo.
- [ ] Tablero: cuadrícula centrada, casillas uniformes y lisas.
- [ ] Fichas: 4 niveles distinguibles; nivel 4 legible a 30 px; mismo margen en los 4.
- [ ] Nada insinúa lo que hay debajo de una ficha.
- [ ] Contraste revisado sobre el fondo `#B7B3B2` y sobre el tablero.
