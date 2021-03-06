//+------------------------------------------------------------------+

//|                                                       xea-maCCI-v1.1.mq4 |

//|                                                       xiaoxin003 |
//  (TimeCurrent()-prev_order_time)/60>=5*Period()
//|                                             sljxiaoxin@qq.com |
//  1、3条均线（60-100-200） + CCI指标
//  2、3条均线之上多，之下空。
//  3、之上通过CCI找买点（超卖点），并且价格不能高于100均线x点。
//  4、之下反之。
//  5、价格突破100均线或者穿破200均线（但未突破），趋势多不保，寻机会卖出。
//  6、加仓手数递减原则，分布加仓出仓。
//   bug:均线底买入，止损设置不对
//+------------------------------------------------------------------+
extern string   strVer                    = "xea-maCCI-v1.1";
extern string   strTips1                  = "建议欧元或日元15分钟图，止损15点";
extern string   strTips2                  = "黄金建议止损50点，大止盈";
extern bool     isBuy                     = true;
extern bool     isSell                    = true;
extern int      SL_Pips                   = 150;
extern int      TP_Pips1                  = 2000;
extern int      TP_Pips2                  = 800;
extern int      TP_Pips3                  = 800;
extern int      fastMa                    = 60;
extern int      slowMa                    = 100;
extern int      slowerMa                  = 200;
extern int      maMethod                  = 0;   //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern double   lots1                     = 0.01;
extern double   lots2                     = 0.01;
extern double   lots3                     = 0.01;
extern int      stage3_close_pips         = 400; 
extern int      Max_Open_Orders           = 3;
extern string   strProfitLock_pips        = "赚多少点开始平保";
extern int      profitLock_pips           = 300;
extern string   strIsTrail                = "是否移动止损";
extern bool     isTrail                   = true;
extern int      trailStop_pips            = 200;   //每多少点涨一次
extern int      trailStep_pips            = 100;   //每次涨多少点
extern string   strBreakout_pips          = "突破点数";
extern int      breakout_pips             = 150;   //突破点数
extern int      gap_pips                  = 200;    //三条均线可买间隙点位
extern int      maxMaGap_pips             = 1000;  //100均线和200均线之间间隔最大值默认100点

int      max_spread                = 200;        //点差大于这个数禁止交易
int      PL_pips                   = 30;         //平保位于价格上点数

int      slippage                  = 5;          //最大滑点数

int       Magic_Number   = 20150531;
string    strComment     = "";
string    strTrend       = "no";
double    redrawtime     = 0;
double    preCCI         = 0;
int       stage          = 0; //阶段 用于判定手数
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
   gap_pips        = gap_pips*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips1        = TP_Pips1*sx;
   TP_Pips2        = TP_Pips2*sx;
   TP_Pips3        = TP_Pips3*sx;
   max_spread      = max_spread*sx;
   PL_pips         = PL_pips*sx;
   stage3_close_pips = stage3_close_pips*sx;
   slippage        = slippage*sx;
   maxMaGap_pips   = maxMaGap_pips*sx;
   strTrend = judgeTrend();
}

int start(){
   getTradeInfo();
   if(checkAccountTrade()){
       if(redrawtime != Time[0]){
           strTrend = judgeTrend();
           preCCI = getCCI();
           redrawtime = Time[0];
           double l_fast_ma,l_slow_ma,l_slower_ma;
           l_fast_ma = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
           l_slow_ma = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
           l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
           if(strTrend == "no"){
               close_buy_orders();
               close_sell_orders();
               stage = 0;
           }
           trailStop( strTrend, l_slower_ma);
       }
       
       if(strTrend == "long" && isBuy){
           if(preCCI < -140 && allowBuy(l_fast_ma,l_slow_ma,l_slower_ma) && l_slow_ma-l_slower_ma <maxMaGap_pips*Point){
               //买点，cci小于-140 并且价格不能高于100均线x点，并且均线间隔不能大于100点
               order_buy();
           }
           stage3_buy_close_check();
       }
       if(strTrend == "short" && isSell){
           if(preCCI > 140 && allowSell(l_fast_ma,l_slow_ma,l_slower_ma) && l_slower_ma-l_slow_ma <maxMaGap_pips*Point){
               //卖点
               order_sell();
           }
           stage3_sell_close_check();
       }
   }
   //trailStop();
   Comment(strComment);
   return 0;
}

/////////////////////////////////////////////////////////////
bool allowBuy(double l_fastMa, double l_slowMa, double l_slowerMa){
   if(MathAbs(Ask-l_fastMa)<=gap_pips*Point || MathAbs(Ask-l_slowMa)<=gap_pips*Point || MathAbs(Ask-l_slowerMa)<=gap_pips*Point){
      return true;
   }
   return false;
}
bool allowSell(double l_fastMa, double l_slowMa, double l_slowerMa){
   if(MathAbs(Bid-l_fastMa)<=gap_pips*Point || MathAbs(Bid-l_slowMa)<=gap_pips*Point || MathAbs(Bid-l_slowerMa)<=gap_pips*Point){
      return true;
   }
   return false;
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

void stage3_buy_close_check(){
   if(iCCI(Symbol(),0,14,PRICE_TYPICAL,0) >= 140){
      int tries=0,oper_max_tries=30;
      bool OrderDeleted = false;
      int ot = OrdersTotal();
      for(int j=0;j<ot;j++)
      {
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number && OrderComment() == "stage3_buy")
         {   
             int ticket = OrderTicket();
             double l_openPrice = OrderOpenPrice();
             if(Bid - l_openPrice >= stage3_close_pips*Point){
                while(!OrderDeleted && tries<oper_max_tries)
                {
                   OrderDeleted = OrderClose(ticket,OrderLots(),Bid,slippage,Red);
                   tries=tries+1;
                }
             }
         }     
       }
    }
}

void stage3_sell_close_check(){
   if(iCCI(Symbol(),0,14,PRICE_TYPICAL,0) < -140){
      int tries=0,oper_max_tries=30;
      bool OrderDeleted = false;
      int ot = OrdersTotal();
      for(int j=0;j<ot;j++)
      {
         if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES)==false) break;
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==Magic_Number && OrderComment() == "stage3_sell")
         {   
             int ticket = OrderTicket();
             double l_openPrice = OrderOpenPrice();
             if(l_openPrice -Ask >= stage3_close_pips*Point){
                while(!OrderDeleted && tries<oper_max_tries)
                {
                   OrderDeleted = OrderClose(ticket,OrderLots(),Ask,slippage,Yellow);
                   tries=tries+1;
                }
             }
         }     
       }
    }
}

int order_buy(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   if(stage == 0){
       NewOrder = market_buy_order(SL_Pips, TP_Pips1, lots1, "stage1_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=5*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips2, lots2, "stage2_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && (TimeCurrent()-prev_order_time)/60>=3*Period()){
       NewOrder = market_buy_order(SL_Pips, TP_Pips3, lots3, "stage3_buy");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }
   return 0;
}

int order_sell(){
   if(total_orders() >= Max_Open_Orders){
      return 0;
   }
   int NewOrder = 0;
   if(stage == 0){
       NewOrder = market_sell_order(SL_Pips, TP_Pips1, lots1, "stage1_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage == 1 && (TimeCurrent()-prev_order_time)/60>=5*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips2, lots2, "stage2_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }else if(stage >1 && (TimeCurrent()-prev_order_time)/60>=3*Period()){
       NewOrder = market_sell_order(SL_Pips, TP_Pips3, lots3, "stage3_sell");
       if(NewOrder >0){
         stage = stage + 1;
       }
       return NewOrder;
   }
   return 0;
}

int market_buy_order(double sl, double tp, double Lots, string memo)
{
   int NewOrder=0,tries=0,oper_max_tries=30;
   double sl_price=0,tp_price=0;
   if(sl == 0){
	   sl_price = 0;
   }else{
      double l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
      if(l_slower_ma>Bid){
         sl_price = Bid - sl*Point;
      }else{
	      sl_price = NormalizeDouble(l_slower_ma,Digits) - sl*Point;
	   }
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
      double l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
      if(Ask > l_slower_ma){
         sl_price = Ask + sl*Point;
      }else{
	      sl_price = NormalizeDouble(l_slower_ma,Digits) + sl*Point;
	   }
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

string judgeTrend(){
   double l_fast_ma = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
   double l_slow_ma = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
   double l_slower_ma = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
   if(l_fast_ma > l_slower_ma && l_slow_ma > l_slower_ma){
      return "long";
   }else if(l_fast_ma < l_slower_ma && l_slow_ma < l_slower_ma){
      return "short";
   }else{
      return "no";
   }
}

double getCCI(){
   double l_cci = iCCI(Symbol(),0,14,PRICE_TYPICAL,1);
   return l_cci;
}

void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastMa+"|"+slowMa+"|"+slowerMa;
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
    strComment += "\n当前阶段："+stage;
    
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

void trailStop(string strTrend,double l_slower_ma){
   if(isTrail && strTrend != "no"){
      double sl;
      for (int i=0; i<OrdersTotal(); i++) {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {     
            if(OrderMagicNumber() == Magic_Number && OrderSymbol() == Symbol()){
               if(strTrend == "long" && OrderType() == OP_BUY){
                  sl = NormalizeDouble(l_slower_ma,Digits) - SL_Pips*Point;
                  market_modify_order(sl);
               }
               if(strTrend == "short" && OrderType() == OP_SELL){
                  sl = NormalizeDouble(l_slower_ma,Digits) + SL_Pips*Point;
                  market_modify_order(sl);
               }
            }
         }
      }
   }
}
bool market_modify_order(double sl)
{
   bool NewOrder = false;
   int tries=0,oper_max_tries=30;
   while(!NewOrder && tries< oper_max_tries)
   {
      Print("-------------modify sl:"+sl);
      RefreshRates();
      NewOrder = OrderModify(OrderTicket(),OrderOpenPrice(),sl, OrderTakeProfit(), 0);            
      tries = tries+1;
   }
   Print("-------------sell result:"+NewOrder);
   return(NewOrder);
}