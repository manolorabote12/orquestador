# Fabrica de Orquestador para RunPod serverless (CPU). La construye GitHub Actions; nadie la
# construye en su PC. Contexto de construccion: la raiz del repositorio (fabrica/ y orqkit/).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    ANDROID_HOME=/opt/android \
    ANDROID_SDK_ROOT=/opt/android \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    GODOT=/usr/local/bin/godot \
    ORQ_PIPER_VOZ=/opt/voces/es_ES-davefx-medium.onnx \
    ORQ_DATOS=/tmp/orq_datos

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip openjdk-17-jdk-headless ffmpeg xvfb xauth wget unzip ca-certificates \
      libfontconfig1 libgl1 libegl1 libxcursor1 libxinerama1 libxrandr2 libxi6 fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# 1 - Godot 4.6.3 (el mismo que el kit) y sus plantillas de exportacion.
ARG GODOT_VERSION=4.6.3
RUN wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip -O /tmp/g.zip \
    && unzip -q /tmp/g.zip -d /tmp/g && mv /tmp/g/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot && rm -rf /tmp/g /tmp/g.zip \
    && wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz -O /tmp/t.zip \
    && mkdir -p /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable \
    && unzip -q /tmp/t.zip -d /tmp/t && mv /tmp/t/templates/* /root/.local/share/godot/export_templates/${GODOT_VERSION}.stable/ \
    && rm -rf /tmp/t /tmp/t.zip

# 2 - Android SDK: plataforma 36 (obligatoria en Google Play desde el 31-08-2026) y lo que pide Godot.
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/c.zip \
    && unzip -q /tmp/c.zip -d /tmp/c && mv /tmp/c/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && rm -rf /tmp/c /tmp/c.zip \
    && yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
      "platform-tools" "platforms;android-36" "build-tools;36.0.0" "build-tools;35.0.1" \
      "cmake;3.10.2.4988404" "ndk;28.1.13356709" > /dev/null

# 3 - Ajustes del editor de Godot: SDK, Java y llave de depuracion (los APK de prueba).
RUN mkdir -p /root/.local/share/godot/keystores /root/.config/godot \
    && keytool -genkeypair -v -keystore /root/.local/share/godot/keystores/debug.keystore \
      -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
      -dname "CN=Android Debug,O=Android,C=US" > /dev/null 2>&1 \
    && printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "/opt/android"\nexport/android/java_sdk_path = "%s"\nexport/android/debug_keystore = "/root/.local/share/godot/keystores/debug.keystore"\nexport/android/debug_keystore_user = "androiddebugkey"\nexport/android/debug_keystore_pass = "android"\n' "$JAVA_HOME" \
      > /root/.config/godot/editor_settings-4.6.tres

# 4 - Python: la fabrica, el SDK de RunPod y la voz local de respaldo (Piper, licencia MIT).
RUN pip3 install --no-cache-dir --break-system-packages \
      pillow numpy jsonschema cryptography runpod piper-tts \
    && mkdir -p /opt/voces \
    && wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx -O /opt/voces/es_ES-davefx-medium.onnx \
    && wget -q https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json -O /opt/voces/es_ES-davefx-medium.onnx.json

# 5 - El codigo. El kit se importa una vez aqui para que cada juego arranque en segundos.
WORKDIR /app
COPY orqkit /app/orqkit
COPY fabrica /app/fabrica
# El plugin de AdMob baja aqui sus binarios de Android (los usan los .aab de tienda).
RUN rm -rf /app/fabrica/datos /app/fabrica/salida_prueba /app/orqkit/.godot \
    && (timeout 600 godot --headless --path /app/orqkit --import > /dev/null 2>&1 || true) \
    && rm -rf /app/orqkit/addons/admob/downloads \
    && if [ -f /app/orqkit/addons/admob/android/bin/package.gd ]; then echo "AdMob Android: listo"; \
       else echo "AVISO: AdMob Android no se pudo descargar; los juegos saldran con anuncios simulados"; fi

# 5b - Compras dentro de los juegos: plugin oficial GodotGooglePlayBilling (MIT), compilado aqui
# desde su version fija (el SDK de Android y el JDK ya estan). Si falla, los juegos salen sin tienda.
ARG BILLING_VERSION=3.3.0
RUN (wget -q https://github.com/godot-sdk-integrations/godot-google-play-billing/archive/refs/tags/${BILLING_VERSION}.tar.gz -O /tmp/gpb.tgz \
      && mkdir -p /tmp/gpb && tar -xzf /tmp/gpb.tgz -C /tmp/gpb --strip-components=1 \
      && cd /tmp/gpb && chmod +x gradlew && timeout 1200 ./gradlew assemble --no-daemon -q \
      && cp -r /tmp/gpb/addons/GodotGooglePlayBilling /app/orqkit/addons/ \
      && sed -i 's|enabled=PackedStringArray("res://addons/admob/plugin.cfg")|enabled=PackedStringArray("res://addons/admob/plugin.cfg", "res://addons/GodotGooglePlayBilling/plugin.cfg")|' /app/orqkit/project.godot \
      && echo "Compras (Google Play Billing): listo") \
    || echo "AVISO: el plugin de compras no se pudo compilar; los juegos saldran sin tienda"; \
    rm -rf /tmp/gpb /tmp/gpb.tgz /root/.gradle/caches/transforms-* || true

# 5c - Avisos en el movil: plugin NotificationScheduler (MIT, godot-mobile-plugins), version y huella fijas.
ARG NOTIF_VERSION=6.0
ARG NOTIF_SHA256=806c85eafe8f4c8aa4ee37e0ed1ab551e85db8755f8aeb1c6302092f809725a3
RUN (wget -q https://github.com/godot-mobile-plugins/godot-notification-scheduler/releases/download/v${NOTIF_VERSION}/NotificationSchedulerPlugin-Android-v${NOTIF_VERSION}.zip -O /tmp/ns.zip \
      && echo "${NOTIF_SHA256}  /tmp/ns.zip" | sha256sum -c - \
      && mkdir -p /tmp/ns && unzip -q /tmp/ns.zip -d /tmp/ns \
      && cp -r /tmp/ns/res/addons/NotificationSchedulerPlugin /tmp/ns/res/addons/GMPShared /app/orqkit/addons/ \
      && sed -i 's|"res://addons/admob/plugin.cfg"|"res://addons/admob/plugin.cfg", "res://addons/NotificationSchedulerPlugin/plugin.cfg"|' /app/orqkit/project.godot \
      && echo "Avisos (NotificationScheduler): listo") \
    || echo "AVISO: el plugin de avisos no se pudo instalar; los juegos saldran sin avisos"; \
    rm -rf /tmp/ns /tmp/ns.zip

# 6 - Prueba de humo al construir: si la cadena no funciona, la imagen no se publica.
RUN cd /app/fabrica && ORQ_SIMULADO=1 timeout 900 python3 -m pruebas.prueba_runpod

WORKDIR /app/fabrica
CMD ["python3", "-u", "runpod_handler.py"]
