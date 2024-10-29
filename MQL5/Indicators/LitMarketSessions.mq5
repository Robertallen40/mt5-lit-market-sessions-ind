//+------------------------------------------------------------------+
//|                                              market sessions.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.02"
#property description "Indicator shows market sessions with automatic summer/winter time adjustments"


#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 1

// includes
#include <Object.mqh>
#include <arrays/arrayobj.mqh>

enum ENUM_TIME_ZONE
  {
   TZauto = 99, // auto
   TZp6 = 6, // +6
   TZp5 = 5, // +5
   TZp4 = 4, // +4
   TZp3 = 3, // +3
   TZp2 = 2, // +2
   TZp1 = 1, // +1
   TZp0 = 0, // 0
   TZm1 = -1, // -1
   TZm2 = -2, // -2
   TZm3 = -3, // -3
   TZm4 = -4, // -4
   TZm5 = -5, // -5
   TZm6 = -6 // -6
  };

enum ENUM_BORDER_STYLE
  {
   BORDER_STYLE_SOLID = STYLE_SOLID, // Solid
   BORDER_STYLE_DASH = STYLE_DASH // Dash
  };

enum ENUM_LIT_SESSION_TYPE
  {
   LIT_SESSION_LONDON,  // 08 AM to 09 AM [UTC] - Open Inducement Window (1 hour)
   LIT_SESSION_NEWYORK, // 01 PM to 02 PM [UTC] - Open Inducement Window (1 hour)
   LIT_SESSION_TOKYO,   // 23 PM to 06 AM [UTC]
   LIT_SESSION_FRANKFURT, // 07 AM to 08 AM [UTC] - Open Inducement Window (1 hour)
   LIT_SESSION_SYDNEY   // 10 PM to 07 AM [UTC]
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Box : public CObject
  {
public:
                     Box(ENUM_LIT_SESSION_TYPE inType, datetime inStart, datetime inEnd, double inLow, double inHigh)
     {
      this.type = inType;
      this.start = inStart;
      this.end = inEnd;
      this.low = inLow;
      this.high = inHigh;
     }

   void              draw()
     {
      string objName = "sbox " + TimeToString(start);
      if(ObjectFind(0, objName) < 0)
        {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, start, low, end, high);

         ObjectSetInteger(0, objName, OBJPROP_COLOR, getTypeAsColor());
         ObjectSetInteger(0, objName, OBJPROP_FILL, InpFill);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, InpBoderStyle);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
        }
     }

   long              getTypeAsColor()
     {
      switch(type)
        {
         case  LIT_SESSION_LONDON:
            return InpLondonColor;
         case  LIT_SESSION_NEWYORK:
            return InpNewyorkColor;
         case  LIT_SESSION_TOKYO:
            return InpTokyoColor;
         case  LIT_SESSION_FRANKFURT:
            return InpFrankfurtColor;
         case  LIT_SESSION_SYDNEY:
            return InpSydneyColor;
         default:
            Print("Unknown type");
            return -1;
        }
     }

   int               getTypeAsNumber()
     {
      switch(type)
        {
         case  LIT_SESSION_LONDON:
            return 1;
         case  LIT_SESSION_NEWYORK:
            return 2;
         case  LIT_SESSION_TOKYO:
            return 3;
         case  LIT_SESSION_FRANKFURT:
            return 4;
         case  LIT_SESSION_SYDNEY:
            return 5;
         default:
            Print("Unknown type");
            return -1;
        }
     }

   ENUM_LIT_SESSION_TYPE type;
   datetime          start;
   datetime          end;
   double            low;
   double            high;
  };

// buffers
double TypeBuffer[];
double LowBuffer[];
double HighBuffer[];

// config
input group "Section :: Main";
input ENUM_TIME_ZONE InpTimeZoneOffsetHours = TZauto; // Time zone (offset in hours)
input bool InpLondonShow = true; // Show London
input bool InpNewyorkShow = true; // Show NewYork
input bool InpTokyoShow = true; // Show Tokyo
input bool InpFrankfurtShow = true; // Show Frankfurt
input bool InpSydneyShow = true; // Show Sydney
input group "Section :: Style";
input color InpLondonColor = clrLightGreen; // London color
input color InpNewyorkColor = clrYellow; // NewYork color
input color InpTokyoColor = clrLightGray; // Tokyo color
input color InpFrankfurtColor = clrBlue; // Frankfurt color
input color InpSydneyColor = clrRed; // Sydney color
input bool InpFill = true; // Fill solid (true) or transparent (false)
input ENUM_BORDER_STYLE InpBoderStyle = BORDER_STYLE_SOLID; // Border line style
input int InpBorderWidth = 2; // Border line width

// runtime
CArrayObj boxes;
int timeShiftSec;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Initialization started");

   ArrayInitialize(TypeBuffer, 0);
   ArrayInitialize(LowBuffer, 0);
   ArrayInitialize(HighBuffer, 0);

   ArraySetAsSeries(TypeBuffer, true);
   ArraySetAsSeries(LowBuffer, true);
   ArraySetAsSeries(HighBuffer, true);

   SetIndexBuffer(0, TypeBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, LowBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, HighBuffer, INDICATOR_CALCULATIONS);

   timeShiftSec = getAutomaticTimeShift();

   Print("Initialization finished");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Deinitialization started");

   ObjectsDeleteAll(0, "sbox");

   Print("Deinitialization finished");
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total == prev_calculated)
     {
      return rates_total;
     }

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   int limit = (int) MathMin(rates_total, rates_total - prev_calculated + 1);

   MqlDateTime currMdt;
   MqlDateTime startMdt;
   MqlDateTime endMdt;

   datetime currDt;
   datetime startDt;
   datetime endDt;

   for(int i = limit - 1; i > 0; i--)
     {
      datetime dt = time[i];

      TimeToStruct(dt, currMdt);
      currDt = StructToTime(currMdt);

      TimeToStruct(dt, startMdt);
      startMdt.min = 0;
      startMdt.sec = 0;

      TimeToStruct(dt, endMdt);
      endMdt.min = 0;
      endMdt.sec = 0;

      // London
      if(InpLondonShow)
        {
         startMdt.hour = 8;
         endMdt.hour = 9;
         startDt = StructToTime(startMdt) + timeShiftSec;
         endDt = StructToTime(endMdt) + timeShiftSec;

         if(currDt >= startDt && currDt < endDt)
           {
            addBox(&boxes, LIT_SESSION_LONDON, startDt, endDt, low[i], high[i], i);
           }
        }

      // NewYork
      if(InpNewyorkShow)
        {
         startMdt.hour = 13;
         endMdt.hour = 14;
         startDt = StructToTime(startMdt) + timeShiftSec;
         endDt = StructToTime(endMdt) + timeShiftSec;

         if(currDt >= startDt && currDt < endDt)
           {
            addBox(&boxes, LIT_SESSION_NEWYORK, startDt, endDt, low[i], high[i], i);
           }
        }

      // Tokyo
      if(InpTokyoShow)
        {
         startMdt.hour = 23;
         endMdt.hour = 6;
         startDt = StructToTime(startMdt) - 86400 + timeShiftSec; // prev day
         endDt = StructToTime(endMdt) + timeShiftSec;

         if(currDt >= startDt && currDt < endDt)
           {
            addBox(&boxes, LIT_SESSION_TOKYO, startDt, endDt, low[i], high[i], i);
           }
        }
      
      // Frankfurt
      if(InpFrankfurtShow)
        {
         startMdt.hour = 7;
         endMdt.hour = 8;
         startDt = StructToTime(startMdt) + timeShiftSec;
         endDt = StructToTime(endMdt) + timeShiftSec;

         if(currDt >= startDt && currDt < endDt)
           {
            addBox(&boxes, LIT_SESSION_FRANKFURT, startDt, endDt, low[i], high[i], i);
           }
        }

      // Sydney
      if(InpSydneyShow)
        {
         startMdt.hour = 22;
         endMdt.hour = 7;
         startDt = StructToTime(startMdt) - 86400 + timeShiftSec; // prev day
         endDt = StructToTime(endMdt) + timeShiftSec;

         if(currDt >= startDt && currDt < endDt)
           {
            addBox(&boxes, LIT_SESSION_SYDNEY, startDt, endDt, low[i], high[i], i);
           }
        }
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Get time zone offset in hours                                    |
//+------------------------------------------------------------------+
int getTimeZoneOffsetHours()
  {
   datetime serverTime = TimeTradeServer();
   datetime gmtTime = TimeGMT();

   int offsetSeconds = ((int)serverTime) - ((int)gmtTime);
   int offsetHours = offsetSeconds / 3600;

   Print("Detected server offset: ", IntegerToString(offsetHours), " hrs");
   return offsetHours;
  }

//+------------------------------------------------------------------+
//| Get automatic time shift in seconds                              |
//+------------------------------------------------------------------+
int getAutomaticTimeShift()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int month = dt.mon;
   int day = dt.day;
   int wday = dt.day_of_week;

   // London DST: Last Sunday of March to Last Sunday of October
   if(InpLondonShow)
     {
      if((month > 3 && month < 10) || (month == 3 && (day - wday) >= 25) || (month == 10 && (day - wday) < 25))
        return 1 * 3600; // Summer time +1 hour
     }

   // New York DST: Second Sunday of March to First Sunday of November
   if(InpNewyorkShow)
     {
      if((month > 3 && month < 11) || (month == 3 && day >= (8 - wday)) || (month == 11 && day < (8 - wday)))
        return 1 * 3600; // Summer time +1 hour
     }

   // Frankfurt DST: Last Sunday of March to Last Sunday of October
   if(InpFrankfurtShow)
     {
      if((month > 3 && month < 10) || (month == 3 && (day - wday) >= 25) || (month == 10 && (day - wday) < 25))
        return 1 * 3600; // Summer time +1 hour
     }

   // Sydney DST: First Sunday of October to First Sunday of April
   if(InpSydneyShow)
     {
      if((month < 4 || month > 10) || (month == 4 && day <= (8 - wday)) || (month == 10 && day >= (8 - wday)))
        return 1 * 3600; // Summer time +1 hour
     }

   // Tokyo does not observe DST
   return 0;
  }

//+------------------------------------------------------------------+
//| Add or update existing box and draw it                           |
//+------------------------------------------------------------------+
void addBox(CArrayObj *allBoxes, ENUM_LIT_SESSION_TYPE type, datetime start, datetime end, double low, double high, int i)
  {
   Box *box = allBoxes.Total() > 0
              ? allBoxes.At(allBoxes.Total() - 1)
              : NULL;

   double lowNormalized = NormalizeDouble(low, _Digits);
   double highNormalized = NormalizeDouble(high, _Digits);

   if(box != NULL && box.start == start)
     {
      if(box.low > lowNormalized || box.high < highNormalized)
        {
         box.end = end;
         box.low = MathMin(box.low, lowNormalized);
         box.high = MathMax(box.high, highNormalized);

         ObjectsDeleteAll(0, "sbox " + TimeToString(start));

         box.draw();
         Print("box redrawn");
        }
     }
   else
     {
      box = new Box(type, start, end, lowNormalized, highNormalized);
      boxes.Add(box);

      box.draw();
      Print("new box drawn");
     }

   setBuffers(box, i);
  }

//+------------------------------------------------------------------+
//| Fill indicator buffers                                           |
//+------------------------------------------------------------------+
void setBuffers(Box *box, int i)
  {
   TypeBuffer[i] = box.getTypeAsNumber();
   LowBuffer[i] = box.low;
   HighBuffer[i] = box.high;
  }
//+------------------------------------------------------------------+
