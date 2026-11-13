// Cabecera, pie y correo de contacto comunes a todas las paginas.
(function () {
  var c = window.ORQ || {};
  var correo = c.correo && c.correo.indexOf("__") !== 0 ? c.correo : "";
  var logo = '<svg viewBox="0 0 32 32" aria-hidden="true"><circle cx="16" cy="16" r="13" fill="none" stroke="#e8b04b" stroke-width="3"/>' +
    '<circle cx="16" cy="16" r="5" fill="#e8b04b"/><path d="M16 1v5M16 26v5M1 16h5M26 16h5" stroke="#e8b04b" stroke-width="3"/></svg>';
  var top = document.createElement("header");
  top.className = "top";
  top.innerHTML = '<a href="./">' + logo + '</a><a href="./">ORQUESTADOR</a>';
  document.body.prepend(top);
  var pie = document.createElement("footer");
  pie.innerHTML = '<a href="escaparate.html">Juegos</a><a href="privacidad.html">Privacidad</a><a href="terminos.html">Términos</a>' +
    '<a href="borrar-cuenta.html">Borrar mi cuenta</a>' + (correo ? '<a href="mailto:' + correo + '">' + correo + "</a>" : "") +
    "<span>© " + new Date().getFullYear() + " Orquestador</span>";
  document.body.append(pie);
  var resp = c.responsable && c.responsable.indexOf("__") !== 0 ? c.responsable : "";
  document.querySelectorAll("[data-responsable]").forEach(function (el) { if (resp) el.textContent = resp; });
  document.querySelectorAll("[data-correo]").forEach(function (el) {
    if (correo) { el.textContent = correo; if (el.tagName === "A") el.href = "mailto:" + correo; }
  });
})();
