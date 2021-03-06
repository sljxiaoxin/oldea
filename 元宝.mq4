//+------------------------------------------------------------------+

//|                                                             元宝 |
//+------------------------------------------------------------------+

extern string   strVer            = "元宝";
extern int      Magic_Number      = 20151026;
extern int      fastMa            = 89;
extern int      slowMa            = 120;
extern int      slowerMa          = 200;
extern int      SL_Pips           = 0;
extern int      TP_Pips           = 800;
extern double   lots                   = 0.01;
extern int      Max_Open_Orders        = 20;
extern int      maMethod               = 0;      //0:Simple, 1:Exponential, 2:Smoothed, 3:Linear_Wighted
extern string   strMemo1               = "fastMa上下多少点可以开反向单";   
extern int      fastMa_distence_Pips   = 1000; 

string          tradeType         = "none";      //buy sell none
string          strComment        = "";
datetime        prev_order_time   = 1262278861;
int             max_spread        = 300; 
double          ma1,ma2,ma3,fast_ma1,slow_ma1,slower_ma1;
datetime        prev_open_time    = 0;
int             stage             = 0;
int slippage       = 5;          //最大滑点数
int sx  = 1;
int init(){
   if(Symbol() == "XAUUSDm"){
      	sx = 10;
   }
   fastMa_distence_Pips    = fastMa_distence_Pips*sx;
   max_spread      = max_spread*sx;
   SL_Pips         = SL_Pips*sx;
   TP_Pips         = TP_Pips*sx;
   return 0;
}

int start(){
   
   if(prev_open_time != Time[0]){
      prev_open_time = Time[0];
      fast_ma1   = iMA(Symbol(),0,fastMa,0,maMethod,PRICE_CLOSE,1);
      slow_ma1   = iMA(Symbol(),0,slowMa,0,maMethod,PRICE_CLOSE,1);
      slower_ma1 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,1);
      ma1 = slower_ma1;
      ma2 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,2);
      ma3 = iMA(Symbol(),0,slowerMa,0,maMethod,PRICE_CLOSE,3);
      if(Close[3] - ma3 >=0 && Close[2]-ma2>=0 && Low[1]- ma1>=0 ){
         if(tradeType == "none"){
            stage += 1;
            first_buy();
         }
         if(tradeType == "sell"){
            //close_Profit_orders();
            close_sell_Profit_orders();
            stage += 1;
            first_buy();
         }
         tradeType = "buy";
      }
      if(Close[3] - ma3 <=0 && Close[2] - ma2 <=0 && High[1] - ma1 <=0 ){
         if(tradeType == "none"){
            stage += 1;
            first_sell();
         }
         if(tradeType == "buy"){
            //close_Profit_orders();
            close_buy_Profit_orders();
            stage += 1;
            first_sell();
         }
         tradeType = "sell";
      }
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
         order_sell();
      }else if(SR_buy_check()){
         order_buy();
      }
   }
   if(tradeType == "sell"){
      if(nishi_buy_check()){
         order_buy();
      }else if(SR_sell_check()){
         order_sell();
      }
   }
   
}
 
void first_buy(){
   if(Bid-ma1>0 && Bid-ma1<=250*sx*Point){
      double realLots = getLots();
      market_buy_order(0, 3*TP_Pips, realLots, "FirstBuy");
      Print("--趋势第一个买单！");
   } 
}

void first_sell(){
   if(ma1 - Ask>0 && ma1 - Ask<=250*sx*Point){
      double realLots = getLots();
      market_sell_order(0, 3*TP_Pips, realLots, "FirstSell");
      Print("--趋势第一个卖单！");
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
      prev_order_time = TimeCurrent();
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
      prev_order_time = TimeCurrent();
   }
   return(NewOrder);
}

int order_buy(){
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_buy_order(SL_Pips, TP_Pips, realLots, "buy");
   if(NewOrder >0){
      return NewOrder;
   }
   return 0;
}

int order_sell(){
   int NewOrder = 0;
   double realLots = getLots();
   NewOrder = market_sell_order(SL_Pips, TP_Pips, realLots, "sell");
   if(NewOrder >0){
       return NewOrder;
   }
   return 0;
}


//逆势加单检测
bool nishi_buy_check(){
   
   if((TimeCurrent()-prev_order_time)/60<18*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      //Print("--已开单最大值");
      return false;
   }
   if(Ask>Low[0] && fast_ma1<slower_ma1 && slow_ma1<slower_ma1 && fast_ma1-Bid>fastMa_distence_Pips*Point){
      Print("--逆势buy_check is true!!");
      return true;
   }
   return false;

}

bool nishi_sell_check(){
   if((TimeCurrent()-prev_order_time)/60<18*Period()){
      //Print("--距离上次不足5根");
      return false;
   }
   if(total_orders() >= Max_Open_Orders){
      //Print("--已开单最大值");
      return false;
   }
   if(High[0]>Ask && fast_ma1>slower_ma1 && slow_ma1>slower_ma1 && Ask - fast_ma1>fastMa_distence_Pips*Point){
      Print("--逆势sell_check is true!!");
      return true;
   }
   return false;
   
}

bool SR_buy_check(){
   
   if(total_orders() >= Max_Open_Orders){
      //Print("--已开单最大值");
      return false;
   }
   if(Ask - slower_ma1 >0 && Ask-slower_ma1<40*sx*Point){
      if((TimeCurrent()-prev_order_time)/60<20*Period()){
         //Print("--距离上次不足8根");
         return false;
      }
      return true;
   }
   if(Ask - slow_ma1 >0 && Ask - slow_ma1<40*sx*Point){
      if((TimeCurrent()-prev_order_time)/60<30*Period()){
         //Print("--距离上次不足20根");
         return false;
      }
      return true;
   }
   return false;
}

bool SR_sell_check(){
   if(total_orders() >= Max_Open_Orders){
      //Print("--已开单最大值");
      return false;
   }
   if(slower_ma1 - Ask >0 && slower_ma1 - Ask<40*sx*Point){
      if((TimeCurrent()-prev_order_time)/60<20*Period()){
         //Print("--距离上次不足8根");
         return false;
      }
      return true;
   }
   if(slow_ma1 - Ask >0 && slow_ma1 - Ask<40*sx*Point){
      if((TimeCurrent()-prev_order_time)/60<30*Period()){
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
          OrderDeleted=OrderClose(ord_arr[j],ord_arrlots[j],Bid,5,Red);
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
void getTradeInfo(){
    strComment = strVer;
    strComment += " -----------------------> "+Symbol();
    strComment += "\n请认真确认3条均线值:"+fastMa+"|"+slowMa+"|"+slowerMa;
    //strComment += "\n买入价："+Bid;
    //strComment += "\n卖出价："+Ask;
    strComment += "\n交易方向："+tradeType;
    strComment += "\n账户余额："+AccountBalance();
    strComment += "\n账户净值："+AccountEquity();
    strComment += "\n可用保证金："+AccountFreeMargin();
    strComment += "\n杠杆："+AccountLeverage();
    strComment += "\n点差："+getAsk_Bid()/Point;
    strComment += "\n今天周几："+DayOfWeek();
    strComment += "\n当前时间："+Hour()+":"+Minute();
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