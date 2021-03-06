//+------------------------------------------------------------------+

//|                                               xea-MA-mtframe.mq4 |
   //1、顺大周期，逆小周期寻找开仓点
   //2、一小时均线上下40点内才允许开单，防止追高
//+------------------------------------------------------------------+
extern string   strVer            = "xea-MA-mtframe";
extern int Magic_Number           = 20150920;
extern int      SL_Pips           = 0;
extern int      TP_Pips           = 600;
extern int fastFrame_fastMa       = 60;
extern int fastFrame_slowMa       = 120;
extern int fastFrame_slowerMa     = 200;
extern int slowFrame_Ma           = 60;
extern double   lots              = 0;
extern int      Max_Open_Orders   = 5;
extern int      maMethod          = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern int      trigger_pips      = 40;     //触发买卖点
extern int      trend_lasheng_pips  = 120;   //急剧拉升12点，急涨急跌标准值

int fastFrame   = PERIOD_M5;    //5     交易周期
int slowFrame   = PERIOD_H1;    //60    方向周期


string tradeType = "none";      //buy sell none
bool tradeOver   = false;       
double fastFrame_openTime=0,
       slowFrame_openTime=0;
int sx  = 1;
double l_fast_ma,
       l_slow_ma,
       l_slower_ma;

string    strComment     = "";
string    strTrend       = "";
int       max_spread     = 200;        //点差大于这个数禁止交易
int       stage          = 0;          //阶段 用于判定手数
int       slippage       = 5;          //最大滑点数
datetime prev_order_time = 1262278861;
bool    isChanged = false;
double h1_ma1,h1_ma2,h1_ma3;
bool isCanFirst = false;  //趋势发生逆转，可以开始第一单
bool isSuperMgr = false;

int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   trigger_pips    = trigger_pips*sx;
   max_spread      = max_spread*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips         = TP_Pips*sx;
   trend_lasheng_pips = trend_lasheng_pips*sx;
   return 0;
}

int start(){
   
   if(tradeOver || !checkAccountTrade()){return 0;}
   //H1
   if(slowFrame_openTime != iTime(NULL,slowFrame,0)){
      slowFrame_openTime = iTime(NULL,slowFrame,0);
      isSuperMgr = true;
      h1_ma1 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,1);
      h1_ma2 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,2);
      h1_ma3 = iMA(Symbol(),slowFrame,slowFrame_Ma,0,maMethod,PRICE_CLOSE,3);
      if(iClose(NULL,slowFrame,3) - h1_ma3 >=0 && iClose(NULL,slowFrame,2) -h1_ma2>=0 && iLow(NULL,slowFrame,1) -h1_ma1>=0 ){
         if(tradeType == "sell"){
            stage = 0;
            isCanFirst = true;
            //关闭所有卖出单
            close_sell_orders();
         }
         stage+=1;
         if(stage > 10){
            isCanFirst = false;
         }
         tradeType = "buy";
      }
      if(iClose(NULL,slowFrame,3) - h1_ma3 <=0 && iClose(NULL,slowFrame,2) - h1_ma2 <=0 && iHigh(NULL,slowFrame,1) - h1_ma1 <=0 ){
         if(tradeType == "buy"){
            stage = 0;
            isCanFirst = true;
            //关闭所有买单
            close_buy_orders();
         }
         stage+=1;
         if(stage > 10){
            isCanFirst = false;
         }
         tradeType = "sell";
      }
   }
   //M5
   if(fastFrame_openTime != Time[0]){
      fastFrame_openTime = Time[0];
      l_fast_ma = iMA(Symbol(),0,fastFrame_fastMa,0,maMethod,PRICE_CLOSE,1);
      l_slow_ma = iMA(Symbol(),0,fastFrame_slowMa,0,maMethod,PRICE_CLOSE,1);
      l_slower_ma = iMA(Symbol(),0,fastFrame_slowerMa,0,maMethod,PRICE_CLOSE,1);
      string strTrendTmp = strTrend;
      judgeTrend();
      //isChanged = false;
      if(strTrend != strTrendTmp){
         isChanged = true;
      }
      trailStop();
   }
   orderMgr();
   tradeRun();
   
   ///////////////////////////////////////////////////
   
   getTradeInfo();
   Comment(strComment);
   return 0;
}

void first_buy(){
   if(!isCanFirst){
      return;
   }
   if(Ask-h1_ma1>0 && Ask-h1_ma1<=100*sx*Point){
      double realLots = getLots();
      market_buy_order(200*sx, 1200*sx, realLots*2, "FirstBuy");
      isCanFirst = false;
      Print("--趋势第一个买单！");
   } 
}

void first_sell(){
   if(!isCanFirst){
      return;
   }
   if(h1_ma1 - Ask>0 && h1_ma1 - Ask<=100*sx*Point){
      double realLots = getLots();
      market_sell_order(200*sx, 1200*sx, realLots*2, "FirstSell");
      isCanFirst = false;
      Print("--趋势第一个卖单！");
   }
}

void tradeRun(){
   if(tradeType == "buy"){
      first_buy();
      if(strTrend == "short"){
         if(allowBuy()){
            order_buy();  //买
         }
      }
      ///*
      if(strTrend == "long" && isChanged){
         if(total_orders() >= 2){
            isChanged = false;
            return;
         }
         //刚变为long
         if(Bid-l_slower_ma>0 && Bid-l_slower_ma <= trigger_pips*Point && (TimeCurrent()-prev_order_time)/60>=30*Period()){
            Print("--趋势逆转购买");
            order_buy();  //买
            isChanged = false;
         }
      }
      //*/
      if(strTrend == "long"){
         //刚变为long
         if(((Ask-l_slower_ma>0 && Ask-l_slower_ma <= trigger_pips*Point) || (Ask-l_slow_ma>0 && Ask-l_slow_ma <= trigger_pips*Point)) && (TimeCurrent()-prev_order_time)/60>=20*Period() && total_orders()<=1){
            Print("--趋势无开单购买");
            order_buy();  //买
         }
      }
   }
   if(tradeType == "sell"){
      first_sell();
      if(strTrend == "long"){
         if(allowSell()){
            order_sell();  //卖
         }
      }
      ///*
      if(strTrend == "short" && isChanged){
         if(total_orders() >= 2){
            isChanged = false;
            return;
         }
         //刚变为long
         if(l_slower_ma-Ask>0 && l_slower_ma-Ask <= trigger_pips*Point && (TimeCurrent()-prev_order_time)/60>=30*Period()){
            Print("--趋势逆转卖出");
            order_sell();  //买
            isChanged = false;
         }
      }
      //*/
      if(strTrend == "short"){
         //刚变为long
         if(((l_slower_ma-Bid>0 && l_slower_ma-Bid <= trigger_pips*Point) || (l_slow_ma-Bid>0 && l_slow_ma-Bid <= trigger_pips*Point)) && (TimeCurrent()-prev_order_time)/60>=20*Period() && total_orders()<=1){
            Print("--趋势无开单卖出");
            order_sell();
         }
      }
   }
   
}

bool allowBuy(){
   
   if((TimeCurrent()-prev_order_time)/60<20*Period()){
      //Print("--距离上次不足20根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      Print("--已开单最大值");
      return false;
   }
   if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma && l_fast_ma<l_slow_ma){
      //当前价格<fast_ma并且小于一定范围
      if(l_fast_ma - Close[1]> 0){
           if(Open[1]>Close[1] && l_fast_ma-Low[1]>250*sx*Point){
               for(int i=2;i<=5;i++){
                  if(Close[i]>Open[i]){
                     break;
                  }
               }
               if(Open[i-1] - Close[1] >= trend_lasheng_pips*Point){
                  if(Bid - Open[0] >0){
                     return true;
                  }
               }
            }
      }
   }
   if(l_fast_ma<l_slower_ma){
      if(l_fast_ma - Low[1]>300*sx*Point && (Close[1] - Low[1]>=50*sx*Point || Close[1]-Open[1]>0)){
         if(l_fast_ma - Bid >= 250*sx*Point){
            return true;
         }
      }
   }
   return false;

}

bool allowSell(){
   if((TimeCurrent()-prev_order_time)/60<20*Period()){
      //Print("--距离上次不足20根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      Print("--已开单最大值");
      return false;
   }
   if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma && l_fast_ma>l_slow_ma){
       if(Close[1]>Open[1] && High[1] - l_fast_ma>250*sx*Point){
         for(int i=2;i<=5;i++){
            if(Close[i]<Open[i]){
               break;
            }
         }
         if(Close[1] - Open[i-1] >= trend_lasheng_pips*Point){
             if(Open[0] - Ask >0){
               return true;
             }
         }
      }
   }
   if(l_fast_ma>l_slower_ma){
      if(High[1] - l_fast_ma>=300*sx*Point && (High[1] - Close[1]>=50*sx*Point || Close[1]-Open[1]<0)){
         if(Ask - l_fast_ma >= 250*sx*Point){
            return true;
         }
      }
   }
   return false;
}
int order_buy(){
   if(Ask - h1_ma1>400*sx*Point){
      //防止追高
      Print("order_buy:防止追高");
      return 0;
   }
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_buy_order(SL_Pips, TP_Pips, realLots, "buy");
   if(NewOrder >0){
      return NewOrder;
   }
   return 0;
}

int market_buy_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
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
int order_sell(){
   if(h1_ma1 - Ask>400*sx*Point){
      //防止追高
      Print("order_sell:防止追高");
      return 0;
   }
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_sell_order(SL_Pips, TP_Pips, realLots, "sell");
   if(NewOrder >0){
       return NewOrder;
   }
   return 0;
}
int market_sell_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
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

//判断M5-Trend
void judgeTrend(){
   if(strTrend == ""){
      if(Close[1] - l_slower_ma>0){
         strTrend = "long";
      }
      if(Close[1] - l_slower_ma<0){
          strTrend = "short";
      }
   }else{
      if(Close[2]- l_slower_ma>0 && Low[1]-l_slower_ma>=0){
          strTrend = "long";
      }
      if(Close[2]- l_slower_ma<0 && High[1]-l_slower_ma<=0){
          strTrend = "short";
      }
   }
   
   /*
   if(l_fast_ma>l_slower_ma && l_slow_ma>l_slower_ma && l_fast_ma>l_slow_ma){
      strTrend = "long";
   }else if(l_fast_ma<l_slower_ma && l_slow_ma<l_slower_ma && l_fast_ma<l_slow_ma){
      strTrend = "short";
   }else{
      strTrend = "";
   }
   */
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastFrame_fastMa+"|"+fastFrame_slowMa+"|"+fastFrame_slowerMa;
    //strComment += "\n买入价："+Bid;
    //strComment += "\n卖出价："+Ask;
    strComment += "\n交易方向："+tradeType;
    strComment += "\ntrend方向："+strTrend;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前阶段："+stage;
    //strComment += "\n高点前三："+arrZigzagHigh[0]+"|"+arrZigzagHigh[1]+"|"+arrZigzagHigh[2];
    //strComment += "\n低点前三："+arrZigzagLow[0]+"|"+arrZigzagLow[1]+"|"+arrZigzagLow[2];
    
}


//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=10 || AccountFreeMargin()<=5 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	   return false;
   }else{
	   return true;
   }
}

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
          Print("------close all buy:ticket="+ord_arr[j]+";result:"+OrderDeleted);
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
          Print("------close all sell:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

double getLots(){
   if(lots != 0){
      return lots;
   }
   double equity = AccountEquity();
   if(equity <= 150){
      return 0.01;
   }else if(equity > 150 && equity <= 250){
      return 0.02;
   }else if(equity > 250 && equity <= 400){
      return 0.03;
   }else if(equity > 400 && equity <= 600){
      return 0.04;
   }else if(equity > 600 && equity <= 800){
      return 0.05;
   }else if(equity > 800 && equity <= 1200){
      return 0.06;
   }else if(equity > 1200 && equity <= 1600){
      return 0.07;
   }else if(equity > 1600 && equity <= 2000){
      return 0.08;
   }else if(equity > 2000 && equity <= 2600){
      return 0.09;
   }else if(equity > 2600 && equity <= 3200){
      return 0.1;
   }else if(equity > 3200 && equity <= 3800){
      return 0.12;
   }else if(equity > 3800 && equity <= 4400){
      return 0.15;
   }else if(equity > 4400 && equity <= 5000){
      return 0.18;
   }else if(equity > 5000 && equity <= 5800){
      return 0.2;
   }else if(equity > 5800 && equity <= 6800){
      return 0.25;
   }else if(equity > 6800 && equity <= 8000){
      return 0.3;
   }else if(equity > 8000 && equity <= 9000){
      return 0.35;
   }else if(equity > 9000 && equity <= 10000){
      return 0.4;
   }else if(equity > 10000 && equity <= 12000){
      return 0.5;
   }else if(equity > 12000 && equity <= 14000){
      return 0.6;
   }else if(equity > 14000 && equity <= 16000){
      return 0.7;
   }else if(equity > 16000 && equity <= 20000){
      return 0.8;
   }else if(equity > 20000 && equity <= 28000){
      return 0.9;
   }else if(equity > 28000){
      return 1;
   }
}


//移动止损
void trailStop(){
   if(!tradeOver && tradeType != "none"){
      double newSL;
      double openPrice,myStopLoss;
      for (int i=0; i<OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
         if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
            if(OrderComment() == "FirstBuy" || OrderComment() == "BreakBuy"){
		         openPrice = OrderOpenPrice();
		         myStopLoss = OrderStopLoss();
               if(myStopLoss<openPrice && Bid - openPrice > 500*sx*Point){
                  //设置平保
                  newSL = openPrice+50*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstBuy设置平保："+OrderTicket());
               }
               if(Bid - openPrice > 800*sx*Point && myStopLoss>openPrice && myStopLoss-openPrice<200*sx*Point){
                  newSL = openPrice+400*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstBuy设置盈利锁定40："+OrderTicket());
               }
            }
            if(OrderComment() == "FirstSell" || OrderComment() == "BreakSell"){
	            openPrice = OrderOpenPrice();
	            myStopLoss = OrderStopLoss();
               if((myStopLoss>openPrice || myStopLoss ==0) && openPrice-Ask > 500*sx*Point){
                  //设置平保
                  newSL = openPrice - 50*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstSell设置平保："+OrderTicket());
               }
               if(openPrice-Ask > 800*sx*Point && myStopLoss<openPrice && openPrice-myStopLoss<200*sx*Point){
                  newSL = openPrice - 400*sx*Point;
                  OrderModify(OrderTicket(),openPrice,newSL, OrderTakeProfit(), 0);
                  Print("---firstSell设置盈利锁定40："+OrderTicket());
               }
            }
         }
      }
     }
   }
}

void orderMgr(){
   //double realLots;
   if(tradeType == "buy"){
      if(isSuperMgr && h1_ma1-Ask>120*sx*Point && iHigh(NULL,slowFrame,0)-h1_ma1>=180*sx*Point){
         isSuperMgr = false;
         close_buy_orders();
         //realLots = getLots();
         //market_sell_order(400*sx, 800*sx, realLots*2, "BreakSell");  //超级突破后，反向下一单
         Print("---orderMgr:超级突破，止损保护 close buy ");
      }
   }
   if(tradeType == "sell"){
      if(isSuperMgr && Bid - h1_ma1>120*sx*Point && h1_ma1 - iLow(NULL,slowFrame,0)>=180*sx*Point){
         isSuperMgr = false;
         close_sell_orders();
         //realLots = getLots();
         //market_buy_order(400*sx, 800*sx, realLots*2, "BreakBuy");   //超级突破后，反向下一单
         Print("---orderMgr:超级突破，止损保护 close sell ");
      }
   
   }
   
}