//+------------------------------------------------------------------+

//|                                                             元宝2|
//+------------------------------------------------------------------+

extern string   strVer            = "元宝3";
extern int      Magic_Number      = 20160216;
extern int      Magic_Number_Lock = 2016021601;
extern int      fastMa            = 89;
extern int      slowMa            = 120;
extern int      slowerMa          = 200;
extern int      SL_Pips           = 0;
extern int      TP_Pips           = 0;
extern double   lots                   = 0.01;
extern int      Max_Open_Orders        = 20;
extern int      maMethod               = 0;      //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern string   strMemo1               = "fastMa上下多少点可以开反向单";   
extern int      fastMa_distence_Pips   = 0;
extern int      lock_ticket_buy   = 0;//买锁单单号，中断后可用作初始化
extern int      lock_ticket_sell  = 0;//卖锁单单号，中断后可用作初始化

string          tradeType         = "none";      //buy sell none
string          strComment        = "";
datetime        prev_order_time_buy   = 1262278861;
datetime        prev_order_time_sell  = 1262278861;
datetime        prev_zigzag_time   = 1262278861;
int             max_spread        = 300; 
double          ma1,ma2,ma3,fast_ma1,slow_ma1,slower_ma1;
datetime        prev_open_time    = 0;
int             stage             = 0;
int             intZhuziNums      = 0;
int slippage       = 5;          //最大滑点数
int sx  = 1;
int weekFrame = PERIOD_W1;       //1周的分钟数
int dayFrame  = PERIOD_D1;        //1day
double dayFrame_openTime = 0;
double last_buy_price=0;
double last_sell_price=0;

double last_nishi_buy_price = 999999;
double last_nishi_sell_price = 0;

double arrZigzagHigh[]; //高点数组
double arrZigzagLow[];  //低点数组 
int ExtDepth = 6;
int ExtDeviation = 5;
int ExtBackstep = 3;
int zg_Bars = 150;
double ZigzagBuffer[];
double HighMapBuffer[];
double LowMapBuffer[];
double onlyBuyArea,onlySellArea;  //buy之下只能买，sell之上只能卖
double A,B,C,D,E,F;
string zigzagTrendType;
double Spread;
double max_open_order_buy,max_open_order_sell;
int firstNum,firstTPSize;
int init(){
   Spread = NormalizeDouble(MarketInfo(Symbol(), MODE_SPREAD),Digits)*Point;
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   if(fastMa_distence_Pips != 0){
      fastMa_distence_Pips    = fastMa_distence_Pips*sx;
   }
   if(TP_Pips != 0){
      TP_Pips         = TP_Pips*sx;
   }
   max_spread      = max_spread*sx;
   SL_Pips         = SL_Pips*sx;
   
   ArrayResize(HighMapBuffer,zg_Bars);
   ArrayResize(LowMapBuffer,zg_Bars);
   ArrayInitialize(HighMapBuffer,0.0);
   ArrayInitialize(LowMapBuffer,0.0);
   max_open_order_buy = Max_Open_Orders*0.5;
   max_open_order_sell = Max_Open_Orders*0.5;
   if(Period() == PERIOD_M5){
      intZhuziNums = 30;
      if(fastMa_distence_Pips == 0){
         fastMa_distence_Pips = 300*sx;
      }
      if(TP_Pips == 0){
         TP_Pips         = 400*sx;
      }
      dayFrame = PERIOD_M30;
      firstNum = 15;
      firstTPSize = 3;
   }else if(Period() == PERIOD_M15){
      intZhuziNums = 12;
      if(fastMa_distence_Pips == 0){
         fastMa_distence_Pips = 600*sx;
      }
      if(TP_Pips == 0){
         TP_Pips         = 500*sx;
      }
      dayFrame = PERIOD_H4;
      firstNum = 10;
      firstTPSize = 3;
   }else if(Period() == PERIOD_M30){
      intZhuziNums = 6;
      if(fastMa_distence_Pips == 0){
         fastMa_distence_Pips = 600*sx;
      }
      if(TP_Pips == 0){
         TP_Pips         = 600*sx;
      }
      dayFrame = PERIOD_D1;
      firstNum = 7;
      firstTPSize = 2;
   }else if(Period() == PERIOD_H1){
      intZhuziNums = 4;
      if(fastMa_distence_Pips == 0){
         fastMa_distence_Pips = 3000*sx;
      }
      if(TP_Pips == 0){
         TP_Pips         = 2500*sx;
      }
      dayFrame = PERIOD_D1;
      firstNum = 3;
      firstTPSize = 2;
   }else{
      intZhuziNums = 5;
      if(fastMa_distence_Pips == 0){
         fastMa_distence_Pips = 1000*sx;
      }
      if(TP_Pips == 0){
         TP_Pips         = 800*sx;
      }
      firstNum = 3;
      firstTPSize = 1;
   }
   Print("间隔柱子数量："+intZhuziNums);
   Print("逆势开单点数："+fastMa_distence_Pips);
   Print("止盈点数："+TP_Pips);
   return 0;
}

int start(){
   //一周获取一次zigzag
   if(dayFrame_openTime != iTime(NULL,dayFrame,0)){
      dayFrame_openTime = iTime(NULL,dayFrame,0);
      getZigzag(); //获取高低点
   }
   getZigzagArea();
   if(prev_open_time != Time[0]){
      prev_open_time = Time[0];
      fast_ma1   = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
      slow_ma1   = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
      slower_ma1 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
      ma1 = slower_ma1;
      //ma2 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,2);
      //ma3 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,3);
      if(first_buy_check()){
         if(tradeType == "none"){
            stage = 1;
         }
         if(tradeType == "sell"){
            close_sell_Profit_orders();
            stage = 1;
            last_nishi_buy_price = 999999;
            last_nishi_sell_price = 0;
            //sell转buy
            //关闭sell锁单
            if(lock_ticket_sell != 0){
               close_order_byticket("sell",lock_ticket_sell);
            }
            //开启buy锁单
            open_buy_order_lock();
            
            
         }
         tradeType = "buy";
      }
      if(first_sell_check()){
         if(tradeType == "none"){
            stage = 1;
         }
         if(tradeType == "buy"){
            close_buy_Profit_orders();
            stage = 1;
            last_nishi_buy_price = 999999;
            last_nishi_sell_price = 0;
            if(lock_ticket_buy != 0){
               close_order_byticket("buy",lock_ticket_buy);
            }
            open_sell_order_lock();
         }
         tradeType = "sell";
      }
      stage += 1;
   }
   
   tradeRun();
   ///////////////////////////////////////////////////
   
   getTradeInfo();
   Comment(strComment);
   return 0;
}

void tradeRun(){
   if(tradeType == "buy"){
      if(nishi_sell_check()){
         order_sell("nishi");
      }else if(SR_buy_check()){
         order_buy("SR");
      }
   }
   if(tradeType == "sell"){
      if(nishi_buy_check()){
         order_buy("nishi");
      }else if(SR_sell_check()){
         order_sell("SR");
      }
   }
   //zigzag_buy_check();
   //zigzag_sell_check();
   
}

bool first_buy_check(){
  
   double tmpMa;
   for(int i=1;i<firstNum;i++){
      tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      if(Close[i] - tmpMa<0){
         return false;
      }
   }
   return true;
}
bool first_sell_check(){
   double tmpMa;
   for(int i=1;i<firstNum;i++){
      tmpMa = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,i);
      if(tmpMa - Close[i]<0){
         return false;
      }
   }
   return true;
}
bool zigzag_sell_check(){
   
   if((TimeCurrent()-prev_zigzag_time)/60<intZhuziNums*3*Period()){
      return false;
   }
   if(total_orders_sell() >= max_open_order_sell){
      return false;
   }
   if(A -Ask >0 && A -Ask <30*sx*Point && High[0]<=A && Close[1]<A && Close[2]<A){
      //zigzag_sell(D);
      return true;
   }else if(B>A && B-Ask >0 && B-Ask <30*sx*Point && High[0]<=B && Close[1]<B && Close[2]<B){
      zigzag_sell(E);
      return true;
   }else if(C>B && C>A && C-Ask >0 && C-Ask <30*sx*Point && High[0]<=C && Close[1]<C && Close[2]<C){
      zigzag_sell(F);
      return true;
   }
   return false;

}

bool zigzag_buy_check(){
   
   if((TimeCurrent()-prev_zigzag_time)/60<intZhuziNums*3*Period()){
      return false;
   }
   if(total_orders_buy() >= max_open_order_buy){
      return false;
   }
   if(Bid - D >0 && Bid - D <30*sx*Point && Low[0]>=D && Close[1]>D && Close[2]>D){
      //zigzag_buy(A);
      return true;
   }else if(E<D && Bid - E >0 && Bid - E <30*sx*Point && Low[0]>=E && Close[1]>E && Close[2]>E){
      zigzag_buy(B);
      return true;
   }else if(F<E && F<D && Bid - F >0 && Bid - F <30*sx*Point && Low[0]>=F && Close[1]>F && Close[2]>F){
      zigzag_buy(C);
      return true;
   }
   return false;

}

void zigzag_buy(double val){
   double realLots = getLots();
   double v = NormalizeDouble(val,Digits);
   string memo = "ZigzagBuy-"+val;
   v = (v - Ask)/Point*0.6;
   v = NormalizeDouble(v,0);
   //v = v-50*sx*Point;
   memo += "@"+v;
   int orderNo = market_buy_order(0, v, realLots, memo);
   if(orderNo >0){
      prev_zigzag_time = TimeCurrent();
   }
}

void zigzag_sell(double val){
   double realLots = getLots();
   double v = NormalizeDouble(val,Digits);
   string memo = "ZigzagSell-"+v;
   v = (Bid -v)/Point*0.6;
   v = NormalizeDouble(v,0);
   //v = v+50*sx*Point;
   memo += "@"+v;
   int orderNo = market_sell_order(0, v, realLots, memo);
   if(orderNo >0){
      prev_zigzag_time = TimeCurrent();
   }
}

int market_buy_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
   if(!checkAccountTrade()){return 0;}
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
      last_buy_price = Ask;
      if(memo == "nishi"){
         last_nishi_buy_price = Ask;
      }
      prev_order_time_buy = TimeCurrent();
   }
   return(NewOrder);
}

int market_sell_order(double sl, double tp, double Lots, string memo)
{
   if(AccountLeverage()<400){return 0;}
   if(!checkAccountTrade()){return 0;}
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
      if(memo == "nishi"){
         last_nishi_sell_price = Bid;
      }
      last_sell_price = Bid;
      prev_order_time_sell = TimeCurrent();
   }
   return(NewOrder);
}

int order_buy(string type){
   if(MathAbs(Ask-last_buy_price) < 250*sx*Point){
      //防止磨线
      return 0;
   }
   int NewOrder = 0;
   double realLots = getLots();
   int realTP = TP_Pips;
   if(type == "nishi"){
      realTP = getNishi_TP_Pips();
   }
   if(type == "SR"){
      realTP = getSR_TP_Pips();
   }
   NewOrder = market_buy_order(SL_Pips, realTP, realLots, type);
   if(NewOrder >0){
      return NewOrder;
   }
   return 0;
}

int order_sell(string type){
   if(MathAbs(Bid-last_sell_price) < 250*sx*Point){
      //防止磨线
      return 0;
   }
   int NewOrder = 0;
   double realLots = getLots();
   int realTP = TP_Pips;
   if(type == "nishi"){
      realTP = getNishi_TP_Pips();
      
   }
   if(type == "SR"){
      realTP = getSR_TP_Pips();
   }
   NewOrder = market_sell_order(SL_Pips, realTP, realLots, type);
   if(NewOrder >0){
       return NewOrder;
   }
   return 0;
}


//逆势加单检测
bool nishi_buy_check(){

   if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders_buy() >= max_open_order_buy){
      //Print("--已开单最大值");
      return false;
   }
   if(last_nishi_buy_price - Ask<250*sx*Point){
      return false;
   }
   if(Ask>Low[0] && fast_ma1<slower_ma1 && slow_ma1<slower_ma1 && fast_ma1-Bid>fastMa_distence_Pips*Point){
      //Print("--逆势buy_check is true!!");
      return true;
   }
   return false;

}

bool nishi_sell_check(){

   if((TimeCurrent()-prev_order_time_sell)/60<intZhuziNums*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders_sell() >= max_open_order_sell){
      //Print("--已开单最大值");
      return false;
   }
   if(Bid - last_nishi_sell_price<250*sx*Point){
      return false;
   }
   if(High[0]>Ask && fast_ma1>slower_ma1 && slow_ma1>slower_ma1 && Ask - fast_ma1>fastMa_distence_Pips*Point){
      //Print("--逆势sell_check is true!!");
      return true;
   }
   return false;
   
}

bool SR_buy_check(){
   
   if(total_orders_buy() >= max_open_order_buy){
      //Print("--已开单最大值");
      return false;
   }
   if(zigzagTrendType == "sell"){
      return false;
   }
   if(Ask - slower_ma1 >0 && Ask-slower_ma1<100*sx*Point){
      if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
         //Print("--距离上次不足8根");
         return false;
      }
      return true;
   }
   if(Ask - slow_ma1 >0 && Ask - slow_ma1<100*sx*Point){
      if((TimeCurrent()-prev_order_time_buy)/60<intZhuziNums*Period()){
         //Print("--距离上次不足20根");
         return false;
      }
      return true;
   }
   return false;
}

bool SR_sell_check(){
   if(total_orders_sell() >= max_open_order_sell){
      //Print("--已开单最大值");
      return false;
   }
   if(zigzagTrendType == "buy"){
      return false;
   }
   if(slower_ma1 - Ask >0 && slower_ma1 - Ask<100*sx*Point){
      if((TimeCurrent()-prev_order_time_sell)/60<intZhuziNums*Period()){
         //Print("--距离上次不足8根");
         return false;
      }
      return true;
   }
   if(slow_ma1 - Ask >0 && slow_ma1 - Ask<100*sx*Point){
      if((TimeCurrent()-prev_order_time_sell)/60<intZhuziNums*Period()){
         //Print("--距离上次不足20根");
         return false;
      }
      return true;
   }
   return false;
}

void close_Profit_orders(){
   close_buy_Profit_orders();
   close_sell_Profit_orders();
}
void close_buy_Profit_orders()
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
         if(OrderType()==OP_BUY && OrderProfit()>0)   
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
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Bid,Spread,Red);
          tries=tries+1;
          Print("------close all buy:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

void close_sell_Profit_orders()
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
         if(OrderType()==OP_SELL && OrderProfit()>0)   
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
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Ask,Spread,Red);
          tries=tries+1;
          Print("------close all sell:ticket="+ord_arr[j]+";result:"+OrderDeleted);
       }
    }
}

void close_order_byticket(string bs_type, int ticket){
   int tries=0,oper_max_tries=30;
   bool OrderDeleted = false;
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)){
       double b_lots = OrderLots();
       while(!OrderDeleted && tries<oper_max_tries)
       {
          if(bs_type == "buy"){
            OrderDeleted=OrderClose(ticket,b_lots,Bid,Spread,Red);
          }
          if(bs_type == "sell"){
            OrderDeleted=OrderClose(ticket,b_lots,Ask,Spread,Red);
          }
          tries=tries+1;
       }
   }
}


double getLots(){
   if(lots != 0){
      return lots;
   }
   double equity = AccountEquity();
   if(equity <= 1000){
      return 0.01;
   }else if(equity > 1000 && equity <= 2000){
      return 0.02;
   }else if(equity > 2000 && equity <= 3000){
      return 0.03;
   }else if(equity > 3000 && equity <= 4000){
      return 0.04;
   }else if(equity > 4000 && equity <= 5000){
      return 0.05;
   }else if(equity > 5000 && equity <= 6000){
      return 0.06;
   }else if(equity > 6000 && equity <= 7000){
      return 0.07;
   }else if(equity > 7000 && equity <= 8000){
      return 0.08;
   }else if(equity > 9000 && equity <= 10000){
      return 0.09;
   }else if(equity > 10000){
      return 0.1;
   }
}

int total_orders()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber() == Magic_Number && OrderSymbol()==Symbol())
      {
         if(OrderType() == OP_BUY){
            tot_orders = tot_orders + 1;
         }else if(OrderType() == OP_SELL){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}

int total_orders_buy()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber() == Magic_Number && OrderSymbol()==Symbol())
      {
         if(OrderType() == OP_BUY){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}

int total_orders_sell()
{ 
   int tot_orders = 0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber() == Magic_Number && OrderSymbol()==Symbol())
      {
         if(OrderType() == OP_SELL){
            tot_orders = tot_orders + 1;
         }
         
      }
   }
   return(tot_orders);
}
void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastMa+"|"+slowMa+"|"+slowerMa;
    //strComment += "\n买入价："+Bid;
    //strComment += "\n卖出价："+Ask;
    strComment += "\n交易方向："+tradeType;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    //strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    //strComment += "\n点差："+getAsk_Bid()/Point;
    //strComment += "\n今天周几："+DayOfWeek();
    //strComment += "\n当前时间："+Hour()+":"+Minute();
    strComment += "\n当前阶段："+stage;
    strComment += "\n当前zigzagTrendType："+zigzagTrendType;
    
}


//点差检测
double getAsk_Bid(){
   return (Ask - Bid);
}

//检测账户开单条件
bool checkAccountTrade(){
   if(AccountEquity() <=40 || AccountFreeMargin()<=30 || getAsk_Bid() > max_spread*Point){
	strComment += "\n账户净值或保证金不足 || 点差>"+max_spread+"，风险过大！";
	   return false;
   }else{
	   return true;
   }
}

/////////////////////////////////////////////////////////zigzag/////////////////////////////

void getZigzag(){
   int limit;
   int shift,back;
   double val,res;
   double lasthigh,lastlow;
   //string var1;
   limit = zg_Bars - ExtDepth;
   for(shift=limit; shift>=4; shift--)
   {
      val=iLow(NULL,dayFrame,iLowest(NULL,dayFrame,MODE_LOW,ExtDepth,shift));
      if(val==lastlow) val=0.0;
      else 
        { 
         lastlow=val; 
         if((iLow(NULL,dayFrame,shift)-val)>(ExtDeviation*Point)) val=0.0;
         else
           {
            for(back=1; back<=ExtBackstep; back++)
              {
               res=LowMapBuffer[shift+back];
               if((res!=0)&&(res>val)) LowMapBuffer[shift+back]=0.0; 
              }
           }
        } 
      if (iLow(NULL,dayFrame,shift)==val) LowMapBuffer[shift]=val; else LowMapBuffer[shift]=0.0;
      //--- high
      val=iHigh(NULL,dayFrame,iHighest(NULL,dayFrame,MODE_HIGH,ExtDepth,shift));
      if(val==lasthigh) val=0.0;
      else 
        {
         lasthigh=val;
         if((val-iHigh(NULL,dayFrame,shift))>(ExtDeviation*Point)) val=0.0;
         else
           {
            for(back=1; back<=ExtBackstep; back++)
              {
               res=HighMapBuffer[shift+back];
               if((res!=0)&&(res<val)) HighMapBuffer[shift+back]=0.0; 
              } 
           }
        }
      if (iHigh(NULL,dayFrame,shift)==val) HighMapBuffer[shift]=val; else HighMapBuffer[shift]=0.0;
   }
   //整理为高低点相隔的顺序，去除例如高点高点低点的顺序
   int gd = 0; //1高2低
   double gd_val = 0.0;
   int gd_idx = 0;
   int g_count = 0; //高点个数
   int d_count = 0; //低点个数
   for(int i=limit;i>=4;i--){
         //高低点整理
       if(LowMapBuffer[i] >0){
          if(gd == 0 || gd ==1){
             d_count += 1; 
             gd = 2;
             gd_idx = i;
             gd_val = LowMapBuffer[i];
          }
          else if(gd == 2){
             if(LowMapBuffer[i]<=gd_val){
               LowMapBuffer[gd_idx] = 0.0;
               gd_idx = i;
               gd_val = LowMapBuffer[i];
             }
             if(LowMapBuffer[i]>gd_val){
               LowMapBuffer[i] = 0.0;
             }
             
          }
       }
       if(HighMapBuffer[i] >0){
          if(gd == 0 || gd ==2){
             g_count += 1;
             gd = 1;
             gd_idx = i;
             gd_val = HighMapBuffer[i];
          }
          else if(gd == 1){
             if(HighMapBuffer[i]>=gd_val){
               HighMapBuffer[gd_idx] = 0.0;
               gd_idx = i;
               gd_val = HighMapBuffer[i];
             }
             if(HighMapBuffer[i]<gd_val){
               HighMapBuffer[i] = 0.0;
             }
             
          }
       }
   }
   setZigzagText(limit);
   int g_fori = 0;
   int d_fori = 0;
   ArrayResize(arrZigzagHigh, g_count);
   ArrayResize(arrZigzagLow, d_count);
   //ArrayResize(g_dataIndex,g_count);
   //ArrayResize(d_dataIndex,d_count);
   for(i=0;i<=limit;i++){
      if(LowMapBuffer[i] >0){
         arrZigzagLow[d_fori] = LowMapBuffer[i];
         //d_dataIndex[d_fori] = i;
         d_fori++;
      }
      if(HighMapBuffer[i]>0){
         arrZigzagHigh[g_fori] = HighMapBuffer[i];
         //g_dataIndex[g_fori] = i;
         g_fori++;
      }
   }
   //setZigzagLine();
   
}

//画线
void setZigzagText(int limit){
     //删除文本
     ObjectsDeleteAll(0, OBJ_TEXT);
     for(int mm=limit;mm>=4;mm--){
        if(LowMapBuffer[mm] >0){
            ObjectCreate("text_object"+mm, OBJ_TEXT, 0, iTime(NULL,dayFrame,mm), iLow(NULL,dayFrame,mm));
            ObjectSetText("text_object"+mm, "低点", 10, "Times New Roman", Red);
        }
        if(HighMapBuffer[mm] >0){
            //var1=TimeToStr(Time[i],TIME_DATE|TIME_SECONDS);
            //Print("High time = "+var1+"; index = "+i+" ; value = "+HighMapBuffer[i]);
            ObjectCreate("text_object"+mm, OBJ_TEXT, 0, iTime(NULL,dayFrame,mm), iHigh(NULL,dayFrame,mm)+50*Point*sx);
            ObjectSetText("text_object"+mm, "高点", 10, "Times New Roman", White);
        }
     }
}


void getZigzagArea(){
   A = arrZigzagHigh[0];
   B = arrZigzagHigh[1];
   C = arrZigzagHigh[2];
   D = arrZigzagLow[0];
   E = arrZigzagLow[1];
   F = arrZigzagLow[2];
   onlyBuyArea = 0;
   onlySellArea = 0;
   zigzagTrendType = "none";   //可以buy or sell
  /*
   if(Ask >= D && Ask <= A){
      onlySellArea = A - (A-D)*0.15;
      onlyBuyArea = D + (A-D)*0.15;
   }else if(Ask >= E && Ask <= B){
      onlySellArea = B - (B-E)*0.15;
      onlyBuyArea = E + (B-E)*0.15;
   }else if(Ask >= F && Ask <= C){
      onlySellArea = C - (C-F)*0.15;
      onlyBuyArea = F + (C-F)*0.15;
   }
   if(onlySellArea >0 && Ask >=onlySellArea){
      zigzagTrendType = "sell";
   }else if(onlyBuyArea >0  && Ask <= onlyBuyArea){
      zigzagTrendType = "buy";
   }
   */
}

int getNishi_TP_Pips(){
   if(stage <= 100){
      return TP_Pips*0.8;
   }else if(stage > 100 && stage <= 200){
      return TP_Pips;
   }else if(stage > 200 && stage <= 300){
      return TP_Pips*1.2;
   }else if(stage > 300 && stage <= 400){
      return TP_Pips*1.5;
   }else if(stage > 400 && stage <= 500){
      return TP_Pips*2;
   }else if(stage > 500){
      return TP_Pips*2.5;
   }else{
      return TP_Pips;
   }
   
}

int getSR_TP_Pips(){
   if(stage <= 30){
      return TP_Pips*3;
   }else if(stage > 30 && stage <= 150){
      return TP_Pips*2;
   }else if(stage > 150 && stage <= 250){
      return TP_Pips*1.5;
   }else if(stage > 250 && stage <= 400){
      return TP_Pips*1;
   }else if(stage > 400 && stage <= 500){
      return TP_Pips*1.2;
   }else if(stage > 500){
      return TP_Pips*1.5;
   }else{
      return TP_Pips;
   }
}

void open_buy_order_lock(){
   double all_lots = 0;
   for (int i = 0; i < OrdersTotal(); i++){
       if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic_Number){
              if (OrderType() == OP_SELL){
                 all_lots += OrderLots();
              }
            }
       }
   }
   if(all_lots > 0){
       int NewOrder=0,tries=0,oper_max_tries=30;
       while(NewOrder<=0 && tries< oper_max_tries)
       {
          NewOrder = OrderSend(Symbol(), OP_BUY, all_lots, Ask, slippage, 0,0, "buy_lock",Magic_Number_Lock,0,Blue);            
          tries = tries+1;
       }
       if(NewOrder >0){
           lock_ticket_buy = NewOrder;
       }
   }
}

void open_sell_order_lock(){
   double all_lots = 0;
   for (int i = 0; i < OrdersTotal(); i++){
       if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic_Number){
              if (OrderType() == OP_BUY){
                 all_lots += OrderLots();
              }
            }
       }
   }
   if(all_lots > 0){
       int NewOrder=0,tries=0,oper_max_tries=30;
       while(NewOrder<=0 && tries< oper_max_tries)
       {
          NewOrder = OrderSend(Symbol(), OP_SELL, all_lots, Bid, slippage, 0,0, "sell_lock",Magic_Number_Lock,0,White);            
          tries = tries+1;
       }
       if(NewOrder >0){
           lock_ticket_sell = NewOrder;
       }
   }
}