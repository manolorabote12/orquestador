// Ajusta el proyecto Android que crea Capacitor (npx cap add android) para la tienda:
//   1 - versionCode / versionName (cada compilacion sube el numero; Google Play lo exige);
//   2 - Android 16: targetSdk y compileSdk 36 (obligatorio en Google Play desde el 31-08-2026);
//   3 - AdMob: ID de app en el manifiesto (sin el, la app se cierra al arrancar los anuncios).
// Uso: node scripts/preparar-android.mjs <versionCode>   (ADMOB_APP_ID en el entorno)
import { readFileSync, writeFileSync, existsSync } from "node:fs";

const codigo = Number.parseInt(process.argv[2] ?? "1", 10);
const version = JSON.parse(readFileSync("package.json", "utf8")).version;
const admob = process.env.ADMOB_APP_ID || "ca-app-pub-3940256099942544~3347511713";
const raiz = process.argv[3] ?? "android";

function cambiar(ruta, fn) {
  if (!existsSync(ruta)) throw new Error(`No existe ${ruta}: ejecuta antes "npx cap add android"`);
  const antes = readFileSync(ruta, "utf8");
  const despues = fn(antes);
  writeFileSync(ruta, despues);
  return antes !== despues;
}

cambiar(`${raiz}/app/build.gradle`, (s) => s
  .replace(/versionCode\s+\d+/, `versionCode ${codigo}`)
  .replace(/versionName\s+"[^"]*"/, `versionName "${version}"`));

cambiar(`${raiz}/variables.gradle`, (s) => s
  .replace(/compileSdkVersion\s*=\s*\d+/, (m) => Number(m.match(/\d+/)[0]) < 36 ? "compileSdkVersion = 36" : m)
  .replace(/targetSdkVersion\s*=\s*\d+/, (m) => Number(m.match(/\d+/)[0]) < 36 ? "targetSdkVersion = 36" : m));

cambiar(`${raiz}/app/src/main/AndroidManifest.xml`, (s) => {
  const meta = `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="${admob}"/>`;
  if (s.includes("com.google.android.gms.ads.APPLICATION_ID")) {
    return s.replace(/<meta-data android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID" android:value="[^"]*"\/>/, meta);
  }
  return s.replace(/(<application[^>]*>)/, `$1\n        ${meta}`);
});

console.log(`Android listo: versionCode ${codigo}, version ${version}, API 36, AdMob ${admob.startsWith("ca-app-pub-3940256099942544") ? "de prueba" : "propio"}`);
