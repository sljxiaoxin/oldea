//+------------------------------------------------------------------+

//|                                                       xea-maCross.mq4 |

//|                                                       xiaoxin003 |
//  (TimeCurrent()-prev_order_time)/60>=5*Period()
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
extern string   strVer                    = "xea-maCross";
extern int      Fast_MA_Period            = 60;    
extern int      Slow_MA_Period            = 100;       
extern int      MA_Method                 = 0; //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int      _SL_Pips                  = 0;
extern int      _TP_Pips                  = 1000;
extern double   Lots                      = 0.01;
extern int      Max_Open_Orders           = 3;
extern string   strMin_Distance_pips      = "加仓间隔点数";
extern int      _Min_Distance_pips        = 200;
extern string   strProfitLock_pips        = "赚多少点开始平保";
extern int      _profitLock_pips          = 300;
extern string   strisTrailStop            = "是否移动止损";
extern bool     isTrailStop               = false;
extern int      _TrailStop_pips           = 200;
extern int      _TrailStep_pips           = 100;
extern string   strentry_pips             = "提前入场点数默认4点";
extern int      _entry_pips               = 40;
extern string   strbreakout_pips          = "突破点数";
extern int      _breakout_pips            = 100;

extern bool     isBuy                     = false;
extern bool     isSell                    = false;

int            _max_spread                = 200;        //点差大于这个数禁止交易
int            _PL_pips                   = 30;         //平保位于价格上点数


int Magic_Number  = 20150429;
double redrawtime = 0;
int sx;   //倍数
string strComment = "";
int    NewOrder   =0;
int    oper_max_tries = 20,tries=0;
double sl_price=0,tp_price=0;
bool OrderSelected=false,OrderDeleted=false;
datetime prev_order_time=1262278861;

double fast_ma=0,slow_ma=0,prev_fast_ma=0,prev_slow_ma=0;
int ord_arr[20];
double prev_order_price=0;

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
int _gap_pips = 300;  //交叉时，汇价-均线价格不能大于30点
int gap_pips;
bool isInited = false;
void myInit(){
   sx = 1;
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
   gap_pips          = _gap_pips*sx;
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+Fast_MA_Period+"|"+Slow_MA_Period;
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

void close_sell_orders()
{ 
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
        Print("-------------close:----"+ord_arr[j]);
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

void doit(){
    int ttOrders   = total_orders();
    
    if(redrawtime == Time[0]){
        
    }else{
       fast_ma        = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,1);
       slow_ma        = iMA(Symbol(),0,Slow_MA_Period,0,MA_Method,PRICE_CLOSE,1);
       prev_fast_ma   = iMA(Symbol(),0,Fast_MA_Period,0,MA_Method,PRICE_CLOSE,2);
       prev_slow_ma   = iMA(Symbol(),0,Slow_MA_Period,0,MA_Method,PRICE_CLOSE,2);
       if(prev_fast_ma < prev_slow_ma && fast_ma>slow_ma && ttOrders<Max_Open_Orders){
           //buy
           close_sell_orders();
           if(Ask - fast_ma < gap_pips*Point){
               market_buy_order("macross buy");
           }
       }
       if(prev_fast_ma > prev_slow_ma && fast_ma < slow_ma && ttOrders<Max_Open_Orders){
           //sell
           close_buy_orders();
           if(fast_ma - Bid < gap_pips*Point){
              market_sell_order("macross sell");
           }
       }
       redrawtime = Time[0];
    }
}

int start(){
   getTradeInfo();
   if(!isInited){
	myInit();
	isInited = true;
   }
   if(checkAccountTrade()){
      doit();  //主要交易
   }
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