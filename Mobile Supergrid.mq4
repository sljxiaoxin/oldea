#include <stderror.mqh>
#include <stdlib.mqh>
#define name "Mobile Supergrid" //Recommended for M1 or M5 timeframes.
bool DEBUG=true;

extern string comment=name;
extern int MagicNumber=12345;
extern bool useFixedLots=true;
extern double  FixedLots=0.01;
extern double RiskPerTrade_percent=0.025;//gets you starting with 0.01 lots on a $10,000 account using a stoploss of 250 points.

//HOW TO GET RiskPerTrade_percent or X:

//[(AccountBalance)(X) / STOP LOSS = Required lot size] x 100 (for percent)

//In other words take your desired lotsize, multiply it by the stoploss and then divide this number
//by the starting account balance. Then times this number by 100.

extern int slippage=5;
extern bool EveryTick=true;
extern string HeaderMartingale="=== Martingale";
extern bool StartOverAfterEAReload=true;
extern double MartingaleMultiplier=2.0; // or maybe try 1.9 if you are using a starting lotsize of 0.10 or more. 

//(I think 1.9 might be more profitable because you can start with a smaller account balance.)                

extern int PointsToEnter=5;//this isn't used. I was scared to get rid of it lol.
extern int PointsToExit=5;//same with this.

extern int  stoploss_points=250;                         
extern int  takeprofit_points=250;                        
//breakeven
extern bool use_breakeven=true;//you don't necessarily need this. on my tests it helped get rid of a loss or two during some sequences. 
extern int breakeven_threshold_points=200; 
extern int breakeven_addition_points=20; 
//trailing stop
extern bool useTrailingStop=false;
extern int trailingStop_threshold=1;
extern int trailingStop_trail=250;

//order repetition
int repeat=30;//new
int sleep_interval=1000;//new

datetime start_time=0;

int init()
{
   if(StartOverAfterEAReload)
   {
      start_time=TimeCurrent();
   }
   else start_time=0;
   return(0);
}
  
int deinit()
{
   return(0);
}

int start()
{
   if(IsNewBar() || EveryTick)
   {
      if(ExitLong()) CloseLong();
      if(ExitShort()) CloseShort();
      if(LongSignal() && NoTrades() && (!ExitLong()))
      {
         EnterLong();
      }
      else if(ShortSignal() && NoTrades() && (!ExitShort()))
      {
         EnterShort();
      }
   }
   AssignSL();
   Breakeven();
   Trail();
   return(0);
}


bool IsNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time = Time[0];
 
   if(0 == last_time)
   {  // only just after initialization
      last_time=lastbar_time;
      return( false);
   }
 
   if(last_time!=lastbar_time)
   {
      last_time = lastbar_time;
      return( true);
   }
 
   return (false);
}


bool NoTrades()
{
   int total=OrdersTotal();
   for(int n=0;n<total;n++)
   {
      if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderCloseTime()!=0) continue;
      if((OrderType()==OP_SELL) || (OrderType()==OP_BUY)) 
      {
         return (false);
      }
   }
   return (true);
}

void EnterLong()
{
  int res=-1;
  for(int i=0;(i<repeat) && (res<0);i++)
  {
      RefreshRates();
      res=OrderSend(Symbol(),OP_BUY,Lots(),Ask,slippage,0,0,comment,MagicNumber,0,Black);
      if(res<0)
      {
        PrintError(Symbol());
        Sleep(sleep_interval);
      }
      else break;
   }
}

void EnterShort()
{
  int res=-1;
  for(int i=0;(i<repeat) && (res<0);i++)
  {
      RefreshRates();
      res=OrderSend(Symbol(),OP_SELL,Lots(),Bid,slippage,0,0,comment,MagicNumber,0,DeepPink);
      if(res<0)
      {
        PrintError(Symbol());
        Sleep(sleep_interval);
      }
      else break;
  }
}

void Breakeven()
{
   if(!use_breakeven) return;
   double sl=-1;
   int total=OrdersTotal();
   for(int n=0;n<total;n++)
   {
      if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderCloseTime()!=0) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      RefreshRates();
      if(OrderType()==OP_SELL) 
      {
         if((OrderOpenPrice()-Ask)>=(breakeven_threshold_points*Point))
         {
            sl=OrderOpenPrice()-breakeven_addition_points*Point;
            sl=NormalizeDouble(sl,Digits);
         }
         if((sl<OrderStopLoss() || IsEqual(OrderStopLoss(),0)) && (sl>=0))
         {
            OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
            continue;
         }
      }
      if(OrderType()==OP_BUY) 
      {
         if((Bid-OrderOpenPrice())>=(breakeven_threshold_points*Point))
         {
            sl=OrderOpenPrice()+breakeven_addition_points*Point;
            sl=NormalizeDouble(sl,Digits);
         }
         if(sl>OrderStopLoss())
         {
            OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
            continue;
         }
      }
   }
}


void AssignSL()
{
   double sl=0;
   double tp=0;
   int total=OrdersTotal();
   for(int n=0;n<total;n++)
   {
      if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderCloseTime()!=0) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if((IsEqual(OrderStopLoss(),0) && IsEqual(OrderTakeProfit(),0)) && ((!IsEqual(stoploss_points,0)) || (!IsEqual(takeprofit_points,0))))
      {
         if(OrderType()==OP_SELL) 
         {
            sl=OrderOpenPrice()+stoploss_points*Point;
            if(IsEqual(stoploss_points,0)) sl=0;
            tp=OrderOpenPrice()-takeprofit_points*Point;
            if(IsEqual(takeprofit_points,0)) tp=0;
            OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0);
            continue;
         }
         if(OrderType()==OP_BUY) 
         {
            sl=OrderOpenPrice()-stoploss_points*Point;
            if(IsEqual(stoploss_points,0)) sl=0;
            tp=OrderOpenPrice()+takeprofit_points*Point;
            if(IsEqual(takeprofit_points,0)) tp=0;
            OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0);
            continue;
         }
      }
   }
}

void Trail()
{
   if(!useTrailingStop) return;
   if(trailingStop_threshold<=0) return;
   if(trailingStop_trail<=0) return;

   double sl=0;
   int total=OrdersTotal();
   for(int n=0;n<total;n++)
   {
      if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderCloseTime()!=0) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()==OP_SELL) 
      {
         if(Ask<=(OrderOpenPrice()-trailingStop_threshold*Point) || (!IsEqual(OrderStopLoss(),0) && (OrderStopLoss()<(OrderOpenPrice()-(breakeven_addition_points+1)*Point)) ) )
         {
            sl=Ask+trailingStop_trail*Point;
            if(sl<OrderStopLoss() || IsEqual(OrderStopLoss(),0))
               OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
         }
         continue;
      }
      if(OrderType()==OP_BUY) 
      {
         if(Bid>=(OrderOpenPrice()+trailingStop_threshold*Point) || (!IsEqual(OrderStopLoss(),0) && (OrderStopLoss()>(OrderOpenPrice()+(breakeven_addition_points+1)*Point)) ) )
         {
            sl=Bid-trailingStop_trail*Point;
            if(sl>OrderStopLoss())
               OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0);
         }
         continue;
      }
   }
}

void PrintError(string pair)
{
   int err=GetLastError();
   Print("Error# ",err," ",ErrorDescription(err)," for ",pair);
}

bool IsEqual(double val1, double val2,int acc=1)
{
   return (MathAbs(val1-val2)<=(acc*Point));
}

double RoundLots(double lots)
{
   double l=lots;
   double maxl=MarketInfo(Symbol(),MODE_MAXLOT);
   double minl=MarketInfo(Symbol(),MODE_MINLOT);
   double stepl=MarketInfo(Symbol(),MODE_LOTSTEP);
   if(l<minl) l=minl;
   if(l>maxl) l=maxl;
   l=MathFloor(l/stepl)*stepl;
   return (l);
}

double LotsForSL(double sl_points,double RiskPerTrade)
{
   double sl_ticks=sl_points*Point/MarketInfo(Symbol(),MODE_TICKSIZE);
   double free=MathMin(AccountBalance(),AccountFreeMargin());
   double lots=RiskPerTrade/100.*free/sl_ticks/MarketInfo(Symbol(),MODE_TICKVALUE); //(AccountFreeMargin()*MaximumRisk/1000,2)
   //Margin can be insufficient
   double lot_lim=AccountFreeMargin()/MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   return (MathMin(lots,lot_lim));
}

double RiskLots()
{
   double sl=stoploss_points;
   if(IsEqual(sl,0))
   {
      sl=Ask/Point;
   }
   double l=LotsForSL(sl,RiskPerTrade_percent);
   l=RoundLots(l);
   return (l);
}

double Lots()
{
   datetime lasttime=0;
   int ticket=-1;
   double lastlots=0;
   bool isLoser=false;
   bool isNeutral=false;//breakeven
   int total=OrdersHistoryTotal();
   for(int n=0;n<total;n++)
   {
      if(!OrderSelect(n,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()==OP_BUY || OrderType()==OP_SELL)
      {
         if(OrderOpenTime()>lasttime && OrderOpenTime()>=start_time)
         {
            lasttime=OrderOpenTime();
            ticket=OrderTicket();
            lastlots=OrderLots();
            isLoser=OrderProfit()<0;
            isNeutral=OrderProfit()>=0 && MathAbs(OrderClosePrice()-OrderOpenPrice())<=((breakeven_addition_points+1)*Point);
         }
      }
   }
   if(ticket<0)
   {
      //trade from scratch
      return (BaseLots());
   }
   else
   {
      //martingale
      if(isLoser) return (RoundLots(MartingaleMultiplier*lastlots));
      else if(isNeutral) return (lastlots);
      else return (BaseLots());//winner
      
      
   }
   return (BaseLots());//will never happen
}

double BaseLots()
{
   if(useFixedLots)
   {
      return (FixedLots);
   }
   //Money management
   return (RiskLots());
}

void CloseShort()
{
   int i;
   //close own short market, if any
   bool something_closed=true;
   while(something_closed)
   {
      something_closed=false;
      int total=OrdersTotal();
      for(int n=0;n<total;n++)
      {
         if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderCloseTime()!=0) continue;
         if(OrderMagicNumber()!=MagicNumber) continue;
         if(OrderType()==OP_SELL) 
         {
            for(i=0;i<repeat;i++)
            {
               RefreshRates();
               if(!OrderClose(OrderTicket(),OrderLots(),Ask,slippage))
               {
                  PrintError(Symbol());
                  Sleep(sleep_interval);
               }
               else
               {
                  something_closed=true;
                  break;
               }
            }
            if(something_closed) break;
         }
      }
   }
}

void CloseLong()
{
   int i;
   //close own long market, if any
   bool something_closed=true;
   while(something_closed)
   {
      something_closed=false;
      int total=OrdersTotal();
      for(int n=0;n<total;n++)
      {
         if(OrderSelect(n,SELECT_BY_POS,MODE_TRADES)==false) continue;
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderCloseTime()!=0) continue;
         if(OrderMagicNumber()!=MagicNumber) continue;
         if(OrderType()==OP_BUY) 
         {
            for(i=0;i<repeat;i++)
            {
               RefreshRates();
               if(!OrderClose(OrderTicket(),OrderLots(),Bid,slippage))
               {
                  PrintError(Symbol());
                  Sleep(sleep_interval);
               }
               else
               {
                  something_closed=true;
                  break;
               }
            }
            if(something_closed) break;
         }
      }
   }
}

double GetStochastics(int kperiod,int shift)
{
   return (iStochastic(NULL,0,kperiod,3,3,MODE_SMA,0,MODE_MAIN,shift));
}

bool LongSignal()
{
   int shift=1;
   if(EveryTick) shift=0;      
   
   double CycleCurrent=GetStochastics(5,shift+1);//not used. i didn't know how to get rid of it.        
   double CyclePrevious=GetStochastics(5,shift+2);
   
   double MAImperial=iMA(NULL,0,100,0,MODE_SMA,PRICE_CLOSE,0);

   int ct;
   ct=Hour()*100+Minute();

   
   return (Close[0]<MAImperial-200*Point && Close[0]>MAImperial-210*Point && Close[0]>Open[0]
   
               || Close[0]<MAImperial-400*Point && Close[0]>MAImperial-410*Point && Close[0]>Open[0]
               
                     || Close[0]<MAImperial-800*Point && Close[0]>MAImperial-810*Point && Close[0]>Open[0]
                     
                           || Close[0]<MAImperial-1200*Point && Close[0]>MAImperial-1210*Point && Close[0]>Open[0]);  
}

bool ShortSignal()
{
   int shift=1;
   if(EveryTick) shift=0;      
   
   double CycleCurrent=GetStochastics(5,shift+1);        
   double CyclePrevious=GetStochastics(5,shift+2);
   
   double MAImperial=iMA(NULL,0,100,0,MODE_SMA,PRICE_CLOSE,0);
  
   int ct;
   ct=Hour()*100+Minute();
 
    
   return (Close[0]>MAImperial+200*Point && Close[0]<MAImperial+210*Point && Close[0]<Open[0]
   
               || Close[0]>MAImperial+400*Point && Close[0]<MAImperial+410*Point && Close[0]<Open[0]
               
                     || Close[0]>MAImperial+800*Point && Close[0]<MAImperial+810*Point && Close[0]<Open[0]
                     
                           || Close[0]>MAImperial+1200*Point && Close[0]<MAImperial+1210*Point && Close[0]<Open[0]); 
}

bool ExitLong()
{
   int shift=1;
   if(EveryTick) shift=0;      
   
   double CycleCurrent=GetStochastics(5,shift+1);        
   double CyclePrevious=GetStochastics(5,shift+2);
   
   return (High[0]<Low[0]); 
}

bool ExitShort()
{
   int shift=1;
   if(EveryTick) shift=0;      
   
   double CycleCurrent=GetStochastics(5,shift+1);        
   double CyclePrevious=GetStochastics(5,shift+2);
   
   return (High[0]<Low[0]); 
}