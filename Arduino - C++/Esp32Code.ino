// ESP32: sincroniza meds desde Firestore y manda ADD:... al Arduino UNO + nombre del usuario

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ====== CONFIGURACIÓN ======
const char* WIFI_SSID = "Claro123";
const char* WIFI_PASS = "Mili1210";

const char* PROJECT_ID = "pillbox-e83d7";
const char* API_KEY    = "AIzaSyDKyNmIMLRvSFKtU_O1gfSmCj7lx6DImnw";
const char* DEVICE_ID  = "PB-0001";
// ============================

// UART hacia el Arduino UNO
static const int ESP_TX = 17;  // conecta a RX del UNO (pin 3 si usás SoftwareSerial)
static const int ESP_RX = 16;  // conecta a TX del UNO (pin 4)
const unsigned long SYNC_INTERVAL_MS = 5UL * 60UL * 1000UL; // cada 5 minutos
unsigned long lastSync = 0;

// ------------------- Helpers Firestore URLs -------------------
String buildDeviceUrl() {
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += DEVICE_ID;
  url += "?key=";
  url += API_KEY;
  return url;
}

String buildUserUrl(const String& ownerUid) {
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += PROJECT_ID;
  url += "/databases/(default)/documents/users/";
  url += ownerUid;
  url += "?key=";
  url += API_KEY;
  return url;
}

String buildMedsUrl(const String& ownerUid) {
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += PROJECT_ID;
  url += "/databases/(default)/documents/users/";
  url += ownerUid;
  url += "/meds?key=";
  url += API_KEY;
  return url;
}

// ------------------- Paso 1: obtener ownerUID y displayName -------------------
bool fetchOwnerInfo(String &uidOut, String &nameOut) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  String url = buildDeviceUrl();
  Serial.println("GET device: " + url);

  if (!http.begin(client, url)) {
    Serial.println("HTTP begin FAIL (device)");
    return false;
  }

  int code = http.GET();
  if (code != 200) {
    Serial.print("HTTP device FAIL, code=");
    Serial.println(code);
    http.end();
    return false;
  }

  String payload = http.getString();
  http.end();

  DynamicJsonDocument doc(4096);
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.print("JSON device error: ");
    Serial.println(err.f_str());
    return false;
  }

  JsonObject fields = doc["fields"];
  if (fields.isNull()) {
    Serial.println("Device doc sin fields");
    return false;
  }

  uidOut = String(fields["ownerUID"]["stringValue"] | "");
  uidOut.trim();

  if (uidOut.length() == 0) {
    Serial.println("ownerUID vacío en devices/{DEVICE_ID}");
    return false;
  }

  // Intentamos obtener displayName si está en el documento del dispositivo
  nameOut = String(fields["displayName"]["stringValue"] | "");
  nameOut.trim();

  // Si no está ahí, vamos a buscarlo en el documento del usuario
  if (nameOut.length() == 0) {
    HTTPClient httpUser;
    String userUrl = buildUserUrl(uidOut);
    Serial.println("GET user: " + userUrl);

    if (httpUser.begin(client, userUrl)) {
      int userCode = httpUser.GET();
      if (userCode == 200) {
        String userPayload = httpUser.getString();
        DynamicJsonDocument userDoc(4096);
        if (deserializeJson(userDoc, userPayload) == DeserializationError::Ok) {
          JsonObject userFields = userDoc["fields"];
          if (!userFields.isNull()) {
            nameOut = String(userFields["displayName"]["stringValue"] | "");
            nameOut.trim();
          }
        }
      }
      httpUser.end();
    }
  }

  if (nameOut.length() == 0) nameOut = "Usuario";

  Serial.print("ownerUID = ");
  Serial.println(uidOut);
  Serial.print("displayName = ");
  Serial.println(nameOut);

  // 🔹 Enviamos al UNO que el dispositivo está vinculado
  String cmd = "DEVICE:LINKED:" + nameOut;
  Serial.println("→ Enviando al UNO: " + cmd);
  Serial2.println(cmd);
  delay(100);

  return true;
}

// ------------------- Paso 2: leer meds del usuario y mandar ADD -------------------
bool syncMedsForOwner(const String& ownerUid) {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  String url = buildMedsUrl(ownerUid);
  Serial.println("GET meds: " + url);

  if (!http.begin(client, url)) {
    Serial.println("HTTP begin FAIL (meds)");
    return false;
  }

  int code = http.GET();
  if (code != 200) {
    Serial.print("HTTP meds FAIL, code=");
    Serial.println(code);
    http.end();
    return false;
  }

  String payload = http.getString();
  http.end();

  DynamicJsonDocument doc(16384);
  DeserializationError err = deserializeJson(doc, payload);
  if (err) {
    Serial.print("JSON meds error: ");
    Serial.println(err.f_str());
    return false;
  }

  JsonArray docs = doc["documents"].as<JsonArray>();
  if (docs.isNull()) {
    Serial.println("No hay documentos en users/{uid}/meds");
    return false;
  }

  Serial.println("→ CLEAR (borrar alarmas anteriores en UNO)");
  Serial2.println("CLEAR");
  delay(50);

  for (JsonVariant v : docs) {
    if (!v.is<JsonObject>()) continue;
    JsonObject fields = v["fields"];
    if (fields.isNull()) continue;

    String name = String(fields["name"]["stringValue"] | "");
    if (name.length() == 0) continue;

    JsonArray times = fields["times24h"]["arrayValue"]["values"].as<JsonArray>();
    if (times.isNull() || times.size() == 0) continue;

    JsonArray wdays = fields["weekdays"]["arrayValue"]["values"].as<JsonArray>();
    int daysMask = 0;
    int idx = 0;
    for (JsonVariant wv : wdays) {
      bool on = false;
      if (wv.is<JsonObject>()) {
        JsonObject wo = wv.as<JsonObject>();
        if (wo.containsKey("booleanValue")) {
          on = wo["booleanValue"].as<bool>();
        } else if (wo.containsKey("integerValue")) {
          on = String(wo["integerValue"].as<const char*>()).toInt() != 0;
        }
      }
      if (on && idx < 7) daysMask |= (1 << idx);
      idx++;
    }
    if (daysMask == 0) daysMask = 127;

    int doses = 1;

    for (JsonVariant tv : times) {
      String tstr;
      if (tv.is<JsonObject>()) {
        tstr = String(tv["stringValue"] | "");
      } else {
        tstr = tv.as<String>();
      }

      if (tstr.length() < 4) continue;
      int colon = tstr.indexOf(':');
      if (colon < 0) continue;

      int hour   = tstr.substring(0, colon).toInt();
      int minute = tstr.substring(colon + 1).toInt();

      String cmd = "ADD:";
      cmd += hour;
      cmd += ":";
      cmd += minute;
      cmd += ":";
      cmd += daysMask;
      cmd += ":";
      cmd += doses;
      cmd += ":";
      cmd += name;

      Serial.println("→ CMD al UNO: " + cmd);
      Serial2.println(cmd);
      delay(40);
    }
  }

  Serial.println("Sincronización de meds completada.");
  return true;
}

// ------------------- Paso 3: sincronización completa -------------------
void syncFromFirestore() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Sin WiFi, no sincronizo.");
    return;
  }

  String ownerUid, ownerName;
  if (!fetchOwnerInfo(ownerUid, ownerName)) {
    Serial.println("No se pudo obtener ownerUID, no sincronizo meds.");
    return;
  }

  syncMedsForOwner(ownerUid);
}

// ------------------- SETUP / LOOP -------------------
void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, ESP_RX, ESP_TX); // ⚠️ ahora 9600 baudios

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  Serial.print("Conectando a WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("WiFi OK, IP: ");
  Serial.println(WiFi.localIP());

  syncFromFirestore();
  lastSync = millis();
}

void loop() {
  if (millis() - lastSync > SYNC_INTERVAL_MS) {
    Serial.println("Re-sincronizando meds desde Firestore...");
    syncFromFirestore();
    lastSync = millis();
  }
  delay(100);
}
