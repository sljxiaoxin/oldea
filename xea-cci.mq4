//+------------------------------------------------------------------+

//|                                                       xea-cci.mq4 |

//|                                                       xiaoxin003 |
//  (TimeCurrent()-prev_order_time)/60>=5*Period()
//|                                             sljxiaoxin@qq.com |
//+------------------------------------------------------------------+
extern string   strVer                    = "xea-cci";
extern bool     isBuy                     = true;
extern bool     isSell                    = true;
extern int      SL_Pips                   = 250;
extern int      TP_Pips                   = 600;
extern double   lots                      = 0.01;
extern int      Max_Open_Orders           = 2;
extern string   strProfitLock_pips        = "赚多少点开始平保";
extern int      profitLock_pips           = 300;
extern string   strIsTrail                = "是否移动止损";
extern bool     isTrail                   = true;
extern int      trailStop_pips            = 200;   //每多少点涨一次
extern int      trailStep_pips            = 100;   //每次涨多少点
extern string   strBreakout_pips          = "突破点数";
extern int      breakout_pips             = 150;   //突破点数

int      max_spread                = 200;        //点差大于这个数禁止交易
int      PL_pips                   = 30;         //平保位于价格上点数

int      slippage                  = 5;          //最大滑点数

int       Magic_Number   = 20150617;
string    strComment     = "";
double    preCCI         = 0;
double    redrawtime     = 0;
datetime prev_order_time = 1262278861;

int init(){
   int sx = 1;
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   profitLock_pips = profitLock_pips*sx;
   trailStop_pips  = trailStop_pips*sx;
   trailStep_pips  = trailStep_pips*sx;
   breakout_pips   = breakout_pips*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips         = TP_Pips*sx;
   max_spread      = max_spread*sx;
   PL_pips         = PL_pips*sx;
   slippage        = slippage*sx;
}

int start(){
   getTradeInfo();
   if(checkAccountTrade()){
       if(redrawtime != Time[0]){
           preCCI = getCCI();
           redrawtime = Time[0];
           if(isBuy && preCCI < -200 && (TimeCurrent()-prev_order_time)/60>=6*Period()){
               //买点，cci小于-140 并且价格不能高于100均线x点，并且均线间隔不能大于100点
               close_sell_orders();
               order_buy();
           }
           if(isSell && preCCI > 200 && (TimeCurrent()-prev_order_time)/60>=6*Period()){
               //卖点
               close_buy_orders();
               order_sell();
           }
           trailStop();
       }
   }
   Comment(strComment);
   return 0;
}

/////////////////////////////////////////////////////////////
void close_buy_orders()
{  
   int k=-1;
   int ord_arr[20];
   double ord_arrlots[20];
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   for(int j=0;j<20;j++){
      ord_arr[j]=0;
      ord_arrlots[j] = 0;
   }
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_BUY)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
            ord_arrlots[k]=OrderLots();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Bid,5,Red);
          tries=tries+1;
       }
    }
}

void close_sell_orders()
{  
   int k=-1;
   int ord_arr[20];
   double ord_arrlots[20];
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   for(int j=0;j<20;j++){
      ord_arr[j]=0;
      ord_arrlots[j] = 0;
   }
   int ot = OrdersTotal();
   for(j=0;j<ot;j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number)
      {   
         if(OrderType()==OP_SELL)   
         {  k = k + 1; 
            ord_arr[k]=OrderTicket();
            ord_arrlots[k]=OrderLots();
         }
      }     
    }
    for(j=0;j<=k;j++)
    {  OrderDeleted=false;
       tries=0;
       while(!OrderDeleted && tries<oper_max_tries)
       {
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Ask,5,Red);
          tries=tries+1;
       }
    }
}

int order_buy(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   NewOrder = market_buy_order(SL_Pips, TP_Pips, lots, "cci_buy");
   return NewOrder;
}

int order_sell(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   NewOrder = market_sell_order(SL_Pips, TP_Pips, lots, "cci_sell");
   return NewOrder;
}

int market_buy_order(double sl, double tp, double Lots, string memo)
{
   int NewOrder=0,tries=0,oper_max_tries=30;
   double sl_price=0,tp_price=0;
   if(sl == 0){
	   sl_price = 0;
   }else{
      sl_price = Bid - sl*Point;
   }
   if(tp == 0){
	   tp_price = 0;
   }else{
	   tp_price = Ask + tp*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------buy:----sl:"+sl_price+";tp:"+tp_price);
      //RefreshRates();
      NewOrder = OrderSend(Symbol(),OP_BUY,Lots,Ask,slippage,sl_price,tp_price,memo,Magic_Number,0,Blue);            
      tries = tries+1;
   }
   Print("-------------buy result:"+NewOrder);
   if(NewOrder>0){
      prev_order_time = TimeCurrent();
   }
   return(NewOrder);
}

int market_sell_order(double sl, double tp, double Lots, string memo)
{
   int NewOrder=0,tries=0,oper_max_tries=30;
   double sl_price=0,tp_price=0;
   if(sl == 0){
	   sl_price = 0;
   }else{
      sl_price = Ask + sl*Point;
   }
   if(tp == 0){
	   tp_price = 0;
   }else{
	   tp_price = Bid - tp*Point;
   }
   while(NewOrder<=0 && tries< oper_max_tries)
   {
      Print("-------------sell:----bid:"+Bid+";sl:"+sl_price+";tp:"+tp_price);
      RefreshRates();
      NewOrder = OrderSend(Symbol(),OP_SELL,Lots,Bid,slippage,sl_price,tp_price,memo,Magic_Number,0,White);            
      tries = tries+1;
   }
   Print("-------------sell result:"+NewOrder);
   if(NewOrder>0){
      prev_order_time = TimeCurrent();
   }
   return(NewOrder);
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


double getCCI(){
   double l_cci = iCCI(Symbol(),0,14,PRICE_TYPICAL,1);
   return l_cci;
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n买入价："+Bid;
    strComment += "\n卖出价："+Ask;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前CCI："+preCCI;
    
}


//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=1 || AccountFreeMargin()<=5 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	return false;
   }else{
	return true;
   }
}

void trailStop(){
   if(isTrail){
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
               if(Bid - openPrice > trailStop_pips*Point){
                  //按比例移动止损
                  x = (Bid - openPrice)/(trailStop_pips*Point);
                  newSL = (openPrice-SL_Pips*Point)+x*trailStep_pips*Point;
                  if(myStopLoss + trailStep_pips*Point < newSL){
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
               if(openPrice - Ask > trailStop_pips*Point){
                  y = (openPrice - Ask)/(trailStop_pips*Point);
                  newSLy = (openPrice+SL_Pips*Point)-y*trailStep_pips*Point;
                  if(myStopLoss-trailStep_pips*Point>newSLy){
                     OrderModify(OrderTicket(),openPrice,newSLy, OrderTakeProfit(), 0);
                  }
               }
            }
         }
      }
     }
   }
}