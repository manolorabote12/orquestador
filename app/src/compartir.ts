// Compartir un vídeo con su texto en TikTok, Instagram, YouTube...
// 1 - En el móvil (app de Capacitor): se guarda en la caché y se abre el menú de compartir del
//     sistema con el archivo; el texto va también al portapapeles (TikTok e Instagram lo ignoran
//     al compartir, así que basta con pegarlo).
// 2 - En el navegador con Web Share (móviles): igual, con navigator.share.
// 3 - Si no hay nada de eso: se copia el texto y se descarga el vídeo.

import { Capacitor } from "@capacitor/core";

export type ResultadoCompartir = "compartido" | "cancelado" | "descargado";

async function copiar(texto: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(texto);
  } catch {
    /* sin permiso de portapapeles: el texto también va en el menú de compartir */
  }
}

function aBase64(blob: Blob): Promise<string> {
  return new Promise((ok, mal) => {
    const r = new FileReader();
    r.onload = () => ok(String(r.result).split(",", 2)[1] ?? "");
    r.onerror = () => mal(r.error);
    r.readAsDataURL(blob);
  });
}

export async function compartir(url: string, nombre: string, texto: string): Promise<ResultadoCompartir> {
  await copiar(texto);
  try {
    const blob = await (await fetch(url)).blob();
    if (Capacitor.isNativePlatform()) {
      const [{ Filesystem, Directory }, { Share }] = await Promise.all([import("@capacitor/filesystem"), import("@capacitor/share")]);
      const escrito = await Filesystem.writeFile({ path: nombre, data: await aBase64(blob), directory: Directory.Cache });
      await Share.share({ title: nombre, text: texto, files: [escrito.uri], dialogTitle: "Publicar el vídeo" });
      return "compartido";
    }
    const archivo = new File([blob], nombre, { type: "video/mp4" });
    if (navigator.canShare?.({ files: [archivo] })) {
      await navigator.share({ files: [archivo], text: texto });
      return "compartido";
    }
  } catch (e) {
    if (e instanceof DOMException && e.name === "AbortError") return "cancelado";
    if (e instanceof Error && /cancel/i.test(e.message)) return "cancelado";
  }
  const a = document.createElement("a");
  a.href = url;
  a.download = nombre;
  a.rel = "noopener";
  document.body.append(a);
  a.click();
  a.remove();
  return "descargado";
}

/** Compartir un enlace (el de jugar a un juego). Móvil: menú del sistema; si no, se copia. */
/** La página propia de un juego del escaparate (web/juegos/<id>.html) lleva su imagen y su título
 *  para la vista previa de WhatsApp, Instagram o X. Se genera unos minutos después de publicarlo:
 *  si aún no está, vale el enlace directo. */
export async function enlaceConTarjeta(web: string, proyectoId: string, directo: string): Promise<string> {
  const bonita = `${web.replace(/\/$/, "")}/juegos/${proyectoId}.html`;
  try {
    const corte = new AbortController();
    const reloj = setTimeout(() => corte.abort(), 2500);
    const r = await fetch(bonita, { method: "HEAD", signal: corte.signal, cache: "no-store" });
    clearTimeout(reloj);
    return r.ok ? bonita : directo;
  } catch {
    return directo;
  }
}

export async function compartirEnlace(url: string, titulo: string): Promise<"compartido" | "copiado"> {
  const texto = `¡Juega a «${titulo}»! Lo he creado con Orquestador:`;
  try {
    if (Capacitor.isNativePlatform()) {
      const { Share } = await import("@capacitor/share");
      await Share.share({ title: titulo, text: texto, url, dialogTitle: "Compartir el juego" });
      return "compartido";
    }
    if (navigator.share) {
      await navigator.share({ title: titulo, text: texto, url });
      return "compartido";
    }
  } catch {
    /* cancelado: se copia igualmente */
  }
  await copiar(`${texto} ${url}`);
  return "copiado";
}
