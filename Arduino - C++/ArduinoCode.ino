/*
   ARDUINO (UNO/MEGA) - Controlador Local del Pastillero
   - Motor Stepper
   - LCD
   - RTC (DS1307)
   - LED
   - Entrada de comandos por USB (Serial) y por ESP32 (SoftwareSerial en pin 3)
*/

#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <RTClib.h>
#include <EEPROM.h>
#include <AccelStepper.h>
#include <SoftwareSerial.h>   // 👈 AÑADIDO

// ====== Serial del ESP32 por SoftwareSerial ======
const uint8_t ESP_RX = 3;  // ESP32 TX -> UNO 3
const uint8_t ESP_TX = 4;  // (opcional)
SoftwareSerial espSerial(ESP_RX, ESP_TX); // RX, TX

// ========== LCD y RTC ==========
LiquidCrystal_I2C lcd(0x27, 16, 2);
RTC_DS1307 rtc;

// ========== Motor ==========
#define motorPin1  8
#define motorPin2  9
#define motorPin3  10
#define motorPin4  11
AccelStepper stepper(8, motorPin1, motorPin3, motorPin2, motorPin4);

const int led = 2;
const long STEPS_PER_DOSE = 2048;
const unsigned long HOLD_AFTER_DISPENSE_MS = 40000;

// ========== Buzzer ==========
#define BUZZER_PIN 6
const unsigned int BUZZ_FREQ = 2000;
const unsigned long BUZZ_TOGGLE_MS = 200;

// ========== Alarmas ==========
#define MAX_ALARMS 50
#define NAME_LENGTH 20
struct Alarm {
  uint8_t hour, minute, daysOfWeek, doses, active;
  char name[NAME_LENGTH];
};

#define MAX_ACTIVE_ALARMS 20
Alarm activeAlarms[MAX_ACTIVE_ALARMS];
int activeAlarmCount = 0;
bool alarmTriggered[MAX_ACTIVE_ALARMS];
int totalAlarmCount = 0;
int lastLoadedDay = -1;

unsigned long lastLCDUpdate = 0;
unsigned long bootTime = 0;
volatile bool isDispensing = false;

#define EEPROM_TOTAL_COUNT 0
#define EEPROM_ALARMS_START 2

// ====== Estado del dispositivo (nuevas variables) ======
bool deviceLinked = false;
char ownerName[NAME_LENGTH] = "";
bool wifiConnected = false;

// ---------- Utilidades RTC seguras ----------
bool dtInRange(const DateTime& dt) {
  int h = dt.hour(), m = dt.minute(), s = dt.second();
  int mo = dt.month(), d = dt.day();
  int y = dt.year();
  return (y >= 2000 && y <= 2099) &&
         (mo >= 1 && mo <= 12) &&
         (d >= 1 && d <= 31) &&
         (h >= 0 && h <= 23) &&
         (m >= 0 && m <= 59) &&
         (s >= 0 && s <= 59);
}

bool safeNow(DateTime &out) {
  out = rtc.now();
  if (dtInRange(out)) return true;
  delay(10);
  out = rtc.now();
  return dtInRange(out);
}

// ---------- EEPROM ----------
void saveTotalCount() { EEPROM.write(EEPROM_TOTAL_COUNT, totalAlarmCount); }
void loadTotalCount() {
  totalAlarmCount = EEPROM.read(EEPROM_TOTAL_COUNT);
  if (totalAlarmCount > MAX_ALARMS) totalAlarmCount = 0;
}
void saveAlarmToEEPROM(int index, const Alarm &alarm) {
  if (index >= MAX_ALARMS) return;
  int addr = EEPROM_ALARMS_START + (index * (int)sizeof(Alarm));
  EEPROM.put(addr, alarm);
}
void loadAlarmFromEEPROM(int index, Alarm &alarm) {
  if (index >= MAX_ALARMS) return;
  int addr = EEPROM_ALARMS_START + (index * (int)sizeof(Alarm));
  EEPROM.get(addr, alarm);
}
void loadTodaysAlarms() {
  DateTime now;
  if (!safeNow(now)) { activeAlarmCount = 0; return; }
  int currentDay = now.dayOfTheWeek();
  activeAlarmCount = 0;
  for (int i = 0; i < totalAlarmCount && activeAlarmCount < MAX_ACTIVE_ALARMS; i++) {
    Alarm tempAlarm; loadAlarmFromEEPROM(i, tempAlarm);
    if (tempAlarm.active) {
      bool isDayActive = (tempAlarm.daysOfWeek >> currentDay) & 1;
      if (isDayActive) {
        activeAlarms[activeAlarmCount] = tempAlarm;
        alarmTriggered[activeAlarmCount] = false;
        activeAlarmCount++;
      }
    }
  }
  lastLoadedDay = currentDay;
}
int remainingDosesToday() {
  DateTime now;
  if (!safeNow(now)) return activeAlarmCount;
  int remaining = 0;
  for (int i = 0; i < activeAlarmCount; i++) {
    const Alarm &a = activeAlarms[i];
    bool future =
      (a.hour > now.hour()) ||
      (a.hour == now.hour() && a.minute > now.minute()) ||
      (a.hour == now.hour() && a.minute == now.minute() && !alarmTriggered[i]);
    if (future) remaining++;
  }
  return remaining;
}

// ---------- Protocolo por texto ----------
void processSerialCommand(String command); // forward

String usbBuffer = "";
String espBuffer = "";

// ---------- Motor / LCD durante dosis ----------
void rotateMotor(const Alarm &alarm) {
  isDispensing = true;

  lcd.clear();
  lcd.setCursor(0,0); lcd.print(alarm.name);
  lcd.setCursor(0,1); lcd.print("Tomar: "); lcd.print(alarm.doses);
  lcd.print(alarm.doses==1 ? " pastilla" : " pastillas");

  digitalWrite(led, HIGH);

  stepper.enableOutputs();
  stepper.setMaxSpeed(1000);
  stepper.setSpeed(500);

  auto handleBuzzer = [&](bool enable){
    static unsigned long lastToggle = 0;
    static bool on = false;
    if (!enable) { noTone(BUZZER_PIN); on = false; return; }
    unsigned long nowMs = millis();
    if (nowMs - lastToggle >= BUZZ_TOGGLE_MS) {
      lastToggle = nowMs;
      on = !on;
      if (on) tone(BUZZER_PIN, BUZZ_FREQ);
      else    noTone(BUZZER_PIN);
    }
  };

  for (int d=0; d<alarm.doses; d++) {
    stepper.setCurrentPosition(0);
    stepper.moveTo(STEPS_PER_DOSE);
    while (stepper.distanceToGo()!=0) {
      stepper.runSpeedToPosition();
      handleBuzzer(true);
    }
    handleBuzzer(false);
    if (d < alarm.doses-1) delay(300);
  }

  noTone(BUZZER_PIN);
  delay(HOLD_AFTER_DISPENSE_MS);

  long back = -(long)alarm.doses * STEPS_PER_DOSE;
  stepper.setCurrentPosition(0);
  stepper.moveTo(back);
  while (stepper.distanceToGo()!=0) {
    stepper.runSpeedToPosition();
    handleBuzzer(true); // comenta esta línea si no querés sonido al volver
  }
  handleBuzzer(false);

  stepper.disableOutputs();
  digitalWrite(led, LOW);
  isDispensing = false;
}

// ----- nuevo: test simple del motor al encendido -----
void testMotorOnce() {
  // Pequeña prueba: una vuelta completa hacia adelante y volver, sin buzzer ni delays largos.
  stepper.enableOutputs();
  stepper.setMaxSpeed(800);
  stepper.setSpeed(400);

  stepper.setCurrentPosition(0);
  stepper.moveTo(STEPS_PER_DOSE);
  unsigned long start = millis();
  while (stepper.distanceToGo() != 0) {
    stepper.runSpeedToPosition();
    if (millis() - start > 5000) break; // timeout de seguridad 5s
  }
  delay(200);

  stepper.setCurrentPosition(0);
  stepper.moveTo(-STEPS_PER_DOSE);
  start = millis();
  while (stepper.distanceToGo() != 0) {
    stepper.runSpeedToPosition();
    if (millis() - start > 5000) break;
  }
  stepper.disableOutputs();
}

// ---------- Alarmas ----------
void checkAlarms() {
  DateTime now;
  if (!safeNow(now)) return;

  if (now.dayOfTheWeek() != lastLoadedDay) loadTodaysAlarms();

  for (int i=0;i<activeAlarmCount;i++) {
    if (activeAlarms[i].hour == now.hour() &&
        activeAlarms[i].minute == now.minute() &&
        now.second() == 0 &&
        !alarmTriggered[i]) {
      alarmTriggered[i] = true;
      rotateMotor(activeAlarms[i]);
      Serial.print("ALARM:"); Serial.print(activeAlarms[i].name); Serial.print(":");
      Serial.println(activeAlarms[i].doses);
    }
    if (activeAlarms[i].minute != now.minute()) alarmTriggered[i] = false;
  }
}

// ---------- LCD (modo normal) ----------
void updateLCD() {
  if (isDispensing) return;

  DateTime now;
  bool ok = safeNow(now);

  lcd.setCursor(0,0);
  char l1[17];
  if (ok) snprintf(l1, sizeof(l1), "Hora:%02d:%02d:%02d", now.hour(), now.minute(), now.second());
  else    snprintf(l1, sizeof(l1), "Hora: --:--:--");
  lcd.print(l1); for (int i=strlen(l1); i<16; i++) lcd.print(' ');

  lcd.setCursor(0,1);
  // Nueva lógica de estado para la segunda línea del LCD:
  char l2[17];
  if (!deviceLinked) {
    snprintf(l2, sizeof(l2), "No vinculado");
  } else {
    // Si está vinculado mostramos owner o 'Pastillero listo' si WiFi ok
    if (wifiConnected) {
      // mostrar propietario pero acortado si es muy largo
      char ownerShort[14];
      strncpy(ownerShort, ownerName, 13); ownerShort[13] = '\0';
      snprintf(l2, sizeof(l2), "%s Ready", ownerShort);
    } else {
      char ownerShort[14];
      strncpy(ownerShort, ownerName, 13); ownerShort[13] = '\0';
      snprintf(l2, sizeof(l2), "%s No WiFi", ownerShort);
    }
  }
  lcd.print(l2);
  for (int i=strlen(l2); i<16; i++) lcd.print(' ');
}

// ---------- Comandos ----------
void processSerialCommand(String command) {
  command.trim();
  // No convertir aUppercase para mantener nombres con mayúsculas/minúsculas
  // pero para identificar comandos usamos startsWith con mayúsculas
  if (command.startsWith("ADD:") || command.startsWith("add:")) {
    String c = command;
    c.toUpperCase();
    // delegar al parser original (convertimos sólo para identificar)
  }

  // Nuevos comandos para estado del dispositivo (pueden venir desde ESP32)
  if (command.startsWith("DEVICE:LINKED:")) {
    String name = command.substring(strlen("DEVICE:LINKED:"));
    name.trim();
    int len = min((int)name.length(), NAME_LENGTH - 1);
    for (int i = 0; i < len; i++) ownerName[i] = name[i];
    ownerName[len] = '\0';
    deviceLinked = true;
    Serial.print("UNO: Device marked linked to '"); Serial.print(ownerName); Serial.println("'");
    return;
  }
  else if (command == "DEVICE:UNLINKED") {
    deviceLinked = false;
    ownerName[0] = '\0';
    Serial.println("UNO: Device unlinked");
    return;
  }
  else if (command == "WIFI:ON") {
    wifiConnected = true;
    Serial.println("UNO: WiFi ON");
    return;
  }
  else if (command == "WIFI:OFF") {
    wifiConnected = false;
    Serial.println("UNO: WiFi OFF");
    return;
  }

  // Mantener compatibilidad con el parser original:
  // Convertir a mayúsculas para identificar comandos clásicos
  String upper = command;
  upper.toUpperCase();

  if (upper.startsWith("ADD:")) {
    if (totalAlarmCount >= MAX_ALARMS) { Serial.println("ERROR:MAX_ALARMS"); return; }
    int i1 = command.indexOf(':', 4);
    int i2 = command.indexOf(':', i1 + 1);
    int i3 = command.indexOf(':', i2 + 1);
    int i4 = command.indexOf(':', i3 + 1);
    if (i1>0 && i2>0 && i3>0 && i4>0) {
      Alarm newAlarm{};
      newAlarm.hour = command.substring(4, i1).toInt();
      newAlarm.minute = command.substring(i1 + 1, i2).toInt();
      newAlarm.daysOfWeek = command.substring(i2 + 1, i3).toInt();
      newAlarm.doses = command.substring(i3 + 1, i4).toInt();
      String pillName = command.substring(i4 + 1); pillName.trim();
      int len = min((int)pillName.length(), NAME_LENGTH - 1);
      for (int i = 0; i < len; i++) newAlarm.name[i] = pillName[i];
      newAlarm.name[len] = '\0';
      newAlarm.active = 1;
      if (newAlarm.hour <= 23 && newAlarm.minute <= 59 && newAlarm.doses > 0) {
        saveAlarmToEEPROM(totalAlarmCount, newAlarm);
        totalAlarmCount++; saveTotalCount(); loadTodaysAlarms();
        Serial.print("OK:ADDED:"); Serial.println(totalAlarmCount - 1);
      } else {
        Serial.println("ERROR:INVALID_VALUES");
      }
    }
  }
  else if (upper.startsWith("DEL:")) {
    int index = command.substring(4).toInt();
    if (index >= 0 && index < totalAlarmCount) {
      for (int i = index; i < totalAlarmCount - 1; i++) {
        Alarm tmp; loadAlarmFromEEPROM(i + 1, tmp); saveAlarmToEEPROM(i, tmp);
      }
      totalAlarmCount--; saveTotalCount(); loadTodaysAlarms(); Serial.println("OK:DELETED");
    } else Serial.println("ERROR:INVALID_INDEX");
  }
  else if (upper == "CLEAR") {
    totalAlarmCount = 0; saveTotalCount(); loadTodaysAlarms(); Serial.println("OK:CLEARED");
  }
  else if (upper == "LIST") {
    Serial.print("ALARMS:"); Serial.println(totalAlarmCount);
    for (int i=0;i<totalAlarmCount;i++){
      Alarm t; loadAlarmFromEEPROM(i,t);
      Serial.print(i);Serial.print(":");Serial.print(t.hour);Serial.print(":");
      Serial.print(t.minute);Serial.print(":");Serial.print(t.daysOfWeek);Serial.print(":");
      Serial.print(t.doses);Serial.print(":");Serial.print(t.active);Serial.print(":");
      Serial.println(t.name);
    }
  }
  else if (upper == "STATUS") {
    DateTime now; bool ok = safeNow(now);
    Serial.print("STATUS:");
    if (ok) {
      Serial.print(now.year()); Serial.print(":"); Serial.print(now.month()); Serial.print(":");
      Serial.print(now.day());  Serial.print(":"); Serial.print(now.hour());  Serial.print(":");
      Serial.print(now.minute()); Serial.print(":"); Serial.print(now.second());
    } else {
      Serial.print("----:--:--:--:--:--");
    }
    Serial.print(":"); Serial.print(totalAlarmCount); Serial.print(":"); Serial.println(activeAlarmCount);
  }
  else if (upper.startsWith("SETTIME:")) {
    int idx[6]; int last=8;
    for (int i=0;i<5;i++){ idx[i]=command.indexOf(':',last); last=idx[i]+1; }
    int year = command.substring(8, idx[0]).toInt();
    int month= command.substring(idx[0]+1, idx[1]).toInt();
    int day  = command.substring(idx[1]+1, idx[2]).toInt();
    int hour = command.substring(idx[2]+1, idx[3]).toInt();
    int minute=command.substring(idx[3]+1, idx[4]).toInt();
    int second=command.substring(idx[4]+1).toInt();
    DateTime nt(year,month,day,hour,minute,second);
    if (nt.isValid()) { rtc.adjust(nt); loadTodaysAlarms(); Serial.println("OK:TIME_SET"); }
    else { Serial.println("ERROR:INVALID_TIME"); }
  }
  else if (upper.startsWith("DISPENSE:")) {
    int c = command.indexOf(':', 9);
    String name = command.substring(9, c);
    int doses = command.substring(c + 1).toInt();
    Alarm a{}; strncpy(a.name, name.c_str(), NAME_LENGTH-1); a.name[NAME_LENGTH-1]='\0';
    a.doses = max(1, doses);
    rotateMotor(a); Serial.println("OK:DISPENSED");
  }
}

// ---------- Setup / Loop ----------
void setup() {
  Serial.begin(115200);      // USB → PC
  espSerial.begin(9600);     // UART desde ESP32 (pin 3 RX / pin 4 TX)

  Wire.begin();              // UNO: SDA=A4, SCL=A5
  Wire.setClock(100000);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0,0); lcd.print("  BIENVENIDO A");
  lcd.setCursor(0,1); lcd.print("    PILLBOX");
  delay(1500);

  if (!rtc.begin()) { Serial.println("ERROR:RTC_INIT"); }
  DateTime now;
  if (!rtc.isrunning() || !safeNow(now)) {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  stepper.setMaxSpeed(1000);
  pinMode(led, OUTPUT); digitalWrite(led, LOW);
  pinMode(BUZZER_PIN, OUTPUT);

  loadTotalCount();
  loadTodaysAlarms();

  Serial.println("ARDUINO:READY");
  bootTime = millis();

  // --- Mostrar estado inicial en LCD ---
  lcd.clear();
  lcd.setCursor(0,0); lcd.print("Comprobando...");
  lcd.setCursor(0,1); lcd.print("motor & estado");
  delay(800);

  // --- Test motor corto al encendido ---
  testMotorOnce();

  // después del test, mostrar estado real en el LCD inmediatamente
  updateLCD();
}

void loop() {
  // —— Comandos por USB/PC (Serial) ——
  while (Serial.available()) {
    char c = Serial.read();
    if (c=='\n' || c=='\r') {
      if (usbBuffer.length() > 0) { processSerialCommand(usbBuffer); usbBuffer=""; }
    } else usbBuffer += c;
  }

  // —— Comandos por ESP32 (SoftwareSerial) ——
  while (espSerial.available()) {
    char c = espSerial.read();
    if (c=='\n' || c=='\r') {
      if (espBuffer.length() > 0) {
        Serial.print("ESP->UNO: "); Serial.println(espBuffer); // debug a PC
        processSerialCommand(espBuffer);
        espBuffer="";
      }
    } else espBuffer += c;
  }

  checkAlarms();

  if (!isDispensing && (millis() - lastLCDUpdate > 1000)) {
    updateLCD();
    lastLCDUpdate = millis();
  }

  delay(5);
}
