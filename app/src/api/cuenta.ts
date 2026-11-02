// Cuenta: entrar (correo o Google), salir, borrar la cuenta, invitaciones y perfil de creador.

import type { PerfilCreador } from "../creador";
import { ErrorApp } from "../errores";
import { esNativo, googleIdToken, googleNativoDisponible } from "../nativo";
import type { Conexion } from "./conexion";

/** Tu código para invitar amigos y lo que te ha dado. */
export interface Invitacion {
  codigo: string;
  invitados: number;
  pagados: number;
  ganadas: number;
  por_amigo: number;
  me_invito: boolean;
}

export function mensajeInvitacion(m: string): string {
  if (m.includes("bad_code")) return "Ese código no existe. Revísalo con quien te invitó.";
  if (m.includes("own_code")) return "No puedes usar tu propio código.";
  if (m.includes("already_invited")) return "Ya usaste el código de otra persona.";
  if (m.includes("too_late")) return "El código de invitación solo vale en la primera semana y antes de tu primer juego.";
  return "No se pudo usar el código.";
}

/** Lo que la app puede pedir en esta area (servidor real o demostracion). */
export interface ApiCuenta {
  usuario(): Promise<{ email: string } | null>;
  pedirCodigo(email: string): Promise<void>;
  verificarCodigo(email: string, codigo: string): Promise<void>;
  /** Entrar con Google: "dentro" (ya hay sesion), "redirigiendo" (la web se va a Google y
   *  vuelve sola) o "cancelado" (la persona cerro el selector de cuentas). */
  entrarConGoogle(): Promise<"dentro" | "redirigiendo" | "cancelado">;
  salir(): Promise<void>;
  /** Borra la cuenta y todo lo suyo (irreversible). premium_activo: hay que cancelar en Google Play. */
  borrarCuenta(): Promise<{ premium_activo: boolean }>;
  /** Tu código de invitación (se crea la primera vez) y cuánto te ha dado. */
  miInvitacion(): Promise<Invitacion>;
  /** Lo que has hecho y lo que ha conseguido (para tu nivel e insignias de creador). */
  perfilCreador(): Promise<PerfilCreador>;
  /** Apunta el código de quien te invitó (primera semana, antes de tu primer juego). */
  usarInvitacion(codigo: string): Promise<void>;
}

/** Servidor real (Supabase). */
export function supaCuenta(con: Conexion): ApiCuenta {
  const api: ApiCuenta = {
    async usuario() {
      const { data } = await con.sb.auth.getSession();
      const u = data.session?.user;
      return u ? { email: u.email ?? "" } : null;
    },

    // Inicio de sesión con un código de 6 cifras por correo: funciona igual en el navegador y
    // en la app instalada, sin enlaces que tengan que volver a abrir la app.
    async pedirCodigo(email: string) {
      const { error } = await con.sb.auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
      if (error) throw new ErrorApp(error.status === 429 ? "Espera un minuto antes de pedir otro código." : "No se pudo enviar el código. Revisa el correo.");
    },

    async verificarCodigo(email: string, codigo: string) {
      const { error } = await con.sb.auth.verifyOtp({ email, token: codigo, type: "email" });
      if (!error) return;
      // 1 - Cuenta de revision de Google Play / App Store (correo y codigo fijos, solo en el servidor).
      try {
        const { data } = await con.sb.functions.invoke("review-login", { body: { email, codigo } });
        if (data?.access_token && data?.refresh_token) {
          const r = await con.sb.auth.setSession({ access_token: data.access_token, refresh_token: data.refresh_token });
          if (!r.error) return;
        }
      } catch {
        /* no es la cuenta de revision */
      }
      throw new ErrorApp("Código incorrecto o caducado.");
    },

    async entrarConGoogle(): Promise<"dentro" | "redirigiendo" | "cancelado"> {
      if (esNativo()) {
        if (!googleNativoDisponible()) throw new ErrorApp("Entrar con Google aún no está activado en esta versión. Usa el correo.");
        // 1 - Nonce: a Google va cifrado y a Supabase en claro; asi nadie puede reutilizar el token.
        const crudo = Array.from(crypto.getRandomValues(new Uint8Array(24)), (b) => b.toString(16).padStart(2, "0")).join("");
        const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(crudo));
        const cifrado = Array.from(new Uint8Array(hash), (b) => b.toString(16).padStart(2, "0")).join("");
        let token: string | null;
        try {
          token = await googleIdToken(cifrado);
        } catch {
          throw new ErrorApp("No se pudo abrir Google. Comprueba que tienes una cuenta de Google en el móvil.");
        }
        if (!token) return "cancelado";
        const { error } = await con.sb.auth.signInWithIdToken({ provider: "google", token, nonce: crudo });
        if (error) throw new ErrorApp("Google no ha dejado entrar ahora. Prueba otra vez o entra con el correo.");
        return "dentro";
      }
      const vuelta = location.origin + location.pathname;
      const { error } = await con.sb.auth.signInWithOAuth({ provider: "google", options: { redirectTo: vuelta } });
      if (error) throw new ErrorApp("Entrar con Google no está activado en el servidor. Usa el correo.");
      return "redirigiendo";
    },

    async salir() {
      await con.sb.auth.signOut();
    },

    async perfilCreador() {
      const { data, error } = await con.sb.rpc("perfil_creador");
      if (error || !data) throw new ErrorApp("No se pudo cargar tu perfil de creador.");
      return data as PerfilCreador;
    },

    async miInvitacion() {
      const { data, error } = await con.sb.rpc("mi_invitacion");
      if (error) throw new ErrorApp("No se pudo cargar tu código de invitación.");
      return data as Invitacion;
    },

    async usarInvitacion(codigo: string) {
      const { error } = await con.sb.rpc("usar_invitacion", { p_codigo: codigo });
      if (error) throw new ErrorApp(mensajeInvitacion(error.message));
    },

    async borrarCuenta() {
      const r = await con.invocar<{ ok: boolean; premium_activo: boolean }>("delete-account", { confirmar: "BORRAR" }, "No se pudo borrar la cuenta.");
      await con.sb.auth.signOut({ scope: "local" });
      return { premium_activo: !!r.premium_activo };
    },
  };
  return api;
}
