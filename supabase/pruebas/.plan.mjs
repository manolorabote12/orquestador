// functions/_shared/cambios-datos.ts
var PRECIOS_CAMBIO = { "base": 3, "textos": 1, "ajustes": 3, "redibujar": 12, "paleta": 40, "estilo": 45, "anadir_enemigo": 15, "quitar_enemigo": 3, "anadir_nivel": 6, "quitar_nivel": 1, "rehacer_nivel": 5, "poderes": 6, "disparo": 4, "jefe": 18, "jefe_quitar": 2, "musica": 5, "extras": 6, "vista": 3, "historia": 4, "mapa": 2, "preguntas": 6, "genero": 10, "funciones": 0, "prueba_ab": 5, "prueba_ab_fin": 1, "giros": 3, "idiomas": 4 };
var PROTEGIDOS = ["mario", "luigi", "sonic", "pokemon", "pikachu", "zelda", "link", "kirby", "disney", "mickey", "minecraft", "fortnite", "roblox", "pacman", "pac-man", "donkey kong", "megaman", "mega man", "spiderman", "spider-man", "batman", "superman", "marvel", "star wars", "harry potter", "nintendo", "sega", "rayman", "crash bandicoot", "hello kitty", "peppa", "bluey", "among us", "angry birds"];
var GENEROS = { "plataformas": { "jefe": true, "disparo": true, "poderes": true, "extras": true, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": true, "nace_3d": false }, "runner": { "jefe": false, "disparo": true, "poderes": true, "extras": true, "enemigos": true, "enemigos_fijos": false, "corre_solo": true, "vista_3d": true, "nace_3d": false }, "volador": { "jefe": false, "disparo": false, "poderes": true, "extras": true, "enemigos": false, "enemigos_fijos": false, "corre_solo": true, "vista_3d": true, "nace_3d": false }, "horda": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "puzle": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "torres": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "carreras": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": true, "corre_solo": true, "vista_3d": true, "nace_3d": true }, "naves": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "rompebloques": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "bloques": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "corredor": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": true, "vista_3d": false, "nace_3d": false }, "serpiente": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": true, "vista_3d": false, "nace_3d": false }, "memoria": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cajas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "preguntas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "apilar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "topos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "saltos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "arena": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "aldea": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "ritmo": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "clicker": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cartas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "rpg": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "laberinto": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "golf": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "pesca": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "fusion": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tubos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "burbujas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "imperio": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "minas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "mazmorras": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "granja": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "mazo": { "jefe": true, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "aventura": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cocina": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "mahjong": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "aparcamiento": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "sopa": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "sudoku": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "nonograma": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cortar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "penaltis": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "agujero": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "ciudad": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "canasta": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "espiral": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "buscaminas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "conecta": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "damas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "billar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "solitario": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "parchis": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "caida": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "bolos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "mundo": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "royale": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": true, "nace_3d": true }, "cruzar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "arco": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cubos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "parkour": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tienda": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "futbol": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "terror": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "conduccion": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "zombis": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "baloncesto": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tenis": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "karts": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "supervivencia": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": true, "nace_3d": true }, "triple": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tornillos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "hexas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "autobus": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "duelo": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": true, "nace_3d": true }, "escalada": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tirachinas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "plantas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "palabra": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "letras": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tycoon": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tragaperras": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "reino": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "multitud": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "pedidos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "a_medida": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "poder": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "diferencias": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "rompecabezas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "pintar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cuchillos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "arquero": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "flechas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "numeros": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cartas_locas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "domino": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "bloques_colores": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "tuberias": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "ajedrez": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "reversi": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "buscar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "deslizar": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "ahorcado": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "flota": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "simon": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "estrategia": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "autobatalla": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "gemas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "coleccionables": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "roguelike": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "bombas": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "artilleria": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "comecocos": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "cadena": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "lucha": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "sandia": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "pinball": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": false, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "metroidvania": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false }, "sigilo": { "jefe": false, "disparo": false, "poderes": false, "extras": false, "enemigos": true, "enemigos_fijos": false, "corre_solo": false, "vista_3d": false, "nace_3d": false } };
var EDITOR = { "plataformas": { "letras": ".#PGC^R=HJMVIEKFB", "una": "PG", "filas": [8, 24], "ancho": [16, 300] }, "runner": { "letras": ".#PGC^RHJMVIEKF", "una": "PG", "filas": [8, 24], "ancho": [16, 300] }, "volador": { "letras": ".#PGCRHJMVI", "una": "PG", "filas": [10, 24], "ancho": [20, 400] }, "rompebloques": { "letras": ".123#CLM", "una": "", "filas": [3, 12], "ancho": [9, 9] }, "cajas": { "letras": ".#PBOQR", "una": "", "filas": [5, 12], "ancho": [5, 12] }, "topos": { "letras": ".o", "una": "", "filas": [2, 4], "ancho": [3, 4] }, "aldea": { "letras": ".#HGEMKCAO", "una": "H", "filas": [14, 24], "ancho": [14, 24] }, "arena": { "letras": ".#*BPR", "una": "P", "filas": [11, 31], "ancho": [9, 25] }, "laberinto": { "letras": ".#PCXLD", "una": "P", "filas": [7, 15], "ancho": [5, 11] }, "golf": { "letras": ".#BHWS", "una": "BH", "filas": [8, 18], "ancho": [5, 11] }, "imperio": { "letras": ".~^TBOPEcqlwht#", "una": "P", "filas": [16, 34], "ancho": [14, 28] } };
var GIROS = { "oscuridad": { "nombre": "A oscuras", "que": "Solo ves lo que alumbra tu linterna", "generos": ["plataformas", "runner", "volador", "horda", "naves", "cajas", "laberinto", "golf"], "seguro": true, "mezcla": false }, "espejo": { "nombre": "Mundo espejo", "que": "El mundo se ve al rev\xE9s: izquierda y derecha se cambian", "generos": ["plataformas", "runner", "volador", "horda", "cajas", "laberinto", "golf", "serpiente"], "seguro": true, "mezcla": false }, "contrarreloj": { "nombre": "Contrarreloj", "que": "Cada intento tiene un tiempo; si se acaba, a empezar", "generos": ["laberinto", "golf", "cajas", "serpiente", "bloques", "memoria", "rompebloques", "saltos", "apilar", "cartas"], "seguro": false, "mezcla": false }, "racha": { "nombre": "Racha", "que": "Cada nivel sin morir sube el multiplicador de monedas (hasta x3)", "generos": "*", "seguro": true, "mezcla": false }, "fantasma": { "nombre": "Fantasma", "que": "Corres contra tu mejor partida: una figura transparente repite tu mejor camino", "generos": ["plataformas", "runner", "volador", "horda"], "seguro": true, "mezcla": false }, "cola": { "nombre": "Laberinto serpiente", "que": "Mezcla con la serpiente: las casillas que dejas atr\xE1s se cierran", "generos": ["laberinto"], "seguro": false, "mezcla": true }, "niebla": { "nombre": "Niebla de guerra", "que": "Solo ves lo que tienen cerca tus aldeanos, tropas y edificios: hay que explorar para encontrar al rival", "generos": ["imperio"], "seguro": false, "mezcla": true }, "viento": { "nombre": "Viento", "que": "El viento empuja la bola mientras rueda: hay que apuntar contando con \xE9l", "generos": ["golf"], "seguro": false, "mezcla": false }, "tormenta": { "nombre": "Tormenta", "que": "Llueve y los peces nadan cada vez m\xE1s r\xE1pido", "generos": ["pesca"], "seguro": false, "mezcla": false }, "piedras": { "nombre": "Piedras", "que": "Piedras que estorban hasta que una fusi\xF3n al lado las rompe", "generos": ["fusion"], "seguro": false, "mezcla": false }, "hielo": { "nombre": "Suelo de hielo", "que": "Las cajas resbalan hasta chocar con algo: hay que pensar d\xF3nde se paran", "generos": ["cajas"], "seguro": false, "mezcla": false }, "tuneles": { "nombre": "T\xFAneles", "que": "Huecos en el borde: sales por un lado y entras por el contrario", "generos": ["serpiente"], "seguro": false, "mezcla": false }, "barajar": { "nombre": "Cartas inquietas", "que": "Cada 2 fallos, dos cartas tapadas se cambian de sitio (se ve el cambio)", "generos": ["memoria"], "seguro": false, "mezcla": false }, "dorado": { "nombre": "Bichos de oro", "que": "A veces asoma uno de oro: se va antes, pero vale 3 golpes", "generos": ["topos"], "seguro": false, "mezcla": false }, "invisibles": { "nombre": "Notas invisibles", "que": "Las notas se apagan antes de llegar: hay que tocar de memoria y al ritmo", "generos": ["ritmo"], "seguro": false, "mezcla": false }, "apocalipsis": { "nombre": "Apocalipsis zombi", "que": "Supervivencia tras el fin del mundo: saquea casas y coches, zombis que no temen al fuego, muros y una radio para pedir rescate", "generos": ["supervivencia"], "seguro": false, "mezcla": true }, "invierno": { "nombre": "Invierno", "que": "Hace fr\xEDo de noche: hoguera, cama o un abrigo de piel de ciervo para no congelarte", "generos": ["supervivencia"], "seguro": false, "mezcla": true }, "caza": { "nombre": "Caza", "que": "Ciervos que huyen y jabal\xEDes que embisten: caza, cocina la carne en la hoguera (cruda enferma)", "generos": ["supervivencia"], "seguro": false, "mezcla": true }, "equipo": { "nombre": "Equipo de h\xE9roes", "que": "RPG de equipo tipo Raid o Summoners War: cuatro h\xE9roes con habilidades, elementos, estados, turnos por velocidad y bot\xF3n AUTO", "generos": ["rpg"], "seguro": false, "mezcla": true }, "criaturas": { "nombre": "Criaturas", "que": "Combates uno contra uno de criaturas de fuego, agua y planta con cuatro movimientos (al caer una, sale la siguiente)", "generos": ["rpg"], "seguro": false, "mezcla": true }, "survivor": { "nombre": "Estilo Survivor", "que": "Hordas tipo Survivor.io: kunais, drones, rayos que saltan, escudos que giran y evoluciones de armas", "generos": ["horda"], "seguro": false, "mezcla": true }, "vampiros": { "nombre": "Estilo Vampiros", "que": "Hordas tipo Vampire Survivors: latigo, ajo, agua bendita, libro que gira y evoluciones", "generos": ["horda"], "seguro": false, "mezcla": true }, "fantasia": { "nombre": "Imperio de fantas\xEDa", "que": "El imperio con guardianes, elfas arqueras, jinetes de grifo, g\xF3lems y torres de mago", "generos": ["imperio"], "seguro": false, "mezcla": false }, "galactico": { "nombre": "Imperio gal\xE1ctico", "que": "Estrategia espacial: drones mineros, marines, francotiradores, motos a\xE9reas y tanques de asedio", "generos": ["imperio"], "seguro": false, "mezcla": false }, "fiesta": { "nombre": "Karts de fiesta", "que": "Mas objetos en la ruleta: la estrella (nada te para) y la cascara triple", "generos": ["karts"], "seguro": false, "mezcla": false }, "dados": { "nombre": "Tablero de dados", "que": "Tipo Monopoly Go: en vez de rodillos, dos dados y una ficha que da la vuelta a un tablero con premios", "generos": ["tragaperras"], "seguro": false, "mezcla": false }, "mina": { "nombre": "Tycoon de mina", "que": "Tipo Idle Miner: pozos que sacan mineral, ascensor que lo sube y almacen que lo vende (manda el mas lento)", "generos": ["tycoon"], "seguro": false, "mezcla": false }, "monstruos": { "nombre": "Golf de monstruos", "que": "Mezcla con el RPG: derriba monstruos con la bola para abrir el hoyo", "generos": ["golf"], "seguro": false, "mezcla": true } };

// functions/_shared/plan-logica.ts
var ARTE_TOTAL = /* @__PURE__ */ new Set(["estilo", "paleta"]);
function costePlan(plan) {
  const ops = plan.operaciones.map((o) => o.op);
  if (ops.length === 0) return 0;
  const arteTotal = ops.some((o) => ARTE_TOTAL.has(o));
  let total = PRECIOS_CAMBIO.base;
  plan.operaciones.forEach((op) => {
    const o = op.op;
    if (o === "redibujar" && arteTotal) return;
    if (o === "jefe" && op.activo === false) {
      total += PRECIOS_CAMBIO.jefe_quitar;
      return;
    }
    if (o === "prueba_ab" && (op.ganadora || op.activo === false)) {
      total += PRECIOS_CAMBIO.prueba_ab_fin;
      return;
    }
    total += PRECIOS_CAMBIO[o] ?? 999;
  });
  return total;
}
var REQUISITOS = {
  textos: [],
  ajustes: [],
  redibujar: ["que", "descripcion"],
  paleta: ["paleta"],
  estilo: ["familia", "descripcion"],
  anadir_enemigo: ["tipo", "nombre", "descripcion"],
  quitar_enemigo: ["tipo"],
  anadir_nivel: ["nombre"],
  quitar_nivel: ["indice"],
  rehacer_nivel: ["indice"],
  poderes: [],
  disparo: ["activo"],
  jefe: ["activo"],
  musica: ["ambiente"],
  extras: [],
  genero: ["genero"],
  vista: ["vista"],
  historia: [],
  mapa: ["indice", "mapa"],
  preguntas: ["preguntas"],
  funciones: [],
  prueba_ab: [],
  giros: ["giros"],
  idiomas: ["idiomas"]
};
function girosDe(genero) {
  return Object.entries(GIROS).filter(([, g]) => g.generos === "*" || g.generos.includes(genero)).map(([id]) => id);
}
function luminancia(hex) {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function problemasMapa(genero, mapa) {
  const e = EDITOR[genero];
  if (!e) return [`los niveles de un juego de tipo ${genero} aun no se pueden editar a mano`];
  if (!Array.isArray(mapa) || !mapa.every((f) => typeof f === "string")) return ["el mapa tiene que ser una lista de filas de texto"];
  const filas = mapa;
  const out = [];
  if (filas.length < e.filas[0] || filas.length > e.filas[1]) out.push(`el nivel tiene que tener entre ${e.filas[0]} y ${e.filas[1]} filas`);
  const anchos = new Set(filas.map((f) => f.length));
  if (anchos.size !== 1) out.push("todas las filas tienen que medir lo mismo");
  else {
    const w = [...anchos][0];
    if (w < e.ancho[0] || w > e.ancho[1]) out.push(`el nivel tiene que medir entre ${e.ancho[0]} y ${e.ancho[1]} casillas de ancho`);
  }
  const raras = [...new Set(filas.join("").split("").filter((c) => !e.letras.includes(c)))].sort();
  if (raras.length) out.push("casillas que no existen en este tipo de juego: " + raras.join(" "));
  for (const c of e.una) {
    const n = filas.join("").split(c).length - 1;
    if (n !== 1) {
      out.push(c === "P" ? "tiene que haber exactamente un punto de salida del heroe" : c === "G" ? "tiene que haber exactamente una meta" : `tiene que haber exactamente un '${c}'`);
    }
  }
  return out;
}
function vistaDe(diseno, genero) {
  const g = GENEROS[genero];
  if (!g || !g.vista_3d) return "2d";
  return String(diseno.vista ?? (g.nace_3d ? "3d" : "2d"));
}
function reglaGenero(genero, o) {
  const g = GENEROS[genero] ?? GENEROS.plataformas;
  if (o.op === "jefe" && o.activo === true && !g.jefe) return `un juego de tipo ${genero} no lleva jefe final`;
  if (o.op === "disparo" && !g.disparo) return `en un juego de tipo ${genero} no hay disparo`;
  if (o.op === "poderes" && !g.poderes) return `en un juego de tipo ${genero} no hay poderes`;
  if (o.op === "preguntas" && genero !== "preguntas") return "las preguntas solo existen en los juegos de preguntas";
  if (o.op === "vista" && !g.vista_3d) {
    return "la vista 3D de momento solo existe en " + Object.keys(GENEROS).filter((k) => GENEROS[k].vista_3d).join(", ");
  }
  if (o.op === "extras" && !g.extras) return `en un juego de tipo ${genero} no hay puntos de control ni plataformas moviles`;
  if (o.op === "extras" && o.plataformas_moviles === true && genero !== "plataformas") {
    return `en un juego de tipo ${genero} no hay plataformas moviles (no se puede frenar)`;
  }
  if (o.op === "anadir_enemigo" && (!g.enemigos || g.enemigos_fijos)) return `en un juego de tipo ${genero} no se pueden anadir enemigos`;
  if (o.op === "quitar_enemigo" && g.enemigos_fijos) return `en un juego de tipo ${genero} no se pueden quitar enemigos`;
  return "";
}
function validarPlan(plan, diseno, esquema) {
  const errores = esquema(plan);
  if (errores.length) return errores;
  const p = plan;
  const n = diseno.niveles.length;
  const tipos = new Set(diseno.enemigos.map((e) => e.tipo));
  let niveles = n;
  const textos = [];
  const actual = String(diseno.genero ?? "plataformas");
  const genero = String(p.operaciones.find((o) => o.op === "genero")?.genero ?? actual);
  p.operaciones.forEach((o, i) => {
    if (o.op === "genero" && o.genero === actual) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    const motivo = reglaGenero(genero, o);
    if (motivo) errores.push(`operaciones/${i}: ${motivo}`);
    for (const campo of REQUISITOS[o.op] ?? []) {
      if (!(campo in o)) errores.push(`operaciones/${i}: '${o.op}' necesita '${campo}'`);
    }
    const indice = typeof o.indice === "number" ? o.indice : 0;
    if ((o.op === "quitar_nivel" || o.op === "rehacer_nivel") && indice >= n) {
      errores.push(`operaciones/${i}: el juego tiene ${n} niveles (\xEDndices 0 a ${n - 1})`);
    }
    if (o.op === "anadir_enemigo" && tipos.has(String(o.tipo))) errores.push(`operaciones/${i}: ya hay un enemigo de tipo ${o.tipo}`);
    if (o.op === "quitar_enemigo" && !tipos.has(String(o.tipo))) errores.push(`operaciones/${i}: no hay enemigo de tipo ${o.tipo}`);
    if (o.op === "redibujar" && String(o.que ?? "").startsWith("enemigo_") && !tipos.has(String(o.que).slice(8))) {
      errores.push(`operaciones/${i}: no hay ${o.que} que redibujar`);
    }
    if (o.op === "poderes" && !(o.activar?.length || o.desactivar?.length)) {
      errores.push(`operaciones/${i}: 'poderes' necesita 'activar' o 'desactivar'`);
    }
    if (o.op === "jefe" && o.activo === true && !(o.nombre && o.descripcion)) {
      errores.push(`operaciones/${i}: para poner un jefe hacen falta 'nombre' y 'descripcion'`);
    }
    if (o.op === "jefe" && o.activo === false && !diseno.jefe) errores.push(`operaciones/${i}: el juego no tiene jefe que quitar`);
    if (o.op === "redibujar" && o.que === "jefe" && !diseno.jefe) errores.push(`operaciones/${i}: el juego no tiene jefe`);
    if (o.op === "extras") {
      if (!("puntos_control" in o) && !("plataformas_moviles" in o)) {
        errores.push(`operaciones/${i}: 'extras' necesita 'puntos_control' o 'plataformas_moviles'`);
      }
      const ex = diseno.extras ?? {};
      const igual = ["puntos_control", "plataformas_moviles"].filter((k) => k in o).every((k) => (ex[k] ?? k === "puntos_control") === o[k]);
      if (igual) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    }
    if (o.op === "disparo" && Boolean(diseno.disparo) === Boolean(o.activo)) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    if (o.op === "mapa" && "mapa" in o) {
      for (const pr of problemasMapa(genero, o.mapa)) errores.push(`operaciones/${i}: ${pr}`);
      const letras = new Set((Array.isArray(o.mapa) ? o.mapa : []).join("").split(""));
      const faltan = [["E", "walker"], ["K", "spiky"], ["F", "flyer"]].filter(([c, t]) => letras.has(c) && !tipos.has(t)).map(([, t]) => t);
      if (faltan.length) errores.push(`operaciones/${i}: el juego no tiene enemigos de tipo ${faltan.join(", ")}`);
      if (letras.has("B") && !diseno.jefe) errores.push(`operaciones/${i}: para poner al jefe en un nivel, el juego tiene que tener jefe`);
      if (Number(o.indice ?? 0) >= n) errores.push(`operaciones/${i}: el juego tiene ${n} niveles (indices 0 a ${n - 1})`);
    }
    if (o.op === "mapa" && p.operaciones.some((x) => ["anadir_nivel", "quitar_nivel", "genero"].includes(x.op))) {
      errores.push(`operaciones/${i}: un nivel editado a mano no se puede mezclar con anadir o quitar niveles ni cambiar de genero`);
    }
    if (o.op === "historia" && o.activo === false && !diseno.historia) errores.push(`operaciones/${i}: el juego no tiene historia que quitar`);
    if (o.op === "historia" && o.activo !== false && !o.historia) {
      errores.push(`operaciones/${i}: 'historia' necesita los dialogos nuevos (o activo false para quitarlos)`);
    }
    if (o.op === "historia" && o.historia) {
      for (const n2 of o.historia.niveles ?? []) {
        for (const l of [...n2.intro ?? [], ...n2.fin ?? []]) textos.push(l.texto);
      }
    }
    if (o.op === "vista" && vistaDe(diseno, genero) === o.vista) errores.push(`operaciones/${i}: eso ya esta asi en el juego`);
    if (o.op === "anadir_nivel") niveles++;
    if (o.op === "quitar_nivel") niveles--;
    if (o.op === "paleta" && Array.isArray(o.paleta)) {
      const pal = o.paleta;
      if (luminancia(pal[0]) > 0.12) errores.push(`operaciones/${i}: el primer color (cielo) debe ser oscuro`);
      if (pal.filter((c) => luminancia(c) < 0.1).length < 2) errores.push(`operaciones/${i}: hacen falta 2 colores oscuros`);
      if (!pal.some((c) => luminancia(c) > 0.65)) errores.push(`operaciones/${i}: hace falta un color claro`);
    }
    for (const k of ["titulo", "lema", "heroe_nombre", "nombre", "descripcion"]) {
      if (typeof o[k] === "string") textos.push(o[k]);
    }
    if (o.op === "giros") {
      const vale = girosDe(genero);
      const malos = (o.giros ?? []).filter((g) => !vale.includes(g));
      if (malos.length) errores.push(`operaciones/${i}: en un juego de tipo ${genero} no existe el giro ${malos.join(", ")}`);
    }
    if (o.referencia && (o.op !== "redibujar" || o.que !== "heroe")) {
      errores.push(`operaciones/${i}: la referencia (tu dibujo) solo vale para redibujar al heroe`);
    }
    if (o.op === "prueba_ab") {
      const fin = Boolean(o.ganadora) || o.activo === false;
      if (fin && !diseno.prueba_ab) errores.push(`operaciones/${i}: no hay ninguna prueba A/B en marcha`);
      if (!fin && diseno.prueba_ab) errores.push(`operaciones/${i}: ya hay una prueba A/B en marcha; terminala antes de empezar otra`);
      if (!fin && (typeof o.indice !== "number" || o.indice >= n)) errores.push(`operaciones/${i}: 'prueba_ab' necesita el 'indice' de un nivel (0 a ${n - 1})`);
      if (p.operaciones.some((x) => ["anadir_nivel", "quitar_nivel", "genero"].includes(x.op))) {
        errores.push(`operaciones/${i}: una prueba A/B no se puede mezclar con anadir o quitar niveles ni cambiar de genero`);
      }
    }
    for (const nn of o.nombres_niveles ?? []) {
      if (nn.indice >= n) errores.push(`operaciones/${i}: \xEDndice de nivel fuera de rango`);
      textos.push(nn.nombre);
    }
  });
  if (niveles < 3 || niveles > 8) errores.push("el juego debe tener entre 3 y 8 niveles");
  if (genero === "preguntas") {
    const op = p.operaciones.find((o) => o.op === "preguntas");
    const qs = op?.preguntas ?? diseno.preguntas ?? [];
    if (qs.length < 3 * niveles) errores.push(`preguntas: hacen falta al menos 3 por nivel (${3 * niveles} para ${niveles} niveles)`);
    for (const q of op ? qs : []) {
      textos.push(q.pregunta, ...q.opciones);
      if (new Set(q.opciones.map((x) => x.trim().toLowerCase())).size !== 4) errores.push("preguntas: las 4 opciones tienen que ser distintas");
    }
  }
  const todo = textos.join(" ").toLowerCase();
  for (const nombre of PROTEGIDOS) {
    if (new RegExp(`\\b${nombre.replace(/[.*+?^${}()|[\]\\-]/g, "\\$&")}\\b`).test(todo)) {
      errores.push(`contenido protegido: '${nombre}'. Crea un equivalente original`);
    }
  }
  return errores;
}
function contexto(diseno, historial) {
  const resumen = {
    titulo: diseno.titulo,
    lema: diseno.lema,
    genero: diseno.genero ?? "plataformas",
    estilo: diseno.estilo,
    heroe: diseno.heroe,
    vista: vistaDe(diseno, String(diseno.genero ?? "plataformas")),
    coleccionable: diseno.coleccionable,
    escenario: diseno.escenario,
    enemigos: diseno.enemigos,
    sensacion: diseno.sensacion,
    dificultad: diseno.dificultad,
    poderes: diseno.poderes ?? [],
    disparo: diseno.disparo ?? false,
    jefe: diseno.jefe ?? null,
    extras: diseno.extras ?? {},
    musica: diseno.musica,
    niveles: diseno.niveles.map((nombre, indice) => ({ indice, nombre })),
    historia: diseno.historia ?? null,
    prueba_ab: diseno.prueba_ab ?? null
  };
  const cambios = historial.slice(-10).map((h) => `v${h.version}: ${h.prompt}`).join("\n") || "(ninguno)";
  return `JUEGO ACTUAL:
${JSON.stringify(resumen, null, 1)}

CAMBIOS ANTERIORES (memoria del proyecto):
${cambios}`;
}
export {
  PRECIOS_CAMBIO,
  contexto,
  costePlan,
  girosDe,
  problemasMapa,
  reglaGenero,
  validarPlan,
  vistaDe
};
