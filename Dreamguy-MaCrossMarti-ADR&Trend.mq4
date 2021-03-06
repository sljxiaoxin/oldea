//+------------------------------------------------------------------+
//|                                           Dreamguy-MaCrossMarti.mq4 |
//|                                  Copyright ?2016-2020, Dreamguy | 
//+------------------------------------------------------------------+

#property copyright "Copyright ?2016-2020, Dreamguy"
#property link      "http://www.forexfactory.com"


//----------------------- INCLUDES
#include <stdlib.mqh>
enum ENUM_OPERATATIONMODE 
  {
   OP_OpenPrice = 0,     // Open Prices
   OP_EveryTick = 1,     // Every Tick
  };

enum ENUM_TPMODE
  {
   TP_OpenPrice = 0,     // Open Prices
   TP_EveryTick = 1,     // Every Tick
  };

//----------------------- EA PARAMETER
extern string           Expert_Name          = "---------- Dreamguy-MaCrossMarti-ADR&Trend v1.0";
extern int              MagicNumber          = 5678;
extern int              isUseADR             = 1;    //是否采用adr计算gridsize
extern double           Lots                 = 0.06;
extern double           TPinMoney            = 9.0;          //Net TP (money)
extern double           SLinMoney            = 0.0;          //Net SL (money)
extern double           Mutilplier           = 1.2;   //Martingale Mutiplier
extern int              GridSize             = 50;      //GridSize (In Pip)
extern int              MaxMarti             = 5;           // Max Marti (0-Unlimited)
extern string           Trend_Setting        = "---------- 启用趋势，则顺势单止盈加倍，并且保护性开单策略";    
extern bool             isUseTrend            = true;    //顺势加倍
extern int              intTrendMulti         = 7;       //止盈倍数
extern string           Indicator_Setting    = "---------- Indicator Setting";
extern int              FastMAPeriod         = 10,
                        FastMAType           = 1,    //0:SMA 1:EMA 2:SMMA 3:LWMA
                        FastMAPrice          = 0,    //0:Close 1:Open 2:High 3:Low 4:Median 5:Typical 6:Weighted
                        FastMAshift          = 0,
                        
                        SlowMAPeriod         = 20,
                        SlowMAType           = 1,    //0:SMA 1:EMA 2:SMMA 3:LWMA
                        SlowMAPrice          = 0,    //0:Close 1:Open 2:High 3:Low 4:Median 5:Typical 6:Weighted
                        SlowMAshift          = 0;
                        
extern string           Trend_Setting1        = "---------- Trend MA Setting";              
extern int              TrendMAPeriod         = 300,
                        TrendMAType           = 1,    //0:SMA 1:EMA 2:SMMA 3:LWMA
                        TrendMAPrice          = 0,    //0:Close 1:Open 2:High 3:Low 4:Median 5:Typical 6:Weighted
                        TrendMAshift          = 0;
                        
extern string           Order_Setting        = "---------- Order Setting";
extern int              NumberOfTries        = 10,
                        Slippage             = 5;
extern string           Testing_Parameters= "---------- Back Test Parameter";
extern bool             PrintControl         = true,
                        Show_Settings        = true;
extern string           Separator_2          = "==== Martingale Settings ===="; //Section

input                ENUM_OPERATATIONMODE OperatationMode=0;  // Operatation Mode


//----------------------- GLOBAL VARIABLE
static int              TimeFrame            = 0;
string                  TicketComment        = "Dreamguy-MaCrossMarti-ADR v1.0",
                        LastTrade,
                        LastAlert,
                        TradeDirection       = "NONE",
                        PreviousDirection    = "NONE",
                        CurrentDirection     = "NONE";
datetime                CheckTime,
                        CrossTime;
int                     MaxOpenTrade         = 1,
                        MinPriceDistance     = 5;
             
double                  StopLoss             = 0,
                        TakeProfit           = 0;
string                  trendType            = "none";      //buy sell none
double Pip;
double netProfit;
string strAdr = "";
double multi = 1;   //首单目标是TPMoney的5倍
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   if(Digits==2 || Digits==4) Pip = Point;
   else if(Digits==3 || Digits==5) Pip = 10*Point;
   else if(Digits==6) Pip = 100*Point;
//----------------------- GENERATE MAGIC NUMBER AND TICKET COMMENT
//----------------------- SOURCE : PENGIE
   MagicNumber    = subGenerateMagicNumber(MagicNumber, Symbol(), Period());
	TicketComment  = StringConcatenate(TicketComment, "-", Symbol(), "-", Period());


//----------------------- SHOW EA SETTING ON THE CHART
//----------------------- SOURCE : CODERSGURU
   if(Show_Settings==true) subPrintDetails();
   else Comment("");

//----------------------- MaxTrade ALWAYS >= 1
   if(MaxOpenTrade<=0) MaxOpenTrade = 1;
   
//+------------------------------------------------------------------+
//| CHECK LAST OPEN TRADE                                            |
//+------------------------------------------------------------------+
   LastTrade = subCheckOpenTrade();
   Print("Last Trade : ",LastTrade);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
 
//----------------------- PREVENT RE-COUNTING WHILE USER CHANGING TIME FRAME
//----------------------- SOURCE : CODERSGURU
   TimeFrame=Period(); 
   return(0);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
{
   double FastMACurrent;
   double SlowMACurrent;
   double TrendMACurrent;
                   
   int ticket;
   int total;
         
   bool BuyCondition = false;
   bool SellCondition = false;
   string CrossDirection;         
   netProfit = 0;

//----------------------- CHECK CHART NEED MORE THAN 100 BARS
   if(Bars<100)
   {
      Print("bars less than 100");
      return(0);  
   }         
   CheckMartingale();
   ProfitProtector();
   subPrintDetails();
//----------------------- SET VALUE FOR VARIABLE
   if(CheckTime==iTime(NULL,TimeFrame,0)){
      return(0);
   }else{
      CheckTime = iTime(NULL,TimeFrame,0);
      if(isUseADR >0){
         GridSize = setGridsizeByADR();
         /*
         if(GridSize < 20){
            GridSize = 20;
         }
         */
      }
      if(isUseTrend){
         //判断趋势
         if(trend_buy_check()){
            trendType = "buy";
         }
         if(trend_sell_check()){
            trendType = "sell";
         }
      }
   }
   
      FastMACurrent    = iMA(NULL,TimeFrame,FastMAPeriod,FastMAshift,FastMAType,FastMAPrice,1);
      SlowMACurrent    = iMA(NULL,TimeFrame,SlowMAPeriod,SlowMAshift,SlowMAType,SlowMAPrice,1);
      TrendMACurrent   = iMA(NULL,TimeFrame,TrendMAPeriod,TrendMAshift,TrendMAType,TrendMAPrice,1);
   
   CrossDirection = subCrossDirection(FastMACurrent,SlowMACurrent);

//----------------------- CONDITION CHECK
   //----------------------- BUY CONDITION   
      if(CrossDirection=="UP")
      {
         BuyCondition   = true;
         TradeDirection = "UP";
         CrossTime      = iTime(NULL,TimeFrame,0);
         multi = 1;
      }                       

//----------------------- SELL CONDITION   
      if(CrossDirection=="DOWN")
      {
         SellCondition  = true;
         TradeDirection = "DOWN";
         CrossTime      = iTime(NULL,TimeFrame,0);
         multi = 1;
      }

   if(PrintControl==true)
   {
      //if(BuyCondition==true)  Print("MA Cross BUY");
      //if(SellCondition==true) Print("MA Cross SELL");
   }                            

//----------------------- ENTRY
//----------------------- TOTAL ORDER BASE ON MAGICNUMBER AND SYMBOL
   total = subTotalTrade();

//----------------------- IF NUMBER TRADE LESS THAN MaxTrade
   if(total<MaxOpenTrade && (BuyCondition==true || SellCondition==true)) 
   {     

//----------------------- BUY CONDITION   
      if(BuyCondition==true)
      {
         //if(isUseTrend && trendType != "buy")return(0);   //趋势交易，非马丁单只有向上趋势才能买
         if(MaxOpenTrade>1 && subHighestLowest("BUY")==false) return(0);
         //如果启用趋势交易，则买单判断和趋势线的距离
         if(isUseTrend && trendType == "sell"){
            if(TrendMACurrent > Ask && TrendMACurrent-Ask<18*Pip){
               Print("trend protect not open buy order!");
               return (0);
            }
         }
         ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         subCheckError(ticket,"BUY");
         LastTrade = "BUY";
         if(isUseTrend && trendType == "buy"){
            multi = intTrendMulti;
         }
         return(0);
      }

//----------------------- SELL CONDITION   
      if(SellCondition==true)
      {
         //if(isUseTrend && trendType != "sell")return(0);   //趋势交易，非马丁单只有向下趋势才能卖
         if(MaxOpenTrade>1 && subHighestLowest("SELL")==false) return(0);
         //如果启用趋势交易，则卖单判断和趋势线的距离
         if(isUseTrend && trendType == "buy"){
            if(Bid > TrendMACurrent && Bid-TrendMACurrent<18*Pip){
               Print("trend protect not open sell order!");
               return (0);
            }
         }
         ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         subCheckError(ticket,"SELL");
         LastTrade = "SELL";
         if(isUseTrend && trendType == "sell"){
            multi = intTrendMulti;
         }
         return(0);
      }
      return(0);
   }
   
   return(0);
}

//----------------------- END PROGRAM

//+------------------------------------------------------------------+
//| FUNCTION DEFINITIONS
//+------------------------------------------------------------------+

bool trend_buy_check(){
  
   double tmpMa;
   for(int i=1;i<=50;i++){
      tmpMa = iMA(NULL,TimeFrame,TrendMAPeriod,TrendMAshift,TrendMAType,TrendMAPrice,i);
      //tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      if(Close[i] - tmpMa<0){
         return false;
      }
   }
   return true;
}
bool trend_sell_check(){
   double tmpMa;
   for(int i=1;i<=50;i++){
      //tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      tmpMa = iMA(NULL,TimeFrame,TrendMAPeriod,TrendMAshift,TrendMAType,TrendMAPrice,i);
      if(tmpMa - Close[i]<0){
         return false;
      }
   }
   return true;
}


//----------------------- NUMBER OF ORDER BASE ON SYMBOL AND MAGICNUMBER FUNCTION
int subTotalTrade()
{
   int cnt;
   int total = 0;

   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber) total++;
   }
   return(total);
}

//+------------------------------------------------------------------+
//| FUNCTION : CHECK OPEN ORDER BASE ON SYMBOL AND MAGIC NUMBER      |
//| SOURCE   : n/a                                                   |
//| MODIFIED : FIREDAVE                                              |
//+------------------------------------------------------------------+
string subCheckOpenTrade()
{
   int cnt = 0;
   string lasttrade = "None";      

   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
      {
         if(OrderType()==OP_BUY ) lasttrade = "BUY";
         if(OrderType()==OP_SELL) lasttrade = "SELL";
      }         
   }
   return(lasttrade);
}

//----------------------- FIND LOWEST/HIGHEST BUY-SELL FUNCTION
bool subHighestLowest(string type)
{
   int cnt;
   int total = 0;
      
   double HighestBuy  = 0;
   double LowestBuy   = 10000;
   double HighestSell = 0;
   double LowestSell  = 10000;

   for(cnt=0;cnt<OrdersTotal();cnt++)
   {
      OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
      if(OrderType()<=OP_SELL &&
         OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
      {
         if(OrderType()==OP_BUY)
         {
            if(OrderOpenPrice()<LowestBuy ) LowestBuy  = OrderOpenPrice();
            if(OrderOpenPrice()>HighestBuy) HighestBuy = OrderOpenPrice();
         }

         if(OrderType()==OP_SELL)
         {
            if(OrderOpenPrice()<LowestSell ) LowestSell  = OrderOpenPrice();
            if(OrderOpenPrice()>HighestSell) HighestSell = OrderOpenPrice();
         }

      }
   }
   
   if     (type=="BUY"  && (Ask<=LowestBuy -MinPriceDistance*Pip || Ask>=HighestBuy +MinPriceDistance*Pip)) return(true);
   else if(type=="SELL" && (Bid<=LowestSell-MinPriceDistance*Pip || Bid>=HighestSell+MinPriceDistance*Pip)) return(true);
   else return(false);
}

//+------------------------------------------------------------------+
//| FUNCTION : CHECK IS CROSS OR NOT                                 |
//| SOURCE   : CODERSGURU                                            |
//| MODIFIED : FIREDAVE                                              |
//+------------------------------------------------------------------+
string subCrossDirection(double fastMA, double slowMA)
{
        if(fastMA>slowMA) CurrentDirection = "UP";
   else if(fastMA<slowMA) CurrentDirection = "DOWN";
   
   if(PreviousDirection=="NONE")
   {
      PreviousDirection = CurrentDirection;
      return("NONE");
   }

   //if(PrintControl==true) Print("Prev : ",PreviousDirection," - Curr : ",CurrentDirection);
   
   if(PreviousDirection!=CurrentDirection)
   {
      PreviousDirection = CurrentDirection;
      return(CurrentDirection);
   }
   else return("NONE");
}

//----------------------- OPEN ORDER FUNCTION
//----------------------- SOURCE   : CODERSGURU
//----------------------- SOURCE   : PENGIE
//----------------------- MODIFIED : FIREDAVE
int subOpenOrder(int type, int stoploss, int takeprofit)
{
   int
         ticket      = 0,
         err         = 0,
         c           = 0;
         
   double         
         aStopLoss   = 0,
         aTakeProfit = 0,
         bStopLoss   = 0,
         bTakeProfit = 0;

   if(stoploss!=0)
   {
      aStopLoss   = NormalizeDouble(Bid-stoploss*Pip,Digits);
      bStopLoss   = NormalizeDouble(Ask+stoploss*Pip,Digits);
   }
   
   if(takeprofit!=0)
   {
      aTakeProfit = NormalizeDouble(Bid+takeprofit*Pip,Digits);
      bTakeProfit = NormalizeDouble(Ask-takeprofit*Pip,Digits);
   }
   
   if(type==OP_BUY)
   {
      for(c=0;c<NumberOfTries;c++)
      {
         ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,aStopLoss,aTakeProfit,TicketComment,MagicNumber,0,Green);
         err=GetLastError();
         if(err==0)
         { 
            if(ticket>0) break;
         }
         else
         {
            if(err==0 || err==4 || err==136 || err==137 || err==138 || err==146) //Busy errors
            {
               Sleep(5000);
               continue;
            }
            else //normal error
            {
               if(ticket>0) break;
            }  
         }
      }   
   }
   if(type==OP_SELL)
   {   
      for(c=0;c<NumberOfTries;c++)
      {
         ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,bStopLoss,bTakeProfit,TicketComment,MagicNumber,0,Red);
         err=GetLastError();
         if(err==0)
         { 
            if(ticket>0) break;
         }
         else
         {
            if(err==0 || err==4 || err==136 || err==137 || err==138 || err==146) //Busy errors
            {
               Sleep(5000);
               continue;
            }
            else //normal error
            {
               if(ticket>0) break;
            }  
         }
      }   
   }  
   return(ticket);
}


//----------------------- CLOSE ORDER FUNCTION
void subCloseOrder()
{
   int
         cnt, 
         total       = 0,
         ticket      = 0,
         err         = 0,
         c           = 0;

   total = OrdersTotal();
   for(cnt=total-1;cnt>=0;cnt--)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

      if(OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
      {
         switch(OrderType())
         {
            case OP_BUY      :
               for(c=0;c<NumberOfTries;c++)
               {
                  ticket=OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,Violet);
                  err=GetLastError();
                  if(err==0)
                  { 
                     if(ticket>0) break;
                  }
                  else
                  {
                     if(err==0 || err==4 || err==136 || err==137 || err==138 || err==146) //Busy errors
                     {
                        Sleep(5000);
                        continue;
                     }
                     else //normal error
                     {
                        if(ticket>0) break;
                     }  
                  }
               }   
               break;
               
            case OP_SELL     :
               for(c=0;c<NumberOfTries;c++)
               {
                  ticket=OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,Violet);
                  err=GetLastError();
                  if(err==0)
                  { 
                     if(ticket>0) break;
                  }
                  else
                  {
                     if(err==0 || err==4 || err==136 || err==137 || err==138 || err==146) //Busy errors
                     {
                        Sleep(5000);
                        continue;
                     }
                     else //normal error
                     {
                        if(ticket>0) break;
                     }  
                  }
               }   
               break;
               
            case OP_BUYLIMIT :
            case OP_BUYSTOP  :
            case OP_SELLLIMIT:
            case OP_SELLSTOP :
               OrderDelete(OrderTicket());
         }
      }
   }      
}


//----------------------- CHECK ERROR CODE FUNCTION
//----------------------- SOURCE : CODERSGURU
void subCheckError(int ticket, string Type)
{
    if(ticket>0) 
    {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) Print(Type + " order opened : ",OrderOpenPrice());
    }
    else Print("Error opening " + Type + " order : (",GetLastError(),") ", ErrorDescription(GetLastError()));
}

//----------------------- GENERATE MAGIC NUMBER BASE ON SYMBOL AND TIME FRAME FUNCTION
//----------------------- SOURCE   : PENGIE
//----------------------- MODIFIED : FIREDAVE
int subGenerateMagicNumber(int MagicNumber, string symbol, int timeFrame)
{
   int isymbol = 0;
   if (symbol == "EURUSD")       isymbol = 1;
   else if (symbol == "GBPUSD")  isymbol = 2;
   else if (symbol == "USDJPY")  isymbol = 3;
   else if (symbol == "USDCHF")  isymbol = 4;
   else if (symbol == "AUDUSD")  isymbol = 5;
   else if (symbol == "USDCAD")  isymbol = 6;
   else if (symbol == "EURGBP")  isymbol = 7;
   else if (symbol == "EURJPY")  isymbol = 8;
   else if (symbol == "EURCHF")  isymbol = 9;
   else if (symbol == "EURAUD")  isymbol = 10;
   else if (symbol == "EURCAD")  isymbol = 11;
   else if (symbol == "GBPUSD")  isymbol = 12;
   else if (symbol == "GBPJPY")  isymbol = 13;
   else if (symbol == "GBPCHF")  isymbol = 14;
   else if (symbol == "GBPAUD")  isymbol = 15;
   else if (symbol == "GBPCAD")  isymbol = 16;
   else                          isymbol = 17;
   if(isymbol<10) MagicNumber = MagicNumber * 10;
   return (StrToInteger(StringConcatenate(MagicNumber, isymbol, timeFrame)));
}


//----------------------- PRINT COMMENT FUNCTION
//----------------------- SOURCE : CODERSGURU
void subPrintDetails()
{
   string sComment   = "";
   string sp         = "----------------------------------------\n";
   string NL         = "\n";

   sComment = sp;
   sComment = sComment + "Net = " + netProfit + NL; 
   sComment = sComment + "Net = " + netProfit + NL; 
   sComment = sComment + sp;
   sComment = sComment + "TPinMoney=" + TPinMoney + " | ";
   sComment = sComment + "multi=" + multi + NL;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + NL;
   sComment = sComment + sp;
   sComment = sComment + "GridSize=" + DoubleToStr(GridSize,2) + NL;
   sComment = sComment + "strAdr=" + strAdr + NL;
   
   if(isUseTrend){
      sComment = sComment + sp;
      sComment = sComment + "trendType=" + trendType + NL;
   }
   
   Comment(sComment);
}


//----------------------- BOOLEN VARIABLE TO STRING FUNCTION
//----------------------- SOURCE : CODERSGURU
string subBoolToStr ( bool value)
{
   if(value==true) return ("True");
   else return ("False");
}

//----------------------- END FUNCTION

//----------------------------------------------马丁格尔-------------
static int LastBar4Martingale = 0;
bool IsNewBar4Martingale()
{
     if(LastBar4Martingale == 0 || LastBar4Martingale < iBars(Symbol(),NULL))
     {
          LastBar4Martingale = Bars;
          return(1);
     }
     return(0);
}
void CheckMartingale()
{
     //Check max open
     if(MaxOpen() > 0 && subTotalTrade() > MaxOpen())
     {
          return;
     }
     //Check
     if(NeedOpenMartingale())
     {                    
          //int LastTradeTicket = TradeLastOrderTicket();               
          int LastTradeType;  
          for(int cnt=0;cnt<OrdersTotal();cnt++)
         {
            OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
            if(OrderType()<=OP_SELL &&
               OrderSymbol()==Symbol() &&
               OrderMagicNumber()==MagicNumber)
            {
               LastTradeType = OrderType();
            }         
         }     
          double NewOrderLot   = NewOrderLot(); 
          int NewOrderTicket   = Open_Ord(LastTradeType,NewOrderLot,0,0);
     }
     return;
}

bool NeedOpenMartingale()
{
     if(subTotalTrade() < 0) return(false);    
     
     double ToLast = (OperatationMode == 0) ? DistanceToBar0InPoint() : DistanceToLastOrderInPoint();
     if(ToLast > 0) return(false);
     
     if(OperatationMode == 1 || (OperatationMode == 0 && IsNewBar4Martingale()))
     {
          if(ToLast < 0 && MathAbs(ToLast/Pip) > PipRange())
          {          
              return(true);
          }
     }    
    
     return(false);
}


double DistanceToBar0InPoint()
{
     double DistancePoint = 0.0;
     //int LastTradeTicket;
     double LastTradePrice;
     int LastTradeType;
     
      for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            LastTradeType = OrderType();
            LastTradePrice = OrderOpenPrice();
         }         
      }
     
     if(LastTradeType == OP_BUY)
     {
          DistancePoint = NormalizeDouble(Open[0],Digits) - NormalizeDouble(LastTradePrice,Digits);
     }
     
     if(LastTradeType == OP_SELL )
     {
          DistancePoint = NormalizeDouble(LastTradePrice,Digits) - NormalizeDouble(Open[0],Digits);
     }  
     return(DistancePoint);
}


double DistanceToLastOrderInPoint()
{
     double DistancePoint  = 0 ;
     //int LastTradeTicket;
     double LastTradePrice;
     int LastTradeType;
     
      for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            LastTradeType = OrderType();
            LastTradePrice = OrderOpenPrice();
         }         
      }
     if(LastTradeType == OP_BUY)
     {
          DistancePoint = NormalizeDouble(Bid,Digits) - NormalizeDouble(LastTradePrice,Digits);
     }
     
     if(LastTradeType == OP_SELL )
     {
          DistancePoint = NormalizeDouble(LastTradePrice,Digits) - NormalizeDouble(Ask,Digits);
     }     
     return(DistancePoint);
}

int MaxOpen()
{
     return(MaxMarti);
}
int PipRange()
{
     return(GridSize);
}

double NewOrderLot()
{
     if(subTotalTrade() > 1)
     {
          int lotdecimal = 2;
          int NumOfTrades = subTotalTrade()-1;
          double Lotsize      = NormalizeDouble(Lots * MathPow(Mutilplier, NumOfTrades), lotdecimal);
          return(Lotsize);
     }
     return(Lots);
}

string GlobalBusyOpeningString()
{
     string Busy = "_BUSY_OPENING";
     return("Dreamguy-MaCrossMarti" + "_" + Symbol() + Busy);     
}


int Open_Ord(int Tip, double OrdLot,int OrdStopLoss, int OrdTakeProfit)
{
     //------------------------------------------------- 1 --
     string GlobalBusyOpening  = GlobalBusyOpeningString();
     bool BusyOpening  = (bool)GlobalVariableGet(GlobalBusyOpening);
     if(BusyOpening == true)
     {          
          Print("It is busy at opening ");
          return(-1);  
     }
     //------------------------------------------------- 2 --
     int    Ticket=-1,                       // Order ticket
            MN;                           // MagicNumber
     double OpenPrice, NewOrdStopLoss, NewOrdTakeProfit;       
     string NewOrdCmt = NewOrderComment(Tip);
     MN = MagicNumber;                  //  MagicNumber
     //------------------------------------------------ 2.1 --
     GlobalVariableSet(GlobalBusyOpening,true);//Set true at global
     while( Ticket < 0 )                    // Until they  ..
     {                                          //.. succeed          
          //-------------------------------------- 2.2 --
          if (Tip == OP_BUY)                                
          {
               OpenPrice        = NormalizeDouble(Ask,Digits);
               NewOrdStopLoss   = 0.0;
               NewOrdTakeProfit = 0.0;   
               Ticket           = OrderSend(Symbol(),0,OrdLot,OpenPrice,Slippage,NewOrdStopLoss,NewOrdTakeProfit,NewOrdCmt,MN,0,Green); 
          }
          //-------------------------------------- 2.3 --
          if ( Tip == OP_SELL )                       
          {
               OpenPrice        = NormalizeDouble(Bid,Digits);
               NewOrdStopLoss   = 0.0;  
               NewOrdTakeProfit = 0.0;   
               Ticket           = OrderSend(Symbol(),1,OrdLot,OpenPrice,Slippage,NewOrdStopLoss,NewOrdTakeProfit,NewOrdCmt,MN,0,Red);
          }
          //------------------------------------- 2.4 --
          if ( Ticket < 0 )                              // Faied :( 
          {                                            // Check for errors:
               if ( Errors(GetLastError()) == false )  // If the error is ritical
               {
                    break;                             // .. then leave.
               }     
          }
          //Terminal();                                  // Order accounting function 
          //Events();                                    // Event tracking
          //------------------------------------- 2.5 --
     }     
     GlobalVariableSet(GlobalBusyOpening,false); //Set false at global
     //------------------------------------------ 3 --
     return(Ticket);// Exit the user-defined function
}


string NewOrderComment(int Tip)
{     
     string OrdCmt =  "DREAMGUYEA ";
     return(OrdCmt);                
}

bool Errors(int Error)                    //Custom function
  {
   // Error             // Error number  
   if(Error==0)
      return(false);                      // No Error
//--------------------------------------------------------------- 3 --
   switch(Error)
     {   // Overcomeable errors:
      case 129:         // Wrong price
      case 135:         // Price changed
         RefreshRates();                  // Renew date
         return(true);                    // Error is overcomable
      case 136:         // No quotes. Waiting for the tick to come
      case 138:         // The price is outdated, need to be refresh
         while(RefreshRates()==false)     // Before new tick
            Sleep(1);                     // Delay in the cycle
         return(true);                    // Error is ovecomable
      case 146:         // The trade sybsystem is busy
         Sleep(500);                      // Simple solution
         RefreshRates();                  // Renew data
         return(true);                    // Error is overcomable
         // Critical errors:
      case 2 :          // Common error
      case 5 :          // Old version of the client terminal
      case 64:          // Account blocked
      case 133:         // Trading is prohibited
      default:          // Other variants
         return(false);                   // Critical error
     }
//--------------------------------------------------------------- 4 --
  }
  
double TotalNetProfit()
{
     double op = 0;
     for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            op = op + OrderProfit();
         }         
      }
      netProfit = op;
      return op;
}

void ProfitProtector()
{
     //when there are more than one order open  
     if(TotalNetProfit() > TPinMoney*multi)
     {
          CloseAllMarketOrder();
     }    
       
     return;
}

void CloseAllMarketOrder()
{
     int Ticket;    
     for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            Ticket = OrderTicket();               
            CloseMarketOrder(Ticket);       
         }         
      }
}



bool CloseMarketOrder(int Ticket)
{
     bool  Ans = false;         
     double ClosePrice = 0.0;
     
     if(OrderSelect(Ticket,SELECT_BY_TICKET))
     {
          while(!Ans)    //Trying closing the order until successfuly
          {
               //-----------------------------------------------------------------------
               if ( OrderType() == OP_BUY )
               {
                    ClosePrice = NormalizeDouble(Bid,Digits);
                    Ans        = OrderClose(Ticket,OrderLots(),ClosePrice,Slippage,Green);
               }     
               if ( OrderType() == OP_SELL )
               {
                    ClosePrice = NormalizeDouble(Ask,Digits);
                    Ans = OrderClose(Ticket,OrderLots(),ClosePrice,Slippage,Red);
               }               
               //----------------------------------------------------------------------
               if(Ans == false)
               {
                    if ( Errors(GetLastError())==false )// If the error is ritical
                    {
                         
                         return(false);
                    }
               }
          }
     }
     
     return(Ans);     
} 

//--------------------------ADR FUNCTION
double AverageRange(int TF,int length)
{
   double sum=0;
   int nBars=iBars(NULL,TF);
   //printf("bars:"+nBars);
   int iLimit=length;
   if(iLimit>nBars) iLimit=nBars;
   for(int iPos=0; iPos<iLimit; iPos++)
   {
         
       double H=iHigh(NULL,TF,iPos)/Pip;
       double L=iLow(NULL,TF,iPos)/Pip;
       //printf("TF:"+TF+"---H:"+H+"----L:"+L);
       sum+=H-L;
   }
   return(NormalizeDouble((sum)/iLimit,1));
}

double setGridsizeByADR(){
   strAdr = "D1:"+(AverageRange(PERIOD_D1,3));
   strAdr += "  H1:"+(AverageRange(PERIOD_H1,3));
   //strAdr += "  W1:"+(AverageRange(PERIOD_W1,3));
   double adr=(AverageRange(PERIOD_D1,3));
   double gridsize;
   gridsize = MathRound(adr*0.5);
   
   int totalT = subTotalTrade();
   if(totalT>2){
      if(gridsize<40){
         gridsize = 40;
      }
      gridsize += (totalT-2)*10;
   }
   
   return gridsize;
}