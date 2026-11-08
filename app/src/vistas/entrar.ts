// Entrar con Google (un toque) o con un código de 6 cifras enviado al correo (sin contraseñas).

import type { App } from "../main";
import { crearChispa, h, svg, type VistaHecha } from "../ui";
import { mensajeError } from "../errores";

const G_LOGO = `<svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>`;

// Sin cliente de Google configurado (GOOGLE_OAUTH_CLIENT_ID en GitHub) el boton no se ensena: solo correo.
const CON_GOOGLE = !!(import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID as string | undefined);

export function vistaEntrar(app: App): VistaHecha {
  const chispa = crearChispa(CON_GOOGLE ? "¡Hola! Soy Chispa. Entra con tu cuenta de Google o dime tu correo y te mando un código."
    : "¡Hola! Soy Chispa. Dime tu correo y te mando un código para entrar.");
  const google = h("button", { class: "btn btn-google", type: "button" }, svg(G_LOGO), "Continuar con Google");
  const correo = h("input", { type: "email", autocomplete: "email", inputmode: "email", placeholder: "tu@correo.com", "aria-label": "Correo" });
  const codigo = h("input", { type: "text", inputmode: "numeric", autocomplete: "one-time-code", maxlength: "6", placeholder: "······", class: "code-input", "aria-label": "Código de 6 cifras" });
  const estado = h("p", { class: "status", role: "status" });
  const pedir = h("button", { class: "btn btn-brass" }, "Enviarme el código");
  const validar = h("button", { class: "btn btn-brass" }, "Entrar");
  const volver = h("button", { class: "btn btn-line" }, "Cambiar de correo");

  const paso1 = h("div", { class: "sheet" },
    h("div", { class: "sheet-head" }, h("h2", {}, "Entrar")),
    ...(CON_GOOGLE ? [google, h("div", { class: "o-separador", role: "separator" }, h("span", {}, "o con tu correo"))] : []),
    correo, h("div", { style: "height:12px" }), pedir);
  const paso2 = h("div", { class: "sheet", hidden: true },
    h("div", { class: "sheet-head" }, h("h2", {}, "Tu código"), h("span", { class: "tag" }, "paso 2 de 2")),
    h("p", { class: "muted small", style: "margin-bottom:10px" }, "Mira tu correo (y la carpeta de spam)."),
    codigo, h("div", { style: "height:12px" }), validar, h("div", { style: "height:10px" }), volver);

  const ocupado = (b: HTMLButtonElement, si: boolean) => { b.disabled = si; };

  google.addEventListener("click", async () => {
    ocupado(google, true);
    estado.className = "status";
    estado.textContent = "Abriendo Google...";
    try {
      const r = await app.api.entrarConGoogle();
      if (r === "dentro") {
        estado.textContent = "";
        chispa.decir("¡Dentro! Vamos a fabricar algo.", "happy");
        await app.entrar();
      } else if (r === "cancelado") {
        estado.textContent = "";
      }
      // "redirigiendo": la pagina se va a Google y vuelve ya con la sesion.
    } catch (e) {
      estado.className = "status err";
      estado.textContent = mensajeError(e, "No se pudo entrar con Google. Prueba con el correo.");
    } finally {
      ocupado(google, false);
    }
  });

  pedir.addEventListener("click", async () => {
    const email = correo.value.trim();
    if (!/^\S+@\S+\.\S+$/.test(email)) {
      estado.className = "status err";
      estado.textContent = "Ese correo no parece válido.";
      return;
    }
    ocupado(pedir, true);
    estado.className = "status";
    estado.textContent = "Enviando...";
    try {
      await app.api.pedirCodigo(email);
      paso1.hidden = true;
      paso2.hidden = false;
      estado.textContent = "";
      chispa.decir(app.api.demo ? "En la demostración vale cualquier código de 6 cifras." : `Te he mandado un código a ${email}.`);
      codigo.focus();
    } catch (e) {
      estado.className = "status err";
      estado.textContent = mensajeError(e, "Algo ha fallado. Inténtalo otra vez.");
    } finally {
      ocupado(pedir, false);
    }
  });

  const entrar = async () => {
    ocupado(validar, true);
    estado.className = "status";
    estado.textContent = "Comprobando...";
    try {
      await app.api.verificarCodigo(correo.value.trim(), codigo.value.trim());
      chispa.decir("¡Dentro! Vamos a fabricar algo.", "happy");
      await app.entrar();
    } catch (e) {
      estado.className = "status err";
      estado.textContent = mensajeError(e, "Algo ha fallado. Inténtalo otra vez.");
      chispa.decir("Ese código no me cuadra. Revísalo.", "error");
    } finally {
      ocupado(validar, false);
    }
  };
  validar.addEventListener("click", entrar);
  codigo.addEventListener("input", () => {
    codigo.value = codigo.value.replace(/\D/g, "").slice(0, 6);
    if (codigo.value.length === 6) void entrar();
  });
  correo.addEventListener("keydown", (e) => { if (e.key === "Enter") pedir.click(); });
  volver.addEventListener("click", () => {
    paso2.hidden = true;
    paso1.hidden = false;
    codigo.value = "";
    estado.textContent = "";
  });

  return { el: h("div", { class: "wrap-inner" }, chispa.el, paso1, paso2, estado) };
}
