//+------------------------------------------------------------------+

//|                                                       yea-ma-crossSR_V2.mq4 |

//|                                                       xiaoxin003 |

//|                                              http://www.mql5.com |
//|  2015-1-29  update to ver V2
//+------------------------------------------------------------------+
extern string   strVer          = "yea-ma-crossRS_V2";
extern int      Fast_MA_Period            = 60;    
extern int      Slow_MA_Period            = 120;    
extern int      Slower_MA_Period          = 200;    
extern int      MA_Method                 = 1; //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int      _SL_Pips        = 0;
extern int      _TP_Pips        = 1000;
extern double   Lots            = 0.01;
extern int      Max_Open_Orders = 3;
extern string   strMin_Distance_pips = "加仓间隔点数";
extern int      _Min_Distance_pips   = 200;
extern string   strProfitLock_pips   = "赚多少点开始平保";
extern int      _profitLock_pips     = 300;
extern string   strisTrailStop       = "是否移动止损";
extern bool     isTrailStop          = true;
extern int      _TrailStop_pips      = 200;
extern int      _TrailStep_pips      = 100;
extern string   strentry_pips        = "提前入场点数默认4点";
extern int      _entry_pips          = 40;
extern string   strbreakout_pips     = "突破点数";
extern int      _breakout_pips       = 100;
extern string   strearlyCloseNum     = "fast_ma反向运行多少柱体close订单，默认7";
extern int      earlyCloseNum        = 7;

int    _max_spread = 200;  //点差大于这个数禁止交易
int    _PL_pips    = 30;   //平保位于价格上点数


int Magic_Number = 19870201;
int sx;
string strComment = "";
int longOrShort = 0;  //0:未出方向，1：buy，2：sell
double longPrice = 0;
double shortPrice = 0;
int    NewOrder=0;
int    oper_max_tries = 20,tries=0;
double sl_price=0,tp_price=0;
bool OrderSelected=false,OrderDeleted=false;
datetime prev_order_time=1262278861;
datetime singleTime = 1262278861;  //#bug 刚交叉时反复fast大于小于slow

double fast_ma=0,slow_ma=0,slower_ma=0,prev_fast_ma=0,prev_slow_ma=0,prev_slower_ma=0;
int ord_arr[20];
double lineKeyPrice[2];
double prev_order_price=0;

bool is_buy_alarming = false;
bool is_sell_alarming = false;
datetime buy_alarm_time=1262278861;
datetime sell_alarm_time=1262278861;

int SL_Pips,
    TP_Pips,
    Min_Distance_pips,
    profitLock_pips,
    TrailStop_pips,
    TrailStep_pips,
    max_spread,
    PL_pips,
    entry_pips,
    breakout_pips;

void myInit(){
   sx = 1;
   //Print("symbol"+Symbol());
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   SL_Pips           = _SL_Pips*sx;
   TP_Pips           = _TP_Pips*sx;
   Min_Distance_pips = _Min_Distance_pips*sx;
   profitLock_pips   = _profitLock_pips*sx;
   TrailStop_pips    = _TrailStop_pips*sx;
   TrailStep_pips    = _TrailStep_pips*sx;
   max_spread        = _max_spread*sx;
   PL_pips           = _PL_pips*sx;
   entry_pips        = _entry_pips*sx;
   breakout_pips     = _breakout_pips*sx;
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+Fast_MA_Period+"|"+Slow_MA_Period+"|"+Slower_MA_Period;
    strComment += "\n买入价："+Bid;
    strComment += "\n卖出价："+Ask;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    
}

int total_orders()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber() == Magic_Number 
         && OrderSymbol()==Symbol()
         && (OrderType()==OP_BUY || OrderType()==OP_SELL)
      )
      {
           tot_orders = tot_orders + 1;
      }
   }
   return(tot_orders);
}

double last_buy_price()
{ 
   double ord_price=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()== Magic_Number 
         && OrderSymbol() == Symbol()
         && OrderType() == OP_BUY
         && OrderOpenPrice() > ord_price
        ) 
        ord_price = OrderOpenPrice();
   }
   
   return(ord_price + Min_Distance_pips*Point);
}

double last_sell_price()
{ 
   double ord_price=999999;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()==Magic_Number 
         && OrderSymbol()==Symbol()
         && OrderType()==OP_SELL
         && OrderOpenPrice()<ord_price
        ){ 
            ord_price = OrderOpenPrice();
	}
   }
   return(ord_price - Min_Distance_pips*Point);
}

int market_buy_order(string memo)
{
   is_buy_alarming = false;
   is_sell_alarming = false;
   NewOrder=0;
   tries=0;
   if(SL_Pips==0){
	sl_price = 0;
   }else{
	sl_price = Bid - SL_Pips*Point;
   }
   if(TP_Pips==0){
	tp_price = 0;
   }else{
	tp_price = Ask + TP_Pips*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      NewOrder=OrderSend(Symbol(),OP_BUY,Lots,Ask,5,sl_price,tp_price,memo,Magic_Number,0,Blue);            
      tries = tries+1;
   }
   if(NewOrder>0){
      OrderSelect(NewOrder, SELECT_BY_TICKET);
      prev_order_time = TimeCurrent();
      prev_order_price = OrderOpenPrice();
   }
   return(NewOrder);
}

int market_sell_order(string memo)
{
   is_buy_alarming = false;
   is_sell_alarming = false;
   NewOrder=0;
   tries=0;
   if(SL_Pips==0){
	sl_price = 0;
   }else{
	sl_price = Ask+SL_Pips*Point;
   }
   if(TP_Pips==0){
	tp_price = 0;
   }else{
	tp_price = Bid-TP_Pips*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      NewOrder = OrderSend(Symbol(),OP_SELL,Lots,Bid,5,sl_price,tp_price,memo,Magic_Number,0,Red);            
      tries = tries+1;
   }
   if(NewOrder>0){
      OrderSelect(NewOrder, SELECT_BY_TICKET);
      prev_order_time = TimeCurrent();
      prev_order_price = OrderOpenPrice();
   }
   return(NewOrder);
}

int last_order_type()
{ 
   int ord_type=-1;
   int tkt_num=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()==Magic_Number 
         && OrderSymbol()==Symbol()
         && OrderTicket()>tkt_num
        ) 
        {
            ord_type = OrderType();
            tkt_num=OrderTicket();
        }
   }
   return(ord_type);
}

void close_sell_orders(string debug)
{ 
   is_buy_alarming = false;
   is_sell_alarming = false;
   int k=-1;
   for(int j=0;j<20;j++) ord_arr[j]=0;
   
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_SELL)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
        Print("-------------close:----"+ord_arr[j]+";debug:"+debug);
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],OrderLots(),Ask,5,Red);
          tries=tries+1;
         
       }
    }
    prev_order_time = 1262278861;
    prev_order_price = 0;
    
}

void close_buy_orders()
{  
   is_buy_alarming = false;
   is_sell_alarming = false;
   int k=-1;
   for(int j=0;j<20;j++) ord_arr[j]=0;
   
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_BUY)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],OrderLots(),Bid,5,Red);
          tries=tries+1;
       }
    }
    prev_order_time=1262278861;
    prev_order_price = 0;
}

bool earlyClose(int type){
   double ma0,ma1;
   bool ret = true;
   for(int i=1;i<=earlyCloseNum;i++){
      ma0 = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,i);
      ma1 = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,i+1);
      if(type == 1){
         //long
	 if(ma0>ma1){
	    ret = false;
	    break;
	 }
      }
      if(type == 2){
         //short
	 if(ma0<ma1){
	    ret = false;
	    break;
	 }
      }
   }
   if(ret)Print("yea:---------------earlyClose is true-----------------");
   return ret;
}

void doit(){
   int ttOrders = total_orders();
   prev_fast_ma   = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,1);
   prev_slow_ma   = iMA(Symbol(),0,Slow_MA_Period,0,MA_Method,PRICE_CLOSE,1);
   prev_slower_ma = iMA(Symbol(),0,Slower_MA_Period,0,MA_Method,PRICE_CLOSE,1);
   fast_ma   = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,0);
   slow_ma   = iMA(Symbol(),0,Slow_MA_Period,0,MA_Method,PRICE_CLOSE,0);
   slower_ma = iMA(Symbol(),0,Slower_MA_Period,0,MA_Method,PRICE_CLOSE,0);

   if(last_order_type()==0 && (TimeCurrent()-singleTime)/60>=2*Period() && (fast_ma<slow_ma || earlyClose(1)) && ttOrders>0) close_buy_orders();
   if(last_order_type()==1 && (TimeCurrent()-singleTime)/60>=2*Period() && (fast_ma>slow_ma || earlyClose(2)) && ttOrders>0) close_sell_orders("1");

   if (fast_ma>slow_ma){
      if(longOrShort !=1){
         longOrShort = 1; //Long
         singleTime = TimeCurrent();
      }
      strComment += "\n当前方向为：long!";
   }
   else 
   {
      if (fast_ma<slow_ma){
         if(longOrShort !=2){
            longOrShort = 2; //short
            singleTime = TimeCurrent();
         }
	      strComment += "\n当前方向为：short!";
      }else{
         if(longOrShort !=0){
            longOrShort = 0; //none
            singleTime = TimeCurrent();
         }
	      strComment += "\n当前方向为：none!";
      }
   }
   //判断是否买卖
   if(longOrShort == 1)
   {  
      if(fast_ma>slow_ma && fast_ma>slower_ma && slow_ma>slower_ma && slower_ma - Ask > breakout_pips*Point && ttOrders>0){
         if(!is_buy_alarming){
	    is_buy_alarming = true;
	    buy_alarm_time = Time[0];
	 }
	 if(slower_ma - Ask > 4*breakout_pips*Point){
	    is_buy_alarming = false;
	    close_buy_orders();
	 }
      }else{
         if(fast_ma>slow_ma && prev_fast_ma<prev_slow_ma && (TimeCurrent()-prev_order_time)/60>=4*Period() && ttOrders<Max_Open_Orders){
            market_buy_order("MA-CROSS-BUY");
            Print("yea:--------------MA-CROSS-BUY-----------------");
         }else{
            if(slow_ma>prev_slow_ma && slower_ma>prev_slower_ma && 
	       fast_ma > slow_ma && fast_ma>slower_ma && slow_ma>slower_ma && !earlyClose(1)){  //趋势向上，并且线条都向上弯曲
               getSRLong();  //支撑阻力买入机会
	    }
         }
      }
      
    }
   if(longOrShort == 2)
   {
      if(fast_ma<slow_ma && fast_ma<slower_ma && slow_ma<slower_ma && Bid - slower_ma > breakout_pips*Point && ttOrders>0){
         if(!is_sell_alarming){
            is_sell_alarming = true;
            sell_alarm_time = Time[0];
         }
         if(Ask - slower_ma > 4*breakout_pips*Point){
            is_sell_alarming = false;
            close_sell_orders("2");
         }
      }else{
         if(fast_ma<slow_ma && prev_fast_ma>prev_slow_ma && (TimeCurrent()-prev_order_time)/60>=4*Period() && ttOrders<Max_Open_Orders)
         {
            market_sell_order("MA-CROSS-SELL");
            Print("yea:--------------MA-CROSS-SELL-----------------");
         }else{
            if(slow_ma<prev_slow_ma && slower_ma<prev_slower_ma && 
	    fast_ma < slow_ma && fast_ma<slower_ma && slow_ma<slower_ma && !earlyClose(2)){ //趋势向下，并且线条都向下弯曲
               getSRShort(); //支撑阻力卖出机会
	         }
         }
      }

   }
}

double getPrevKeyPrice(int index){
   int arr[3];
   arr[0] = Fast_MA_Period;
   arr[1] = Slower_MA_Period;
   double val;
   val = iMA(Symbol(),0, arr[index], 0,MA_Method, PRICE_CLOSE, 1);
   return val;
}
void getMaSRNow(){
   lineKeyPrice[0] =  NormalizeDouble(fast_ma,Digits);
   lineKeyPrice[1] =  NormalizeDouble(slower_ma,Digits);
}
//判断是否到达支撑位置，并买入
void getSRLong(){
   getMaSRNow();
   double prev_key_price;
   if((TimeCurrent()-prev_order_time)/60>=5*Period() && total_orders()<Max_Open_Orders){
      for(int i=0;i<2;i++){
          prev_key_price = getPrevKeyPrice(i);
      	 if(Close[1] > prev_key_price && Low[0] < Bid && Low[0] - lineKeyPrice[i] < entry_pips*Point && Low[0] - lineKeyPrice[i]>(0-entry_pips*Point)){
      	    if(MathAbs(Ask-prev_order_price) > Min_Distance_pips*Point){
      	       market_buy_order("MA-SR-BUY maI:"+i);
      	       Print("yea:---------------------MA-SR-BUY maI:"+i);
      	       break;
      	    }
      	 }
      }
   }
}

void getSRShort(){
   getMaSRNow();
   double prev_key_price;
   if((TimeCurrent()-prev_order_time)/60>=5*Period() && total_orders()<Max_Open_Orders){
      for(int i=0;i<2;i++){
         prev_key_price = getPrevKeyPrice(i);
	 if(Close[1] < prev_key_price && High[0]>Ask && lineKeyPrice[i] - High[0]<entry_pips*Point && lineKeyPrice[i]-High[0]>(0-entry_pips*Point)){
	    if(MathAbs(Ask-prev_order_price) > Min_Distance_pips*Point){
	       market_sell_order("MA-SR-SELL maI:"+i);
	       Print("yea:---------------------MA-SR-SELL maI:"+i);
	       break;
	    }
	 }
      }
   }
}

int start(){
   getTradeInfo();
   myInit();
   if(checkAccountTrade()){
      doit();  //主要交易
   }
   alarm_SL_Action();
   trailStop();
   Comment(strComment);
   return 0;
}

//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=1 || AccountFreeMargin()<=1 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	return false;
   }else{
	return true;
   }
}

void trailStop(){
   if(isTrailStop){
     double x,y,newSL,newSLy;
     double openPrice,myStopLoss;
     for (int i=0; i<OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
            if(OrderType() == OP_BUY){
		         openPrice = OrderOpenPrice();
		         myStopLoss = OrderStopLoss();
               if(myStopLoss<openPrice && Bid - openPrice > profitLock_pips*Point){
                  //设置平保
                  newSL = openPrice+PL_pips*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
               }
               if(Bid - openPrice > TrailStop_pips*Point){
                  //按比例移动止损
                  x = (Bid - openPrice)/(TrailStop_pips*Point);
                  newSL = (openPrice-SL_Pips*Point)+x*TrailStep_pips*Point;
                  if(myStopLoss + TrailStep_pips*Point < newSL){
                     OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  }
               }
            }
            if(OrderType() == OP_SELL){
	            openPrice = OrderOpenPrice();
	            myStopLoss = OrderStopLoss();
               if(myStopLoss>openPrice && openPrice-Ask > profitLock_pips*Point){
                  //设置平保
                  newSL = openPrice - PL_pips*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
               }
               if(openPrice - Ask > TrailStop_pips*Point){
                  y = (openPrice - Ask)/(TrailStop_pips*Point);
                  newSLy = (openPrice+SL_Pips*Point)-y*TrailStep_pips*Point;
                  if(myStopLoss-TrailStep_pips*Point>newSLy){
                     OrderModify(OrderTicket(),openPrice,newSLy, OrderTakeProfit(), 0);
                  }
               }
            }
         }
      }
     }
   }
}

void alarm_SL_Action(){
    if(longOrShort == 1 && is_buy_alarming){
       if((TimeCurrent()-buy_alarm_time)/60>3*Period()){
   	  if(Ask<slower_ma){
   	     is_buy_alarming = false;
   	     Print("yea:alarm close buy orders.......");
   	     close_buy_orders();
   	  }
       }
    }
    if(longOrShort == 2 && is_sell_alarming){
       if((TimeCurrent()-sell_alarm_time)/60>3*Period()){
   	  if(Ask>slower_ma){
   	     is_sell_alarming = false;
   	      Print("yea:alarm close sell orders.......");
   	     close_sell_orders("3");
   	  }
       }
    }
}