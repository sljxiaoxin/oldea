//+------------------------------------------------------------------+
//|                                           Dreamguy-MaCrossMarti.mq4 |
//|                                  Copyright ?2016-2020, Dreamguy | 
//+------------------------------------------------------------------+

#property copyright "Copyright ?2016-2020, Dreamguy"
#property link      "http://www.forexfactory.com"

extern string           Expert_Name          = "Dreamguy-MaRSIOverlying-ver2";
extern int              MagicNumber          = 1204;
extern double           Lots                 = 0.2;
extern double           TPinMoney            = 10;          //Net TP (money)
extern int              RsiLevel             = 50;
extern double           Mutilplier           = 1.2;   //Martingale Mutiplier
extern int              MaxMarti             = 5;           // Max Marti (0-Unlimited)
extern int              GridSize             = 50;      //GridSize (In Pip)
extern int              NumberOfTries        = 10,
                        Slippage             = 5;
                        


//----------------------- GLOBAL VARIABLE
static int              TimeFrame            = 0;
datetime                CheckTime,
                        CrossTime;
 double                  StopLoss             = 0,
                        TakeProfit           = 0;
string                  TicketComment        = "MaRSIOverlying-ver2";
double ma10,ma10_pre;
double ma120,ma120_pre;
double ma10Overlying;
double ma120Overlying;
double SLMaValue;
double netProfit;
string RSIPosition = "";
double Pip;
datetime orderOpenTime=0;
double orderOpenPrice = 0;
string LastTrade = "";
double TPProtect;
double RSIHighLow;   //记录RSI穿越前后的最大值或最小值
double sx=1;  //两个价格差，计算多少点，按小数点4位为标准店，相当于点值
double slPrice,SLnet,diff;
double arrMa10[10];
double arrMa10Overlying[10];
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   if(Digits==2 || Digits==4) {
      Pip = Point;
   }else if(Digits==3 || Digits==5){
      Pip = 10*Point;
      sx = 0.1;
   }else if(Digits==6){
      Pip = 100*Point;
      sx = 0.01;
   }
   TPProtect = TPinMoney;
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
//----------------------- SET VALUE FOR VARIABLE
   CheckMartingale();
   subPrintDetails();
   ProfitProtector();
   if(CheckTime==iTime(NULL,TimeFrame,0)){
      return(0);
   } else {
      CheckTime = iTime(NULL,TimeFrame,0);
      int candleCrossNums = 0;
      double ma10Overlying_buffer[200];
      double ma120Overlying_buffer[200];
      int i,limit=ArraySize(ma10Overlying_buffer);
      ArraySetAsSeries(ma10Overlying_buffer,true);
      ArraySetAsSeries(ma120Overlying_buffer,true);
       
      for(i=0; i<limit; i++){
         ma10Overlying_buffer[i]  = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,i);
         ma120Overlying_buffer[i] = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,i);
      }
      //ma10_pre = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,2);
      //ma120_pre = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,2);
      SLMaValue = iMA(NULL,0,30,0,MODE_LWMA,PRICE_CLOSE,1);   //止损基准线
      ma10 = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,1);
      ma120 = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,1);
      ma10Overlying = iMAOnArray(ma10Overlying_buffer,limit,10,0,MODE_EMA,1);
      ma120Overlying = iMAOnArray(ma120Overlying_buffer,limit,120,0,MODE_EMA,1);
      for(i=0;i<10;i++){
         arrMa10[i] = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,i+1);
         arrMa10Overlying[i] = iMAOnArray(ma10Overlying_buffer,limit,10,0,MODE_EMA,i+1);
      }
      
      double Rsi3_three = iRSI(NULL,0,3,PRICE_CLOSE,3);
      double Rsi3_one = iRSI(NULL,0,3,PRICE_CLOSE,1);
      double Rsi3_two = iRSI(NULL,0,3,PRICE_CLOSE,2);
      
      if(Rsi3_one > Rsi3_two && Rsi3_one > 55  && (Rsi3_two < 35 || Rsi3_three<35) ){
         //buy
         crossBuy();
      }
      
      if(Rsi3_one < Rsi3_two && Rsi3_one <45  && (Rsi3_two >65 || Rsi3_three>65)){
         //sell
         crossSell();
      }
      
      //Print("ma10:",ma10,"ma10Overlying:",ma10Overlying,"RSI3:",Rsi3);
   }
   
   return(0);
}
void subPrintDetails()
{
   string sComment   = "";
   string sp         = "----------------------------------------\n";
   string NL         = "\n";

   sComment = sp;
   sComment = sComment + "Net = " + netProfit + NL; 
   sComment = sComment + "Net = " + netProfit + NL; 
   sComment = sComment + sp;
   sComment = sComment + "TPinMoney=" + TPinMoney + " | slPrice="+slPrice+NL;
   sComment = sComment + "Lots=" + DoubleToStr(Lots,2) + NL;
   sComment = sComment + "diff="+diff+" | SLnet=" + SLnet + NL;
   
   
  
   Comment(sComment);
}
void crossBuy(){
   //if(candleNum<=4 && subTotalTrade() == 0){
   if(subTotalTrade() == 0){
      if(ma10>ma10Overlying  && ma10Overlying>ma120 && ma120>ma120Overlying){
         int ticket;
         ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         //if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         //if(ticket<=0) ticket = subOpenOrder(OP_BUY,StopLoss,TakeProfit);
         if(ticket>0){
            LastTrade = "BUY";
            orderOpenTime = iTime(NULL,TimeFrame,0);
         }
      }
   }
}

void crossSell(){
   //if(candleNum<=4 && subTotalTrade() == 0){
   if( subTotalTrade() == 0){
      if(ma10<ma10Overlying  && ma10Overlying<ma120 && ma120<ma120Overlying){
         int ticket;
         ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         //if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         //if(ticket<=0) ticket = subOpenOrder(OP_SELL,StopLoss,TakeProfit);
         if(ticket>0){
            LastTrade = "SELL";
            orderOpenTime = iTime(NULL,TimeFrame,0);
         }
      }
   }
}


void ProfitProtector()
{
      //TPProtect
     //when there are more than one order open  
     //(orderOpenTime >0 && (CheckTime-orderOpenTime)/60/Period()>=SLCandleNum) || 
     double _net = TotalNetProfit();
     if(_net > TPProtect)
     {
          CloseAllMarketOrder();
     }
     if(LastTrade == "BUY" && orderOpenPrice != 0){
        if(arrMa10[9] > arrMa10Overlying[9] 
           && arrMa10[8] < arrMa10Overlying[8] 
           && arrMa10[7] < arrMa10Overlying[7] 
           && arrMa10[6] < arrMa10Overlying[6] 
           && arrMa10[5] < arrMa10Overlying[5] 
           && arrMa10[4] < arrMa10Overlying[4] 
           && arrMa10[3] < arrMa10Overlying[3] 
           && arrMa10[2] < arrMa10Overlying[2] 
           && arrMa10[1] < arrMa10Overlying[1]
           && arrMa10[0] < arrMa10Overlying[0]){
              if(_net > (-1*TPProtect*3)){
                  CloseAllMarketOrder();
              }
           }
     }
     if(LastTrade == "SELL" && orderOpenPrice != 0){
        if(arrMa10[9] < arrMa10Overlying[9] 
            && arrMa10[8] > arrMa10Overlying[8] 
           && arrMa10[7] > arrMa10Overlying[7] 
           && arrMa10[6] > arrMa10Overlying[6] 
           && arrMa10[5] > arrMa10Overlying[5] 
           && arrMa10[4] > arrMa10Overlying[4]
           && arrMa10[3] > arrMa10Overlying[3] 
           && arrMa10[2] > arrMa10Overlying[2] 
           && arrMa10[1] > arrMa10Overlying[1]
           && arrMa10[0] > arrMa10Overlying[0]){
              if(_net > (-1*TPProtect*3)){
                  CloseAllMarketOrder();
              }
           }
     }
     /*
     if(LastTrade == "BUY" && orderOpenPrice != 0){
         slPrice = NormalizeDouble((SLMaValue - 10*Pip),Digits);
         diff = (slPrice - orderOpenPrice)/Point*sx;//*Digits*sx;
         SLnet = diff * Lots * 10;
         if(_net < SLnet)
         {
             CloseAllMarketOrder();
         }
     }
     if(LastTrade == "SELL"  && orderOpenPrice != 0){
         slPrice = NormalizeDouble((SLMaValue + 10*Pip),Digits);
         diff = (orderOpenPrice - slPrice)/Point*sx;//*Digits*sx;
         SLnet = diff * Lots * 10;
         if(_net < SLnet)
         {
             CloseAllMarketOrder();
         }
     }
     */
     return;
     
}

double TotalNetProfit()
{
     double op = 0;
     orderOpenPrice = 0;
     for(int cnt=0;cnt<OrdersTotal();cnt++)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if(OrderType()<=OP_SELL &&
            OrderSymbol()==Symbol() &&
            OrderMagicNumber()==MagicNumber)
         {
            if(orderOpenPrice == 0){
               orderOpenPrice = OrderOpenPrice();
            }
            op = op + OrderProfit();
         }  
                
      }
      netProfit = op;
      return op;
}
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
               Sleep(1000);
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
               Sleep(1000);
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
     int total = subTotalTrade();
     if(total < 0) return(false);    
     
     double ToLast = DistanceToBar0InPoint();
     if(ToLast > 0) return(false);
     
     if(IsNewBar4Martingale())
     {
          if(ToLast < 0 && MathAbs(ToLast/Pip) > PipRange(total))
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


int MaxOpen()
{
     return(MaxMarti);
}
int PipRange(int total)
{
     /*
      ma10 = iMA(NULL,0,10,0,MODE_EMA,PRICE_CLOSE,1);
      ma120 = iMA(NULL,0,120,0,MODE_EMA,PRICE_CLOSE,1);
      ma10Overlying = iMAOnArray(ma10Overlying_buffer,limit,10,0,MODE_EMA,1);
      ma120Overlying = iMAOnArray(ma120Overlying_buffer,limit,10,0,MODE_EMA,1);
     */
     if(total == 1){
         //Print("totalTrade num is 1 return 20 GridSize!");
         if(LastTrade == "SELL" && !(Ask > ma10 && Ask > ma120 && Ask > ma10Overlying && Ask>ma120Overlying)){
               return 20;
         }
         if(LastTrade == "BUY" && !(Bid < ma10 && Bid < ma120 && Bid < ma10Overlying && Bid<ma120Overlying)){
               return 20;
         }
         return 40;
         
     }
     return(GridSize + 10*total);
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
     return("Dreamguy-MaRisOverlying" + "_" + Symbol() + Busy);     
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