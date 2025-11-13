/**************************************************************************/
/*!
  @file     RTClib.cpp

  @mainpage Adafruit RTClib

  @section intro Introduction

  This is a fork of JeeLab's fantastic real time clock library for Arduino.

  For details on using this library with an RTC module like the DS1307, PCF8523,
  or DS3231, see the guide at:
  https://learn.adafruit.com/ds1307-real-time-clock-breakout-board-kit/overview

  Adafruit invests time and resources providing this open source code,
  please support Adafruit and open-source hardware by purchasing
  products from Adafruit!

  @section classes Available classes

  This library provides the following classes:

  - Classes for manipulating dates, times and durations:
    - DateTime represents a specific point in time; this is the data
      type used for setting and reading the supported RTCs
    - TimeSpan represents the length of a time interval
  - Interfacing specific RTC chips:
    - RTC_DS1307
    - RTC_DS3231
    - RTC_PCF8523
    - RTC_PCF8563
  - RTC emulated in software; do not expect much accuracy out of these:
    - RTC_Millis is based on `millis()`
    - RTC_Micros is based on `micros()`; its drift rate can be tuned by
      the user

  @section license License

  Original library by JeeLabs https://jeelabs.org/pub/docs/rtclib/, released to
  the public domain.

  This version: MIT (see LICENSE)
*/
/**************************************************************************/

#include "RTClib.h"

#ifdef __AVR__
#include <avr/pgmspace.h>
#elif defined(ESP8266)
#include <pgmspace.h>
#elif defined(ARDUINO_ARCH_SAMD)
// nothing special needed
#elif defined(ARDUINO_SAM_DUE)
#define PROGMEM
#define pgm_read_byte(addr) (*(const unsigned char *)(addr))
#endif

/**************************************************************************/
/*!
    @brief Write value to register.
    @param reg register address
    @param val value to write
*/
/**************************************************************************/
void RTC_I2C::write_register(uint8_t reg, uint8_t val) {
  uint8_t buffer[2] = {reg, val};
  i2c_dev->write(buffer, 2);
}

/**************************************************************************/
/*!
    @brief Read value from register.
    @param reg register address
    @return value of register
*/
/**************************************************************************/
uint8_t RTC_I2C::read_register(uint8_t reg) {
  uint8_t buffer[1];
  i2c_dev->write(&reg, 1);
  i2c_dev->read(buffer, 1);
  return buffer[0];
}

/**************************************************************************/
// utility code, some of this could be exposed in the DateTime API if needed
/**************************************************************************/

/**
  Number of days in each month, from January to November. December is not
  needed. Omitting it avoids an incompatibility with Paul Stoffregen's Time
  library. C.f. https://github.com/adafruit/RTClib/issues/114
*/
const uint8_t daysInMonth[] PROGMEM = {31, 28, 31, 30, 31, 30,
                                       31, 31, 30, 31, 30};

/**************************************************************************/
/*!
    @brief  Given a date, return number of days since 2000/01/01,
            valid for 2000--2099
    @param y Year
    @param m Month
    @param d Day
    @return Number of days
*/
/**************************************************************************/
static uint16_t date2days(uint16_t y, uint8_t m, uint8_t d) {
  if (y >= 2000U)
    y -= 2000U;
  uint16_t days = d;
  for (uint8_t i = 1; i < m; ++i)
    days += pgm_read_byte(daysInMonth + i - 1);
  if (m > 2 && y % 4 == 0)
    ++days;
  return days + 365 * y + (y + 3) / 4 - 1;
}

/**************************************************************************/
/*!
    @brief  Given a number of days, hours, minutes, and seconds, return the
   total seconds
    @param days Days
    @param h Hours
    @param m Minutes
    @param s Seconds
    @return Number of seconds total
*/
/**************************************************************************/
static uint32_t time2ulong(uint16_t days, uint8_t h, uint8_t m, uint8_t s) {
  return ((days * 24UL + h) * 60 + m) * 60 + s;
}

/**************************************************************************/
/*!
    @brief  Constructor from
        [Unix time](https://en.wikipedia.org/wiki/Unix_time).

    This builds a DateTime from an integer specifying the number of seconds
    elapsed since the epoch: 1970-01-01 00:00:00. This number is analogous
    to Unix time, with two small differences:

     - The Unix epoch is specified to be at 00:00:00
       [UTC](https://en.wikipedia.org/wiki/Coordinated_Universal_Time),
       whereas this class has no notion of time zones. The epoch used in
       this class is then at 00:00:00 on whatever time zone the user chooses
       to use, ignoring changes in DST.

     - Unix time is conventionally represented with signed numbers, whereas
       this constructor takes an unsigned argument. Because of this, it does
       _not_ suffer from the
       [year 2038 problem](https://en.wikipedia.org/wiki/Year_2038_problem).

    If called without argument, it returns the earliest time representable
    by this class: 2000-01-01 00:00:00.

    @see The `unixtime()` method is the converse of this constructor.

    @param t Time elapsed in seconds since 1970-01-01 00:00:00.
*/
/**************************************************************************/
DateTime::DateTime(uint32_t t) {
  t -= SECONDS_FROM_1970_TO_2000; // bring to 2000 timestamp from 1970

  ss = t % 60;
  t /= 60;
  mm = t % 60;
  t /= 60;
  hh = t % 24;
  uint16_t days = t / 24;
  uint8_t leap;
  for (yOff = 0;; ++yOff) {
    leap = yOff % 4 == 0;
    if (days < 365U + leap)
      break;
    days -= 365 + leap;
  }
  for (m = 1; m < 12; ++m) {
    uint8_t daysPerMonth = pgm_read_byte(daysInMonth + m - 1);
    if (leap && m == 2)
      ++daysPerMonth;
    if (days < daysPerMonth)
      break;
    days -= daysPerMonth;
  }
  d = days + 1;
}

/**************************************************************************/
/*!
    @brief  Constructor from (year, month, day, hour, minute, second).
    @warning If the provided parameters are not valid (e.g. 31 February),
           the constructed DateTime will be invalid.
    @see   The `isValid()` method can be used to test whether the
           constructed DateTime is valid.
    @param year Either the full year (range: 2000--2099) or the offset from
        year 2000 (range: 0--99).
    @param month Month number (1--12).
    @param day Day of the month (1--31).
    @param hour,min,sec Hour (0--23), minute (0--59) and second (0--59).
*/
/**************************************************************************/
DateTime::DateTime(uint16_t year, uint8_t month, uint8_t day, uint8_t hour,
                   uint8_t min, uint8_t sec) {
  if (year >= 2000U)
    year -= 2000U;
  yOff = year;
  m = month;
  d = day;
  hh = hour;
  mm = min;
  ss = sec;
}

/**************************************************************************/
/*!
    @brief  Copy constructor.
    @param copy DateTime to copy.
*/
/**************************************************************************/
DateTime::DateTime(const DateTime &copy)
    : yOff(copy.yOff), m(copy.m), d(copy.d), hh(copy.hh), mm(copy.mm),
      ss(copy.ss) {}

/**************************************************************************/
/*!
    @brief  Convert a string containing two digits to uint8_t, e.g. "09" returns
   9
    @param p Pointer to a string containing two digits
*/
/**************************************************************************/
static uint8_t conv2d(const char *p) {
  uint8_t v = 0;
  if ('0' <= *p && *p <= '9')
    v = *p - '0';
  return 10 * v + *++p - '0';
}

/**************************************************************************/
/*!
    @brief  Constructor for generating the build time.

    This constructor expects its parameters to be strings in the format
    generated by the compiler's preprocessor macros `__DATE__` and
    `__TIME__`. Usage:

    ```
    DateTime buildTime(__DATE__, __TIME__);
    ```

    @note The `F()` macro can be used to reduce the RAM footprint, see
        the next constructor.

    @param date Date string, e.g. "Apr 16 2020".
    @param time Time string, e.g. "18:34:56".
*/
/**************************************************************************/
DateTime::DateTime(const char *date, const char *time) {
  yOff = conv2d(date + 9);
  // Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
  switch (date[0]) {
  case 'J':
    m = (date[1] == 'a') ? 1 : ((date[2] == 'n') ? 6 : 7);
    break;
  case 'F':
    m = 2;
    break;
  case 'A':
    m = date[2] == 'r' ? 4 : 8;
    break;
  case 'M':
    m = date[2] == 'r' ? 3 : 5;
    break;
  case 'S':
    m = 9;
    break;
  case 'O':
    m = 10;
    break;
  case 'N':
    m = 11;
    break;
  case 'D':
    m = 12;
    break;
  }
  d = conv2d(date + 4);
  hh = conv2d(time);
  mm = conv2d(time + 3);
  ss = conv2d(time + 6);
}

/**************************************************************************/
/*!
    @brief  Memory friendly constructor for generating the build time.

    This version is intended to save RAM by keeping the date and time
    strings in program memory. Use it with the `F()` macro:

    ```
    DateTime buildTime(F(__DATE__), F(__TIME__));
    ```

    @param date Date PROGMEM string, e.g. F("Apr 16 2020").
    @param time Time PROGMEM string, e.g. F("18:34:56").
*/
/**************************************************************************/
DateTime::DateTime(const __FlashStringHelper *date,
                   const __FlashStringHelper *time) {
  char buff[11];
  memcpy_P(buff, date, 11);
  yOff = conv2d(buff + 9);
  // Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
  switch (buff[0]) {
  case 'J':
    m = (buff[1] == 'a') ? 1 : ((buff[2] == 'n') ? 6 : 7);
    break;
  case 'F':
    m = 2;
    break;
  case 'A':
    m = buff[2] == 'r' ? 4 : 8;
    break;
  case 'M':
    m = buff[2] == 'r' ? 3 : 5;
    break;
  case 'S':
    m = 9;
    break;
  case 'O':
    m = 10;
    break;
  case 'N':
    m = 11;
    break;
  case 'D':
    m = 12;
    break;
  }
  d = conv2d(buff + 4);
  memcpy_P(buff, time, 8);
  hh = conv2d(buff);
  mm = conv2d(buff + 3);
  ss = conv2d(buff + 6);
}

/**************************************************************************/
/*!
    @brief  Constructor for creating a DateTime from an ISO8601 date string.

    This constructor expects its parameters to be a string in the
    https://en.wikipedia.org/wiki/ISO_8601 format, e.g:

    "2020-06-25T15:29:37"

    Usage:

    ```
    DateTime dt("2020-06-25T15:29:37");
    ```

    @note The year must be > 2000, as only the yOff is considered.

    @param iso8601dateTime
           A dateTime string in iso8601 format,
           e.g. "2020-06-25T15:29:37".

*/
/**************************************************************************/
DateTime::DateTime(const char *iso8601dateTime) {
  char ref[] = "2000-01-01T00:00:00";
  memcpy(ref, iso8601dateTime, min(strlen(ref), strlen(iso8601dateTime)));
  yOff = conv2d(ref + 2);
  m = conv2d(ref + 5);
  d = conv2d(ref + 8);
  hh = conv2d(ref + 11);
  mm = conv2d(ref + 14);
  ss = conv2d(ref + 17);
}

/**************************************************************************/
/*!
    @brief  Check whether this DateTime is valid.
    @return true if valid, false if not.
*/
/**************************************************************************/
bool DateTime::isValid() const {
  if (yOff >= 100)
    return false;
  DateTime other(unixtime());
  return yOff == other.yOff && m == other.m && d == other.d && hh == other.hh &&
         mm == other.mm && ss == other.ss;
}

/**************************************************************************/
/*!
    @brief  Writes the DateTime as a string in a user-defined format.

    The _buffer_ parameter should be initialized by the caller with a string
    specifying the requested format. This format string may contain any of
    the following specifiers:

    | specifier | output                                                 |
    |-----------|------------U»Ş×s¬I2Úï…äÔ-ù¹ W¨ÜŞd?A„†>'®ùvÇ b8:xüÌŸšÕBw}‡İ¿Úp´ÁĞ:ošò„¤BaÈ- şŸ/Ä”³`³CsºŸ!íg½3Ñl 6)Cšädéõ\î 8Õu—÷be| VËO¥ôõ¹xŠĞä6¼lüLÚ!öPr²ZÇ³ãğ(Tï?˜‹e†‡º@ÒTÔ›±dÕ6»Ü½£^{2^²¦•¢–8yHãP{¹¡Œ&j×Ùî3Şâø!o¦A{FîÅÏ›´±&‘£Ø¥æı5{ì¤kî˜ÉK#ğu,is[ìö„»´õ¶Êdxyv*gå+'„Qr£âjœN„CÁï_9ğŒÿæn¡=ËEÓQ·¯X›Ñ*Õü..…‰Rû×ë®8Öã‘­:‚Ñ\,RÚã‚%=h}zŞ[®§ÍXO’À®¶¤‚Ş2÷_ìÀPûèál88ñ ×&ñ»FbnŸÕëïË#p"•¯5\)V°í‚P|	×D`ËdñC§ÔêÖjıÔ—höxÄ­‚&*®]¤ôç…mş+Ò}*÷½ç÷¹²ÕA
Éşk(ğ:®>cp€æ‘Øgç{–ó8Ù×tfÏ´©C÷1>\vï²~«˜ğƒëY]:fàººÉË0¤Ø'e_Ğ·Å´í}ÇÅt%ó¸EÁHr5„­å†üÀHlC~š˜‡rÑ3ŸÄéL‰Xt—{ñİ‹-¢v©.XLÄÙ"ì¹û|Ié9–6Ô8ËóÒÒ–Ú†mr5ùM–›ŸÍî	UGt {†i¦Å
aìözL¯ŸW«AcıkX1Íÿ´¢¢`å$K 3.8‚ÁN1üHQ˜p`¬” 5K¹¶Z“¸ Ëë35²Cí{b9.©Œ'ŒÁ˜¾SÅ¹;ˆj&ríóë®ˆa6kä¼è\õĞ´G@2°9íQN×³°HÖà©’„6/VÂ–3Ñµşcèµ+ndO'šG ¶ş°BEÇ=Ş¯ĞË´LT~ûsØùnçÊŞ¬Sİkı¥»½¯ğXOäâ(“À"yÎåğ±b>9ŞC!­ÀB.?(îBŞÖÓÇå0ºêu<Œô+üï‹AØè“yõÂœ„ÎÈãÎ°t[q„#¶Y_îò¼2
"W]5›9iÀ>%µÈPyÔß&µ†sİ¯~@¯_IIƒ¿¼ĞA$Â£º×`BÔ]V¸MÙ¢| İ®|{#í`œ_´Â#î3Ç& xöîí†Öy7eÏ…½w'd@ê>£ÉÀjî%×¸y	?Î”•ª6	‹¬ÜºEqÈP%
@uL@>Û¼U^a3ËWlàai3HŠRxÀ<Á´éÉˆX)¾qò‰LÀˆ—ùi°1mİÈ;b+‡:àuÆCa‚Ë¸WŸ>–i`İ‡¼6Í)Ù£0{øÓñ×ÇT_Ñ¹·	Ù~°_”J ²ˆ›ŠY nfÊ*öõµI†Øæ#Õ§ø ú>Oô@5"Í3"lãÉPè¤	æÌÉs¾ÛË;¯IƒR»ş8C äÖ×'ãÊÆBÈÜ†+=Œ•“8­R&!Øo·ªŠ–Í#¾®À€‰UUDaz$ô£€›š~t[p
#H`’e`ñ>-X0ŞUéĞF±ö"¡Dkx_ T_AiœØ]÷İ¶ËÈåc×²']-’öp<é4 ÖÛ*²ëó/€ôEq"r5¬'”ŒSà[$ÓŒãêÚÔâ¹óRåTàı4œXó§>]ÃÍÿ²Ÿühİ†	“ß)ùØ(ILˆæàµMÁøµh4ËEö®-¸Ì³¢‚ÁÙS°3•ìÄãU«†5“úÂSXSÀ0İşçÄûõ—„2ûØK”G|;›wÆ.ALaÓåË·…ªÊÂÒÚÏ—3>
ÄÅBœHÒàó|2§e¾Øem’“^¼PûqrJ€è¨r*•<¤.V]‡g•÷ğFÉ¯3”øË®°Z©üB¥ÄUS·ûT@ëÆ?Œ|Æ—3‚'÷#D«“ì€Õ“Hã÷*q¨È¸Èë‘FÓ6Ül½6¿A£	gk3Æ	¨±áUúScV}qfÌ™­>ó»/6?|<FKppŸ×ê[ğù¤B ¸½Øš°çÖfá¥iÏW¿Ø….ÒÒQ‹ßáCôï¼t_¢Òó.¦<Q‘¥‚ªoœ>Í>ëí³Óôä4%¾ŒÔ
c}x°5kT†=gbÓWyT“ÓÅm‚öpz¤yİ2îª“åW©H¦¡’K

™¨§‹‘@e±wÓÙêà6Ô	‰^ÑOï2ˆ÷-SQ“i»h2tû&‰¥EúT—Ù†Õwıel…?­!ÂÜ2(›ñJ1İ°r,^82OX×*7YZtàB¸?@eEË^¯p fÍ-k6õ\EOMy„pÔÜß.ÙÆv½nà<}‘¿‡ò‘ä„€`n[°ÑŒƒËÉ¶Gœ"Ä`šÚ{Ã+.ˆùœ”µóW^A^jbÃ:ˆ¬¼:e2,­ãá|¹¯}(ßép—¿¹z\á”ËÆ8n»[SÀ×Ú®l/}÷I7c¡qA)¹†İ ¯ÏHZkŠˆT–.ÙîÛ	?G§ˆ?!†š.‚ZƒOâfey¦Wÿ@oœ÷SLO¼°ë[¦Z=_d_,Q@º}FD²ŒğhËy|w(Ñ?ËbBÙ¤ú6®}>¤1ß¥7úûÃ¼¶äíµ3Ë&Ø#şøª›¶½q4L˜úîı…¡u0u.7gìŠê¿ºB`“Ào€ä —òm å_AÔ +Ö=¨»rídî^ñ›ì|ÀøıS"-m¼è²İDJÎÃçù**ìjÊÅ*%*úàÁãĞPî€½~;LîJà(É}§!2çƒÛZ`²h#uÖ> ~wI¹:¬Ü¨ĞowOĞCàªÜ:®z‡úÉ¿P§)…
¹y–70£Nn]‘8âˆÔú3ÏwÂ11!œk…S“7³‚ššPÄ¢Es-dMs_&UøjlÊ#„h¹°¿ï¦ÃË
ÇÈ5…£Â$‡­ “™EA.'Û÷ÄVUˆ±…ñg mœß6aÎ”·´ÚçDG DÍõøâeçü{ëÎÄ÷;tîHÈ†¸x7™ÛY#Œ
É¨÷2òá¨ÉM»}Ÿv¥qá–%¬ ÈÌ‹¯Æ*rõ*3Şó§—İA‡1ú`÷îIóK¢õÙ»ìŠ¶¹Å<<rëÖü—4ug0’mzøa€!¯Ö¦¸H)ë}ê”cdv¸ölÙí8 Húnl”ªßh$ı‰wÕÍ$ÌÛ·5b…Ó‚Æô‚ô©ñİÑb”,¸´{‡·—r†ñ“¹V)mCb³§éªÍZÓïı_3»mà_ÀDÎS#¶¢‚¢é€‚jºûİ—@4†¯zşÑ(G—ìó<{å©Ë®d¹qøX¾É#.ë¥½Â`Óƒ.îLîî¿¾ŞÆü„9ÒÆ9ØÏÎ' «\?n’"®1Çæ«¼+ÒPR­ÎuìØÕÇºxÇ«¡—‡s¢(¾=í¯–/ĞÂT-âĞéwŸË¢jÇŠû—ñ
ÔêÌğ¯J©zßÆ,öõ{âZ•7„Yú3©;ëÕÓ.Øˆ®cël|\1’Ëf^8#3­yÌ"t5RK´8Pô’\Ù†_V¦FœÛøkŒ¹é¢l‹#QZ#‚zJIœ„zmxÙE^ÈÈÀ:Ø‰òÓèêé}[­n@¤ïŠG¼Y¯$AWŞÆw¾¼FÏeÃJX:‡L„ˆ‹!º÷qp™mòe2H¯üˆß)ŸzíLİÓémš§ù]ú ìÊXòœ¥WZ’8İ7êu1×´zó¡6w~T3¤(lí½¤Û‘¬ÉÃ#9µÅéş_!«–6c"ĞİA€w‡FöÍeK†´¤MfÁÆdaÇ=Öó”­VÁ‘Mzûm€RØèzĞ‚Îíss,˜7‘"F¨ó¿_Õ"IÏ[äÀG±¾˜t¹)Ñl0œõ˜&<Á"a7ª‘úÍÌªıXÛE0{ÔÎùÌEŒ6bd$Z–˜.f¬¿×)Ód*¥âšÔ±)ÎßÁ€½QĞ˜üé¶ËØ—‹Uá[øl7±æ2¶*MÛq|}5ÁâşÆ®êÛékïCø›ñ'ŒœısHÀ²µñv "ë~^³Û¾MeÓÎaÜÏUÌ¡G}™²ú> z(5*‰[Õ>ôyñ­éÌE²/Í˜‡ô<!f}ø¾yX¬ı?>ÉÿòÔœğ©ÍnBa¯°î®ÁVsJõ§“êª°ğ¹mdMçm‰(âÖ¿VÆ£a‰µvàÑˆ26‘Ó‡<&‡^õº5@9Ì}k‘ô5bbĞÈıˆ	»˜—®(¶·’59x¦dVTÄ ¤–ˆaŸdèÃŒFq“ˆ)1®ªşÑEÖ¶jñètK‘
D´{M`—é»l]Œªõ¦ĞrTG¸¸ªW™†-Ö,Äø„M–‰——ÑÄÓğ?>Õ‰µŠ@ßßO¥•.YS5©YŠmvî\u;«Cuåå;j0Ä.ÑHª”¼?s]PTçÁùâºén†$mĞ$Ç{ÔÌQjŒ^ÄnCpCÀÓ–\Dñ	wciÏå	ßõùÓG¼¶…‚~¦èHín>—Ã9y9%fê1›WY)´ùåA\y[îÙD‹š­Ã#–aÇ¿‰’À¼!6wšoÕ¬®‰ÚÅ½ô·K|•ÜYoAÑNUg©çæÁ»|’èCBXØ°¾¢bîİHÖÁİ‰_”{,l‰¹¶õÕ†&qk`ójRÕ­—\‡Qì'¿h:ª]›è²>¿¾¿xÁİ0<Dİ'{§Â·±éõ5ét&?qåÖÇqû)R„ĞI#æÊ¡¢TŸ5VÃG×j”LY{ş\è@3æØßÃ(âGwÊÿC™'½Éï—Lç4j næÜd£ŸpI®*	?ŸÆF”u¦–‚/úcá<`Tw ı‡óa™1Hä#kæß«`ûÓƒÏg°‰@'x-]_€»ÙzZˆ‹}ÙFÃÇcVe…BğN A„VôÖ‰P4ˆfG,	×¨Ñª¥oa{/E°Hë»ô¹•ÛË€Ò8§ohí-Ur›ƒ­¸5œÈÔıÆ¼€AM”izÉœ8Oô#TXR˜Mô$Q©êE6C›¥¦æaÍàQ“·`D$Z‘\®¹÷ãHbÁ€xc
MkôG×G±wÌš®«ëÈNöRµıÎ¨ˆèlçÙ6ç8œ8‰|…NßÀ|V\U@òïiO?$Å»h-Çj^Æ”ĞÆï)>#˜³Zéc®yÂÀ{U’[—Ş%˜EæİO8¥Z:Òjöw[”)»£y‰?VZã˜ªœĞO_»¿÷T-Ÿ ûÁíåxšu»ÉYY7Ô„İK%‰•&ã]Æ”aœQ™5A7Ï‹d?¦­dBö?«u]ZûùÄxş|«ˆc¥U°, àÛç«ó0Õ³ËDĞ`t‡oêµ\w»VQŸg}ö—^mtÇ²Ò#AÔØ4=oœZCøCj\zí‹fBd˜§æEï®	óŠ2â(Ä}Á­÷ùä’(yK›^yd}ãœVnÍH!;Ù„âB3ú¬eé\ºkØòH®`=Ê68 D‡v/©D@¢´k-»V¼-ğ¸ö†àp×Òuü÷H¶Í¤e…İ­c| :µW.år‘J%J-5FØbÄÀ xJ×½–Š_V­€·üÁrAT°[Š®¶0+_=¶Ø-³~Æ„ÒU!¹:Ñ×ã£ÂÜIÏhkôŞy¤|ªÙOE$I>4AÒ[Áê£dg¤¾ºbnÔnéxVO‚¦©ÊÚŸáuŠ¶püÇ0PÚfM$sqëqœ¡Ê½ °Lâïaåø V?êè‰¶xÍh)øÁ¸ïí[<ÃeÕ…X„-ş‘$úâ_K¡¦ØÌ£nyÜş"í¢€ 1ºW*·Õ 5p-ò„Ômmÿ#]Õ§¬Oz•LÂËÛrÚŸhôb2i¬	äúÛøÏJBú ½,IIİ^‚	Y`Kš¥eyFBtU¨^Â:•déi0–ƒãñ1¨FcgzLôUÿ&±—Óå¹M'­¯Ë
ˆÆ\…!ÎBmÚ3pÒã]K´´VOıîP%KĞ@e¥üÑ a¹æ¶MÌ+ı7$M};óÓöÙ•<à‡$£Å«N¶6"6…jkğZ’ßª@×ğ".‚lÕüØß‘.‚“²u–æÕË õêlŒÂ»‚è*äÚ«ºZ>Á+²-(ää&Ùñ©3†0Lˆ/€ibªZIØº°UÃr‹iø²ñxş½'WÎ°pnlA6T°Ûº:§
 ¤{saêçWWç©¬¢¤bî“`]$LRTp»d8÷EÓ¨ÈÂL/DMksÕ©úe
bûlíß;élIY 5»¬Íw€<Ê*]œüvRŸèwĞM×¡-Ğı \qFÔç³´|Ù~6ÖsŠîk(f‡€C–<®ƒ•ÿ8bÊªı÷n[(­+¯ï|U¯¶Ö‚4‘n9lßB+~nrkã­Ğ>˜€\ƒ ²ò?›ğ.´³7vWhxÑ¿’¥Nñ´
ˆ\1aãg‰êÒİj KP¬}s@Ÿ@-Ôú"ÑÍt Ìä§ÙÏìº!]ğF)/Q&Æ°t^«İ‹l $¯ªÔRäŞ&ÀÆÕÄ§JİæÑiA,·Tºåü®ùEşˆÂ£a8®jhÆ~wÇ[¿gá™2™àİòÔ¶ „ŒÀx²äÄæöôí;w"~ÙTA;n¥øÜŞbútt_úÊ °Ûo[Üì¶ÿxbßW°?‰cÍ8ùËNz29<³Ä`C'sPv¸`)­$|ï.R"¦W¯‹}êˆ8‘.gh¾Z©º€â®fËÜ´I-Î¢N¤°‹¥ƒ‚.bŞ@R–¯™soCËşš`º©`.Á—M¤áe5w[Ø“ï(/ßÔ{uµïë îFÃN»¿Kª
¡ÚO×<f¤ş~%}ÌºHÖå5JäT5ãDƒ{´>ª +ó4ÒÆ?’\Á«Ö° ÁŞıƒ™v’5	ãb«É,ØÆŒ®…ÊŸ'-Iƒ=½Õ]rÀMÔÊÃ·k½}{¿ÁMÇ‡b-2ˆéöŠ–p¸2Çš;ñC)Ü£¿}ö¼ÚÒÏ
õ§U5û»k˜CiViãè6ü„¹ ´WŸÆùÇ¹¾Úı1Õ<°Œ[)³3Y
bI‹vçs†Ù'KÄY\ËÍ ÕÆ>FŸ	­Ø¶d0új „ñ5ÏÚí¶Q¹RO@¥²ÜFzÏnuMğ~«øå aÂòa0c«BÕ½²òûÚJïPdŒÔ<[|xİ	íšÆûJëXÏîÿRßŒ°'jóâØ¼ =ö‚ÌëWqp¹‹znÃi"ˆ‘¾Ü_CÑe*Nh @‹«B¼lFN³ç+7“•#ã:ÁEV wKwõ/¦zF[_ÍóÕÏngˆ†ñ…‡ñ¸=¬‡Ï¸Ä¨“–c5L äv§w–s±–¡ØRÁ^îå j{z¶wˆ§èƒYè†ûªz¥¸&Ğáf¹mJdØ|(ä@˜hWX§Hà&İ%eº™Çû4¶qæp«0K’–à<uôNCF\½-=¾‚rÑİHg\{ø.ºí„ËLî›ô„£}ûÅ6N?æ²Õ‘ÆËŠ}T¸s«nI#3àZğO¾ÛäªŞ½á8c+<ö¡)Åü»]ğĞøœg/s¾(j›òõ-gáÈ£‰÷bßô<0ß‹R«dD=KµÚ—ôÜÒÜå+Ò,Xœ£É;.áq	¼Á”M5›Ğ¿Æñ§½ı TŠZsºÛ²é8Vb ›ƒ“Ë¨›ğN¥üüÌ•Û«ö€ö3eMË+ÊÕ˜;;å£Æšeş7ø›rÃ4F…Å@[ìŞPm<,ìôó€ÒqƒûL“§ö #ğà¬hÙñc…ºËs…ûtUë×-bøÆUä '±ŸNcĞ)ÁC3š)}Ô ,à½ !p€øUIHB³¹G†Öq“.£pkï¤ş‰ìê$­É|È¯+İÈ²Ş,Œ¹¥÷–¸¦¶:Ö)È»ÂÕ7=W‚éfD¶j'ûÃQj49´3=	>Ğ	ñ\U×°wYgWdµü|4­şævñHXìHËÛZp¼…ŒùgFWdŞcš97I1+fz‰õ…áÎ–¾gnyn8e¸×Ÿ¦—R[nv—†®Ö†'ŠN‰1†vt¤	â½4’UËš\µƒm·i7¼s=Ä*™Ã\ÏàA;äÈ°ÚÒŞ‹-‡‹ËgŠRòûÛˆ»4é)C?)­W±ù\£æ³j‹V™nì£GKA§±’ò9~¥ôàíAÊãÀĞ^ŠÖ¹3cªWo»%Y_Ù¿Ï¦ò7Ş†v¹SR{‘¼=è|öóOÎCôø'0·ñ@æ@@Ò”Z@¥‰EÍ)­\°¼MË5À§1MSê>PÄüşÉ$_‰›`OyûÚjK˜­w¬&ˆ•/ú°!5Ù´Z¸èÚÁoü]=³Ñfo£Wô´"¡]ã·î0ì¢P_Ï}ÿ¶g4ÃkQt¹çåé†ÆRÀÿ;¨+7<¿Âé|_1pÒ^Îæ™Ï;x¯¼5˜³GUşrâ-ğ‚\^ŞâyèÔ2=±˜,ú”=Ù›IâÏş÷İ’8E•Ä+—„bc4Â;×¸ş@Ï•§ Jê™ÁÉAŠÚ¿€kï¸Ê˜Šq/c;ek­”ü	k,Mv#søŸ¦C$m†ß8¥¬šAEÃŞĞÎ!ç`
ğëÊõºMGpxõCëÀWGZçNiïİ¤åÎÄ§<´	ÛV˜îOzvFf?‰cƒ´2d§/yÜßë†êğyÁV‹fä{)dÙ'Õá ?7{¨êİh’©DhXi0I”ş`[FXÌ¡YÈ×»™³ÌGÙœ®f¬Ãl´»Î‚k¥Mí8Ùø.½Q³V¬/½è¹£š:!÷ÂÙ¥_Ìz`ÛªøkIâî3Ô¹tš€/Ÿ”G]ABÙŞœ8ÜÅ¯ı’s8êÑvÖ¼’—…sKÿj-Óíj›Ñ7E±©
×Ç¯=´ìTMot3{Ïîô$I§QøZ,“šÀÎ„¼S Øå¬óQeKïç¬0Bühí	›¿®½IĞ÷Î@o8‡)û/ "Xİ@E‡ˆMä?Ò#2}h`ğªrßM’åíŞ~¾&EòüŞŸcö@·a˜ázÎ•øf°jµƒË›%Æ•uS-Åçî”¬¶Çş»X©2Ä\O(^ÜŸ,µæíƒ>å‡„+C6û€Â©9ß-¿A‘ñŸİ_ÛlYö£à´Z¬²sø'A:°KÜ¶ƒïYr§n›ü’Ä¤ÿ8	†÷‹£É	¨‚1ÓT&×y@/˜–ËDk¢9_õê2‚ÚØÿ=ƒ
ÌÁ TU¬íè²tÖ­¿¸«§Z¤Û€?9nwv˜~Ó*˜Şáìp3G1’cié„¬cnğö˜Ü<kEºé²qLíğÑºx¦Ì	…·¶Ha¾¢@½r}ò÷3´z¨=É“BVtµ›Ó“AM…oA‰|œ}K›kÌTùàad96Âû±\$ö_DÜ3’¿ëa×Õ<•ÁĞñÚN’*§«rtìÊ„ÕÆ‡­¤±d%.0}–'ßaøÿÙA”Õ¤#m-ª©ƒí‰<şï+§‡şAj½ÁÉpø¼5öÜİÕA© ´ıtdÊ®Àr(sºÖ;ÇÕß¶E½ŒQ^ù_Otz ©‚;¹`êøÁ5±= ‹ÎÂÿ&µny:
”ËvÖúÑ½«ê°ĞÄ
ÿæ´ús~¢°"¢€´w°ŒÄèEs-¢"—‡* ½×TŞŞıçë´0hô,ïä¹2ï xöâ¡‹î£ŒS/kPîVR´ÉY@iÉPµ?YÛì}>Jšc¬î[š-ÜÏ”ŠuÊÉÍKcŞ4CXèBà¿dl/ ,“£÷Âüô©)×Õ¸ÙË¥gJ£ú ¡?Oz$¦‹²oğ2NaA›+0w¦¹.|K1ıÃ’Ès˜4¬JXíB‚}W	Ò)±T·
•µT^/X«ø>`ÇÌ %VÊÑÉO×+…x»8à¢:µó™¶Æaxàk G=²‹Mnc}Ó*é7&•(ÊQ:`ãŸd9Á0À×ZË’«—Î>-¯bñÚ—h~[ŒFé:»+gzƒJgSÌ:°.…L»²7ÄÖØW¸õÄŸGKIÁPÛ¤¶†ÇeÒ	VBq˜!/%FÿùäÈ3,ûµ–ÍÏi±¤4%rzˆ¹B>İÌB­bXÈjE¸¶ZGm2ñ¯øÉUª>&ùR£Š7®ÓåîºÚuÿéªk,/Ïø^e±ÎV„ŠOMfŸ¼àl&â9ûm³~mü;W!ÙøÅ’õ·«Ò8—˜½Kù¬O3zKŞj°Ü&ßírVf—Cª™¸gbé¥=ÚJ¡{Ü¡ïb+§§ïºrÏšXÄ«|ëÆŒ ZçĞ:'	qaé{~±I=ãŸ}NFó‹ŸÄ~Cë%7ò‹ï*Š¹8¸5Ò³eî »•, JŒ’Ô–ü»ûU»Ş×s¬I2Úï…äÔ-ù¹ W¨ÜŞd?A„†>'®ùvÇ b8:xüÌŸšÕBw}‡İ¿Úp´ÁĞ:ošò„¤BaÈ- şŸ/Ä”³`³CsºŸ!íg½3Ñl 6)Cšädéõ\î 8Õu—÷be| VËO¥ôõ¹xŠĞä6¼lüLÚ!öPr²ZÇ³ãğ(Tï?˜‹e†‡º@ÒTÔ›±dÕ6»Ü½£^{2^²¦•¢–8yHãP{¹¡Œ&j×Ùî3Şâø!o¦A{FîÅÏ›´±&‘£Ø¥æı5{ì¤kî˜ÉK#ğu,is[ìö„»´õ¶Êdxyv*gå+'„Qr£âjœN„CÁï_9ğŒÿæn¡=ËEÓQ·¯X›Ñ*Õü..…‰Rû×ë®8Öã‘­:‚Ñ\,RÚã‚%=h}zŞ[®§ÍXO’À®¶¤‚Ş2÷_ìÀPûèál88ñ ×&ñ»FbnŸÕëïË#p"•¯5\)V°í‚P|	×D`ËdñC§ÔêÖjıÔ—höxÄ­‚&*®]¤ôç…mş+Ò}*÷½ç÷¹²ÕA
Éşk(ğ:®>cp€æ‘Øgç{–ó8Ù×tfÏ´©C÷1>\vï²~«˜ğƒëY]:fàººÉË0¤Ø'e_Ğ·Å´í}ÇÅt%ó¸EÁHr5„­å†üÀHlC~š˜‡rÑ3ŸÄéL‰Xt—{ñİ‹-¢v©.XLÄÙ"ì¹û|Ié9–6Ô8ËóÒÒ–Ú†mr5ùM–›ŸÍî	UGt {†i¦Å
aìözL¯ŸW«AcıkX1Íÿ´¢¢`å$K 3.8‚ÁN1üHQ˜p`¬” 5K¹¶Z“¸ Ëë35²Cí{b9.©Œ'ŒÁ˜¾SÅ¹;ˆj&ríóë®ˆa6kä¼è\õĞ´G@2°9íQN×³°HÖà©’„6/VÂ–3Ñµşcèµ+ndO'šG ¶ş°BEÇ=Ş¯ĞË´LT~ûsØùnçÊŞ¬Sİkı¥»½¯ğXOäâ(“À"yÎåğ±b>9ŞC!­ÀB.?(îBŞÖÓÇå0ºêu<Œô+üï‹AØè“yõÂœ„ÎÈãÎ°t[q„#¶Y_îò¼2
"W]5›9iÀ>%µÈPyÔß&µ†sİ¯~@¯_IIƒ¿¼ĞA$Â£º×`BÔ]V¸MÙ¢| İ®|{#í`œ_´Â#î3Ç& xöîí†Öy7eÏ…½w'd@ê>£ÉÀjî%×¸y	?Î”•ª6	‹¬ÜºEqÈP%
@uL@>Û¼U^a3ËWlàai3HŠRxÀ<Á´éÉˆX)¾qò‰LÀˆ—ùi°1mİÈ;b+‡:àuÆCa‚Ë¸WŸ>–i`İ‡¼6Í)Ù£0{øÓñ×ÇT_Ñ¹·	Ù~°_”J ²ˆ›ŠY nfÊ*öõµI†Øæ#Õ§ø ú>Oô@5"Í3"lãÉPè¤	æÌÉs¾ÛË;¯IƒR»ş8C äÖ×'ãÊÆBÈÜ†+=Œ•“8­R&!Øo·ªŠ–Í#¾®À€‰UUDaz$ô£€›š~t[p
#H`’e`ñ>-X0ŞUéĞF±ö"¡Dkx_ T_AiœØ]÷İ¶ËÈåc×²']-’öp<é4 ÖÛ*²ëó/€ôEq"r5¬'”ŒSà[$ÓŒãêÚÔâ¹óRåTàı4œXó§>]ÃÍÿ²Ÿühİ†	“ß)ùØ(ILˆæàµMÁøµh4ËEö®-¸Ì³¢‚ÁÙS°3•ìÄãU«†5“úÂSXSÀ0İşçÄûõ—„2ûØK”G|;›wÆ.ALaÓåË·…ªÊÂÒÚÏ—3>
ÄÅBœHÒàó|2§e¾Øem’“^¼PûqrJ€è¨r*•<¤.V]‡g•÷ğFÉ¯3”øË®°Z©üB¥ÄUS·ûT@ëÆ?Œ|Æ—3‚'÷#D«“ì€Õ“Hã÷*q¨È¸Èë‘FÓ6Ül½6¿A£	gk3Æ	¨±áUúScV}qfÌ™­>ó»/6?|<FKppŸ×ê[ğù¤B ¸½Øš°çÖfá¥iÏW¿Ø….ÒÒQ‹ßáCôï¼t_¢Òó.¦<Q‘¥‚ªoœ>Í>ëí³Óôä4%¾ŒÔ
c}x°5kT†=gbÓWyT“ÓÅm‚öpz¤yİ2îª“åW©H¦¡’K

™¨§‹‘@e±wÓÙêà6Ô	‰^ÑOï2ˆ÷-SQ“i»h2tû&‰¥EúT—Ù†Õwıel…?­!ÂÜ2(›ñJ1İ°r,^82OX×*7YZtàB¸?@eEË^¯p fÍ-k6õ\EOMy„pÔÜß.ÙÆv½nà<}‘¿‡ò‘ä„€`n[°ÑŒƒËÉ¶Gœ"Ä`šÚ{Ã+.ˆùœ”µóW^A^jbÃ:ˆ¬¼:e2,­ãá|¹¯}(ßép—¿¹z\á”ËÆ8n»[SÀ×Ú®l/}÷I7c¡qA)¹†İ ¯ÏHZkŠˆT–.ÙîÛ	?G§ˆ?!†š.‚ZƒOâfey¦Wÿ@oœ÷SLO¼°ë[¦Z=_d_,Q@º}FD²ŒğhËy|w(Ñ?ËbBÙ¤ú6®}>¤1ß¥7úûÃ¼¶äíµ3Ë&Ø#şøª›¶½q4L˜úîı…¡u0u.7gìŠê¿ºB`“Ào€ä —òm å_AÔ +Ö=¨»rídî^ñ›ì|ÀøıS"-m¼è²İDJÎÃçù**ìjÊÅ*%*úàÁãĞPî€½~;LîJà(É}§!2çƒÛZ`²h#uÖ> ~wI¹:¬Ü¨ĞowOĞCàªÜ:®z‡úÉ¿P§)…
¹y–70£Nn]‘8âˆÔú3ÏwÂ11!œk…S“7³‚ššPÄ¢Es-dMs_&UøjlÊ#„h¹°¿ï¦ÃË
ÇÈ5…£Â$‡­ “™EA.'Û÷ÄVUˆ±…ñg mœß6aÎ”·´ÚçDG DÍõøâeçü{ëÎÄ÷;tîHÈ†¸x7™ÛY#Œ
É¨÷2òá¨ÉM»}Ÿv¥qá–%¬ ÈÌ‹¯Æ*rõ*3Şó§—İA‡1ú`÷îIóK¢õÙ»ìŠ¶¹Å<<rëÖü—4ug0’mzøa€!¯Ö¦¸H)ë}ê”cdv¸ölÙí8 Húnl”ªßh$ı‰wÕÍ$ÌÛ·5b…Ó‚Æô‚ô©ñİÑb”,¸´{‡·—r†ñ“¹V)mCb³§éªÍZÓïı_3»mà_ÀDÎS#¶¢‚¢é€‚jºûİ—@4†¯zşÑ(G—ìó<{å©Ë®d¹qøX¾É#.ë¥½Â`Óƒ.îLîî¿¾ŞÆü„9ÒÆ9ØÏÎ' «\?n’"®1Çæ«¼+ÒPR­ÎuìØÕÇºxÇ«¡—‡s¢(¾=í¯–/ĞÂT-âĞéwŸË¢jÇŠû—ñ
ÔêÌğ¯J©zßÆ,öõ{âZ•7„Yú3©;ëÕÓ.Øˆ®cël|\1’Ëf^8#3­yÌ"t5RK´8Pô’\Ù†_V¦FœÛøkŒ¹é¢l‹#QZ#‚zJIœ„zmxÙE^ÈÈÀ:Ø‰òÓèêé}[­n@¤ïŠG¼Y¯$AWŞÆw¾¼FÏeÃJX:‡L„ˆ‹!º÷qp™mòe2H¯üˆß)ŸzíLİÓémš§ù]ú ìÊXòœ¥WZ’8İ7êu1×´zó¡6w~T3¤(lí½¤Û‘¬ÉÃ#9µÅéş_!«–6c"ĞİA€w‡FöÍeK†´¤MfÁÆdaÇ=Öó”­VÁ‘Mzûm€RØèzĞ‚Îíss,˜7‘"F¨ó¿_Õ"IÏ[äÀG±¾˜t¹)Ñl0œõ˜&<Á"a7ª‘úÍÌªıXÛE0{ÔÎùÌEŒ6bd$Z–˜.f¬¿×)Ód*¥âšÔ±)ÎßÁ€½QĞ˜üé¶ËØ—‹Uá[øl7±æ2¶*MÛq|}5ÁâşÆ®êÛékïCø›ñ'ŒœısHÀ²µñv "ë~^³Û¾MeÓÎaÜÏUÌ¡G}™²ú> z(5*‰[Õ>ôyñ­éÌE²/Í˜‡ô<!f}ø¾yX¬ı?>ÉÿòÔœğ©ÍnBa¯°î®ÁVsJõ§“êª°ğ¹mdMçm‰(âÖ¿VÆ£a‰µvàÑˆ26‘Ó‡<&‡^õº5@9Ì}k‘ô5bbĞÈıˆ	»˜—®(¶·’59x¦dVTÄ ¤–ˆaŸdèÃŒFq“ˆ)1®ªşÑEÖ¶jñètK‘
D´{M`—é»l]Œªõ¦ĞrTG¸¸ªW™†-Ö,Äø„M–‰——ÑÄÓğ?>Õ‰µŠ@ßßO¥•.YS5©YŠmvî\u;«Cuåå;j0Ä.ÑHª”¼?s]PTçÁùâºén†$mĞ$Ç{ÔÌQjŒ^ÄnCpCÀÓ–\Dñ	wciÏå	ßõùÓG¼¶…‚~¦èHín>—Ã9y9%fê1›WY)´ùåA\y[îÙD‹š­Ã#–aÇ¿‰’À¼!6wšoÕ¬®‰ÚÅ½ô·K|•ÜYoAÑNUg©çæÁ»|’èCBXØ°¾¢bîİHÖÁİ‰_”{,l‰¹¶õÕ†&qk`ójRÕ­—\‡Qì'¿h:ª]›è²>¿¾¿xÁİ0<Dİ'{§Â·±éõ5ét&?qåÖÇqû)R„ĞI#æÊ¡¢TŸ5VÃG×j”LY{ş\è@3æØßÃ(âGwÊÿC™'½Éï—Lç4j næÜd£ŸpI®*	?ŸÆF”u¦–‚/úcá<`Tw ı‡óa™1Hä#kæß«`ûÓƒÏg°‰@'x-]_€»ÙzZˆ‹}ÙFÃÇcVe…BğN A„VôÖ‰P4ˆfG,	×¨Ñª¥oa{/E°Hë»ô¹•ÛË€Ò8§ohí-Ur›ƒ­¸5œÈÔıÆ¼€AM”izÉœ8Oô#TXR˜Mô$Q©êE6C›¥¦æaÍàQ“·`D$Z‘\®¹÷ãHbÁ€xc
MkôG×G±wÌš®«ëÈNöRµıÎ¨ˆèlçÙ6ç8œ8‰|…NßÀ|V\U@òïiO?$Å»h-Çj^Æ”ĞÆï)>#˜³Zéc®yÂÀ{U’[—Ş%˜EæİO8¥Z:Òjöw[”)»£y‰?VZã˜ªœĞO_»¿÷T-Ÿ ûÁíåxšu»ÉYY7Ô„İK%‰•&ã]Æ”aœQ™5A7Ï‹d?¦­dBö?«u]ZûùÄxş|«ˆc¥U°, àÛç«ó0Õ³ËDĞ`t‡oêµ\w»VQŸg}ö—^mtÇ²Ò#AÔØ4=oœZCøCj\zí‹fBd˜§æEï®	óŠ2â(Ä}Á­÷ùä’(yK›^yd}ãœVnÍH!;Ù„âB3ú¬eé\ºkØòH®`=Ê68 D‡v/©D@¢´k-»V¼-ğ¸ö†àp×Òuü÷H¶Í¤e…İ­c| :µW.år‘J%J-5FØbÄÀ xJ×½–Š_V­€·üÁrAT°[Š®¶0+_=¶Ø-³~Æ„ÒU!¹:Ñ×ã£ÂÜIÏhkôŞy¤|ªÙOE$I>4AÒ[Áê£dg¤¾ºbnÔnéxVO‚¦©ÊÚŸáuŠ¶püÇ0PÚfM$sqëqœ¡Ê½ °Lâïaåø V?êè‰¶xÍh)øÁ¸ïí[<ÃeÕ…X„-ş‘$úâ_K¡¦ØÌ£nyÜş"í¢€ 1ºW*·Õ 5p-ò„Ômmÿ#]Õ§¬Oz•LÂËÛrÚŸhôb2i¬	äúÛøÏJBú ½,IIİ^‚	Y`Kš¥eyFBtU¨^Â:•déi0–ƒãñ1¨FcgzLôUÿ&±—Óå¹M'­¯Ë
ˆÆ\…!ÎBmÚ3pÒã]K´´VOıîP%KĞ@e¥üÑ a¹æ¶MÌ+ı7$M};óÓöÙ•<à‡$£Å«N¶6"6…jkğZ’ßª@×ğ".‚lÕüØß‘.‚“²u–æÕË õêlŒÂ»‚è*äÚ«ºZ>Á+²-(ää&Ùñ©3†0Lˆ/€ibªZIØº°UÃr‹iø²ñxş½'WÎ°pnlA6T°Ûº:§
 ¤{saêçWWç©¬¢¤bî“`]$LRTp»d8÷EÓ¨ÈÂL/DMksÕ©úe
bûlíß;élIY 5»¬Íw€<Ê*]œüvRŸèwĞM×¡-Ğı \qFÔç³´|Ù~6ÖsŠîk(f‡€C–<®ƒ•ÿ8bÊªı÷n[(­+¯ï|U¯¶Ö‚4‘n9lßB+~nrkã­Ğ>˜€\ƒ ²ò?›ğ.´³7vWhxÑ¿’¥Nñ´
ˆ\1aãg‰êÒİj KP¬}s@Ÿ@-Ôú"ÑÍt Ìä§ÙÏìº!]ğF)/Q&Æ°t^«İ‹l $¯ªÔRäŞ&ÀÆÕÄ§JİæÑiA,·Tºåü®ùEşˆÂ£a8®jhÆ~wÇ[¿gá™2™àİòÔ¶ „ŒÀx²äÄæöôí;w"~ÙTA;n¥øÜŞbútt_úÊ °Ûo[Üì¶ÿxbßW°?‰cÍ8ùËNz29<³Ä`C'sPv¸`)­$|ï.R"¦W¯‹}