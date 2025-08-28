//+------------------------------------------------------------------+
//|                                                 LineMidText.mq4  |
//|                         MT4 Custom Indicator: Line with Mid Text |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

//------------------------------- Inputs ------------------------------
input string   InpTag              = "1";            // Unique tag to allow multiple instances
input string   InpText             = "Segment";      // Text to display at midpoint
input color    InpTextColor        = clrWhite;       // Text color
input string   InpTextFont         = "Arial";       // Text font
input int      InpTextSize         = 10;             // Text size

input color    InpLineColor        = clrDeepSkyBlue; // Line color
input int      InpLineWidth        = 2;              // Line width
input ENUM_LINE_STYLE InpLineStyle = STYLE_SOLID;    // Line style

input datetime InpStartTime        = 0;              // Start time (0 = last bar)
input double   InpStartPrice       = 0.0;            // Start price (0 = current price)
input datetime InpEndTime          = 0;              // End time (0 = previous bar)
input double   InpEndPrice         = 0.0;            // End price (0 = current price)

//---------------------------- Constants ------------------------------
string Prefix = "LS_"; // Object name prefix

//---------------------------- Utilities ------------------------------
string BuildLineName()
{
   return(Prefix + "Line_" + InpTag);
}

string BuildLabelName()
{
   return(Prefix + "Label_" + InpTag);
}

bool EnsureTrendline(datetime startTime,
                     double startPrice,
                     datetime endTime,
                     double endPrice)
{
   string lineName = BuildLineName();

   if(ObjectFind(0, lineName) < 0)
   {
      if(!ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, startPrice, endTime, endPrice))
         return(false);

      ObjectSetInteger(0, lineName, OBJPROP_RAY, false);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpLineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, InpLineStyle);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
   }
   else
   {
      // Update coordinates and style
      ObjectSetInteger(0, lineName, OBJPROP_RAY, false);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpLineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, InpLineStyle);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpLineColor);

      // Move points if inputs provided (non-zero). If user dragged, we leave as-is.
      if(startTime != 0 && endTime != 0)
      {
         ObjectMove(0, lineName, 0, startTime, startPrice);
         ObjectMove(0, lineName, 1, endTime, endPrice);
      }
   }
   return(true);
}

bool EnsureLabel()
{
   string labelName = BuildLabelName();
   if(ObjectFind(0, labelName) < 0)
   {
      if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
         return(false);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, 0);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTED, false);
   }

   ObjectSetString(0, labelName, OBJPROP_TEXT, InpText);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, InpTextSize);
   ObjectSetString(0, labelName, OBJPROP_FONT, InpTextFont);
   return(true);
}

bool GetLineEndpoints(datetime &t1, double &p1, datetime &t2, double &p2)
{
   string lineName = BuildLineName();
   if(ObjectFind(0, lineName) < 0)
      return(false);

   t1 = (datetime)ObjectGetInteger(0, lineName, OBJPROP_TIME1);
   p1 = ObjectGetDouble(0, lineName, OBJPROP_PRICE1);
   t2 = (datetime)ObjectGetInteger(0, lineName, OBJPROP_TIME2);
   p2 = ObjectGetDouble(0, lineName, OBJPROP_PRICE2);
   return(true);
}

bool UpdateLabelPositionFromLine()
{
   string labelName = BuildLabelName();
   if(!EnsureLabel())
      return(false);

   datetime t1, t2;
   double p1, p2;
   if(!GetLineEndpoints(t1, p1, t2, p2))
      return(false);

   int x1, y1, x2, y2;
   if(!ChartTimePriceToXY(0, 0, t1, p1, x1, y1))
      return(false);
   if(!ChartTimePriceToXY(0, 0, t2, p2, x2, y2))
      return(false);

   int midX = (x1 + x2) / 2;
   int midY = (y1 + y2) / 2;

   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, midX);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, midY);
   return(true);
}

void CreateOrUpdateAll()
{
   // Determine default coordinates if inputs are zero
   datetime st = InpStartTime;
   datetime et = InpEndTime;
   double   sp = InpStartPrice;
   double   ep = InpEndPrice;

   if(st == 0 || et == 0)
   {
      // Use last two bars
      int lastIndex = 0;
      int prevIndex = 1;
      st = Time[lastIndex];
      et = Time[prevIndex];
      if(st < et)
      {
         datetime tmp = st; st = et; et = tmp; // ensure st is the most recent time to the right
      }
   }

   if(sp == 0.0) sp = (Bid > 0.0 ? Bid : Close[0]);
   if(ep == 0.0) ep = sp;

   EnsureTrendline(st, sp, et, ep);
   EnsureLabel();
   UpdateLabelPositionFromLine();
}

//-------------------------- Indicator Events -------------------------
int OnInit()
{
   IndicatorShortName("LineMidText(" + InpTag + ")");
   CreateOrUpdateAll();
   return(INIT_SUCCEEDED);
}

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
   // Keep label centered; cheap to update on each tick
   UpdateLabelPositionFromLine();
   return(rates_total);
}

void OnDeinit(const int reason)
{
   string lineName = BuildLineName();
   string labelName = BuildLabelName();
   if(ObjectFind(0, labelName) >= 0) ObjectDelete(0, labelName);
   if(ObjectFind(0, lineName) >= 0) ObjectDelete(0, lineName);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   string lineName = BuildLineName();
   string labelName = BuildLabelName();

   if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE)
   {
      if(sparam == lineName)
      {
         UpdateLabelPositionFromLine();
      }
   }
   else if(id == CHARTEVENT_CHART_CHANGE)
   {
      // Reposition on zoom/scroll/resize
      UpdateLabelPositionFromLine();
   }
   else if(id == CHARTEVENT_OBJECT_DELETE)
   {
      if(sparam == lineName)
      {
         if(ObjectFind(0, labelName) >= 0)
            ObjectDelete(0, labelName);
      }
   }
}

//+------------------------------------------------------------------+
