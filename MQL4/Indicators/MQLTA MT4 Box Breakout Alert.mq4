#property link          "https://www.earnforex.com/metatrader-indicators/box-breakout-alert/"
#property version       "1.01"
#property strict
#property copyright     "EarnForex.com - 2019-2025"
#property description   "This indicator can alert you when there is a Box Breakout:"
#property description   "The price breaks above or below a previous high or low."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find More on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 4

// Signal buffer is not displayed. Only used by external EAs/indicators via iCustom().
#property indicator_type1 DRAW_NONE

// Buy arrows:
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrGreen
#property indicator_width2 3
#property indicator_label2 "Buy Signal"

// Sell arrows":
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrRed
#property indicator_width3 3
#property indicator_label3 "Buy Signal"

// If enabled, neutral arrows:
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrGray
#property indicator_width4 3
#property indicator_label4 "Stop Signal"


enum ENUM_TRADE_SIGNAL
{
    SIGNAL_BUY = 1,   // BUY
    SIGNAL_SELL = -1, // SELL
    SIGNAL_NEUTRAL = 0 // NEUTRAL
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE = 0,  // CURRENT CANDLE
    CLOSED_CANDLE = 1    // PREVIOUS CANDLE
};

enum ENUM_CHECK_VALUE
{
    CHECK_VALUE_CLOSE = 0, // CLOSE
    CHECK_VALUE_HIGHLOW = 1 // HIGH/LOW
};

input string Comment1 = "========================";  // Box Breakout Alert Indicator
input string IndicatorName = "MQLTA-BBAI";           // Indicator Short Name

input string Comment2 = "========================";  // Indicator Parameters
input int BoxBars = 10;                              // Number Of Bars In The Box
input ENUM_CHECK_VALUE CheckValue = CHECK_VALUE_CLOSE; // Candle Value to Check for Breakout
input ENUM_CANDLE_TO_CHECK CandleToCheck = CLOSED_CANDLE; // Candle To Use For Analysis
input int BarsToScan = 500;                          // Number Of Candles To Analyse

input string Comment_3 = "====================";   // Notification Options
input bool EnableNotify = false;                   // Enable Notifications Feature
input bool SendAlert = true;                       // Send Alert Notification
input bool SendApp = false;                        // Send Notification to Mobile
input bool SendEmail = false;                      // Send Notification via Email

input string Comment_4 = "====================";   // Buffers Options
input int ArrowTypeBuy = 241;                      // Code For Buy Arrow
input int ArrowTypeSell = 242;                     // Code For Sell Arrow
input bool ArrowShowNeutral = false;               // Show Stop Arrow
input int ArrowTypeStop = 251;                     // Code For Stop Arrow

//Here we define the 4 arrays that will be set as buffers
double BufferBuy[], BufferSell[], BufferStop[], BufferSignal[];

datetime LastNotificationTime;
ENUM_TRADE_SIGNAL LastNotificationDirection;
int Shift = 0;                      // Shift is used to set if the analysis will be on the current or previous candle
double BoxHighValue = 0; // Box highest value for alert text.
double BoxLowValue = 0; // Box lowest value for alert text.

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName); // Set the indicator name.
    OnInitInitialization(); // Internal function to initialize other variables.
    if (!OnInitPreChecksPass())// Check to see there are requirements that need to be met in order to run.
    {
        return INIT_FAILED;
    }
    InitialiseBuffers(); // Initialize the buffers.
    return INIT_SUCCEEDED; // Return successful initialization if all the above are completed.
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
    if (rates_total < BoxBars)
    {
        Print("Not enough candles in chart history.");
        return 0;
    }

    bool IsNewCandle = CheckIfNewCandle();
    
    int counted_bars = 0;
    if (prev_calculated > 0) counted_bars = prev_calculated - 1;

    if (counted_bars < 0) return -1;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;

    if ((limit > BarsToScan) && (BarsToScan > 0))
    {
        limit = BarsToScan;
        if (rates_total < BarsToScan + BoxBars) limit = BarsToScan - 2 - BoxBars;
        if (limit <= 0)
        {
            Print("Not enough candles in chart history.");
            return 0;
        }
    }
    if (limit > rates_total - 2 - BoxBars) limit = rates_total - 2 - BoxBars;

    if ((IsNewCandle) || (prev_calculated == 0))
    {
        DrawArrows(limit);
    }

    DrawArrow(0);

    if (EnableNotify) NotifyHit();

    return rates_total;
}

void OnInitInitialization()
{
    LastNotificationTime = TimeCurrent();
    Shift = CandleToCheck;
}

// Function for run checks of requirements for the indicator to run.
bool OnInitPreChecksPass()
{
    //Check some of the parameters to see if they are valid:
    if (BoxBars < 1) return false; // BoxBars cannot be less than 1.

    return true;
}

void InitialiseBuffers()
{
    SetIndexStyle(0, DRAW_NONE);     // No drawing - only used by external EAs/indicators via iCustom().
    SetIndexBuffer(0, BufferSignal); // Associate the buffer of index zero to the array BufferSignal
    
    SetIndexBuffer(1, BufferBuy);    // Associate the buffer of index one to the array BufferBuy.
    SetIndexArrow(1, ArrowTypeBuy);  // Defining the type of arrow to draw.
    
    SetIndexBuffer(2, BufferSell);   // Associate the buffer of index two to the array BufferSell.
    SetIndexArrow(2, ArrowTypeSell); // Defining the type of arrow to draw.

    SetIndexBuffer(3, BufferStop);   // Associate the buffer of index three to the array BufferStop.
    SetIndexArrow(3, ArrowTypeStop); // Defining the type of arrow to draw.

    // Turn off if neutral arrows are disabled.
    if (!ArrowShowNeutral) SetIndexStyle(3, DRAW_NONE);
}

datetime NewCandleTime = TimeCurrent();
bool CheckIfNewCandle()
{
    if (NewCandleTime == iTime(Symbol(), 0, 0)) return false;
    else
    {
        NewCandleTime = iTime(Symbol(), 0, 0);
        return true;
    }
}

void NotifyHit()
{
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if ((CandleToCheck == CLOSED_CANDLE) && (iTime(Symbol(), PERIOD_CURRENT, 0) <= LastNotificationTime)) return;
    ENUM_TRADE_SIGNAL Signal = IsSignal(0);
    if (Signal == SIGNAL_NEUTRAL)
    {
        LastNotificationDirection = Signal;
        return;
    }
    if (Signal == LastNotificationDirection) return;
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    string AlertText = IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " ";
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " - ";
    string Text = "";

    if (CheckValue == CHECK_VALUE_HIGHLOW)
    {
        if (Signal == SIGNAL_BUY) Text += "High Price (" + DoubleToString(iHigh(Symbol(), PERIOD_CURRENT, Shift), _Digits) + ") > Box High (" + DoubleToString(BoxHighValue, _Digits) + ")";
        else if (Signal == SIGNAL_SELL) Text += "Low Price (" + DoubleToString(iLow(Symbol(), PERIOD_CURRENT, Shift), _Digits) + ") < Box Low (" + DoubleToString(BoxLowValue, _Digits) + ")";
    }
    else if (CheckValue == CHECK_VALUE_CLOSE)
    {
        if (Signal == SIGNAL_BUY) Text += "Close Price (" + DoubleToString(iClose(Symbol(), PERIOD_CURRENT, Shift), _Digits) + ") > Box High (" + DoubleToString(BoxHighValue, _Digits) + ")";
        else if (Signal == SIGNAL_SELL) Text += "Close Price (" + DoubleToString(iClose(Symbol(), PERIOD_CURRENT, Shift), _Digits) + ") < Box Low (" + DoubleToString(BoxLowValue, _Digits) + ")";
    }

    EmailBody += Text;
    AlertText += Text;
    AppText += Text;
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    LastNotificationTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    LastNotificationDirection = Signal;
}

void DrawArrows(int limit)
{
    for (int i = limit - 1; i >= 1; i--)
    {
        DrawArrow(i);
    }
}

// Function to assign the signal for candle of index i to the respective buffer.
void DrawArrow(int i)
{
    // Assign the signal value for candle i to the variable Signal.
    ENUM_TRADE_SIGNAL Signal = IsSignal(i);
    // If the signal is neutral or stop at candle of index i then the BuffeSignal array at that index is set to SIGNAL_NEUTRAL, which is normally 0.
    if (Signal == SIGNAL_NEUTRAL)
    {
        BufferSignal[i + Shift] = SIGNAL_NEUTRAL;
        BufferStop[i + Shift] = iLow(Symbol(), PERIOD_CURRENT, i + Shift); // Set the BufferStop at the index to value Low of the candle so the arrow is drawn below the low.
    }
    // If the signal is buy at candle of index i then the BuffeSignal array at that index is set to SIGNAL_BUY, which is normally 1.
    else if (Signal == SIGNAL_BUY)
    {
        BufferSignal[i + Shift] = SIGNAL_BUY;
        BufferBuy[i + Shift] = iLow(Symbol(), PERIOD_CURRENT, i + Shift); // Set the BufferBuy at the index to value Low of the candle so the arrow is drawn below the low.
        BufferStop[i + Shift] = EMPTY_VALUE;
    }
    // If the signal is sell at candle of index i then the BuffeSignal array at that index is set to SIGNAL_SELL, which is normally -1.
    else if (Signal == SIGNAL_SELL)
    {
        BufferSignal[i + Shift] = SIGNAL_SELL;
        BufferSell[i + Shift] = iHigh(Symbol(), PERIOD_CURRENT, i + Shift); // Set the BufferSell at the index to value High of the candle so the arrow is drawn above the high.
        BufferStop[i + Shift] = EMPTY_VALUE;
    }
}

// The IsSignal function is where you check if the candle of index i has a signal.
// It can return SIGNAL_BUY = 1, SIGNAL_SELL = -1, SIGNAL_NEUTRAL = 0.
ENUM_TRADE_SIGNAL IsSignal(int i)
{
    // Define a variable j which is the index of the candle to check, this is to consider if you are checking the current candle or the closed one.
    int j = i + Shift;
    // Initialize the Signal to a neutral/stop one.
    ENUM_TRADE_SIGNAL Signal = SIGNAL_NEUTRAL;

    // Define the condition for your buy signal and assign SIGNAL_BUY value to the Signal variable if the condition is true:
    // A BUY signal is triggered when the close price of the current candle (or closed if CandleToCheck is closed one) is above the highest high in the previous BoxBars candles.
    BoxHighValue = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BoxBars, j + 1));
    if (CheckValue == CHECK_VALUE_CLOSE)
    {
        if (iClose(Symbol(), PERIOD_CURRENT, j) > BoxHighValue) Signal = SIGNAL_BUY;
    }
    else if (CheckValue == CHECK_VALUE_HIGHLOW)
    {
        if (iHigh(Symbol(), PERIOD_CURRENT, j) > BoxHighValue) Signal = SIGNAL_BUY;
    }
    
    // Define the condition for your sell signal and assign SIGNAL_SELL value to the Signal variable if the condition is true:
    // A SELL signal is triggered when the close price of the current candle (or closed if CandleToCheck is closed one) is below the lowest low in the previous BoxBars candles.
    BoxLowValue = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BoxBars, j + 1));
    if (CheckValue == CHECK_VALUE_CLOSE)
    {
        if (iClose(Symbol(), PERIOD_CURRENT, j) < BoxLowValue) Signal = SIGNAL_SELL;
    }
    else if (CheckValue == CHECK_VALUE_HIGHLOW)
    {
        if (iLow(Symbol(), PERIOD_CURRENT, j) < BoxLowValue) Signal = SIGNAL_SELL;
    }
    
    return Signal;
}
//+------------------------------------------------------------------+