/*
   ARDUINO (UNO) - Controlador Local del Pastillero
   - Motor Stepper 28BYJ-48 + ULN2003
   - LCD
   - RTC (DS1307)
   - Comunicación con ESP32 por Hardware Serial (pines 0 RX, 1 TX)
   - ALARMAS EN RAM (no usa EEPROM - se pierden al apagar)
*/

#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <RTClib.h>

// ====== NO usamos EEPROM ======
// Las alarmas se guardan solo en RAM y se pierden al resetear

// ====== Serial con ESP32 ======
#define espSerial Serial  // Usamos el Serial nativo

// ========== LCD y RTC ==========
LiquidCrystal_I2C lcd(0x27, 16, 2);
RTC_DS1307 rtc;

// ========== Motor (28BYJ-48 con ULN2003) ==========
const int IN1 = 8;
const int IN2 = 10;
const int IN3 = 9;
const int IN4 = 11;

// LED de estado
const int led = 2;

// Secuencia HALF-STEP
const uint8_t STEP_SEQ[8][4] = {
  {1, 0, 0, 0},
  {1, 1, 0, 0},
  {0, 1, 0, 0},
  {0, 1, 1, 0},
  {0, 0, 1, 0},
  {0, 0, 1, 1},
  {0, 0, 0, 1},
  {1, 0, 0, 1}
};

int currentStepIndex = 0;

const long STEPS_PER_SLOT = 2048;
const long STEPS_PER_DOSE = 2048;
const unsigned long HOLD_AFTER_DISPENSE_MS = 45000;

// ========== Alarmas en RAM ==========
#define MAX_ALARMS 7         //  Solo 7 medicamentos diferentes
#define MAX_ACTIVE_ALARMS 14 //  14 alarmas activas por día (2 por medicamento)
#define NAME_LENGTH 12       //  12 caracteres por nombre

struct Alarm {
  uint8_t hour, minute, daysOfWeek, doses, active;
  char name[NAME_LENGTH];  
};

//  ARRAY EN RAM - optimizado para 7 medicamentos
Alarm allAlarms[MAX_ALARMS];      // 7 × 17 = 119 bytes
int totalAlarmCount = 0;

Alarm activeAlarms[MAX_ACTIVE_ALARMS]; // 14 × 17 = 238 bytes
int activeAlarmCount = 0;
bool alarmTriggered[MAX_ACTIVE_ALARMS]; // 14 bytes
int lastLoadedDay = -1;

unsigned long lastLCDUpdate = 0;
unsigned long bootTime = 0;
volatile bool isDispensing = false;

// ====== Estado del dispositivo ======
bool deviceLinked = false;
char ownerName[12] = "";        
bool wifiConnected = false;

char espBuffer[64];  // Buffer de 64 bytes en lugar de String dinámico. Se debe aumentar si se quiere que los nombres de las pastillas sean mas largos o haya mas pastillas. OJO con la RAM!!
int espBufferPos = 0;

// Forward declaration
void updateLCD();

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

// ---------- Manejo de alarmas ----------
void loadTodaysAlarms() {
  DateTime now;
  if (!safeNow(now)) {
    activeAlarmCount = 0;
    return;
  }
  
  int currentDay = now.dayOfTheWeek();
  activeAlarmCount = 0;
  
  for (int i = 0; i < totalAlarmCount && activeAlarmCount < MAX_ACTIVE_ALARMS; i++) {
    if (allAlarms[i].active) {
      bool isDayActive = (allAlarms[i].daysOfWeek >> currentDay) & 1;
      if (isDayActive) {
        activeAlarms[activeAlarmCount] = allAlarms[i];
        alarmTriggered[activeAlarmCount] = false;
        activeAlarmCount++;
      }
    }
  }
  
  lastLoadedDay = currentDay;
}

// ---------- Helpers de motor ----------
void setCoilsFromIndex(int idx) {
  digitalWrite(IN1, STEP_SEQ[idx][0]);
  digitalWrite(IN2, STEP_SEQ[idx][1]);
  digitalWrite(IN3, STEP_SEQ[idx][2]);
  digitalWrite(IN4, STEP_SEQ[idx][3]);
}

void motorAllOff() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}

void singleStep(int dir) {
  if (dir > 0) {
    currentStepIndex = (currentStepIndex + 1) & 0x07;
  } else {
    currentStepIndex = (currentStepIndex + 7) & 0x07;
  }
  setCoilsFromIndex(currentStepIndex);
  delay(3);
}

void moveSteps(long steps) {
  int dir = (steps >= 0) ? 1 : -1;
  long total = steps >= 0 ? steps : -steps;
  for (long i = 0; i < total; i++) {
    singleStep(dir);
  }
  motorAllOff();
}

// ---------- Motor / LCD durante dosis ----------
void rotateMotor(const Alarm &alarm) {
  isDispensing = true;

  DateTime now;
  int dayIndex = 0;
  if (safeNow(now)) {
    dayIndex = now.dayOfTheWeek();  // 0=domingo, 1=lunes, ..., 6=sábado
  }

    
  // Ajustar dayIndex: Domingo(0) → 6, Lunes(1) → 0, ..., Sábado(6) → 5
  int adjustedDay = (dayIndex == 0) ? 6 : (dayIndex - 1);
  
  // timeSlot invertido: 0 = PM, 1 = AM (al revés de lo normal)
  int timeSlot = (alarm.hour >= 12) ? 0 : 1;  
  
  // Slot = 1 + (día ajustado × 2) + (0 si PM, 1 si AM)
  int slotIndex = 1 + (adjustedDay * 2) + timeSlot;

  if (slotIndex < 1)  slotIndex = 1;
  if (slotIndex > 14) slotIndex = 14;

  long stepsToCompartment = (long)slotIndex * STEPS_PER_SLOT;

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(alarm.name);

  lcd.setCursor(0, 1);
  lcd.print("%s");
  lcd.print(slotIndex);
  lcd.print(timeSlot == 1 ? " AM" : " PM");  // Invertido para mostrar

  digitalWrite(led, HIGH);

  moveSteps(stepsToCompartment);
  delay(HOLD_AFTER_DISPENSE_MS);

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Volviendo a 0");

  moveSteps(-stepsToCompartment);

  digitalWrite(led, LOW);
  isDispensing = false;

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("En reposo");
  lcd.setCursor(0, 1);
  lcd.print("Slot 0 (vacio)");
}

void testMotorOnce() {
  moveSteps(STEPS_PER_DOSE);
  delay(300);
  moveSteps(-STEPS_PER_DOSE);
}

// ---------- Alarmas ----------
void checkAlarms() {
  DateTime now;
  if (!safeNow(now)) return;

  if (now.dayOfTheWeek() != lastLoadedDay) loadTodaysAlarms();

  for (int i = 0; i < activeAlarmCount; i++) {
    if (activeAlarms[i].hour == now.hour() &&
        activeAlarms[i].minute == now.minute() &&
        now.second() <= 5 &&        // Permite disparar en los primeros 5 segundos
        !alarmTriggered[i]) {
      alarmTriggered[i] = true;
      rotateMotor(activeAlarms[i]);
    }
    // Reset cuando cambia el minuto
    if (activeAlarms[i].minute != now.minute()) {
      alarmTriggered[i] = false;
    }
  }
}

// ---------- LCD (modo normal) ----------
void updateLCD() {
  DateTime now;
  bool ok = safeNow(now);

  lcd.setCursor(0, 0);
  char l1[17];
  if (ok)
    snprintf(l1, sizeof(l1), "Hora:%02d:%02d:%02d", now.hour(), now.minute(), now.second());
  else
    snprintf(l1, sizeof(l1), "Hora: --:--:--");
  lcd.print(l1);
  for (int i = strlen(l1); i < 16; i++) lcd.print(' ');

  lcd.setCursor(0, 1);
  char l2[17];
  if (!deviceLinked) {
    snprintf(l2, sizeof(l2), "No vinculado");
  } else {
    if (wifiConnected) {
      char ownerShort[14];
      strncpy(ownerShort, ownerName, 13);
      ownerShort[13] = '\0';
      snprintf(l2, sizeof(l2), "%s Ready", ownerShort);
    } else {
      char ownerShort[14];
      strncpy(ownerShort, ownerName, 13);
      ownerShort[13] = '\0';
      snprintf(l2, sizeof(l2), "%s No WiFi", ownerShort);
    }
  }
  lcd.print(l2);
  for (int i = strlen(l2); i < 16; i++) lcd.print(' ');
}

// ---------- Comandos ----------
void processSerialCommand(const char* command) {
  // Crear copia local para manipular
  char cmd[64]; // mModificar si se desea aumentar la longitud del nombre de pastilla o la cantidad de alarmas. 
  strncpy(cmd, command, 63);
  cmd[63] = '\0';
  
  // Trim manual (eliminar espacios)
  int len = strlen(cmd);
  while (len > 0 && (cmd[len-1] == ' ' || cmd[len-1] == '\t')) {
    cmd[--len] = '\0';
  }

  if (strncmp(cmd, "DEVICE:LINKED:", 14) == 0) {
    const char* name = cmd + 14;
    
    int nameLen = min((int)strlen(name), 11); // 12 - 1 para '\0'
    strncpy(ownerName, name, nameLen);
    ownerName[nameLen] = '\0';
    deviceLinked = true;

    lcd.clear();
    updateLCD();
    return;

  } else if (strcmp(cmd, "DEVICE:UNLINKED") == 0) {
    deviceLinked = false;
    ownerName[0] = '\0';

    lcd.clear();
    updateLCD();
    return;

  } else if (strcmp(cmd, "WIFI:ON") == 0) {
    wifiConnected = true;

    lcd.clear();
    updateLCD();
    return;

  } else if (strcmp(cmd, "WIFI:OFF") == 0) {
    wifiConnected = false;

    lcd.clear();
    updateLCD();
    return;
  }

  // Convertir a mayúsculas para comparación
  for (int i = 0; cmd[i]; i++) {
    if (cmd[i] >= 'a' && cmd[i] <= 'z') {
      cmd[i] = cmd[i] - 32;
    }
  }

  if (strncmp(cmd, "ADD:", 4) == 0) {
    if (totalAlarmCount >= MAX_ALARMS) return;
    
    // Crear una COPIA del buffer para strtok (no modificar cmd original)
    char parseBuf[64]; //Modificar si se aumenta el buffer
    strncpy(parseBuf, cmd + 4, 63);
    parseBuf[63] = '\0';
    
    // Parsear: ADD:hour:minute:daysMask:doses:name
    int hour, minute, daysMask, doses;
    char pillName[NAME_LENGTH];
    
    char* token = strtok(parseBuf, ":");
    if (!token) return;
    hour = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    minute = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    daysMask = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    doses = atoi(token);
    
    token = strtok(NULL, "");  // Resto es el nombre
    if (!token) return;
    
    strncpy(pillName, token, NAME_LENGTH - 1);
    pillName[NAME_LENGTH - 1] = '\0';
    
    // daysMask debe ser mayor a 0
    if (hour <= 23 && minute <= 59 && doses > 0 && daysMask > 0) {
      allAlarms[totalAlarmCount].hour = hour;
      allAlarms[totalAlarmCount].minute = minute;
      allAlarms[totalAlarmCount].daysOfWeek = daysMask;
      allAlarms[totalAlarmCount].doses = doses;
      allAlarms[totalAlarmCount].active = 1;
      strncpy(allAlarms[totalAlarmCount].name, pillName, NAME_LENGTH - 1);
      allAlarms[totalAlarmCount].name[NAME_LENGTH - 1] = '\0';
      
      totalAlarmCount++;
      loadTodaysAlarms();
    }
  } else if (strncmp(cmd, "DEL:", 4) == 0) {
    int index = atoi(cmd + 4);
    if (index >= 0 && index < totalAlarmCount) {
      for (int i = index; i < totalAlarmCount - 1; i++) {
        allAlarms[i] = allAlarms[i + 1];
      }
      totalAlarmCount--;
      loadTodaysAlarms();
    }

  } else if (strcmp(cmd, "CLEAR") == 0) {
    totalAlarmCount = 0;
    loadTodaysAlarms();

  } else if (strncmp(cmd, "SETTIME:", 8) == 0) { //para el comando de seteo del RTC exclusivamente.
    // Crear COPIA del buffer para strtok
    char parseBuf[64]; //Modificar si se aumenta el buffer
    strncpy(parseBuf, cmd + 8, 63);
    parseBuf[63] = '\0';
    
    // SETTIME:year:month:day:hour:minute:second
    int year, month, day, hour, minute, second;
    
    char* token = strtok(parseBuf, ":");
    if (!token) return;
    year = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    month = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    day = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    hour = atoi(token);
    
    token = strtok(NULL, ":");
    if (!token) return;
    minute = atoi(token);
    
    token = strtok(NULL, "");
    if (!token) return;
    second = atoi(token);
    
    DateTime nt(year, month, day, hour, minute, second);
    if (nt.isValid()) {
      rtc.adjust(nt);
      loadTodaysAlarms();
    }
  } else if (strncmp(cmd, "DISPENSE:", 9) == 0) {
    // DISPENSE:name:doses
    char name[NAME_LENGTH];
    int doses = 1;
    
    char* colonPos = strchr(cmd + 9, ':');
    if (colonPos) {
      int nameLen = colonPos - (cmd + 9);
      if (nameLen >= NAME_LENGTH) nameLen = NAME_LENGTH - 1;
      strncpy(name, cmd + 9, nameLen);
      name[nameLen] = '\0';
      doses = atoi(colonPos + 1);
    } else {
      strncpy(name, cmd + 9, NAME_LENGTH - 1);
      name[NAME_LENGTH - 1] = '\0';
    }
    
    Alarm a{};
    strncpy(a.name, name, NAME_LENGTH - 1);
    a.name[NAME_LENGTH - 1] = '\0';
    a.doses = max(1, doses);
    rotateMotor(a);
  }
}

// ---------- Setup / Loop ----------
void setup() {
  espSerial.begin(9600);
  
  Wire.begin();
  Wire.setClock(100000);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  BIENVENIDO A");
  lcd.setCursor(0, 1);
  lcd.print("    PILLBOX");
  delay(1500);

  if (!rtc.begin()) {
    lcd.clear();
    lcd.print("ERROR: RTC");
  }
  DateTime now;
  if (!rtc.isrunning() || !safeNow(now)) {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  motorAllOff();

  pinMode(led, OUTPUT);
  digitalWrite(led, LOW);

  // empezamos con 0 alarmas
  totalAlarmCount = 0;
  loadTodaysAlarms();

  espSerial.println("ARDUINO:READY");
  bootTime = millis();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Esperando datos");
  lcd.setCursor(0, 1);
  lcd.print("del ESP32...");
  delay(800);

  testMotorOnce();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Esperando...");
}

void loop() {
  while (espSerial.available()) {
    char c = espSerial.read();
    
    // DEBUG: Parpadear LED
    digitalWrite(led, HIGH);
    delay(10);
    digitalWrite(led, LOW);
    
    if (c == '\n' || c == '\r') {
      if (espBufferPos > 0) {
        espBuffer[espBufferPos] = '\0';  // Terminar string
        
        // Advertir si el buffer estaba lleno (posible truncamiento)
        if (espBufferPos >= 63) {
          lcd.clear();
          lcd.setCursor(0, 0);
          lcd.print("Error: cmd largo");
          delay(2000);
        }
        
        processSerialCommand(espBuffer);
        espBufferPos = 0;  // Reset buffer
      }
    } else if (espBufferPos < 63) {  // Evitar desbordamiento. Modificar si se aumenta el buffer!
      espBuffer[espBufferPos++] = c;
    }
    // Si espBufferPos >= 63, se descartan los bytes extra silenciosamente
  }

  checkAlarms();

  if (!isDispensing && (millis() - lastLCDUpdate > 1000)) {
    updateLCD();
    lastLCDUpdate = millis();
  }

  delay(5);
}