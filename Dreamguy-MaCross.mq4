//+------------------------------------------------------------------+
//|                                           Dreamguy-MaCrossMarti.mq4 |
//|                                  Copyright ?2016-2020, Dreamguy | 
//+------------------------------------------------------------------+

#property copyright "Copyright ?2016-2020, Dreamguy"
#property link      "http://www.forexfactory.com"


//----------------------- INCLUDES
#include <stdlib.mqh>

//----------------------- EA PARAMETER
extern string           Expert_Name          = "---------- Dreamguy-MaCrossMarti v1.0";
extern int              MagicNumber          = 1234;
extern double           StopLoss             = 0,
                        TakeProfit           = 10;
extern string           Indicator_Setting    = "---------- Indicator Setting";
extern int              FastMAPeriod         = 10,
                        FastMAType           = 1,    //0:SMA 1:EMA 2:SMMA 3:LWMA
                        FastMAPrice          = 0,    //0:Close 1:Open 2:High 3:Low 4:Median 5:Typical 6:Weighted
                        FastMAshift          = 0,
                        SlowMAPeriod         = 20,
                        SlowMAType           = 1,    //0:SMA 1:EMA 2:SMMA 3:LWMA
                        SlowMAPrice          = 0,    //0:Close 1:Open 2:High 3:Low 4:Median 5:Typical 6:Weighted
                        SlowMAshift          = 0;
       
extern string           Order_Setting        = "---------- Order Setting";
extern int              NumberOfTries        = 10,
                        Slippage             = 5;
extern string           OpenOrder_Setting    = "---------- Multiple Open Trade Setting";
extern int              MaxOpenTrade         = 1,
                        MinPriceDistance     = 5;
extern string           MM_Parameters        = "---------- Money Management";
extern double           Lots                 = 0.01;
extern bool             MM                   = true; //Use Money Management or not
extern int              Risk                 = 10; //10%
extern string           Alert_Setting        = "---------- Alert Setting";
extern bool             EnableAlert          = false;
extern string           SoundFilename        = "alert.wav";
extern string           Testing_Parameters= "---------- Back Test Parameter";
extern bool             PrintControl         = true,
                        Show_Settings        = true;

//----------------------- GLOBAL VARIABLE
static int              TimeFrame            = 0;
string                  TicketComment        = "Dreamguy-MaCrossMarti v1.0",
                        LastTrade,
                        LastAlert,
                        TradeDirection       = "NONE",
                        PreviousDirection    = "NONE",
                        CurrentDirection     = "NONE";
datetime                CheckTime,
                        CrossTime;

double Pip;
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
                   
   int ticket;
   int total;
         
   bool BuyCondition = false;
   bool SellCondition = false;
   string CrossDirection;         
        

//----------------------- CHECK CHART NEED MORE THAN 100 BARS
   if(Bars<100)
   {
      Print("bars less than 100");
      return(0);  
   }         

//----------------------- ADJUST LOTS IF USING MONEY MANAGEMENT
   if(MM==true) Lots = subLotSize();

//----------------------- SET VALUE FOR VARIABLE
   if(CheckTime==iTime(NULL,TimeFrame,0)) return(0); else CheckTime = iTime(NULL,TimeFrame,0);
   
      FastMACurrent    = iMA(NULL,TimeFrame,FastMAPeriod,FastMAshift,FastMAType,FastMAPrice,1);
      SlowMACurrent    = iMA(NULL,TimeFrame,SlowMAPeriod,SlowMAshift,SlowMAType,SlowMAPrice,1);
   
   CrossDirection = subCrossDirection(FastMACurrent,SlowMACurrent);

//----------------------- CONDITION CHECK
   //----------------------- BUY CONDITION   
      if(CrossDirection=="UP")
      {
         BuyCondition   = true;
         TradeDirection = "UP";
         CrossTime      = iTime(NULL,TimeFrame,0);
      }                       

//----------------------- SELL CONDITION   
      if(CrossDirection=="DOWN")
      {
         SellCondition  = true;
         TradeDirection = "DOWN";
         CrossTime      = iTime(NULL,TimeFrame,0);
      }

   if(PrintControl==true)
   {
      if(BuyCondition==true)  Print("MA Cross BUY");
      if(SellCondition==true) Print("MA Cross SELL");
   }      

//----------------------- ALERT ON CROSS
   if(EnableAlert==true)
   {
      if(TradeDirection=="UP" && LastAlert!="UP")
      {
         subCrossAlert("UP");
         LastAlert = "UP";
      }            
      if(TradeDirection=="DOWN" && LastAlert!="DOWN")
      {
         subCrossAlert("DOWN");
         LastAlert ="DOWN";
      }
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
         if(MaxOpenTrade>1 && subHighestLowest("BUY")==false) return(0);
      
         ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         subCheckError(ticket,"BUY");
         LastTrade = "BUY";
         return(0);
      }

//----------------------- SELL CONDITION   
      if(SellCondition==true)
      {
         if(MaxOpenTrade>1 && subHighestLowest("SELL")==false) return(0);
         
         ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         subCheckError(ticket,"SELL");
         LastTrade = "SELL";
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

//----------------------- MONEY MANAGEMENT FUNCTION  
//----------------------- SOURCE : CODERSGURU
double subLotSize()
{
     double lotMM = MathCeil(AccountFreeMargin() *  Risk / 1000) / 100;
	  
	  if(lotMM < 0.01)                 lotMM = Lots;
     if(lotMM > 1.0)                  lotMM = MathCeil(lotMM);
     if(lotMM > 100)                  lotMM = 100;
	  
	  return (lotMM);
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

   if(PrintControl==true) Print("Prev : ",PreviousDirection," - Curr : ",CurrentDirection);
   
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
   sComment = sComment + "TakeProfit=" + DoubleToStr(TakeProfit,0) + " | ";
   sComment = sComment + "StopLoss=" + DoubleToStr(StopLoss,0) + NL; 
   sComment = sComment + sp;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + " | ";
   sComment = sComment + "MM=" + subBoolToStr(MM) + " | ";
   sComment = sComment + "Risk=" + DoubleToStr(Risk,0) + "%" + NL;
   sComment = sComment + sp;
  
   Comment(sComment);
}


//----------------------- BOOLEN VARIABLE TO STRING FUNCTION
//----------------------- SOURCE : CODERSGURU
string subBoolToStr ( bool value)
{
   if(value==true) return ("True");
   else return ("False");
}

//----------------------- ALERT ON MA CROSS
//----------------------- SOURCE : FIREDAVE
void subCrossAlert(string type)
{
   string AlertComment;
   
   if(type=="UP")   AlertComment = "Moving Average Cross UP !";
   if(type=="DOWN") AlertComment = "Moving Average Cross DOWN !";
   
   Alert(AlertComment);
   PlaySound(SoundFilename);
}

//----------------------- END FUNCTION